#!/bin/bash

# PKI Infrastructure Setup for Proxmox Server with Multiple Intermediate CAs
set -euo pipefail # Exit on error, undefined var, or pipe failure

# Configuration Variables
CERT_VALIDITY_DAYS=365
WARN_BEFORE_EXPIRY=30
ROOT_CA_DIR="/etc/ssl/Root-CA01"

# Service-specific hostnames
FIREWALL_HOSTS=("fw.opkbtn.dk")
SERVICE_HOSTS=("pve.opkbtn.dk" "dns.opkbtn.dk" "npm.opkbtn.dk" "ldaps.opkbtn.dk")
TAK_HOSTS=("tak.opkbtn.dk")

# Password for TAK intermediate CA
TAK_CA_PASSWORD="your-secure-password-here"  # Change this to your desired password

# Intermediate CA directories
FIREWALL_CA_DIR="${ROOT_CA_DIR}/intermediates/Firewall-CA"
SERVICES_CA_DIR="${ROOT_CA_DIR}/intermediates/Services-CA"
TAK_CA_DIR="${ROOT_CA_DIR}/intermediates/TAK-CA"

# Error handling function
error_exit() {
    echo "Error: ${1:-"Unknown Error"}" >&2
    exit 1
}

# Function to extract public key from certificate
extract_public_key() {
    local cert_path=$1
    local output_path=$2
    
    openssl x509 -in "$cert_path" -pubkey -noout > "$output_path" || \
        error_exit "Failed to extract public key from $cert_path"
    chmod 644 "$output_path"
    echo "Public key extracted to $output_path"
}

# Create directory structure
mkdir -p "${ROOT_CA_DIR}"/{root,intermediates/{Firewall-CA,Services-CA,TAK-CA}/{certs,crl,newcerts,private}} || \
    error_exit "Failed to create directory structure"
chmod -R 700 "${ROOT_CA_DIR}" || error_exit "Failed to set directory permissions"

# Initialize CA database files for root and all intermediate CAs
for CA_DIR in "${ROOT_CA_DIR}" "${FIREWALL_CA_DIR}" "${SERVICES_CA_DIR}" "${TAK_CA_DIR}"; do
    touch "${CA_DIR}/index.txt"
    echo "01" > "${CA_DIR}/serial"
    echo "01" > "${CA_DIR}/crlnumber"
done

# Root CA Configuration
cat > "${ROOT_CA_DIR}/Root-CA01-openssl.cnf" << 'EOL'
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = /etc/ssl/Root-CA01
certs             = $dir/certs
crl_dir           = $dir/crl
new_certs_dir     = $dir/newcerts
database          = $dir/index.txt
serial            = $dir/serial
RANDFILE          = $dir/private/.rand
private_key       = $dir/Root-CA01.key
certificate       = $dir/Root-CA01.crt
crlnumber         = $dir/crlnumber
crl               = $dir/Root-CA01.crl
crl_extensions    = crl_ext
default_md        = sha512
preserve          = no
policy            = policy_strict

[policy_strict]
countryName             = match
stateOrProvinceName     = optional
organizationName        = match
organizationalUnitName  = optional
commonName             = supplied
emailAddress           = optional

[crl_ext]
authorityKeyIdentifier=keyid:always

[req]
default_bits = 4096
default_md = sha512
default_keyfile = Root-CA01.key
distinguished_name = Root_CA01_dn
x509_extensions = Root_CA01_ext
prompt = no

[Root_CA01_dn]
countryName = DK
organizationName = OPKBTN
commonName = Root-CA01

[Root_CA01_ext]
basicConstraints = critical, CA:TRUE, pathlen:2
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
crlDistributionPoints = URI:file:///etc/ssl/Root-CA01/Root-CA01.crl
EOL

