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

# Function to generate truststores for TAK CA and certificates
generate_truststores() {
    local ca_dir=$1
    local ca_name=$2
    local password=${3:-"changeit"}
    
    echo "Generating truststores for ${ca_name}..."
    
    # Create a trusted certificate version with client/server auth
    openssl x509 -in "${ca_dir}/${ca_name}-ca.crt" \
        -addtrust clientAuth \
        -addtrust serverAuth \
        -setalias "${ca_name}" \
        -out "${ca_dir}/${ca_name}-trusted.pem"
    
    # Create temporary chain file
    cat > "${ca_dir}/${ca_name}-full.pem" <<EOF
$(cat "${ca_dir}/${ca_name}-ca.crt")
$(cat "${ROOT_CA_DIR}/Root-CA01.crt")
EOF
    
    # Generate PKCS12 truststore with full chain
    openssl pkcs12 -export \
        -in "${ca_dir}/${ca_name}-full.pem" \
        -out "${ca_dir}/truststore-${ca_name}.p12" \
        -nokeys \
        -caname "${ca_name}" \
        -passout pass:"${password}"
    
    # Generate JKS truststore with full chain
    keytool -import -trustcacerts \
        -file "${ca_dir}/${ca_name}-full.pem" \
        -keystore "${ca_dir}/truststore-${ca_name}.jks" \
        -alias "${ca_name}" \
        -storepass "${password}" \
        -noprompt
    
    # Cleanup
    rm "${ca_dir}/${ca_name}-full.pem"
    
    # Set permissions
    chmod 644 "${ca_dir}/${ca_name}-trusted.pem"
    chmod 644 "${ca_dir}/truststore-${ca_name}.p12"
    chmod 644 "${ca_dir}/truststore-${ca_name}.jks"
    
    echo "Truststores generated successfully for ${ca_name}"
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

[Previous OpenSSL configurations remain the same...]

# Generate Root CA
if [ ! -f "${ROOT_CA_DIR}/Root-CA01.key" ]; then
    openssl genrsa -out "${ROOT_CA_DIR}/Root-CA01.key" 4096
    chmod 400 "${ROOT_CA_DIR}/Root-CA01.key"
    
    openssl req -config "${ROOT_CA_DIR}/Root-CA01-openssl.cnf" \
        -key "${ROOT_CA_DIR}/Root-CA01.key" \
        -new -x509 -days $((CERT_VALIDITY_DAYS * 2)) \
        -out "${ROOT_CA_DIR}/Root-CA01.crt"
    chmod 644 "${ROOT_CA_DIR}/Root-CA01.crt"
    
    extract_public_key "${ROOT_CA_DIR}/Root-CA01.crt" "${ROOT_CA_DIR}/Root-CA01.pub"
fi

# Generate Intermediate CAs
generate_intermediate_ca "${FIREWALL_CA_DIR}" "Firewall" false
generate_intermediate_ca "${SERVICES_CA_DIR}" "Services" false

# Generate TAK CA with truststores
generate_intermediate_ca "${TAK_CA_DIR}" "TAK" true "$TAK_CA_PASSWORD"

cat "${TAK_CA_DIR}/TAK-ca.key" "${TAK_CA_DIR}/TAK-ca.crt" > "${TAK_CA_DIR}/TAK-ca.pem"

chmod 400 "${TAK_CA_DIR}/TAK-ca.pem"

generate_truststores "${TAK_CA_DIR}" "TAK" "${TAK_CA_PASSWORD}"

# Generate CRLs
generate_crl \
    "${FIREWALL_CA_DIR}/Firewall-ca.key" \
    "${FIREWALL_CA_DIR}/Firewall-ca.crt" \
    "${FIREWALL_CA_DIR}/Firewall-ca.crl" \
    "${FIREWALL_CA_DIR}/Firewall-openssl.cnf" false

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

# Generate server certificates
echo "Generating Firewall certificates..."
for hostname in "${FIREWALL_HOSTS[@]}"; do
    generate_server_cert "$hostname" "${FIREWALL_CA_DIR}" "Firewall" false
done

echo "Generating Service certificates..."
for hostname in "${SERVICE_HOSTS[@]}"; do
    generate_server_cert "$hostname" "${SERVICES_CA_DIR}" "Services" false
done

# Generate TAK certificates with truststores
echo "Generating TAK certificates..."
for hostname in "${TAK_HOSTS[@]}"; do
    generate_server_cert "$hostname" "${TAK_CA_DIR}" "TAK" true "$TAK_CA_PASSWORD"
    
    # Generate truststores for TAK server certificates
    cert_dir="${TAK_CA_DIR}/certs"
    openssl pkcs12 -export \
        -out "${cert_dir}/truststore-${hostname}.p12" \
        -inkey "${TAK_CA_DIR}/private/${hostname}.key" \
        -in "${cert_dir}/${hostname}.crt" \
        -certfile "${cert_dir}/${hostname}-chain.pem" \
        -passout pass:"${TAK_CA_PASSWORD}"
    
    keytool -import -trustcacerts \
        -file "${cert_dir}/${hostname}-chain.pem" \
        -keystore "${cert_dir}/truststore-${hostname}.jks" \
        -alias "${hostname}" \
        -storepass "${TAK_CA_PASSWORD}" \
        -noprompt
    
    chmod 644 "${cert_dir}/truststore-${hostname}.p12"
    chmod 644 "${cert_dir}/truststore-${hostname}.jks"
done

echo "PKI Infrastructure Setup Complete"