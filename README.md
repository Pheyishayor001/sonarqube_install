# SonarQube Installation Script

This script automates the installation and configuration of SonarQube on an Ubuntu 22.04 server with PostgreSQL 15 and Adoptium Temurin JDK 17. Follow the steps below to use the script.

## Requirements

- **OS**: Ubuntu 22.04
- **Server Specs**: T2.medium instance with 4 GB RAM
- **Database**: PostgreSQL 15
- **Java**: Adoptium Temurin JDK 17
- **Port**: Ensure port 9000 is open in the server's security group for SonarQube access.

### Prerequisites

Before running the script, make sure you have:

1. **Access to the Ubuntu instance** via SSH.
2. **sudo privileges** on the server to install packages and configure services.

## Usage

1. **Clone the Repository** (if hosted on GitHub):
    ```bash
    git clone https://github.com/Pheyishayor001/sonarqube_install.git
    cd sonarqube_install
    ```

2. **Run the Script**:
    Make the script executable and run it:
    ```bash
    chmod +x install_sonarqube.sh
    ./install_sonarqube.sh
    ```

3. **Script Workflow**:
    The script performs the following actions:
    - Updates the system packages.
    - Installs PostgreSQL 15, configures the database for SonarQube, and creates the `sonarqube` database and user.
    - Installs Adoptium Temurin JDK 17.
    - Configures system limits required for SonarQube.
    - Downloads and installs SonarQube, configures it to use the PostgreSQL database, and sets it up as a system service.

4. **Verify Installation**:
    - Check the SonarQube service status:
      ```bash
      sudo systemctl status sonar
      ```
    - If running, you can access SonarQube at `http://<server-ip>:9000`.

5. **Logs**:
    - To view SonarQube logs:
      ```bash
      sudo tail -f /opt/sonarqube/logs/sonar.log
      ```

## Configuration Details

### SonarQube Database Configuration
The script configures SonarQube to use PostgreSQL with the following credentials:
- **Database Name**: `sonarqube`
- **Username**: `sonar`
- **Password**: `sonar`

### System Limits
The following system limits are applied to meet SonarQube requirements:
- **Open files**: 65536
- **Max user processes**: 4096

## Notes

- **Network Configuration**: Ensure port 9000 is open in your security group to access SonarQube from your browser.
- **Reboot**: The server will be rebooted to apply the system limits changes.

## Troubleshooting

- **Service Status**: If SonarQube is not running, check the service status and logs for errors.
- **Database Connectivity**: Ensure PostgreSQL is running and accessible by the `sonar` user with the correct password.

## Contributing

Feel free to open issues or contribute by submitting a pull request if you encounter any issues or improvements.

## License

This project is licensed under the MIT License.