# Function to generate intermediate CA configuration
generate_intermediate_ca_config() {
    local ca_name=$1
    local ca_dir=$2
    local common_name=$3
    
    cat > "${ca_dir}/${ca_name}-openssl.cnf" << EOL
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = ${ca_dir}
certs             = \$dir/certs
crl_dir           = \$dir/crl
new_certs_dir     = \$dir/newcerts
database          = \$dir/index.txt
serial            = \$dir/serial
RANDFILE          = \$dir/private/.rand
private_key       = \$dir/${ca_name}-ca.key
certificate       = \$dir/${ca_name}-ca.crt
crlnumber         = \$dir/crlnumber
crl               = \$dir/${ca_name}-ca.crl
crl_extensions    = crl_ext
default_md        = sha512
preserve          = no
policy            = policy_strict

[policy_strict]
countryName             = match
stateOrProvinceName     = optional
organizationName        = match
organizationalUnitName  = optional
commonName             = supplied
emailAddress           = optional

[crl_ext]
authorityKeyIdentifier=keyid:always

[req]
default_bits = 4096
default_md = sha512
default_keyfile = ${ca_name}-ca.key
distinguished_name = ${ca_name}_ca_dn
x509_extensions = ${ca_name}_ca_ext
prompt = no

[${ca_name}_ca_dn]
countryName = DK
organizationName = OPKBTN
commonName = ${common_name}

[${ca_name}_ca_ext]
basicConstraints = critical, CA:TRUE, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
crlDistributionPoints = URI:file://${ca_dir}/${ca_name}-ca.crl
EOL
}

# Generate configurations for all intermediate CAs
generate_intermediate_ca_config "Firewall" "${FIREWALL_CA_DIR}" "Firewall Intermediate CA"
generate_intermediate_ca_config "Services" "${SERVICES_CA_DIR}" "Services Intermediate CA"
generate_intermediate_ca_config "TAK" "${TAK_CA_DIR}" "TAK Intermediate CA"

# Certificate Expiration Warning Function
check_cert_expiration() {
    local cert_path=$1
    local days_to_warn=$2
    
    if [ ! -f "$cert_path" ]; then
        error_exit "Certificate not found: $cert_path"
    fi
    
    local expiry_date
    expiry_date=$(openssl x509 -enddate -noout -in "$cert_path" | cut -d= -f2)
    
    local days_remaining
    days_remaining=$(date -d "$expiry_date" +%s | xargs -I {} bash -c "echo \$(( ({} - \$(date +%s)) / 86400 ))")
    
    if [ "$days_remaining" -le "$days_to_warn" ]; then
        echo "WARNING: Certificate $cert_path expires in $days_remaining days!"
        return 0
    fi
    
    return 1
}

