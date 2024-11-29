#!/bin/bash

# Function to prompt user with y/n and validate response
prompt_user() {
    local question="$1"
    local response
    read -p "$question (y/n): " response
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
    if [ "$response" != "y" ]; then
        echo "Aborted. $2"
        exit 1
    fi
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo."
    exit 1
fi

# Get the current user's username
current_user="$SUDO_USER"

# Your script here, using $current_user wherever you need the username
echo "Hello! This is an install script for a TAK server, utilizing Ubuntu 22.04, and a couple of other dependencies."
echo "As this is a script created by a newbie, it may run into some errors. Therefore, it is recommended to be at least somewhat advanced when it comes to Ubuntu. Good luck!"

# Prompt for required files
prompt_user "Have you downloaded 'deb_policy.pol'?" "Please download 'deb_policy.pol' before proceeding."
prompt_user "Have you downloaded 'takserver-public-gpg.key'?" "Please download 'takserver-public-gpg.key' before proceeding."
prompt_user "Have you downloaded the latest version of 'takserver'?" "Please download the latest version of 'takserver' before proceeding."

# All required files are present; you can proceed with your script here
echo "All required files are present. Proceed with your script."

# Install required packages
sudo apt install -y curl default-jre vim debsig-verify

# Ask for the ID to find deb_policy.pol ID
read -p "What ID is in your deb_policy.pol file? (e.g., F06237936851F5B5) " id_input

# Create directories and import GPG key
sudo mkdir -p "/usr/share/debsig/keyrings/$id_input"
sudo mkdir -p "/etc/debsig/policies/$id_input"
sudo gpg --no-default-keyring --keyring "/usr/share/debsig/keyrings/$id_input/debsig.gpg" --import "/home/takadmin/Downloads/takserver-public-gpg.key"
sudo cp "/home/$current_user/Downloads/deb_policy.pol" "/etc/debsig/policies/$id_input/debsig.pol"

# Ask for the takserver version to replace "x"
read -p "What version of takserver do you have? (e.g., 4.10-RELEASE12_all.deb): " takserver_version

# Verify the package
debsig-verify -v "/home/$current_user/Downloads/takserver_${takserver_version}"

# Increase the number of TCP connections
echo -e "* soft nofile 32768\n* hard nofile 32768" | sudo tee --append /etc/security/limits.conf > /dev/null

# Set up PostgreSQL repository
sudo mkdir -p /etc/apt/keyrings
sudo curl https://www.postgresql.org/media/keys/ACCC4CF8.asc --output /etc/apt/keyrings/postgresql.asc
sudo sh -c 'echo "deb [signed-by=/etc/apt/keyrings/postgresql.asc] http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/postgresql.list'

# Update and install takserver
sudo apt update
sudo apt install "/home/$current_user/Downloads/takserver_${takserver_version}"

# Check Java version
java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
if [[ "$java_version" < "17" ]]; then
  sudo apt install default-jre
fi

# Run takserver setup script
cd /~
sudo /opt/tak/db-utils/takserver-setup-db.sh
sudo systemctl daemon-reload
sudo systemctl start takserver
sudo systemctl enable takserver

echo "Wait 1 minute for the server to boot"

sleep 60

# Additional steps to set up certificates and configurations

# Prompt for certificate metadata

echo "*****IMPORTANT, READ BELOW*****
You should edit the Cert-metadata.sh file with your specifics. Be aware, the Country part cannot be longer than two letters, AND the password should replace atakatak, and cannot be longer than 10 characters, and cannot contain unique characters."

# Define the filename
filename1="/opt/tak/certs/cert-metadata.sh"

# Check if the file exists
if [ -e "$filename1" ]; then
    # Ask the user which text editor to use
    read -p "Do you want to edit '$filename1' using Nano (N) or Vim (V)? [N/v] " choice

    # Convert the choice to lowercase for case-insensitive comparison
    choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

    case "$choice" in
        "v")
            vim "$filename1"
            ;;
        "n")
            nano "$filename1"
            ;;
        *)
            echo "Invalid choice. No text editor launched."
            ;;
    esac
else
    echo "File '$filename1' does not exist."
fi

# Prompt the user for the RootCA name
echo -n "Enter the RootCA name you want, e.g., Root-CA-01: "
read -r root_ca_name

# Run the makeRootCa.sh script with the provided name
sudo su tak -c "cd /opt/tak/certs && ./makeRootCa.sh --ca-name '$root_ca_name' < cert-metadata.sh < config.cfg"

# Prompt the user for the Intermediate CA name
echo -n "Enter the name for an Intermediate CA (This is required for Certificate Enrollment), e.g., intermediate-ca: "
read -r intermediate_ca_name

