#!/bin/bash

# Ensure the script is run with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root using sudo."
    exit 1
fi

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