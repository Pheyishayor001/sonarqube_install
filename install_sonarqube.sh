#!/bin/bash

# Script to install and configure SonarQube on Ubuntu 22.04
# Requirements: T2.medium, 4GB RAM, PostgreSQL 15, JDK 17, Port 9000 open

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "Please run this script as root or using sudo."
  exit 1
fi

# Update and upgrade the system
echo "Updating and upgrading the system..."
apt update && apt upgrade -y

# Install PostgreSQL 15
echo "Installing PostgreSQL 15..."
sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | tee /etc/apt/trusted.gpg.d/pgdg.asc &>/dev/null
apt update
apt-get -y install postgresql postgresql-contrib

# Enable PostgreSQL to start at boot
echo "Enabling PostgreSQL to start on boot..."
systemctl enable postgresql

# Configure PostgreSQL for SonarQube
echo "Configuring PostgreSQL for SonarQube..."
sudo -u postgres psql -c "CREATE USER sonar WITH ENCRYPTED PASSWORD 'sonar';"
sudo -u postgres psql -c "CREATE DATABASE sonarqube OWNER sonar;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;"

# Install JDK 17
echo "Installing Temurin JDK 17..."
mkdir -p /etc/apt/keyrings
wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | tee /etc/apt/keyrings/adoptium.asc
echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/adoptium.list
apt update
apt install -y temurin-17-jdk

# Set resource limits for SonarQube
echo "Setting resource limits for SonarQube..."
cat <<EOL >> /etc/security/limits.conf
sonarqube   -   nofile   65536
sonarqube   -   nproc    4096
EOL

cat <<EOL >> /etc/sysctl.conf
vm.max_map_count = 262144
EOL
# Apply new sysctl settings without rebooting
sysctl -p

# Download and Install SonarQube
echo "Downloading and installing SonarQube..."
cd /tmp
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.0.65466.zip
apt install -y unzip
unzip sonarqube-9.9.0.65466.zip -d /opt
mv /opt/sonarqube-9.9.0.65466 /opt/sonarqube

# Create a SonarQube group and user
echo "Creating SonarQube user and group..."
groupadd sonar
useradd -c "user to run SonarQube" -d /opt/sonarqube -g sonar sonar
chown -R sonar:sonar /opt/sonarqube

# Configure SonarQube database connection
echo "Configuring SonarQube database connection..."
sed -i 's/#sonar.jdbc.username=.*/sonar.jdbc.username=sonar/' /opt/sonarqube/conf/sonar.properties
sed -i 's/#sonar.jdbc.password=.*/sonar.jdbc.password=sonar/' /opt/sonarqube/conf/sonar.properties
echo "sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonarqube" >> /opt/sonarqube/conf/sonar.properties

# Create a systemd service for SonarQube
echo "Creating systemd service for SonarQube..."
cat <<EOL > /etc/systemd/system/sonar.service
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
EOL

# Start and enable SonarQube service
echo "Starting and enabling SonarQube service..."
systemctl start sonar
systemctl enable sonar

# Confirm the SonarQube status
echo "Checking SonarQube service status..."
systemctl status sonar
tail -f /opt/sonarqube/logs/sonar.log
