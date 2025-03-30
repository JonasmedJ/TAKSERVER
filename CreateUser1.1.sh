#!/bin/bash

# Ensure the script is run with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root using sudo."
    exit 1
fi

# Configuration file path
config_file="$HOME/.tak_server_config"

# Define default variables for CA Password and Truststore file name
CA_Password=""
CACert=""
TAKServer_Name=""
Connection_Name=""

# Function to load configuration if it exists
load_configuration() {
    if [ -f "$config_file" ]; then
        source "$config_file"
        return 0
    else
        return 1
    fi
}

# Function to save configuration
save_configuration() {
    cat > "$config_file" <<EOL
CA_Password="$CA_Password"
CACert="$CACert"
TAKServer_Name="$TAKServer_Name"
Connection_Name="$Connection_Name"
EOL
    chmod 600 "$config_file"  # Set restrictive permissions for security
    echo "Configuration saved successfully."
}

# Function to configure variables
configure_variables() {
    echo "=== TAK Server Configuration ==="
    
    # Show current values if they exist
    if [ -n "$CA_Password" ]; then
        echo "Current CA Password: $CA_Password"
    fi
    read -p "Enter CA Password [default: atakatak]: " new_ca_password
    CA_Password=${new_ca_password:-${CA_Password:-"atakatak"}}
    
    if [ -n "$CACert" ]; then
        echo "Current Truststore File Name: $CACert"
    fi
    read -p "Enter Truststore File Name (without path or extension): " new_cacert
    CACert=${new_cacert:-$CACert}
    
    if [ -n "$TAKServer_Name" ]; then
        echo "Current TAK Server Name: $TAKServer_Name"
    fi
    read -p "Enter TAK Server Name (e.g., TAK_US_SOCOM): " new_takserver_name
    TAKServer_Name=${new_takserver_name:-$TAKServer_Name}
    
    if [ -n "$Connection_Name" ]; then
        echo "Current Connection Name/IP: $Connection_Name"
    fi
    read -p "Enter Connection Name/IP (e.g., 192.168.1.2 or yourdomainname.net): " new_connection_name
    Connection_Name=${new_connection_name:-$Connection_Name}
    
    # Save the configuration
    save_configuration
}

# Display initial message
cat <<'EOF'
  Hey! I've created this script to create users in your TAK Server, which (hopefully) makes it a lot easier for implementation.
  
EOF

# Check if we have a saved configuration
if ! load_configuration; then
    echo "No configuration found. Let's set up your TAK Server configuration first."
    configure_variables
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
    read -p "Enter the Callsign for the User you're creating a data package for: " subfolder_name

    # Initialize subfolder path
    subfolder="$base_dir/$subfolder_name"

    # Check if the subfolder already exists
    if [ -d "$subfolder" ]; then
        echo "A folder with the name '$subfolder_name' already exists."

        # Prompt the user for their choice
        while true; do
            read -p "Do you want to (O)verwrite the existing folder or (N)ame a new folder? (O/N): " choice
            case "$choice" in
                [oO])
                    # Remove existing folder and proceed
                    rm -rf "$subfolder" || { echo "Failed to remove existing subfolder"; exit 1; }
                    break
                    ;;
                [nN])
                    # Prompt for a new subfolder name
                    read -p "Enter a new Callsign for the User: " subfolder_name
                    subfolder="$base_dir/$subfolder_name"
                    ;;
                *)
                    echo "Invalid choice. Please enter 'O' to overwrite or 'N' to name a new folder."
                    ;;
            esac
        done
    fi

    # Create the subfolder and its subdirectories
    mkdir -p "$subfolder/certs" "$subfolder/MANIFEST" || { echo "Failed to create subfolders"; exit 1; }
    
    # Notify the user
    echo "Created subfolder at: $subfolder"
}

# Define cleanup function
cleanup() {
    echo "An error occurred. Cleaning up..."
    if [ -n "$subfolder" ] && [ -d "$subfolder" ]; then
        rm -rf "$subfolder"
    fi
    exit 1
}