# Generate Certificate Revocation List (CRL) Function
generate_crl() {
    local ca_key=$1
    local ca_cert=$2
    local crl_path=$3
    local config_file=$4
    local use_password=${5:-false}
    local password=${6:-""}
    
    # Debug information
    echo "Generating CRL..."
    echo "Using CA certificate: $ca_cert"
    echo "Using config file: $config_file"
    
    # Check if files exist
    [ ! -f "$ca_key" ] && echo "Error: CA key not found: $ca_key" && return 1
    [ ! -f "$ca_cert" ] && echo "Error: CA certificate not found: $ca_cert" && return 1
    [ ! -f "$config_file" ] && echo "Error: Config file not found: $config_file" && return 1
    
    # Ensure directory exists for CRL
    mkdir -p "$(dirname "$crl_path")"
    
    # Set proper permissions
    chmod 700 "$(dirname "$crl_path")"
    
    # Create empty CRL if database is empty
    if [ "$use_password" = true ] && [ -n "$password" ]; then
        openssl ca -gencrl \
            -keyfile "$ca_key" \
            -cert "$ca_cert" \
            -out "$crl_path" \
            -config "$config_file" \
            -passin pass:"$password" \
            -crldays 365 \
            -verbose || \
            error_exit "Failed to generate CRL for $ca_cert"
    else
        openssl ca -gencrl \
            -keyfile "$ca_key" \
            -cert "$ca_cert" \
            -out "$crl_path" \
            -config "$config_file" \
            -crldays 365 \
            -verbose || \
            error_exit "Failed to generate CRL for $ca_cert"
    fi
    
    # Set CRL permissions
    chmod 644 "$crl_path"
    
    echo "CRL generated successfully at $crl_path"
}
# Server Certificate Generation Function - Modified to include public key extraction
generate_server_cert() {
    local hostname=$1
    local ca_dir=$2
    local ca_name=$3
    local use_password=${4:-false}
    local password=${5:-""}
    local config_path="${ca_dir}/${hostname}-openssl.cnf"
    local cert_dir="${ca_dir}/certs"
    local key_dir="${ca_dir}/private"
    
    # Create configuration for specific server
    cat > "$config_path" << EOL
[req]
default_bits = 4096
default_md = sha512
distinguished_name = server_dn
req_extensions = server_ext
prompt = no

[server_dn]
commonName = ${hostname}

[server_ext]
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = critical, serverAuth
subjectAltName = DNS:${hostname},DNS:*.${hostname}
EOL

    # Generate private key
    openssl genrsa -out "${key_dir}/${hostname}.key" 4096
    chmod 400 "${key_dir}/${hostname}.key"
    
    # Generate CSR
    openssl req -config "$config_path" \
        -key "${key_dir}/${hostname}.key" \
        -new -out "${cert_dir}/${hostname}.csr"
    
    # Generate Certificate
    if [ "$use_password" = true ] && [ -n "$password" ]; then
        openssl x509 -req -days "$CERT_VALIDITY_DAYS" -sha512 \
            -CA "${ca_dir}/${ca_name}-ca.crt" \
            -CAkey "${ca_dir}/${ca_name}-ca.key" \
            -passin pass:"$password" \
            -CAcreateserial \
            -in "${cert_dir}/${hostname}.csr" \
            -out "${cert_dir}/${hostname}.crt" \
            -extfile "$config_path" \
            -extensions server_ext || \
            error_exit "Failed to generate certificate for ${hostname}"
    else
        openssl x509 -req -days "$CERT_VALIDITY_DAYS" -sha512 \
            -CA "${ca_dir}/${ca_name}-ca.crt" \
            -CAkey "${ca_dir}/${ca_name}-ca.key" \
            -CAcreateserial \
            -in "${cert_dir}/${hostname}.csr" \
            -out "${cert_dir}/${hostname}.crt" \
            -extfile "$config_path" \
            -extensions server_ext || \
            error_exit "Failed to generate certificate for ${hostname}"
    fi
    
    chmod 644 "${cert_dir}/${hostname}.crt"
    
    # Extract public key
    extract_public_key "${cert_dir}/${hostname}.crt" "${cert_dir}/${hostname}.pub"
    
if [ "$hostname" == "tak.opkbtn.dk" ]; then
    # Generate PEM
    cat "${key_dir}/${hostname}.key" "${cert_dir}/${hostname}.crt" > \
        "${cert_dir}/${hostname}.pem"
    chmod 400 "${cert_dir}/${hostname}.pem"
    
    # Create full chain PEM
    cat > "${cert_dir}/${hostname}-chain.pem" <<EOF
$(cat "${cert_dir}/${hostname}.crt")
$(cat "${TAK_CA_DIR}/TAK-ca.crt")
$(cat "${ROOT_CA_DIR}/Root-CA01.crt")
EOF
    
    # Generate PKCS12 with full chain
    openssl pkcs12 -export \
        -out "${cert_dir}/${hostname}.p12" \
        -inkey "${key_dir}/${hostname}.key" \
        -in "${cert_dir}/${hostname}.crt" \
        -certfile "${cert_dir}/${hostname}-chain.pem" \
        -passout pass:changeit || \
        error_exit "Failed to generate PKCS12 for ${hostname}"
    chmod 400 "${cert_dir}/${hostname}.p12"
    
    # Generate Java Keystore from PKCS12
    keytool -importkeystore \
        -srckeystore "${cert_dir}/${hostname}.p12" \
        -srcstoretype PKCS12 \
        -srcstorepass changeit \
        -destkeystore "${cert_dir}/${hostname}.jks" \
        -deststoretype JKS \
        -deststorepass changeit || \
        error_exit "Failed to generate JKS for ${hostname}"
    chmod 400 "${cert_dir}/${hostname}.jks"
fi

}

