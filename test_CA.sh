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

# Intermediate CA directories
FIREWALL_CA_DIR="${ROOT_CA_DIR}/intermediates/Firewall-CA"
SERVICES_CA_DIR="${ROOT_CA_DIR}/intermediates/Services-CA"
TAK_CA_DIR="${ROOT_CA_DIR}/intermediates/TAK-CA"

# Error handling function
error_exit() {
    echo "Error: ${1:-"Unknown Error"}" >&2
    exit 1
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
cat > "${ROOT_CA_DIR}/root-openssl.cnf" << 'EOL'
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
private_key       = $dir/root-ca.key
certificate       = $dir/root-ca.crt
crlnumber         = $dir/crlnumber
crl               = $dir/root-ca.crl
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
default_keyfile = root-ca.key
distinguished_name = root_ca_dn
x509_extensions = root_ca_ext
prompt = no

[root_ca_dn]
countryName = DK
organizationName = OPKBTN
commonName = Root-CA01

[root_ca_ext]
basicConstraints = critical, CA:TRUE, pathlen:2
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
crlDistributionPoints = URI:file:///etc/ssl/Root-CA01/root-ca.crl
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
    }
    
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
    
    openssl ca -gencrl \
        -keyfile "$ca_key" \
        -cert "$ca_cert" \
        -out "$crl_path" \
        -config "$config_file" || \
        error_exit "Failed to generate CRL for $ca_cert"
        
    chmod 644 "$crl_path"
}

# Server Certificate Generation Function
generate_server_cert() {
    local hostname=$1
    local ca_dir=$2
    local ca_name=$3
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
    openssl x509 -req -days "$CERT_VALIDITY_DAYS" -sha512 \
        -CA "${ca_dir}/${ca_name}-ca.crt" \
        -CAkey "${ca_dir}/${ca_name}-ca.key" \
        -CAcreateserial \
        -in "${cert_dir}/${hostname}.csr" \
        -out "${cert_dir}/${hostname}.crt" \
        -extfile "$config_path" \
        -extensions server_ext
    
    chmod 644 "${cert_dir}/${hostname}.crt"
    
    # Special handling for TAK server
    if [ "$hostname" == "tak.opkbtn.dk" ]; then
        # Generate PEM
        cat "${key_dir}/${hostname}.key" "${cert_dir}/${hostname}.crt" > \
            "${cert_dir}/${hostname}.pem"
        chmod 400 "${cert_dir}/${hostname}.pem"
        
        # Generate PKCS12
        openssl pkcs12 -export \
            -out "${cert_dir}/${hostname}.p12" \
            -inkey "${key_dir}/${hostname}.key" \
            -in "${cert_dir}/${hostname}.crt" \
            -passout pass:changeit
        chmod 400 "${cert_dir}/${hostname}.p12"
        
        # Generate Java Keystore
        keytool -importcert -noprompt \
            -alias "${hostname}" \
            -file "${cert_dir}/${hostname}.crt" \
            -keystore "${cert_dir}/${hostname}.jks" \
            -storepass changeit
        chmod 400 "${cert_dir}/${hostname}.jks"
    fi
}

# Function to generate intermediate CA
generate_intermediate_ca() {
    local ca_dir=$1
    local ca_name=$2
    
    if [ ! -f "${ca_dir}/${ca_name}-ca.key" ]; then
        openssl genrsa -out "${ca_dir}/${ca_name}-ca.key" 4096
        chmod 400 "${ca_dir}/${ca_name}-ca.key"
        
        openssl req -config "${ca_dir}/${ca_name}-openssl.cnf" \
            -key "${ca_dir}/${ca_name}-ca.key" \
            -new -out "${ca_dir}/${ca_name}-ca.csr"
        
        openssl x509 -req -days $CERT_VALIDITY_DAYS -sha512 \
            -CA "${ROOT_CA_DIR}/root-ca.crt" \
            -CAkey "${ROOT_CA_DIR}/root-ca.key" \
            -CAcreateserial \
            -in "${ca_dir}/${ca_name}-ca.csr" \
            -out "${ca_dir}/${ca_name}-ca.crt" \
            -extensions "${ca_name}_ca_ext" \
            -extfile "${ca_dir}/${ca_name}-openssl.cnf"
        chmod 644 "${ca_dir}/${ca_name}-ca.crt"
    fi
}

# Generate Root CA
if [ ! -f "${ROOT_CA_DIR}/root-ca.key" ]; then
    openssl genrsa -out "${ROOT_CA_DIR}/root-ca.key" 4096
    chmod 400 "${ROOT_CA_DIR}/root-ca.key"
    
    openssl req -config "${ROOT_CA_DIR}/root-openssl.cnf" \
        -key "${ROOT_CA_DIR}/root-ca.key" \
        -new -x509 -days $((CERT_VALIDITY_DAYS * 2)) \
        -out "${ROOT_CA_DIR}/root-ca.crt"
    chmod 644 "${ROOT_CA_DIR}/root-ca.crt"
fi

# Generate Intermediate CAs
generate_intermediate_ca "${FIREWALL_CA_DIR}" "Firewall"
generate_intermediate_ca "${SERVICES_CA_DIR}" "Services"
generate_intermediate_ca "${TAK_CA_DIR}" "TAK"

# Generate CRLs
generate_crl \
    "${ROOT_CA_DIR}/root-ca.key" \
    "${ROOT_CA_DIR}/root-ca.crt" \
    "${ROOT_CA_DIR}/root-ca.crl" \
    "${ROOT_CA_DIR}/root-openssl.cnf"

for CA_INFO in "Firewall:${FIREWALL_CA_DIR}" "Services:${SERVICES_CA_DIR}" "TAK:${TAK_CA_DIR}"; do
    IFS=':' read -r ca_name ca_dir <<< "${CA_INFO}"
    generate_crl \
        "${ca_dir}/${ca_name}-ca.key" \
        "${ca_dir}/${ca_name}-ca.crt" \
        "${ca_dir}/${ca_name}-ca.crl" \
        "${ca_dir}/${ca_name}-openssl.cnf"
done

# Generate server certificates for each intermediate CA
echo "Generating Firewall certificates..."
for hostname in "${FIREWALL_HOSTS[@]}"; do
    generate_server_cert "$hostname" "${FIREWALL_CA_DIR}" "Firewall"
done

echo "Generating Service certificates..."
for hostname in "${SERVICE_HOSTS[@]}"; do
    generate_server_cert "$hostname" "${SERVICES_CA_DIR}" "Services"
done

echo "Generating TAK certificates..."
for hostname in "${TAK_HOSTS[@]}"; do
    generate_server_cert "$hostname" "${TAK_CA_DIR}" "TAK"
done

# Check certificate expirations
echo "Checking Certificate Expirations:"
for CA_INFO in "Firewall:${FIREWALL_CA_DIR}:${FIREWALL_HOSTS[*]}" "Services:${SERVICES_CA_DIR}:${SERVICE_HOSTS[*]}" "TAK:${TAK_CA_DIR}:${TAK_HOSTS[*]}"; do
    IFS=':' read -r ca_name ca_dir hosts <<< "${CA_INFO}"
    for hostname in ${hosts}; do
        check_cert_expiration "${ca_dir}/certs/${hostname}.crt" "$WARN_BEFORE_EXPIRY"
    done
done

echo "PKI Infrastructure Setup Complete"