# Function to find and copy truststore
setup_truststore() {
    # Ask the user if the Truststore is located in the Documents folder
    read -p "Is your Truststore located in the Documents folder? (yes/no): " truststore_location_response
    truststore_location_response=$(echo "$truststore_location_response" | tr '[:upper:]' '[:lower:]')

    # Determine the search directory for the Truststore file
    if [[ "$truststore_location_response" == "yes" || "$truststore_location_response" == "y" ]]; then
        search_dir="$home_dir/Documents"
    else
        read -p "Please provide the directory where the Truststore file is located: " search_dir
    fi

    # Search for the Truststore file in the specified directory
    truststore_file=$(find "$search_dir" -name "truststore-*.p12" -print -quit 2>/dev/null)

    if [[ -z "$truststore_file" ]]; then
        echo "No Truststore file matching 'truststore-*.p12' found in $search_dir."
        exit 1
    else
        echo "Truststore file found: $truststore_file"
    fi

    # Copy the Truststore file to the certs directory in the subfolder
    certs_dir="$subfolder/certs"
    truststore_copy="$certs_dir/$CACert.p12"

    echo "Copying Truststore file to: $certs_dir"
    cp "$truststore_file" "$truststore_copy" || { echo "Error: Failed to copy the Truststore file. Exiting."; exit 1; }

    echo "Truststore file copied successfully to $truststore_copy."
}

# Function to prompt for user role and team color
get_user_details() {
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
}

# Function to create a config.pref file for iOS with certificate paths
create_ios_config() {
    certs_dir="$subfolder/certs"
    config_pref="$certs_dir/config.pref"
    
    cat > "$config_pref" <<EOL
<?xml version='1.0' standalone='yes'?>
<preferences>
  <preference version="1" name="cot_streams">
    <entry key="count" class="class java.lang.Integer">1</entry>
    <entry key="description0" class="class java.lang.String">${TAKServer_Name}</entry>
    <entry key="enabled0" class="class java.lang.Boolean">true</entry>
    <entry key="connectString0" class="class java.lang.String">${Connection_Name}:8089:ssl</entry>
  </preference>
  <preference version="1" name="com.atakmap.app_preferences">
    <entry key="displayServerConnectionWidget" class="class java.lang.Boolean">true</entry>
    <entry key="caLocation" class="class java.lang.String">cert/${CACert}.p12</entry>
    <entry key="caPassword" class="class java.lang.String">${CA_Password}</entry>
    <entry key="clientPassword" class="class java.lang.String">${CA_Password}</entry>
    <entry key="certificateLocation" class="class java.lang.String">cert/${subfolder_name}.p12</entry>
  </preference>
</preferences>
EOL

    echo "config.pref file created successfully for iOS in $certs_dir."
}

# Function to create a config.pref file for Android
create_android_config() {
    certs_dir="$subfolder/certs"
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
    <entry key="displayServerConnectionWidget" class="class java.lang.Boolean">true</entry>
    <entry key="locationCallsign" class="class java.lang.String">${subfolder_name}</entry>
    <entry key="locationTeam" class="class java.lang.String">${Team_Color}</entry>
    <entry key="atakRoleType" class="class java.lang.String">${Unit_Role}</entry>
  </preference>
</preferences>
EOL

    echo "config.pref file created successfully for Android in $certs_dir."
}

# Function to create a simple preferences-only config file
create_prefs_only_config() {
    certs_dir="$subfolder/certs"
    config_pref="$certs_dir/config.pref"
    
    # Common portion for both iOS and Android preference-only configs
    cat > "$config_pref" <<EOL
<?xml version='1.0' encoding='ASCII' standalone='yes'?>
<preferences>
  <preference version="1" name="com.atakmap.app_preferences">
    <entry key="displayServerConnectionWidget" class="class java.lang.Boolean">true</entry>
    <entry key="locationCallsign" class="class java.lang.String">${subfolder_name}</entry>
    <entry key="locationTeam" class="class java.lang.String">${Team_Color}</entry>
    <entry key="atakRoleType" class="class java.lang.String">${Unit_Role}</entry>
EOL

    # Add Android-specific preferences if needed
    if [ "$platform" == "android" ]; then
        cat >> "$config_pref" <<EOL
    <entry key="deviceProfileEnableOnConnect" class="class java.lang.Boolean">true</entry>
    <entry key="coord_display_pref" class="class java.lang.String">MGRS</entry>
    <entry key="alt_display_pref" class="class java.lang.String">MSL</entry>
    <entry key="alt_unit_pref" class="class java.lang.String">1</entry>
    <entry key="speed_unit_pref" class="class java.lang.String">1</entry>
    <entry key="rab_brg_units_pref" class="class java.lang.String">1</entry>
    <entry key="rab_rng_units_pref" class="class java.lang.String">1</entry>
    <entry key="staleRemoteDisconnects" class="class java.lang.Boolean">false</entry>
    <entry key="map_center_designator" class="class java.lang.Boolean">true</entry>
    <entry key="atakLongPressMap" class="class java.lang.String">nothing</entry>
    
    <!-- hide user preference options -->
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

    # Close the XML
    cat >> "$config_pref" <<EOL
  </preference>
</preferences>
EOL

    echo "Preferences-only config.pref file created successfully in $certs_dir."
}