# Function to generate intermediate CA - Modified to include public key extraction
generate_intermediate_ca() {
    local ca_dir=$1
    local ca_name=$2
    local use_password=${3:-false}
    local password=${4:-""}
    
    if [ ! -f "${ca_dir}/${ca_name}-ca.key" ]; then
        # Generate private key with or without password
        if [ "$use_password" = true ] && [ -n "$password" ]; then
            # Generate encrypted private key
            openssl genrsa -aes256 -passout pass:"$password" \
                -out "${ca_dir}/${ca_name}-ca.key" 4096 || \
                error_exit "Failed to generate encrypted private key for ${ca_name}"
        else
            # Generate unencrypted private key
            openssl genrsa -out "${ca_dir}/${ca_name}-ca.key" 4096 || \
                error_exit "Failed to generate private key for ${ca_name}"
        fi
        chmod 400 "${ca_dir}/${ca_name}-ca.key"
        
        # Generate CSR (handle password if present)
        if [ "$use_password" = true ] && [ -n "$password" ]; then
            openssl req -config "${ca_dir}/${ca_name}-openssl.cnf" \
                -key "${ca_dir}/${ca_name}-ca.key" \
                -passin pass:"$password" \
                -new -out "${ca_dir}/${ca_name}-ca.csr" || \
                error_exit "Failed to generate CSR for ${ca_name}"
        else
            openssl req -config "${ca_dir}/${ca_name}-openssl.cnf" \
                -key "${ca_dir}/${ca_name}-ca.key" \
                -new -out "${ca_dir}/${ca_name}-ca.csr" || \
                error_exit "Failed to generate CSR for ${ca_name}"
        fi
        
        # Sign the intermediate CA with Root CA
        openssl x509 -req -days $CERT_VALIDITY_DAYS -sha512 \
            -CA "${ROOT_CA_DIR}/Root-CA01.crt" \
            -CAkey "${ROOT_CA_DIR}/Root-CA01.key" \
            -CAcreateserial \
            -in "${ca_dir}/${ca_name}-ca.csr" \
            -out "${ca_dir}/${ca_name}-ca.crt" \
            -extensions "${ca_name}_ca_ext" \
            -extfile "${ca_dir}/${ca_name}-openssl.cnf" || \
            error_exit "Failed to sign ${ca_name} certificate"
        chmod 644 "${ca_dir}/${ca_name}-ca.crt"
        
        # Extract public key for the CA certificate
        extract_public_key "${ca_dir}/${ca_name}-ca.crt" "${ca_dir}/${ca_name}-ca.pub"
    fi
}

# Generate Root CA - Modified to include public key extraction
if [ ! -f "${ROOT_CA_DIR}/Root-CA01.key" ]; then
    openssl genrsa -out "${ROOT_CA_DIR}/Root-CA01.key" 4096
    chmod 400 "${ROOT_CA_DIR}/Root-CA01.key"
    
    openssl req -config "${ROOT_CA_DIR}/Root-CA01-openssl.cnf" \
        -key "${ROOT_CA_DIR}/Root-CA01.key" \
        -new -x509 -days $((CERT_VALIDITY_DAYS * 2)) \
        -out "${ROOT_CA_DIR}/Root-CA01.crt"
    chmod 644 "${ROOT_CA_DIR}/Root-CA01.crt"
    
    # Extract public key for the root CA
    extract_public_key "${ROOT_CA_DIR}/Root-CA01.crt" "${ROOT_CA_DIR}/Root-CA01.pub"
fi

# Generate Intermediate CAs
generate_intermediate_ca "${FIREWALL_CA_DIR}" "Firewall" false
generate_intermediate_ca "${SERVICES_CA_DIR}" "Services" false
generate_intermediate_ca "${TAK_CA_DIR}" "TAK" true "$TAK_CA_PASSWORD"

# Generate CRLs for intermediate CAs
generate_crl \
    "${FIREWALL_CA_DIR}/Firewall-ca.key" \
    "${FIREWALL_CA_DIR}/Firewall-ca.crt" \
    "${FIREWALL_CA_DIR}/Firewall-ca.crl" \
    "${FIREWALL_CA_DIR}/Firewall-openssl.cnf" false

# Change "Services" to match the case used in configuration
generate_crl \
    "${SERVICES_CA_DIR}/Services-ca.key" \
    "${SERVICES_CA_DIR}/Services-ca.crt" \
    "${SERVICES_CA_DIR}/Services-ca.crl" \
    "${SERVICES_CA_DIR}/Services-openssl.cnf" false

generate_crl \
    "${TAK_CA_DIR}/TAK-ca.key" \
    "${TAK_CA_DIR}/TAK-ca.crt" \
    "${TAK_CA_DIR}/TAK-ca.crl" \
    "${TAK_CA_DIR}/TAK-openssl.cnf" true "$TAK_CA_PASSWORD"

# Generate server certificates for each intermediate CA
echo "Generating Firewall certificates..."
for hostname in "${FIREWALL_HOSTS[@]}"; do
    generate_server_cert "$hostname" "${FIREWALL_CA_DIR}" "Firewall" false
done

echo "Generating Service certificates..."
for hostname in "${SERVICE_HOSTS[@]}"; do
    generate_server_cert "$hostname" "${SERVICES_CA_DIR}" "Services" false
done

echo "Generating TAK certificates..."
for hostname in "${TAK_HOSTS[@]}"; do
    generate_server_cert "$hostname" "${TAK_CA_DIR}" "TAK" true "$TAK_CA_PASSWORD"
done

echo "PKI Infrastructure Setup Complete"