# Run the makeCert.sh script to create an intermediate CA
sudo su tak -c "cd /opt/tak/certs && ./makeCert.sh ca '$intermediate_ca_name' -y < cert-metadata.sh < config.cfg"

# Restart the takserver for the intermediate certificate to take effect
sudo systemctl restart takserver

# Wait for the takserver to restart
echo "wait 1 minute for the server to reboot and changes to take effect"

sleep 60

# Create an Admin certificate to manage the server from the browser
sudo su tak -c "cd /opt/tak/certs && ./makeCert.sh client admin <cert-metadata.sh < config.cfg"

# Authorize the Admin certificate to perform administrative tasks
sudo java -jar /opt/tak/utils/UserManager.jar certmod -A /opt/tak/certs/files/admin.pem

# Configure CoreConfig.xml

# Define the filename
filename2="/opt/tak/CoreConfig.xml"

# Replace the "truststoreFile" attribute value
sed -i "s#truststoreFile=\"certs/files/truststore-root.jks\"#truststoreFile=\"certs/files/truststore-${intermediate_ca_name}.jks\"#" "$filename2"

# Extract the password from cert-metadata.sh
password_line=$(grep 'CAPASS=\${CAPASS:-' /opt/tak/certs/cert-metadata.sh)
if [ -n "$password_line" ]; then
    password=$(echo "$password_line" | sed -n 's/.*CAPASS=\${CAPASS:-\(.*\)}/\1/p')
    if [ -n "$password" ]; then
        echo "Password extracted successfully: $password"

         # Use sed to replace the old password with the new password in CoreConfig.xml
         sed -i "s|keystorePass=\"atakatak\"|keystorePass=\"$password\"|g" "$filename2"
         sed -i "s|truststorePass=\"atakatak\"|truststorePass=\"$password\"|g" "$filename2"

         echo "Passwords updated in CoreConfig.xml."

        # Check if the sed commands were successful
        if [ $? -eq 0 ]; then
            echo "Replacement completed successfully."
        else
            echo "Replacement failed."
        fi
    else
        echo "Password not found in cert-metadata.sh."
    fi
else
    echo "CAPASS variable not found in cert-metadata.sh."
fi

# Restart the TAK server to allow the changes to the CoreConfig to take place
sudo systemctl restart takserver

# Wait 1 minute to allow the server to reboot
echo "wait 1 minute for the server to reboot"

sleep 60

# Set up the firewall for the TAK server

# Function to set up UFW
setup_ufw() {
    echo "Setting up UFW..."
    
    # install UFW
    sudo apt install ufw
    
    # check if ufw is running
    sudo ufw status

    # deny incoming to block unknown users
    sudo ufw default deny incoming

    # open ufw to allow outgoing data
    sudo ufw default allow outgoing
    
    # start ufw
    sudo ufw enable

    # allow 8089 to allow users to access the server
    sudo ufw allow 8089
    
    # allow 8443 to access the user dashboard
    sudo ufw allow 8443
    
    # enable 8446 to allow clients to enroll for a certificate
    sudo ufw allow 8446
    echo "UFW setup complete."
}

# Prompt the user for their firewall choice
read -p "Which Linux firewall are you using (ufw/unspecified)? " firewall_choice

# Check the user's input and perform the setup accordingly
case $firewall_choice in
    "UFW" | "ufw")
        setup_ufw
        ;;
    "unspecified")
        echo "You have chosen to set up your firewall manually. Please proceed with your custom setup. Please make sure to open port 8089, 8443, and 8446."
        ;;
    *)
        echo "Unsupported firewall choice. Please select either 'firewalld', 'UFW', or 'unspecified'."
        ;;
esac

# Define the source directory
source_dir="/opt/tak/certs/files"

# Define the destination directory
destination_dir="/home/$current_user/Documents"

# Define the file names
admin_p12="admin.p12"
intermediate_p12="truststore-${intermediate_ca_name}.p12"

# Check if the source files exist
if [ -f "$source_dir/$admin_p12" ] && [ -f "$source_dir/$intermediate_p12" ]; then
  # Copy the admin.p12 file
  sudo cp "$source_dir/$admin_p12" "$destination_dir"
  # Copy the intermediate.p12 file
  sudo cp "$source_dir/$intermediate_p12" "$destination_dir"

  # Change ownership of the copied files to the current user
  sudo chown -v $current_user:$current_user "$destination_dir/$admin_p12"
  sudo chown -v $current_user:$current_user "$destination_dir/$intermediate_p12"
else
  echo "Source files not found. Make sure the source files exist in $source_dir."
fi

echo "TAK server installation complete. Please continue to your browser of choice, and install the admin.p12 file into the browser."
echo "The admin.p12 file is located in your Documents folder, along with your intermediate CA.p12 file."

