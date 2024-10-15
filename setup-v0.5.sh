#!/bin/bash

# Check if the script is run with sudo or as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo."
  exit 1
fi

# Get the current user's username
current_user="$SUDO_USER"

# Your script here, using $current_user wherever you need the username
echo "Hello! This an install script for a TAK server, utilizing Ubuntu 22.04, and a couple of other dependencies. As this is a script created by a newbie, it may run into some errors. Therefore it is recommended to be at least somewhat advanced when it comes to Ubuntu. During the script there will be some popups marked with ***. Please pay attention and read these, as the input can influence the script."

# Get user to acknowledge script start
read -p "Do you want to proceed with the script? (y/n): " acknowledge_start

acknowledge_start=$(echo "$acknowledge_start" | tr '[:upper:]' '[:lower:]')

if [ "$acknowledge_start" != "y" ]; then
	echo "Please rerun script, when you are ready."
	exit 1
fi

# Get user to acknowledge script start
read -p "Are your files located in the Downloads folder? (y/n): " acknowledge_files_location

acknowledge_files_location=$(echo "$acknowledge_files_location" | tr '[:upper:]' '[:lower:]')

if [ "$acknowledge_files_location" != "y" ]; then
	echo "Please rerun the script, when you've moved the files to your Downloads folder."
	exit 1
fi

# Ask the user about 'deb_policy.pol'
read -p "Have you downloaded 'deb_policy.pol'? (y/n): " deb_policy_response

# Convert the response to lowercase for case-insensitive comparison
deb_policy_response=$(echo "$deb_policy_response" | tr '[:upper:]' '[:lower:]')

if [ "$deb_policy_response" != "y" ]; then
    echo "Please download 'deb_policy.pol' before proceeding."
    exit 1
fi

# Ask the user about 'takserver-public-gpg.key'
read -p "Have you downloaded 'takserver-public-gpg.key'? (y/n): " gpg_key_response

# Convert the response to lowercase for case-insensitive comparison
gpg_key_response=$(echo "$gpg_key_response" | tr '[:upper:]' '[:lower:]')

if [ "$gpg_key_response" != "y" ]; then
    echo "Please download 'takserver-public-gpg.key' before proceeding."
    exit 1
fi

# Ask the user about the latest version of 'takserver'
read -p "Have you downloaded the latest version of 'takserver'? (y/n): " takserver_response

# Convert the response to lowercase for case-insensitive comparison
takserver_response=$(echo "$takserver_response" | tr '[:upper:]' '[:lower:]')

if [ "$takserver_response" != "y" ]; then
    echo "Please download the latest version of 'takserver' before proceeding."
    exit 1
fi

# All required files are present; you can proceed with your script here
echo "All required files are present. Proceed with your script."

# Get user to acknowledge download requirements
read -p "TAK server requires some preliminary programs, e.g. curl, vim and java. Do you wish to proceed? (y/n): " acknowledge_reqs

acknowledge_reqs=$(echo "$acknowledge_reqs" | tr '[:upper:]' '[:lower:]')

if [ "$acknowledge_reqs" != "y" ]; then
        echo "Please rerun script, when you are ready."
        exit 1
fi
#preliminary requirements:
#install curl
sudo apt install curl

#install java
sudo apt install default-jre

#install vim
sudo apt install vim

# Verify Deb signature for takserver
sudo apt install debsig-verify

# Define the directory to search in (e.g., the root directory or a specific path)
SEARCH_DIR="/"

# Use 'find' to locate the deb_policy.pol file
POLICY_FILE=$(find "$SEARCH_DIR" -type f -name "deb_policy.pol" 2>/dev/null | head -n 1)

