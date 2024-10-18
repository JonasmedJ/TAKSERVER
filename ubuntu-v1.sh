#!/bin/bash

# Check if the script is run with sudo or as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo."
  exit 1
fi

# Get the current user's username
current_user="$SUDO_USER"

# Your script here, using $current_user wherever you need the username
echo "
Hello! This an install script for a TAK server, utilizing Ubuntu 22.04, and a couple of other dependencies. 

It is recommended to be at least somewhat advanced when it comes to Ubuntu. 

During the script there will be some popups marked with ***. Please pay attention and read these, as the input can influence the script.


**Please ensure that the required files for Ubuntu are in your /home/user/Downloads folder, just to be certain.

Required files:
- takserver_5.2-RELEASE16_all.deb (or newer)
- takserver-public-gpg.key
- deb_policy.pol
"

# Get user to acknowledge script start
acknowledge_start=""
while [ "$acknowledge_start" != "y" ]; do
  read -p "
Do you want to proceed with the script? (y/n): " acknowledge_start
  acknowledge_start=$(echo "$acknowledge_start" | tr '[:upper:]' '[:lower:]')
  if [ "$acknowledge_start" != "y" ]; then
    echo "
  Please rerun the script when you are ready."
    exit 1
  fi
done

# Get user to acknowledge script start
acknowledge_files_location=""
while [ "$acknowledge_files_location" != "y" ]; do
  read -p "
Are your files located in the Downloads folder? (y/n): " acknowledge_files_location
  acknowledge_files_location=$(echo "$acknowledge_files_location" | tr '[:upper:]' '[:lower:]')
  if [ "$acknowledge_files_location" != "y" ]; then
    echo "
  Please move the files to your Downloads folder or ignore this message, and just type "yes" next time."
  fi
done

# Ask the user about 'deb_policy.pol'
deb_policy_response=""
while [ "$deb_policy_response" != "y" ]; do
  read -p "
Have you downloaded 'deb_policy.pol'? (y/n): " deb_policy_response
  deb_policy_response=$(echo "$deb_policy_response" | tr '[:upper:]' '[:lower:]')
  if [ "$deb_policy_response" != "y" ]; then
    echo "
    Please download 'deb_policy.pol' before proceeding."
  fi
done

# Ask the user about 'takserver-public-gpg.key'
gpg_key_response=""
while [ "$gpg_key_response" != "y" ]; do
  read -p "
Have you downloaded 'takserver-public-gpg.key'? (y/n): " gpg_key_response
  gpg_key_response=$(echo "$gpg_key_response" | tr '[:upper:]' '[:lower:]')
  if [ "$gpg_key_response" != "y" ]; then
    echo "
    Please download 'takserver-public-gpg.key' before proceeding."
  fi
done

# Ask the user about the latest version of 'takserver'
takserver_response=""
while [ "$takserver_response" != "y" ]; do
  read -p "
Have you downloaded the latest version of 'takserver'? (y/n): " takserver_response
  takserver_response=$(echo "$takserver_response" | tr '[:upper:]' '[:lower:]')
  if [ "$takserver_response" != "y" ]; then
    echo "
    Please download the latest version of 'takserver' before proceeding."
  fi
done

# All required files are present; you can proceed with your script here
echo "
All required files are present. Proceed with your script."

# Get user to acknowledge download requirements
acknowledge_reqs=""
while [ "$acknowledge_reqs" != "y" ]; do
  read -p "
TAK server requires some preliminary programs, e.g. curl, vim and java. Do you wish to proceed? (y/n): " acknowledge_reqs
  acknowledge_reqs=$(echo "$acknowledge_reqs" | tr '[:upper:]' '[:lower:]')
  if [ "$acknowledge_reqs" != "y" ]; then
    echo "
These files are required, as they are needed for installing the server."
    exit 1
  fi
done


#preliminary requirements:

#install curl
sudo apt install curl -y

#install java
sudo apt install default-jre -y

#install vim
sudo apt install vim -y

# Verify Deb signature for takserver
sudo apt install debsig-verify -y

# Define the directory to search in (you may want to specify a more targeted directory)
SEARCH_DIR="/"

# Use 'find' to locate the deb_policy.pol file
POLICY_FILE=$(find "$SEARCH_DIR" -type f -name "deb_policy.pol" 2>/dev/null | head -n 1)

