#!/bin/bash

# Ensure the script is run with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root using sudo."
    exit 1
fi

# Function to install TAK server on Ubuntu
install_tak_server() {
    echo "Installing TAK server on Ubuntu..."
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
while true; do
  read -p "
Have you read and understood the instructions above? (y/n): " confirmation
  confirmation=$(echo "$confirmation" | tr '[:upper:]' '[:lower:]')

  if [ "$confirmation" == "y" ]; then
    break
  elif [ "$confirmation" == "n" ]; then
    echo "
Please take a moment to read the instructions before proceeding."
  else
    echo "Invalid input. Please enter 'y' for yes or 'n' for no."
  fi
done


# Define the filename
certmetadata="/opt/tak/certs/cert-metadata.sh"

# Check if the file exists and if the script has write permissions
if [ ! -e "$certmetadata" ]; then
    echo "File '$certmetadata' does not exist."
    exit 1
elif [ ! -w "$certmetadata" ]; then
    echo "No write permission to '$certmetadata'. Please check your file permissions."
    exit 1
fi

# Function to confirm user input
confirm() {
    while true; do
        read -p "Is this correct? (yes/no): " CONFIRM
        case $CONFIRM in
            [Yy][Ee][Ss]) return 0 ;;
            [Nn][Oo]) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Prompt the user for details to replace in the cert-metadata

# Ensure COUNTRY input is exactly 2 letters
while true; do
    read -p "
    Input your country (MAX 2 letters): " COUNTRY
    if [[ "$COUNTRY" =~ ^[a-zA-Z]{2}$ ]]; then
        COUNTRY=$(echo "$COUNTRY" | tr '[:lower:]' '[:upper:]')
        echo "Country: $COUNTRY"
        confirm && break
    else
        echo "Country must be exactly 2 letters (no numbers or special characters)."
    fi
done

# Prompt and confirm each variable
while true; do
    read -p "
Input your state: " STATE
    echo "State: $STATE"
    confirm && break
done

while true; do
    read -p "
Input your city: " CITY
    echo "City: $CITY"
    confirm && break
done

while true; do
    read -p "
Input your organization: " ORGANIZATION
    echo "Organization: $ORGANIZATION"
    confirm && break
done

while true; do
    read -p "
Input your unit: " ORGANIZATIONAL_UNIT
    echo "Organizational Unit: $ORGANIZATIONAL_UNIT"
    confirm && break
done