# Function to create a MANIFEST.xml file with trust file
create_full_manifest() {
    manifest_file="$subfolder/MANIFEST/MANIFEST.xml"
    
    # Customize manifest based on platform
    if [ "$platform" == "ios" ]; then
        cat > "$manifest_file" <<EOL
<MissionPackageManifest version="2">
  <Configuration>
    <Parameter name="uid" value="ceb708ec-a6a3-11ea-bb37-0242ac130002"/>
    <Parameter name="name" value="${subfolder_name}.zip"/>
    <Parameter name="onReceiveDelete" value="true"/>
  </Configuration>
  <Contents>
    <Content ignore="false" zipEntry="certs/${CACert}.p12"/>
    <Content ignore="false" zipEntry="certs/${subfolder_name}.p12"/>
    <Content ignore="false" zipEntry="certs/config.pref"/>
  </Contents>
</MissionPackageManifest>
EOL
    else
        cat > "$manifest_file" <<EOL
<MissionPackageManifest version="2">
  <Configuration>
    <Parameter name="uid" value="ceb708ec-a6a3-11ea-bb37-0242ac130002"/>
    <Parameter name="name" value="${subfolder_name}.zip"/>
    <Parameter name="onReceiveDelete" value="true"/>
  </Configuration>
  <Contents>
    <Content ignore="false" zipEntry="certs/${CACert}.p12"/>
    <Content ignore="false" zipEntry="certs/config.pref"/>
  </Contents>
</MissionPackageManifest>
EOL
    fi

    echo "Full MANIFEST.xml file created successfully in $manifest_file."
}

# Function to create a MANIFEST.xml file without trust file
create_pref_manifest() {
    manifest_file="$subfolder/MANIFEST/MANIFEST.xml"
    cat > "$manifest_file" <<EOL
<MissionPackageManifest version="2">
  <Configuration>
    <Parameter name="uid" value="ceb708ec-a6a3-11ea-bb37-0242ac130002"/>
    <Parameter name="name" value="${subfolder_name}.zip"/>
    <Parameter name="onReceiveDelete" value="true"/>
  </Configuration>
  <Contents>
    <Content ignore="true" zipEntry="support/atak_splash.png"/>
    <Content ignore="false" zipEntry="certs/config.pref"/>
  </Contents>
</MissionPackageManifest>
EOL

    echo "Preferences-only MANIFEST.xml file created successfully in $manifest_file."
}

# Function to create zip file
create_zip() {
    suffix=$1
    zip_file="${subfolder}${suffix}.zip"
    echo "Zipping the subfolder into: $zip_file"

    (cd "$base_dir" && zip -r "$zip_file" "$(basename "$subfolder")")
    if [ $? -eq 0 ]; then
        echo "Successfully created zip file at: $zip_file"
    else
        echo "Error: Failed to create the zip file."
        exit 1
    fi
}

# Function to display current configuration
display_current_config() {
    echo "=== Current TAK Server Configuration ==="
    echo "CA Password: $CA_Password"
    echo "Truststore File Name: $CACert"
    echo "TAK Server Name: $TAKServer_Name"
    echo "Connection Name/IP: $Connection_Name"
    echo "==================================="
}