if [[ -n "$POLICY_FILE" ]]; then
  echo "Found deb_policy.pol file at: $POLICY_FILE"
  
  # Use grep and sed to extract the first id from the line
  id_input=$(grep 'id="' "$POLICY_FILE" | sed -n 's/.*id="\([^"]*\)".*/\1/p' | head -n 1)

  if [[ -n "$id_input" ]]; then
    echo "the ID found in the deb_policy.pol file is: $id_input"
    # Proceed with your script logic
  else
    echo "No ID found in the deb_policy.pol file."
  fi
else
  echo "deb_policy.pol file not found."
fi

    sudo mkdir -p /usr/share/debsig/keyrings/$id_input
    
    sudo mkdir -p /etc/debsig/policies/$id_input

    # Create the GPG key file
    sudo touch /usr/share/debsig/keyrings/$id_input/debsig.gpg

    # Import the GPG key
    if [ -f "/home/$current_user/Downloads/takserver-public-gpg.key" ]; then
      sudo gpg --no-default-keyring --keyring /usr/share/debsig/keyrings/$id_input/debsig.gpg --import /home/$current_user/Downloads/takserver-public-gpg.key
    else
      echo "GPG key file not found: /home/$current_user/Downloads/takserver-public-gpg.key"
      exit 1
    fi

    # Copy the policy file
    if [ -f "/home/$current_user/Downloads/deb_policy.pol" ]; then
      sudo cp /home/$current_user/Downloads/deb_policy.pol /etc/debsig/policies/$id_input/debsig.pol
      echo "Policy file copied to /etc/debsig/policies/$id_input/debsig.pol"
    else
      echo "Policy file not found: /home/$current_user/Downloads/deb_policy.pol"
      exit 1
    fi

#!/bin/bash

# Search for the TAK server .deb file (search the system or home directory)
takserver_file=$(find "$SEARCH_DIR" -name 'takserver_*_all.deb' -print -quit 2>/dev/null)

# Check if a TAK server file was found
if [[ -n "$takserver_file" ]]; then
    echo "Found TAK server file: $takserver_file"
    
    # Extract the version part from the filename
    if [[ $takserver_file =~ takserver_([0-9]+\.[0-9]+)-RELEASE[0-9]+_all\.deb ]]; then
        takserver_version="${BASH_REMATCH[1]}"
        echo "Found TAK server version: $takserver_version"

        # Compare the version to 5.2 using sort -V for proper version comparison
        if [[ $(printf '%s\n' "$takserver_version" "5.2" | sort -V | head -n 1) != "5.2" ]]; then
            # Version is below 5.2, prompt with a warning
            echo "Warning: TAK server version is old (below 5.2)."
            read -p "Do you want to continue anyway? (yes/no): " choice
            if [[ "$choice" != "yes" ]]; then
                echo "Aborting due to old TAK server version."
                exit 1
            fi
        fi

        # Use the full path to the .deb file here (not just the version)
        echo "Proceeding with TAK server installation for $takserver_file..."
        # Example command that uses the full file path
        sudo debsig-verify "$takserver_file"
    else
        echo "TAK server file does not match expected pattern."
        exit 1
    fi
else
    echo "TAK server file not found."
    exit 1
fi


# Verify the package
debsig-verify -v $takserver_file

# Increase the number of TCP connections
echo -e "* soft nofile 32768\n* hard nofile 32768" | sudo tee --append /etc/security/limits.conf > /dev/null

# Set up PostgreSQL repository
sudo mkdir -p /etc/apt/keyrings

sudo curl https://www.postgresql.org/media/keys/ACCC4CF8.asc --output /etc/apt/keyrings/postgresql.asc

sudo sh -c 'echo "deb [signed-by=/etc/apt/keyrings/postgresql.asc] http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/postgresql.list'

# Update and install takserver
sudo apt update && sudo apt upgrade

sudo apt install $takserver_file

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

# Display certificate metadata instructions
echo "

*****IMPORTANT, READ BELOW*****

- You should edit the Cert-metadata.sh file with your specifics. 

- Be aware of the following:

The Country part cannot be longer than two letters
The password should replace 'atakatak'
The password cannot be longer than 10 characters
The password cannot contain unique characters.

"

# Prompt user for confirmation
confirmation=""
while [ "$confirmation" != "y" ]; do
  read -p "