# Check if the file was found
if [[ -n "$POLICY_FILE" ]]; then
  echo "Found deb_policy.pol file at: $POLICY_FILE"
  
  # Use grep and sed to extract the id from the line
  id_input=$(grep 'id="' "$POLICY_FILE" | sed -n 's/.*id="\([^"]*\)".*/\1/p')

  if [[ -n "$id_input" ]]; then
    echo "The ID found in the deb_policy.pol file is: $id_input"

    # Create directories if they do not exist
    if [ ! -d "/usr/share/debsig/keyrings/$id_input" ]; then
      sudo mkdir -p /usr/share/debsig/keyrings/$id_input
    fi

    if [ ! -d "/etc/debsig/policies/$id_input" ]; then
      sudo mkdir -p /etc/debsig/policies/$id_input
    fi

    # Create the GPG key file
    sudo touch /usr/share/debsig/keyrings/$id_input/debsig.gpg

    # Import the GPG key
    if [ -f "/home/$current_user/Downloads/takserver-public-gpg.key" ]; then
      sudo gpg --no-default-keyring --keyring /usr/share/debsig/keyrings/$id_input/debsig.gpg --import /home/$current_user/Downloads/takserver-public-gpg.key
    else
      echo "GPG key file not found: /home/$current_user/Downloads/takserver-public-gpg.key"
    fi

    # Copy the policy file
    sudo cp /home/$current_user/Downloads/deb_policy.pol /etc/debsig/policies/$id_input/debsig.pol
  else
    echo "ID not found in the deb_policy.pol file."
  fi
else
  echo "deb_policy.pol file not found."
fi

# Search for the TAK server .deb file
takserver_file=$(find /path/to/directory -name 'takserver_*_all.deb' -print -quit)

# Extract the version part from the filename
if [[ $takserver_file =~ takserver_([0-9]+\.[0-9]+)-RELEASE[0-9]+_all\.deb ]]; then
    takserver_version="${BASH_REMATCH[1]}"
    echo "Found TAK server version: $takserver_version"

    # Compare the version to 5.2
    if [[ $(echo "$takserver_version 5.2" | awk '{print ($1 < $2)}') -eq 1 ]]; then
        # Version is below 5.2, prompt with a warning
        echo "Warning: TAK server version is old (below 5.2)."
        read -p "Do you want to continue anyway? (yes/no): " choice
        if [[ "$choice" != "yes" ]]; then
            echo "Aborting due to old TAK server version."
            exit 1
        fi
    fi
else
    echo "TAK server file not found or does not match expected pattern."
    exit 1
fi

# Verify the package
debsig-verify -v /home/$current_user/Downloads/takserver_${takserver_version}

# Increase the number of TCP connections
echo -e "* soft nofile 32768\n* hard nofile 32768" | sudo tee --append /etc/security/limits.conf > /dev/null

# Set up PostgreSQL repository
sudo mkdir -p /etc/apt/keyrings
sudo curl https://www.postgresql.org/media/keys/ACCC4CF8.asc --output /etc/apt/keyrings/postgresql.asc
sudo sh -c 'echo "deb [signed-by=/etc/apt/keyrings/postgresql.asc] http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/postgresql.list'

# Update and install takserver
sudo apt update
sudo apt install /home/$current_user/Downloads/takserver_${takserver_version}

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

echo "

*****IMPORTANT, READ BELOW*****

- You should edit the Cert-metadata.sh file with your specifics. 

- Be aware, the Country part cannot be longer than two letters, AND the password should replace atakatak, and cannot be longer than 10 characters, and cannot contain unique characters.


"

# Define the filename
certmetadata="/opt/tak/certs/cert-metadata.sh"

# Check if the file exists
if [ -e "$certmetadata" ]; then
    # Ask the user which text editor to use
    read -p "Do you want to edit '$certmetadata' using Nano (N) or Vim (V)? [N/v] " choice

    # Convert the choice to lowercase for case-insensitive comparison
    choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

    case "$choice" in
        "v")
            vim "$certmetadata"
            ;;
        "n")
            nano "$certmetadata"
            ;;
        *)
            echo "Invalid choice. No text editor launched."
            ;;
    esac
else
    echo "File '$certmetadata' does not exist."
fi

# Prompt the user for the RootCA name
echo -n "Enter the RootCA name you want, eg. Root-CA-01: "
read -r root_ca_name