# Function to create a client certificate for iTAK
create_itak_certificate() {
    # Check if we have a username
    if [ -z "$subfolder_name" ]; then
        echo "Error: No username provided for certificate creation."
        exit 1
    fi
    
    echo "Creating certificate for iTAK user: $subfolder_name"
    
    # Use a direct approach with sudo su
    echo "Switching to tak user and creating certificate..."
    echo "This will execute commands as the tak user. Password may be required..."
    
    # Use heredoc to pass commands directly to sudo su tak
    sudo su - tak << EOF
cd /opt/tak/certs/
./makeCert.sh client "$subfolder_name"
exit
EOF
    
    cert_result=$?
    
    if [ $cert_result -ne 0 ]; then
        echo "Error: Failed to create certificate for $subfolder_name."
        exit 1
    fi
    
    # Move the generated certificate to our package folder
    source_cert="/opt/tak/certs/files/${subfolder_name}.p12"
    target_cert="$subfolder/certs/${subfolder_name}.p12"
    
    if [ -f "$source_cert" ]; then
        echo "Moving certificate from $source_cert to $target_cert"
        cp "$source_cert" "$target_cert"
        
        if [ $? -ne 0 ]; then
            echo "Error: Failed to copy certificate to package folder."
            exit 1
        fi
    else
        echo "Error: Certificate file not found at $source_cert."
        exit 1
    fi
    
    echo "Certificate created and copied successfully."
}

# Main execution starts here

# Trap on ERR for cleanup
trap cleanup ERR

while true; do
    echo ""
    echo "TAK Server User Configuration Tool"
    echo "==================================="
    echo "Please select an option:"
    echo "1. Create iPhone Configuration"
    echo "2. Create Android Configuration"
    echo "3. Configure TAK Server Settings"
    echo "4. Show Current Configuration"
    echo "5. Exit"
    echo ""
    read -p "Enter your choice [1-5]: " main_choice

    case $main_choice in
      1)
        echo "Running iPhone (iTAK) Configuration!"
        platform="ios"
        
        # Check if we have all required configuration values
        if [ -z "$CA_Password" ] || [ -z "$CACert" ] || [ -z "$TAKServer_Name" ] || [ -z "$Connection_Name" ]; then
            echo "Missing configuration values. Please configure your TAK Server settings first."
            configure_variables
        fi
        
        # Create folder structure
        create_data_package_subfolder
        
        # Setup truststore
        setup_truststore
        
        # For iPhone configuration, we don't need role and team details
        if [ "$platform" != "ios" ]; then
            # Get user details for non-iOS platforms
            get_user_details
        fi
        
        # Create client certificate for iTAK
        create_itak_certificate
        
        # Create full iOS configuration
        create_ios_config
        
        # Create full manifest
        create_full_manifest
        
        # Create full zip file
        create_zip "-IOS"
        
        # Now create preferences-only configuration
        create_prefs_only_config
        
        # Create preferences-only manifest
        create_pref_manifest
        
        # Create preferences-only zip file
        create_zip "-pref"
        ;;

      2)
        echo "Running Android script!"
        platform="android"
        
        # Check if we have all required configuration values
        if [ -z "$CA_Password" ] || [ -z "$CACert" ] || [ -z "$TAKServer_Name" ] || [ -z "$Connection_Name" ]; then
            echo "Missing configuration values. Please configure your TAK Server settings first."
            configure_variables
        fi
        
        # Create folder structure
        create_data_package_subfolder
        
        # Setup truststore
        setup_truststore
        
        # Get user details
        get_user_details
        
        # Create full Android configuration
        create_android_config
        
        # Create full manifest
        create_full_manifest
        
        # Create full zip file
        create_zip ""
        
        # Now create preferences-only configuration
        create_prefs_only_config
        
        # Create preferences-only manifest
        create_pref_manifest
        
        # Create preferences-only zip file
        create_zip "-pref"
        ;;
        
      3)
        # Configure TAK Server settings
        configure_variables
        ;;
        
      4)
        # Display current configuration
        display_current_config
        ;;
        
      5)
        echo "Exiting TAK Server User Configuration Tool."
        exit 0
        ;;
        
      *)
        echo "Invalid option. Please select 1, 2, 3, 4, or 5."
        ;;
    esac
done

# On successful completion, remove the ERR trap
trap - ERR

echo "Script completed successfully."