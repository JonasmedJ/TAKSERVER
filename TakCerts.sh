#!/bin/bash

# Check if the script is run with sudo or as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo."
  exit 1
fi

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