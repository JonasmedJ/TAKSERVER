#!/bin/bash

# PKI Infrastructure Setup for Proxmox Server with Multiple Intermediate CAs
set -euo pipefail # Exit on error, undefined var, or pipe failure

# Configuration Variables
CERT_VALIDITY_DAYS=365
WARN_BEFORE_EXPIRY=30
ROOT_CA_DIR="/etc/ssl/Root-CA01"

# Service-specific hostnames
FIREWALL_HOSTS=("fw.opkbtn.dk")
SERVICE_HOSTS=("pve.opkbtn.dk" "dns.opkbtn.dk" "npm.opkbtn.dk" "ldaps.opkbtn.dk",)
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

# [Previous configuration sections remain unchanged...]
# [All the openssl.cnf configurations remain the same...]

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
    
    # [Previous certificate generation code remains unchanged until after the certificate is created]
    
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
            -passout pass:changeit || \
            error_exit "Failed to generate PKCS12 for ${hostname}"
        chmod 400 "${cert_dir}/${hostname}.p12"
        
        # Generate Java Keystore
        keytool -importcert -noprompt \
            -alias "${hostname}" \
            -file "${cert_dir}/${hostname}.crt" \
            -keystore "${cert_dir}/${hostname}.jks" \
            -storepass changeit || \
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