# Ensure password constraints
while true; do
    read -p "What password should be used for your certificates? (max 15 characters, only letters and numbers): " PASS
    if [[ ${#PASS} -le 15 && "$PASS" =~ ^[a-zA-Z0-9]+$ ]]; then
        echo "Password: $PASS"
        confirm && break
    else
        echo "Password must be at most 15 characters long and contain only letters and numbers."
    fi
done

# Substitute the variables in the cert-metadata script
COUNTRY_ESCAPED=$(echo "$COUNTRY" | sed 's/[&/\]/\\&/g')
STATE_ESCAPED=$(echo "$STATE" | sed 's/[&/\]/\\&/g')
CITY_ESCAPED=$(echo "$CITY" | sed 's/[&/\]/\\&/g')
ORGANIZATION_ESCAPED=$(echo "$ORGANIZATION" | sed 's/[&/\]/\\&/g')
ORGANIZATIONAL_UNIT_ESCAPED=$(echo "$ORGANIZATIONAL_UNIT" | sed 's/[&/\]/\\&/g')
PASS_ESCAPED=$(echo "$PASS" | sed 's/[&/\]/\\&/g')

# Replace variables in the cert-metadata file
sed -i "s/^COUNTRY=.*/COUNTRY=$COUNTRY_ESCAPED/" "$certmetadata"
sed -i "s/^STATE=.*/STATE=$STATE_ESCAPED/" "$certmetadata"
sed -i "s/^CITY=.*/CITY=$CITY_ESCAPED/" "$certmetadata"
sed -i "s/^ORGANIZATION=.*/ORGANIZATION=$ORGANIZATION_ESCAPED/" "$certmetadata"
sed -i "s/^ORGANIZATIONAL_UNIT=.*/ORGANIZATIONAL_UNIT=$ORGANIZATIONAL_UNIT_ESCAPED/" "$certmetadata"

# Replace the password in the CAPASS line
if grep -q '^CAPASS=' "$certmetadata"; then
    sed -i "s/\(CAPASS=\${CAPASS:-\)[^}]*\}/\1$PASS_ESCAPED}/" "$certmetadata"
    echo "Password in CAPASS has been updated."
else
    echo "'CAPASS' not found in $certmetadata. Please check the file content."
fi

echo "cert-metadata.sh has been updated."


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


}

# Function to recreate certificates
recreate_certificates() {
    echo "Recreating certificates..."
# Get the current user's username
current_user="$SUDO_USER"


# Display certificate metadata instructions
echo "
*****IMPORTANT, READ BELOW*****

Botched your certificates, and want to create new ones? 

***This will replace your full certificate chain, and alter your CoreConfig.xml***

Well you're in luck!

- Be aware of the following:

The Country part cannot be longer than two letters
The password should replace 'atakatak'
The password cannot be longer than 10 characters
The password cannot contain unique characters.

"

# Prompt user for confirmation

confirmation=""
while true; do
  read -p "
Have you read and understood the instructions above? (y/n): " confirmation
  confirmation=$(echo "$confirmation" | tr '[:upper:]' '[:lower:]')

  if [ "$confirmation" == "y" ]; then
    break
  elif [ "$confirmation" == "n" ]; then
    echo "
Please take a moment to read the instructions before proceeding."
  else
    echo "Invalid input. Please enter 'y' for yes or 'n' for no."
  fi
done

sudo rm -r /opt/tak/certs/files

sudo mkdir /opt/tak/certs/files

sudo chown -v tak:tak /opt/tak/certs/files


# Define the filename
certmetadata="/opt/tak/certs/cert-metadata.sh"

# Check if the file exists and if the script has write permissions
if [ ! -e "$certmetadata" ]; then
    echo "File '$certmetadata' does not exist."
    exit 1
elif [ ! -w "$certmetadata" ]; then
    echo "No write permission to '$certmetadata'. Please check your file permissions."
    exit 1
fi

# Prompt the user for details to replace in the cert-metadata

# Ensure COUNTRY input is exactly 2 letters
while true; do
    read -p "
    Input your country (MAX 2 letters): " COUNTRY
    if [[ "$COUNTRY" =~ ^[a-zA-Z]{2}$ ]]; then
        # Convert to uppercase (optional)
        COUNTRY=$(echo "$COUNTRY" | tr '[:lower:]' '[:upper:]')
        break
    else
        echo "Country must be exactly 2 letters (no numbers or special characters)."
    fi
done

read -p "
    Input your state: " STATE
read -p "
    Input your city: " CITY
read -p "
    Input your organization: " ORGANIZATION
read -p "
    Input your unit: " ORGANIZATIONAL_UNIT

# Ensure password constraints
while true; do
    read -p "What password should be used for your certificates? (max 15 characters, only letters and numbers): " PASS
    if [[ ${#PASS} -le 15 && "$PASS" =~ ^[a-zA-Z0-9]+$ ]]; then
        break
    else
        echo "Password must be at most 15 characters long and contain only letters and numbers."
    fi
done

# Substitute the variables in the cert-metadata script
# Escape any special characters in variables to avoid issues with sed
COUNTRY_ESCAPED=$(echo "$COUNTRY" | sed 's/[&/\]/\\&/g')
STATE_ESCAPED=$(echo "$STATE" | sed 's/[&/\]/\\&/g')
CITY_ESCAPED=$(echo "$CITY" | sed 's/[&/\]/\\&/g')
ORGANIZATION_ESCAPED=$(echo "$ORGANIZATION" | sed 's/[&/\]/\\&/g')
ORGANIZATIONAL_UNIT_ESCAPED=$(echo "$ORGANIZATIONAL_UNIT" | sed 's/[&/\]/\\&/g')
PASS_ESCAPED=$(echo "$PASS" | sed 's/[&/\]/\\&/g')

# Replace variables in the cert-metadata file
sed -i "s/^COUNTRY=.*/COUNTRY=$COUNTRY_ESCAPED/" "$certmetadata"
sed -i "s/^STATE=.*/STATE=$STATE_ESCAPED/" "$certmetadata"
sed -i "s/^CITY=.*/CITY=$CITY_ESCAPED/" "$certmetadata"
sed -i "s/^ORGANIZATION=.*/ORGANIZATION=$ORGANIZATION_ESCAPED/" "$certmetadata"
sed -i "s/^ORGANIZATIONAL_UNIT=.*/ORGANIZATIONAL_UNIT=$ORGANIZATIONAL_UNIT_ESCAPED/" "$certmetadata"

# Replace the password in the CAPASS line
if grep -q '^CAPASS=' "$certmetadata"; then
    sed -i "s/\(CAPASS=\${CAPASS:-\)[^}]*\}/\1$PASS_ESCAPED}/" "$certmetadata"
    echo "Password in CAPASS has been updated."
else
    echo "'CAPASS' not found in $certmetadata. Please check the file content."
fi

echo "cert-metadata.sh has been updated."

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

}

# Function to create a .zip file for users
create_zip_file() {
    echo "Creating a .zip file for users..."

# Display initial message
cat <<'EOF'
  Hey! I've created this script to create users in your TAK Server, which (hopefully) makes it a lot easier for implementation.
  
Before the script is run, you need to edit the script and set your default CA Password and Truststore file name in the script directly.

Also, zip is required to run this script, so if you receive "216: zip: command not found", please run "sudo apt install zip".

EOF



# Define variables for CA Password and Truststore file name

# ***Edit these lines before running the script!!
CA_Password="Your_CA_Password_Here" # Default is atakatak
CACert="Your_Truststore_File_Name_Here" # Without path or extension
TAKServer_Name="The Name for your TAK Server" # Ex. TAK_USSOCOM
Connection_Name="The IP/URL for the connection" # Ex. 192.168.1.2 or yourdomainname.net
# ***Edit these lines before running the script!!

# Ask the user if they are ready to proceed
read -p "
- Are you ready to run the script? (Y/n): " ready_choice

# If the user input is not "Y" or "y", exit the script
if [[ ! "$ready_choice" =~ ^[Yy]$ ]]; then
    echo "
    - Exiting script. Please run it again when you're ready."
    exit 1
fi

# Determine the home directory of the user who invoked sudo
home_dir=$(eval echo ~$SUDO_USER)

# Define the base directory
base_dir="$home_dir/Documents/dataPackage"

# Global variable for the subfolder
subfolder=""

# Function to create the dataPackage directory and a new subfolder inside it
create_data_package_subfolder() {
    # Create the dataPackage directory if it doesn't exist
    mkdir -p "$base_dir" || { echo "Failed to create base directory"; exit 1; }

    # Prompt the user for the subfolder name
    read -p "
    - Enter the Callsign for the User you're creating a data package for: " subfolder_name

    # Initialize subfolder path
    subfolder="$base_dir/$subfolder_name"

    # Check if the subfolder already exists
    if [ -d "$subfolder" ]; then
        echo "
        - A folder with the name '$subfolder_name' already exists."

        # Prompt the user for their choice
        while true; do
            read -p "
            - Do you want to (O)verwrite the existing folder or (N)ame a new folder? (O/N): " choice
            case "$choice" in
                [oO])
                    # Remove existing folder and proceed
                    rm -rf "$subfolder" || { echo "Failed to remove existing subfolder"; exit 1; }
                    break
                    ;;
                [nN])
                    # Prompt for a new subfolder name
                    read -p "
                    - Enter a new Callsign for the User: " subfolder_name
                    subfolder="$base_dir/$subfolder_name"
                    ;;
                *)
                    echo "
                    - Invalid choice. Please enter 'O' to overwrite or 'N' to name a new folder."
                    ;;
            esac
        done
    fi

    # Create the subfolder and its subdirectories
    mkdir -p "$subfolder/certs" "$subfolder/MANIFEST" || { echo "
    - Failed to create subfolders"; exit 1; }
    
    # Notify the user
    echo "
    - Created subfolder at: $subfolder"
}

# Define cleanup function
cleanup() {
    echo "
    - An error occurred. Cleaning up..."
    if [ -n "$subfolder" ] && [ -d "$subfolder" ]; then
        rm -rf "$subfolder"
    fi
    exit 1
}

# Trap on ERR for cleanup
trap cleanup ERR

# Create the dataPackage subfolder
create_data_package_subfolder

# Ensure the subfolder was created
if [ ! -d "$subfolder" ]; then
    echo "
    - Error: Failed to create the subfolder. Exiting."
    exit 1
fi

# Set the default directory for the Truststore file
search_dir="$home_dir/Documents"

# Search for the Truststore file in the specified directory
truststore_file=$(find "$search_dir" -name "truststore-*.p12" -print -quit 2>/dev/null)

if [[ -z "$truststore_file" ]]; then
    echo "
    - No Truststore file matching 'truststore-*.p12' found in $search_dir."
    exit 1
else
    echo "
    - Truststore file found: $truststore_file"
fi


# Copy the Truststore file to the certs directory in the subfolder
certs_dir="$subfolder/certs"
truststore_copy="$certs_dir/$CACert.p12"

echo "Copying Truststore file to: $certs_dir"
cp "$truststore_file" "$truststore_copy" || { echo "Error: Failed to copy the Truststore file. Exiting."; exit 1; }

echo "Truststore file copied successfully to $truststore_copy."

# At the end of the script, if everything is successful, remove the trap
trap - EXIT

# Prompt the user to select the Unit Role
unit_options=("Team Member" "Team Lead" "HQ" "Sniper" "Medic" "Forward Observer" "RTO" "K9")
PS3="Select the unit role: "
select Unit_Role in "${unit_options[@]}"; do
    if [[ -n $Unit_Role ]]; then
        echo "You selected: $Unit_Role"
        break
    else
        echo "Invalid option. Please try again."
    fi
done

# Prompt the user to select the Team Color
color_options=("White" "Yellow" "Orange" "Magenta" "Red" "Maroon" "Purple" "Dark Blue" "Blue" "Cyan" "Teal" "Green" "Dark Green" "Brown")
PS3="Select the team color: "
select Team_Color in "${color_options[@]}"; do
    if [[ -n $Team_Color ]]; then
        echo "You selected: $Team_Color"
        break
    else
        echo "Invalid option. Please try again."
    fi
done

# Create or overwrite the config.pref file in the certs directory
config_pref="$certs_dir/config.pref"
cat > "$config_pref" <<EOL
<?xml version='1.0' encoding='ASCII' standalone='yes'?>
<preferences>
  <preference version="1" name="cot_streams">
    <entry key="count" class="class java.lang.Integer">1</entry>
    <entry key="description0" class="class java.lang.String">${TAKServer_Name}</entry>
    <entry key="enabled0" class="class java.lang.Boolean">true</entry>
    <entry key="connectString0" class="class java.lang.String">${Connection_Name}:8089:ssl</entry>
    <entry key="caLocation0" class="class java.lang.String">cert/${CACert}.p12</entry>
    <entry key="caPassword0" class="class java.lang.String">${CA_Password}</entry>
    <entry key="enrollForCertificateWithTrust0" class="class java.lang.Boolean">true</entry>
    <entry key="useAuth0" class="class java.lang.Boolean">true</entry>
    <entry key="cacheCreds0" class="class java.lang.String">Cache credentials</entry>
  </preference>
  <preference version="1" name="com.atakmap.app_preferences">
    <entry key="locationCallsign" class="class java.lang.String">${subfolder_name}</entry>
    <entry key="locationTeam" class="class java.lang.String">${Team_Color}</entry>
    <entry key="atakRoleType" class="class java.lang.String">${Unit_Role}</entry>
    <entry key="deviceProfileEnableOnConnect" class="class java.lang.Boolean">true</entry>

EOL

# Prompt the user to add extra preferences
read -p "Do you want to add extra preferences? (yes/no): " add_prefs
if [[ $add_prefs == "yes" ]]; then
    cat >> "$config_pref" <<EOL
    <entry key="coord_display_pref" class="class java.lang.String">MGRS</entry>
    <entry key="alt_display_pref" class="class java.lang.String">MSL</entry>
    <entry key="alt_unit_pref" class="class java.lang.String">1</entry>
    <entry key="speed_unit_pref" class="class java.lang.String">1</entry>
    <entry key="rab_brg_units_pref" class="class java.lang.String">1</entry>
    <entry key="rab_rng_units_pref" class="class java.lang.String">1</entry>
    <entry key="staleRemoteDisconnects" class="class java.lang.Boolean">false</entry>
    <entry key="expireEverything" class="class java.lang.Boolean">false</entry>
    <entry key="expireUnknowns" class="class java.lang.Boolean">false</entry>
    <entry key="map_center_designator" class="class java.lang.Boolean">true</entry>
    <entry key="atakLongPressMap" class="class java.lang.String">nothing</entry>
    <entry key="displayServerConnectionWidget" class="class java.lang.Boolean">true</entry>
EOL
fi

# Prompt the user to hide menu options
read -p "Do you want to hide any menu options? (yes/no): " hide_menus
if [[ $hide_menus == "yes" ]]; then
    cat >> "$config_pref" <<EOL
    ## Hide menu options
    <entry key="hidePreferenceItem_atakAccounts" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_geocoderPreferences" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_geocodeSupplier" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_atakAdjustCurvedDisplay" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_deviceProfileEnableOnConnect" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_atakChangeLog" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_hostileUpdateDelay" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_apiCertEnrollmentPort" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_apiCertEnrollmentKeyLength" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_chatAddress" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_chatPort" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_encryptionPassphrase" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_configureNonStreamingEncryption" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_clientPassword" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_certificateLocation" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_default_client_credentials" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_caLocation" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_caPassword" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_network_dhcp" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_dexControls" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_network_static_ip_address" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_isrvNetworkPreference" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_apiSecureServerPort" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_apiUnsecureServerPort" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_publishCategory" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_reportingSettings" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_locationReportingStrategy" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_manageInputsLink" class="class java.lang.Boolean">true</entry>
    <entry key="hidePreferenceItem_manageOutputsLink" class="class java.lang.Boolean">true</entry>
EOL
fi

# Close the preferences block
cat >> "$config_pref" <<EOL
  </preference>
</preferences>
EOL

echo "config.pref file created successfully in $certs_dir."

# Create the MANIFEST.xml file in the MANIFEST directory
manifest_file="$subfolder/MANIFEST/MANIFEST.xml"
cat > "$manifest_file" <<EOL
<MissionPackageManifest version="2">
  <Configuration>
    <Parameter name="uid" value="ceb708ec-a6a3-11ea-bb37-0242ac130002" />
    <Parameter name="name" value="${subfolder_name}.zip" />
    <Parameter name="onReceiveDelete" value="false" />
    <Parameter name="version" value="2" />
  </Configuration>
  <Contents>
    <Content ignore="false" zipEntry="certs/${CACert}.p12" />
    <Content ignore="false" zipEntry="certs/config.pref" />
  </Contents>
</MissionPackageManifest>
EOL

echo "MANIFEST.xml file created successfully in $manifest_file."

# Zip the subfolder into a zip file named after the subfolder
zip_file="${subfolder}.zip"
echo "Zipping the subfolder into: $zip_file"

(cd "$base_dir" && zip -r "$zip_file" "$(basename "$subfolder")")
if [ $? -eq 0 ]; then
    echo "Successfully created zip file at: $zip_file"
else
    echo "Error: Failed to create the zip file."
    exit 1
fi

# On successful completion, remove the ERR and EXIT traps
trap - ERR EXIT

echo "Script completed successfully."

}


change_default_values() {
    echo "Changing default values for user creation..."
    # Call the function to change defaults
    change_defaults
}


uninstall_tak_server() {
    echo "Uninstalling TAK Server..."
    
    sudo systemctl stop takserver

    sudo apt-get remove takserver -y && sudo apt-get purge takserver -y

    sudo rm -r /opt/tak
  

    sudo apt-get --purge remove postgresql postgresql-* -y

    sudo rm -r /var/log/postgresql -y

    sudo rm -r /var/lib/postgresql -y

    sudo rm -r /etc/postgresql -y

    sudo apt autoremove -y

    echo "TAK Server removal successfull"
}

while true; do
    # Prompt user for action
    echo "Select an option:"
    echo "
      1) Install TAK Server"
    echo "
      2) Recreate Certificates"
    echo "
      3) Create Zip File for User"
    echo "
      4) Change Default Values for User Creation"
    echo "
      5) Uninstall TAK Server"
    echo "
      6) Exit"
    echo "
    Enter your choice: " 
    read choice

    # Use case statement to run the corresponding function
    case $choice in
        1)
            install_tak_server
            ;;
        2)
            while true; do
                echo "Are you sure you want to recreate certificates? This will overwrite existing ones. (y/n)"
                read confirmation
                if [[ "$confirmation" == "y" || "$confirmation" == "Y" || "$confirmation" == "yes" || "$confirmation" == "YES" ]]; then
                    recreate_certificates
                    break # Exits the confirmation loop after recreating certificates
                elif [[ "$confirmation" == "n" || "$confirmation" == "N" || "$confirmation" == "no" || "$confirmation" == "NO" ]]; then
                    echo "Certificate recreation canceled."
                    break # Exits the confirmation loop, returns to main menu
                else
                    echo "Invalid input. Please enter 'y' for yes or 'n' for no."
                fi
            done
            ;;
        3)
            create_zip_file
            ;;
        4)
            change_default_values
            ;;
        5)
            while true; do
                echo "Are you sure you want to uninstall the TAK Server? This action cannot be undone. (y/n)"
                read confirmation
                if [[ "$confirmation" == "y" || "$confirmation" == "Y" || "$confirmation" == "yes" || "$confirmation" == "YES" ]]; then
                    uninstall_tak_server
                    break 2 # Exits both loops after uninstalling
                elif [[ "$confirmation" == "n" || "$confirmation" == "N" || "$confirmation" == "no" || "$confirmation" == "NO" ]]; then
                    echo "Uninstall canceled."
                    break # Exits the confirmation loop, returns to main menu
                else
                    echo "Invalid input. Please enter 'y' for yes or 'n' for no."
                fi
            done
            ;;
        6)
            echo "Exiting script"
            break # Exits the main loop and ends the script
            ;;
        *)
            echo "Invalid option. Please select a valid option."
            ;;
    esac
done