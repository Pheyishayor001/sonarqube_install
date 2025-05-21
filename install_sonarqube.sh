#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Update and upgrade system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Check and Install PostgreSQL
if command_exists psql; then
    echo "PostgreSQL is already installed."
else
    echo "Installing PostgreSQL..."
    sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo tee /etc/apt/trusted.gpg.d/pgdg.asc &>/dev/null
    sudo apt update
    sudo apt-get -y install postgresql postgresql-contrib
    sudo systemctl enable postgresql
fi

# Configure PostgreSQL for SonarQube
echo "Configuring PostgreSQL for SonarQube..."
sudo passwd postgres
sudo -i -u postgres bash <<EOF
if psql -lqt | cut -d \| -f 1 | grep -qw sonarqube; then
    echo "SonarQube database already exists."
else
    createuser sonar
    psql -c "ALTER USER sonar WITH ENCRYPTED PASSWORD 'sonar';"
    createdb -O sonar sonarqube
    psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;"
fi
EOF

# Check and Install Java 17
if command_exists java && [[ "$(java -version 2>&1)" == *"17."* ]]; then
    echo "Java 17 is already installed."
else
    echo "Installing Java 17..."
    sudo apt install -y wget apt-transport-https
    mkdir -p /etc/apt/keyrings
    wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo tee /etc/apt/keyrings/adoptium.asc
    echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | sudo tee /etc/apt/sources.list.d/adoptium.list
    sudo apt update
    sudo apt install -y temurin-17-jdk
fi

# Set system limits
echo "Configuring system limits..."
if ! grep -q "sonarqube   -   nofile   65536" /etc/security/limits.conf; then
    echo "sonarqube   -   nofile   65536" | sudo tee -a /etc/security/limits.conf
    echo "sonarqube   -   nproc    4096" | sudo tee -a /etc/security/limits.conf
fi

if ! grep -q "vm.max_map_count = 262144" /etc/sysctl.conf; then
    echo "vm.max_map_count = 262144" | sudo tee -a /etc/sysctl.conf
fi

sudo sysctl -p

# Download and Install SonarQube
if [ ! -d "/opt/sonarqube" ]; then
    echo "Downloading and installing SonarQube..."
    wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-25.5.0.107428.zip
    sudo apt install unzip -y
    sudo unzip sonarqube-25.5.0.107428.zip -d /opt
    sudo mv /opt/sonarqube-25.5.0.107428 /opt/sonarqube
else
    echo "SonarQube is already downloaded and installed."
fi

# Create SonarQube group and user if not already existing
if ! id -u sonar &>/dev/null; then
    echo "Creating SonarQube user and group..."
    sudo groupadd sonar
    sudo useradd -c "User to run SonarQube" -d /opt/sonarqube -g sonar sonar
    sudo chown sonar:sonar /opt/sonarqube -R
else
    echo "SonarQube user and group already exist."
fi

# Configure SonarQube database settings
echo "Configuring SonarQube database settings..."
sudo sed -i '/^sonar.jdbc.username/ s/^#//' /opt/sonarqube/conf/sonar.properties
sudo sed -i '/^sonar.jdbc.password/ s/^#//' /opt/sonarqube/conf/sonar.properties
sudo sed -i "/^sonar.jdbc.username/ s/=.*/=sonar/" /opt/sonarqube/conf/sonar.properties
sudo sed -i "/^sonar.jdbc.password/ s/=.*/=sonar/" /opt/sonarqube/conf/sonar.properties

if ! grep -q "sonar.jdbc.url" /opt/sonarqube/conf/sonar.properties; then
    echo "sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonarqube" | sudo tee -a /opt/sonarqube/conf/sonar.properties
fi

# Set up SonarQube as a systemd service
if [ ! -f "/etc/systemd/system/sonar.service" ]; then
    echo "Creating SonarQube systemd service..."
    sudo bash -c 'cat <<EOF > /etc/systemd/system/sonar.service
[Unit]
Description=SonarQube service
After=syslog.target network.target
[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonar
Group=sonar
Restart=always
LimitNOFILE=65536
LimitNPROC=4096
[Install]
WantedBy=multi-user.target
EOF'
else
    echo "SonarQube systemd service file already exists."
fi

# Start and enable SonarQube service
echo "Starting and enabling SonarQube service..."
sudo systemctl daemon-reload
sudo systemctl start sonar
sudo systemctl enable sonar
sudo systemctl status sonar -l
