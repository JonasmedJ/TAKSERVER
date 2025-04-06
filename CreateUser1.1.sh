#!/bin/bash
# Written by Jonas O.
# @JonasMedJ at Fiverr & Upwork
# If redistributed, please refer it to me, in order to allow proper credits.

# Ensure the script is run with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root using sudo."
    exit 1
fi

# Function to clear the terminal
clear_terminal() {
    clear
}

# Configuration file path
config_file="$HOME/.tak_server_config"

# Define default variables 
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
    clear_terminal
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
display_welcome() {
    cat <<'EOF'
  Hey! I've created this script to create users in your TAK Server, which (hopefully) makes it a lot easier for implementation.
  
EOF
}

# Check if we have a saved configuration
load_configuration_on_start() {
    if ! load_configuration; then
        echo "No configuration found. Let's set up your TAK Server configuration first."
        configure_variables
    fi
}

# Determine the home directory of the user who invoked sudo
home_dir=$(eval echo ~$SUDO_USER)

# Define the base directory
base_dir="$home_dir/Documents/dataPackage"

# Global variable for the subfolder
subfolder=""

# Function to create the dataPackage directory and a new subfolder inside it
create_data_package_subfolder() {
    clear_terminal
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
    mkdir -p "$subfolder/certs" "$subfolder/MANIFEST" "$subfolder/maps" || { echo "Failed to create subfolders"; exit 1; }
    
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

# Function to download map files
download_map_files() {
    maps_dir="$subfolder/maps"
    echo "Downloading map files to: $maps_dir"
    
    # Download Google Hybrid map
    echo "Downloading Google Hybrid map..."
    curl -s -o "$maps_dir/google_hybrid.xml" "https://raw.githubusercontent.com/joshuafuller/ATAK-Maps/refs/heads/master/Google/google_hybrid.xml" || { 
        echo "Error: Failed to download Google Hybrid map"; 
        return 1; 
    }
    
    # Download OpenTopo map
    echo "Downloading OpenTopo map..."
    curl -s -o "$maps_dir/opentopo_opentopomap.xml" "https://raw.githubusercontent.com/joshuafuller/ATAK-Maps/refs/heads/master/opentopo/opentopo_opentopomap.xml" || { 
        echo "Error: Failed to download OpenTopo map"; 
        return 1; 
    }
    
    echo "Map files downloaded successfully."
    return 0
}

# Function to find and copy truststore
setup_truststore() {
    # Search in Documents directory by default
    search_dir="$home_dir/Documents"
    
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
    clear_terminal
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
    
    # Common portion for Android preference-only configs
    cat > "$config_pref" <<EOL
<?xml version='1.0' encoding='ASCII' standalone='yes'?>
<preferences>
  <preference version="1" name="com.atakmap.app_preferences">
    <entry key="displayServerConnectionWidget" class="class java.lang.Boolean">true</entry>
    <entry key="locationCallsign" class="class java.lang.String">${subfolder_name}</entry>
    <entry key="locationTeam" class="class java.lang.String">${Team_Color}</entry>
    <entry key="atakRoleType" class="class java.lang.String">${Unit_Role}</entry>
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
  </preference>
</preferences>
EOL

    echo "Preferences-only config.pref file created successfully in $certs_dir."
}

# Function to create a MANIFEST.xml file with trust file and maps
create_full_manifest() {
    manifest_file="$subfolder/MANIFEST/MANIFEST.xml"
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
    <Content ignore="false" zipEntry="maps/google_hybrid.xml"/>
    <Content ignore="false" zipEntry="maps/opentopo_opentopomap.xml"/>
  </Contents>
</MissionPackageManifest>
EOL

    echo "Full MANIFEST.xml file created successfully in $manifest_file."
}

# Function to create a MANIFEST.xml file without trust file but with maps
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
    <Content ignore="false" zipEntry="maps/google_hybrid.xml"/>
    <Content ignore="false" zipEntry="maps/opentopo_opentopomap.xml"/>
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

# New function to fix ownership of files and folders
fix_ownership() {
    local path_to_fix=$1
    
    if [ -z "$SUDO_USER" ]; then
        echo "Warning: SUDO_USER not set, cannot fix ownership."
        return 1
    fi
    
    if [ -z "$path_to_fix" ]; then
        echo "No path specified for ownership fix."
        return 1
    fi
    
    echo "Changing ownership of $path_to_fix to $SUDO_USER"
    chown -R "$SUDO_USER":"$(id -gn "$SUDO_USER")" "$path_to_fix"
    
    if [ $? -eq 0 ]; then
        echo "Ownership changed successfully."
        return 0
    else
        echo "Error: Failed to change ownership."
        return 1
    fi
}

# Function to display current configuration
display_current_config() {
    clear_terminal
    echo "=== Current TAK Server Configuration ==="
    echo "CA Password: $CA_Password"
    echo "Truststore File Name: $CACert"
    echo "TAK Server Name: $TAKServer_Name"
    echo "Connection Name/IP: $Connection_Name"
    echo "==================================="
    
    # Wait for user to press a key before returning to the menu
    read -n 1 -s -r -p "Press any key to continue..."
}

# Function to create iPhone configuration (simplified)
create_itak_configuration() {
    clear_terminal
    # Create temporary directory for files
    tmp_dir="$(mktemp -d)"
    
    # Prompt for iTAK username
    echo "Choose a username for the iTAK user:"
    read -p "> " itak_username
    
    if [ -z "$itak_username" ]; then
        echo "Error: No username provided."
        rm -rf "$tmp_dir"
        exit 1
    fi
    
    # Create certificate with tak user
    echo "Creating certificate for iTAK user: $itak_username"
    sudo su - tak << EOT
cd /opt/tak/certs/
./makeCert.sh client "$itak_username"
exit
EOT
    
    if [ $? -ne 0 ]; then
        echo "Error: Certificate creation failed"
        rm -rf "$tmp_dir"
        exit 1
    fi

    # Check if certificate was created
    client_cert="/opt/tak/certs/files/${itak_username}.p12"
    if [ ! -f "$client_cert" ]; then
        echo "Error: Certificate file not found at $client_cert"
        rm -rf "$tmp_dir"
        exit 1
    fi
    
    # Copy client certificate
    cp "$client_cert" "$tmp_dir/" || {
        echo "Error: Failed to copy client certificate"
        rm -rf "$tmp_dir"
        exit 1
    }
    
    # Search in Documents directory by default
    search_dir="$home_dir/Documents"
    
    truststore_file=$(find "$search_dir" -name "truststore-*.p12" -print -quit 2>/dev/null)
    
    if [[ -z "$truststore_file" ]]; then
        echo "No Truststore file found in $search_dir."
        rm -rf "$tmp_dir"
        exit 1
    fi
    
    # Copy truststore
    cp "$truststore_file" "$tmp_dir/$CACert.p12" || {
        echo "Error: Failed to copy truststore certificate"
        rm -rf "$tmp_dir"
        exit 1
    }
    
    # Create config.pref
    cat > "$tmp_dir/config.pref" <<EOL
<?xml version='1.0' standalone='yes'?>
<preferences>
  <preference version="1" name="cot_streams">
    <entry key="count" class="class java.lang.Integer">1</entry>
    <entry key="description0" class="class java.lang.String">$TAKServer_Name</entry>
    <entry key="enabled0" class="class java.lang.Boolean">true</entry>
    <entry key="connectString0" class="class java.lang.String">$Connection_Name:8089:ssl</entry>
  </preference>
  <preference version="1" name="com.atakmap.app_preferences">
    <entry key="displayServerConnectionWidget" class="class java.lang.Boolean">true</entry>
    <entry key="caLocation" class="class java.lang.String">cert/$CACert.p12</entry>
    <entry key="caPassword" class="class java.lang.String">$CA_Password</entry>
    <entry key="clientPassword" class="class java.lang.String">$CA_Password</entry>
    <entry key="certificateLocation" class="class java.lang.String">cert/${itak_username}.p12</entry>
  </preference>
</preferences>
EOL
    
    # Create zip file for iTAK
    output_zip="$base_dir/${itak_username}-ios.zip"
    (cd "$tmp_dir" && zip -j "$output_zip" "config.pref" "$CACert.p12" "${itak_username}.p12")
    
    if [ $? -eq 0 ]; then
        echo "Successfully created iTAK package: $output_zip"
        echo "Package contains exactly:"
        echo "- config.pref"
        echo "- $CACert.p12 (truststore)"
        echo "- ${itak_username}.p12 (client certificate)"
        
        # Fix ownership of the iOS zip file
        fix_ownership "$output_zip"
    else
        echo "Error: Failed to create the zip file."
    fi
    
    # Clean up
    rm -rf "$tmp_dir"
    
    # Wait for user to press a key before returning to the menu
    read -n 1 -s -r -p "Press any key to continue..."
}

# Function: List All Users
list_all_users() {
    clear_terminal
    echo "=== TAK Server Users ==="
    
    # Check if the base directory exists
    if [ ! -d "$base_dir" ]; then
        echo "No data package directory found at $base_dir"
        read -n 1 -s -r -p "Press any key to continue..."
        return
    fi
    
    # Arrays to store different types of users
    android_users=()
    iphone_users=()
    
    # Find Android user folders
    for user_dir in "$base_dir"/*; do
        if [ -d "$user_dir" ]; then
            user_name=$(basename "$user_dir")
            android_users+=("$user_name")
        fi
    done
    
    # Find Android zip files (non-iOS)
    for zip_file in "$base_dir"/*.zip; do
        if [ -f "$zip_file" ] && [[ ! "$zip_file" == *"-ios.zip" ]]; then
            zip_name=$(basename "$zip_file" .zip)
            # Handle the case where we have both normal and -pref zip files
            if [[ "$zip_name" == *"-pref" ]]; then
                base_name="${zip_name%-pref}"
                if [[ ! " ${android_users[@]} " =~ " ${base_name} " ]]; then
                    android_users+=("$base_name")
                fi
            else
                if [[ ! " ${android_users[@]} " =~ " ${zip_name} " ]]; then
                    android_users+=("$zip_name")
                fi
            fi
        fi
    done
    
    # Find iPhone users (-ios.zip)
    for zip_file in "$base_dir"/*-ios.zip; do
        if [ -f "$zip_file" ]; then
            zip_name=$(basename "$zip_file" -ios.zip)
            iphone_users+=("$zip_name")
        fi
    done
    
    # Display the results
    echo "Android users:"
    if [ ${#android_users[@]} -eq 0 ]; then
        echo "  No Android users found."
    else
        for ((i=0; i<${#android_users[@]}; i++)); do
            echo "  $((i+1)). ${android_users[$i]}"
        done
    fi
    
    echo -e "\niPhone (iTAK) users:"
    if [ ${#iphone_users[@]} -eq 0 ]; then
        echo "  No iPhone users found."
    else
        for ((i=0; i<${#iphone_users[@]}; i++)); do
            echo "  $((i+1)). ${iphone_users[$i]}"
        done
    fi
    
    # Wait for user to press a key before returning to the menu
    echo ""
    read -n 1 -s -r -p "Press any key to continue..."
}

# Function: Revoke iPhone Certificate
revoke_iphone_certificate() {
    local client="$1"
    local ca_cert="$2"
    
    # Extract the CA name without "truststore-" prefix if present
    local ca_base_name="${ca_cert#truststore-}"
    
    # Execute the commands as the tak user with the exact format specified
    sudo su - tak << EOT
cd /opt/tak/certs
./revokeCert.sh "$client" "$ca_base_name" "$ca_base_name"
exit
EOT
    
    return $?
}

# Function to manage group membership
manage_group_membership() {
    clear_terminal
    echo "=== Group Membership Management ==="
    echo "1. Return to main menu"
    echo "2. Add user to group"
    echo "3. Remove user from group"
    echo "4. See user group membership"
    echo ""
    read -p "Enter your choice [1-4]: " group_choice

    case $group_choice in
        1)
            # Return to main menu
            return
            ;;
        2)
            # Add user to group
            add_user_to_group
            ;;
        3)
            # Remove user from group
            remove_user_from_group
            ;;
        4)
            # See user group membership
            view_user_group_membership
            ;;
        *)
            echo "Invalid option. Please select 1-4."
            read -n 1 -s -r -p "Press any key to continue..."
            ;;
    esac
}

# Function to add a user to a group
add_user_to_group() {
    clear_terminal
    echo "=== Add User to Group ==="
    
    # Prompt for username
    read -p "Enter the username: " username
    if [ -z "$username" ]; then
        echo "Error: Username cannot be empty."
        read -n 1 -s -r -p "Press any key to continue..."
        return
    fi
    
    # Prompt for group name
    read -p "Enter the group name: " group_name
    if [ -z "$group_name" ]; then
        echo "Error: Group name cannot be empty."
        read -n 1 -s -r -p "Press any key to continue..."
        return
    fi
    
    # Ask which type of group permission to add
    echo "Select the type of group permission:"
    echo "1. Full access (read and write)"
    echo "2. Write-only access"
    echo "3. Read-only access"
    read -p "Enter your choice [1-3]: " perm_choice
    
    case $perm_choice in
        1)
            # Full access (read and write)
            echo "Adding user '$username' to group '$group_name' with full access..."
            sudo java -jar /opt/tak/UserManager.jar usermod -g "$group_name" -a "$username"
            ;;
        2)
            # Write-only access
            echo "Adding user '$username' to group '$group_name' with write-only access..."
            sudo java -jar /opt/tak/UserManager.jar usermod -ig "$group_name" -a "$username"
            ;;
        3)
            # Read-only access
            echo "Adding user '$username' to group '$group_name' with read-only access..."
            sudo java -jar /opt/tak/UserManager.jar usermod -og "$group_name" -a "$username"
            ;;
        *)
            echo "Invalid option. Operation cancelled."
            read -n 1 -s -r -p "Press any key to continue..."
            return
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo "Successfully added user to group."
    else
        echo "Error: Failed to add user to group."
    fi
    
    read -n 1 -s -r -p "Press any key to continue..."
}

# Function to remove a user from a group
remove_user_from_group() {
    clear_terminal
    echo "=== Remove User from Group ==="
    
    # Prompt for username
    read -p "Enter the username: " username
    if [ -z "$username" ]; then
        echo "Error: Username cannot be empty."
        read -n 1 -s -r -p "Press any key to continue..."
        return
    fi
    
    # Prompt for group name
    read -p "Enter the group name: " group_name
    if [ -z "$group_name" ]; then
        echo "Error: Group name cannot be empty."
        read -n 1 -s -r -p "Press any key to continue..."
        return
    fi
    
    # Ask which type of group permission to remove
    echo "Select the type of group permission to remove:"
    echo "1. Full access (read and write)"
    echo "2. Write-only access"
    echo "3. Read-only access"
    read -p "Enter your choice [1-3]: " perm_choice
    
    case $perm_choice in
        1)
            # Full access (read and write)
            echo "Removing user '$username' from group '$group_name' (full access)..."
            sudo java -jar /opt/tak/UserManager.jar usermod -g "$group_name" -r "$username"
            ;;
        2)
            # Write-only access
            echo "Removing user '$username' from group '$group_name' (write-only access)..."
            sudo java -jar /opt/tak/UserManager.jar usermod -ig "$group_name" -r "$username"
            ;;
        3)
            # Read-only access
            echo "Removing user '$username' from group '$group_name' (read-only access)..."
            sudo java -jar /opt/tak/UserManager.jar usermod -og "$group_name" -r "$username"
            ;;
        *)
            echo "Invalid option. Operation cancelled."
            read -n 1 -s -r -p "Press any key to continue..."
            return
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo "Successfully removed user from group."
    else
        echo "Error: Failed to remove user from group."
    fi
    
    read -n 1 -s -r -p "Press any key to continue..."
}

# Function to view user group membership
view_user_group_membership() {
    clear_terminal
    echo "=== View User Group Membership ==="
    
    # Prompt for username
    read -p "Enter the username: " username
    if [ -z "$username" ]; then
        echo "Error: Username cannot be empty."
        read -n 1 -s -r -p "Press any key to continue..."
        return
    fi
    
    echo "Retrieving group membership for user '$username'..."
    sudo java -jar /opt/tak/UserManager.jar usermod -s "$username"
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to retrieve user information."
    fi
    
    # Wait for user to press enter before returning to menu
    read -p "Press Enter to continue..."
}

# Function: Remove User
remove_user() {
    clear_terminal
    echo "=== Remove User ==="
    
    # Arrays to store different types of users
    android_users=()
    iphone_users=()
    all_users=()
    user_types=()  # To track whether each user is Android or iPhone
    
    # Find Android user folders and zip files
    for user_dir in "$base_dir"/*; do
        if [ -d "$user_dir" ]; then
            user_name=$(basename "$user_dir")
            if [[ ! " ${android_users[@]} " =~ " ${user_name} " ]]; then
                android_users+=("$user_name")
                all_users+=("$user_name")
                user_types+=("android")
            fi
        fi
    done
    
    for zip_file in "$base_dir"/*.zip; do
        if [ -f "$zip_file" ] && [[ ! "$zip_file" == *"-ios.zip" ]]; then
            zip_name=$(basename "$zip_file" .zip)
            # Handle the case where we have both normal and -pref zip files
            if [[ "$zip_name" == *"-pref" ]]; then
                base_name="${zip_name%-pref}"
                if [[ ! " ${android_users[@]} " =~ " ${base_name} " ]]; then
                    android_users+=("$base_name")
                    all_users+=("$base_name")
                    user_types+=("android")
                fi
            else
                if [[ ! " ${android_users[@]} " =~ " ${zip_name} " ]]; then
                    android_users+=("$zip_name")
                    all_users+=("$zip_name")
                    user_types+=("android")
                fi
            fi
        fi
    done
    
    # Find iPhone users
    for zip_file in "$base_dir"/*-ios.zip; do
        if [ -f "$zip_file" ]; then
            zip_name=$(basename "$zip_file" -ios.zip)
            iphone_users+=("$zip_name")
            all_users+=("$zip_name (iPhone)")
            user_types+=("iphone")
        fi
    done
    
    # Check if there are any users to remove
    if [ ${#all_users[@]} -eq 0 ]; then
        echo "No users found to remove."
        read -n 1 -s -r -p "Press any key to continue..."
        return
    fi
    
    # Display menu of users
    echo "Select a user to remove:"
    PS3="Enter number (or 0 to cancel): "
    select user_to_remove in "${all_users[@]}" "Cancel"; do
        if [ "$REPLY" -eq "$((${#all_users[@]}+1))" ] || [ "$REPLY" -eq 0 ]; then
            echo "Operation cancelled."
            read -n 1 -s -r -p "Press any key to continue..."
            return
        fi
        
        if [ "$REPLY" -gt 0 ] && [ "$REPLY" -le "${#all_users[@]}" ]; then
            selected_index=$((REPLY-1))
            selected_user="${all_users[$selected_index]}"
            user_type="${user_types[$selected_index]}"
            
            # Extract the actual username from displayed name for iPhone users
            if [[ "$user_type" == "iphone" ]]; then
                actual_username="${selected_user% (iPhone)}"
            else
                actual_username="$selected_user"
            fi
            
            echo "You selected to remove: $selected_user"
            
            # Different handling based on user type
            if [[ "$user_type" == "android" ]]; then
                # Android user removal
                read -p "Are you sure you want to remove this Android user? This will delete all associated files. (y/n): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    # Remove user directory if it exists
                    if [ -d "$base_dir/$actual_username" ]; then
                        rm -rf "$base_dir/$actual_username" && echo "Deleted user directory: $base_dir/$actual_username"
                    fi
                    
                    # Remove user zip files
                    rm -f "$base_dir/$actual_username.zip" && echo "Deleted user zip file: $base_dir/$actual_username.zip"
                    rm -f "$base_dir/$actual_username-pref.zip" && echo "Deleted user preferences zip file: $base_dir/$actual_username-pref.zip"
                    
                    echo "Android user $actual_username has been removed."
                else
                    echo "Removal cancelled."
                fi
            else
                # iPhone user removal
                read -p "Are you sure you want to remove this iPhone user? This will revoke their certificate. (y/n): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    # Indicate the revocation process
                    echo "Revoking certificate for $actual_username..."
                    
                    # Run the revocation function
                    if revoke_iphone_certificate "$actual_username" "$CACert"; then
                        echo "Certificate for $actual_username has been revoked."
                        
                        # Remove certificate files
                        echo "Removing certificate files..."
                        sudo rm -f "/opt/tak/certs/files/$actual_username.csr" 2>/dev/null
                        sudo rm -f "/opt/tak/certs/files/$actual_username.jks" 2>/dev/null
                        sudo rm -f "/opt/tak/certs/files/$actual_username.pem" 2>/dev/null
                        sudo rm -f "/opt/tak/certs/files/$actual_username.p12" 2>/dev/null
                        sudo rm -f "/opt/tak/certs/files/$actual_username.key" 2>/dev/null
                        sudo rm -f "/opt/tak/certs/files/$actual_username-trusted.pem" 2>/dev/null
                        
                        # Remove user zip file
                        rm -f "$base_dir/$actual_username-ios.zip" && echo "Deleted user zip file: $base_dir/$actual_username-ios.zip"
                        
                        # Ask about server restart
                        echo ""
                        echo -e "\033[0;33mThe TAK Server service must be restarted to apply the revocation.\033[0m"
                        read -p "Do you want to restart the TAK server? (y/n): " restart_server
                        if [[ "$restart_server" =~ ^[Yy]$ ]]; then
                            echo "Restarting TAK server..."
                            sudo systemctl restart takserver
                            echo "TAK server has been restarted."
                        else
                            echo "You should restart the server as soon as possible!"
                        fi
                    else
                        echo "Error: Failed to revoke certificate for $actual_username."
                    fi
                else
                    echo "Removal cancelled."
                fi
            fi
            read -n 1 -s -r -p "Press any key to continue..."
            break
        else
            echo "Invalid selection."
        fi
    done
}

# Main execution starts here

# Trap on ERR for cleanup
trap cleanup ERR

while true; do
    echo ""
    echo "TAK Server User Configuration Tool"
    echo "==================================="
    echo "Please select an option:"
    echo "1. Create ITAK Configuration"
    echo "2. Create ATAK Configuration"
    echo "3. Configure TAK Server Settings"
    echo "4. Show Current ServerConfiguration"
    echo "5. List Current Users"
    echo "6. Remove User"
    echo "7. Manage Group Membership"
    echo "8. Exit"
    echo ""
    read -p "Enter your choice [1-8]: " main_choice

    case $main_choice in
      1)
        echo "Running ITAK user creation."
        
        # Check if we have all required configuration values
        if [ -z "$CA_Password" ] || [ -z "$CACert" ] || [ -z "$TAKServer_Name" ] || [ -z "$Connection_Name" ]; then
            echo "Missing configuration values. Please configure your TAK Server settings first."
            configure_variables
        fi
        
        # Run the simplified iTAK configuration process
        create_itak_configuration
        ;;

      2)
        echo "Running ATAK user creation."
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
        
        # Download map files
        download_map_files
        
        # Create full Android configuration
        create_android_config
        
        # Create full manifest with maps
        create_full_manifest
        
        # Create full zip file
        create_zip ""
        
        # Now create preferences-only configuration
        create_prefs_only_config
        
        # Create preferences-only manifest with maps
        create_pref_manifest
        
        # Create preferences-only zip file
        create_zip "-pref"
        
        # Fix ownership for the created folder and zip files
        fix_ownership "$subfolder"
        fix_ownership "${subfolder}.zip"
        fix_ownership "${subfolder}-pref.zip"
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
        # List all users
        list_all_users
        ;;
        
      6)
        # Remove user
        remove_user
        ;;
        
      7)
        # Manage group membership
        manage_group_membership
        ;;

      8)
        echo "Exiting User Configuration Tool."
        exit 0
        ;;
        
      *)
        echo "Invalid option. Please select 1-8."
        ;;
    esac
done

# On successful completion, remove the ERR trap
trap - ERR

echo "Script completed successfully."