# Run the makeRootCa.sh script with the provided name
sudo su tak -c "cd /opt/tak/certs && ./makeRootCa.sh --ca-name '$root_ca_name' < cert-metadata.sh < config.cfg"

# Prompt the user for the Intermediate CA name
echo -n "Enter the name for an Intermediate CA (This is required for Certificate Enrollment) eg. intermediate-ca-01: "
read -r intermediate_ca_name

# Run the makeCert.sh script in order to create an intermediate CA
sudo su tak -c "cd /opt/tak/certs && ./makeCert.sh ca '$intermediate_ca_name' -y < cert-metadata.sh < config.cfg"

# Since I cannot script a better solution in at the moment, these "cp" commands are required, for the intermediate CA to take effect and control over newly generated certificates
cp /opt/tak/certs/files/$intermediate_ca_name.pem /opt/tak/certs/files/ca.pem
cp /opt/tak/certs/files/$intermediate_ca_name.key /opt/tak/certs/files/ca-do-not-share.key
cp /opt/tak/certs/files/$intermediate_ca_name-trusted.pem /opt/tak/certs/files/ca-trusted.pem

# Tell user that the cp commands are already completed
echo "***Disregard this prompt, as this script has already transferred the ownership of the files for your intermediate CA.***"

# Wait for the takserver to restart
echo "wait 1 minute for the server to reboot and changes to take effect"

# Restart the takserver for the intermediate certificate to take effect
sudo systemctl restart takserver

sleep 60

# Create a certificate for the TAK server
sudo su tak -c "cd /opt/tak/certs && ./makeCert.sh server takserver < cert-metadata.sh < config.cfg"

# Create an Admin certificate, to be able to manage the server from the browser
sudo su tak -c "cd /opt/tak/certs && ./makeCert.sh client admin < cert-metadata.sh < config.cfg"

# Authorize the Admin certificate to be able to perform administrative tasks
sudo java -jar /opt/tak/utils/UserManager.jar certmod -A /opt/tak/certs/files/admin.pem

# Configure CoreConfig.xml

# Define the filename
coreconfig="/opt/tak/CoreConfig.xml"

# Replace the "truststoreFile" attribute value
sed -i "s#truststoreFile=\"certs/files/truststore-root.jks\"#truststoreFile=\"certs/files/truststore-${intermediate_ca_name}.jks\"#" "$coreconfig"

# Extract the password from cert-metadata.sh
password_line=$(grep 'CAPASS=\${CAPASS:-' /opt/tak/certs/cert-metadata.sh)
if [ -n "$password_line" ]; then
    password=$(echo "$password_line" | sed -n 's/.*CAPASS=\${CAPASS:-\(.*\)}/\1/p')
    if [ -n "$password" ]; then
        echo "Password extracted successfully: $password"

         # Use sed to replace the old password with the new password in CoreConfig.xml
         sed -i "s|keystorePass=\"atakatak\"|keystorePass=\"$password\"|g" "$coreconfig"
         sed -i "s|truststorePass=\"atakatak\"|truststorePass=\"$password\"|g" "$coreconfig"

         echo "Passwords updated in CoreConfig.xml."

        # Check if the sed commands were successful
        if [ $? -eq 0 ]; then
            echo "CoreConfig updated successfully."
        else
            echo "Replacement failed."
        fi
    else
        echo "Password not found in cert-metadata.sh."
    fi
else
    echo "CAPASS variable not found in cert-metadata.sh."
fi

# Restart the TAK server, to allow the changes to the CoreConfig to take place
sudo systemctl restart takserver

# Wait 1 minute to allow the server to reboot
echo "wait 1 minute for the server to reboot"

sleep 60

# Set up firewall for the TAKserver

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
        echo "You have chosen to set up your firewall manually. Please proceed with your custom setup. Please make sure to open port 8089, 8443 and 8446."
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


echo "TAK server installation complete. Please continue to your browser of choice, and install the admin.p12 file into the browser.
The admin.p12 file is located in your Documents folder, along with your intermediate CA.p12 file."