Have you read and understood the instructions above? (y/n): " confirmation
  confirmation=$(echo "$confirmation" | tr '[:upper:]' '[:lower:]')
  if [ "$confirmation" != "y" ]; then
    echo "
Please take a moment to read the instructions before proceeding."
  fi
done

# Define the filename
certmetadata="/opt/tak/certs/cert-metadata.sh"

# Check if the file exists
if [ -e "$certmetadata" ]; then
    while true; do
        # Ask the user which text editor to use
        read -p "
        Do you want to edit '$certmetadata' using Nano (N) or Vim (V)? [N/v] " choice

        # Convert the choice to lowercase for case-insensitive comparison
        choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

        case "$choice" in
            "v")
                vim "$certmetadata"
                break
                ;;
            "n")
                nano "$certmetadata"
                break
                ;;
            *)
                echo "Invalid choice. Please select 'N' for Nano or 'V' for Vim."
                ;;
        esac
    done
else
    echo "File '$certmetadata' does not exist."
fi


# Prompt the user for the RootCA name
echo -n "
Enter the RootCA name you want, eg. Root-CA-01: "
read -r root_ca_name

# Run the makeRootCa.sh script with the provided name
sudo su tak -c "cd /opt/tak/certs && ./makeRootCa.sh --ca-name '$root_ca_name' < cert-metadata.sh < config.cfg"

# Prompt the user for the Intermediate CA name
echo -n "
Enter the name for an Intermediate CA (This is required for Certificate Enrollment) eg. intermediate-ca-01: "
read -r intermediate_ca_name

# Run the makeCert.sh script in order to create an intermediate CA
sudo su tak -c "cd /opt/tak/certs && ./makeCert.sh ca '$intermediate_ca_name' -y < cert-metadata.sh < config.cfg"

# Since I cannot script a better solution in at the moment, these "cp" commands are required, for the intermediate CA to take effect and control over newly generated certificates
cp /opt/tak/certs/files/$intermediate_ca_name.pem /opt/tak/certs/files/ca.pem
cp /opt/tak/certs/files/$intermediate_ca_name.key /opt/tak/certs/files/ca-do-not-share.key
cp /opt/tak/certs/files/$intermediate_ca_name-trusted.pem /opt/tak/certs/files/ca-trusted.pem

# Tell user that the cp commands are already completed
echo "
***Disregard this prompt, as this script has already transferred the ownership of the files for your intermediate CA.***"

# Wait for the takserver to restart
echo "
wait 1 minute for the server to reboot and changes to take effect"

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


# Prompt the user for their firewall choice
read -p "
Which Linux firewall are you using (ufw/unspecified)? " firewall_choice


# Function to prompt the user for firewall choice
ask_firewall_choice() {
    echo "Please select a firewall to configure (firewalld, UFW, or 'unspecified' for manual setup):"
    read -r firewall_choice
}

# Function to handle UFW setup (example function, replace with actual setup steps)
setup_ufw() {
    echo "Setting up UFW firewall..."
    # Add your UFW setup logic here
}

# Loop to keep prompting the user until a valid choice is made
while true; do
    ask_firewall_choice

    # Check the user's input and perform the setup accordingly
    case $firewall_choice in
        "UFW" | "ufw")
            setup_ufw
            break
            ;;
        "unspecified")
            echo "
            ***You have chosen to set up your firewall manually.***"
            echo "
            ***Please make sure to open port 8089, 8443, and 8446.***"
            break
            ;;
        *)
            echo "
            Unsupported firewall choice. Please select either 'UFW', or 'unspecified'."
            # The loop will continue since no valid choice was made
            ;;
    esac
done

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


echo "
TAK server installation complete. Please continue to your browser of choice, and install the admin.p12 file into the browser.

>> The admin.p12 file is located in your Documents folder, along with your intermediate CA.p12 file. <<

*** If you encounter this error: 
"Caused by: class org.apache.ignite.IgniteException: Failed to find deployed service: distributed-user-file-manager"

- This is due to services in the TAK service not being fully started yet. Either upgrade your hardware/VM, and run:

> sudo java -jar /opt/tak/utils/UserManager.jar certmod -A /opt/tak/certs/files/admin.pem

This may take a couple of tries, depending on your hardware specs. Sometimes a full reboot should suffice.***

Good luck with TAK!
"
