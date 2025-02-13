# SSL Certificate Creation Guide for opkbtn.dk

## 1. Create Intermediate CA for Services

```bash
# Create directory structure
mkdir -p ca/services
cd ca/services

# Generate private key for services intermediate CA
openssl genrsa -aes256 -out services-intermediate.key 4096

# Generate CSR for services intermediate CA
openssl req -new -sha256 \
    -key services-intermediate.key \
    -out services-intermediate.csr \
    -subj "/C=DK/O=opkbtn.dk/CN=Services Intermediate CA"

# Sign the intermediate CA with root CA
openssl x509 -req -days 3650 -sha256 \
    -in services-intermediate.csr \
    -CA ../ca.pem \
    -CAkey ../ca.key \
    -CAcreateserial \
    -out services-intermediate.pem \
    -extfile <(printf "basicConstraints=critical,CA:true,pathlen:0\nkeyUsage=critical,digitalSignature,keyCertSign,cRLSign")
```

## 2. Create Intermediate CA for OPNsense Firewall

```bash
# Create directory for firewall
mkdir -p ../firewall
cd ../firewall

# Generate private key for firewall intermediate CA
openssl genrsa -aes256 -out firewall-intermediate.key 4096

# Generate CSR for firewall intermediate CA
openssl req -new -sha256 \
    -key firewall-intermediate.key \
    -out firewall-intermediate.csr \
    -subj "/C=DK/O=opkbtn.dk/CN=Firewall Intermediate CA"

# Sign the intermediate CA with root CA
openssl x509 -req -days 3650 -sha256 \
    -in firewall-intermediate.csr \
    -CA ../ca.pem \
    -CAkey ../ca.key \
    -CAcreateserial \
    -out firewall-intermediate.pem \
    -extfile <(printf "basicConstraints=critical,CA:true,pathlen:0\nkeyUsage=critical,digitalSignature,keyCertSign,cRLSign")
```

## 3. Generate Service Certificates

### DNS Certificate (P12 format)

```bash
cd ../services

# Generate private key
openssl genrsa -out dns.key 2048

# Generate CSR
openssl req -new -sha256 \
    -key dns.key \
    -out dns.csr \
    -subj "/C=DK/O=opkbtn.dk/CN=dns.opkbtn.dk"

# Sign certificate
openssl x509 -req -days 365 -sha256 \
    -in dns.csr \
    -CA services-intermediate.pem \
    -CAkey services-intermediate.key \
    -CAcreateserial \
    -out dns.pem \
    -extfile <(printf "subjectAltName=DNS:dns.opkbtn.dk\nkeyUsage=digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth")

# Convert to P12 format
openssl pkcs12 -export \
    -inkey dns.key \
    -in dns.pem \
    -certfile services-intermediate.pem \
    -out dns.p12
```

### NGINX Proxy Manager Certificate

```bash
# Generate private key
openssl genrsa -out nginx.key 2048

# Generate CSR
openssl req -new -sha256 \
    -key nginx.key \
    -out nginx.csr \
    -subj "/C=DK/O=opkbtn.dk/CN=proxy.opkbtn.dk"

# Sign certificate
openssl x509 -req -days 365 -sha256 \
    -in nginx.csr \
    -CA services-intermediate.pem \
    -CAkey services-intermediate.key \
    -CAcreateserial \
    -out nginx.pem \
    -extfile <(printf "subjectAltName=DNS:proxy.opkbtn.dk\nkeyUsage=digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth")
```

### WireGuard VPN Certificate

```bash
# Generate private key
openssl genrsa -out wireguard.key 2048

# Generate CSR
openssl req -new -sha256 \
    -key wireguard.key \
    -out wireguard.csr \
    -subj "/C=DK/O=opkbtn.dk/CN=vpn.opkbtn.dk"

# Sign certificate
openssl x509 -req -days 365 -sha256 \
    -in wireguard.csr \
    -CA services-intermediate.pem \
    -CAkey services-intermediate.key \
    -CAcreateserial \
    -out wireguard.pem \
    -extfile <(printf "subjectAltName=DNS:vpn.opkbtn.dk\nkeyUsage=digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth")
```

### LDAP Certificate

```bash
# Generate private key
openssl genrsa -out ldap.key 2048

# Generate CSR
openssl req -new -sha256 \
    -key ldap.key \
    -out ldap.csr \
    -subj "/C=DK/O=opkbtn.dk/CN=ldap.opkbtn.dk"

# Sign certificate
openssl x509 -req -days 365 -sha256 \
    -in ldap.csr \
    -CA services-intermediate.pem \
    -CAkey services-intermediate.key \
    -CAcreateserial \
    -out ldap.pem \
    -extfile <(printf "subjectAltName=DNS:ldap.opkbtn.dk\nkeyUsage=digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth")
```

### Proxmox Certificate

```bash
# Generate private key
openssl genrsa -out proxmox.key 2048

# Generate CSR
openssl req -new -sha256 \
    -key proxmox.key \
    -out proxmox.csr \
    -subj "/C=DK/O=opkbtn.dk/CN=proxmox.opkbtn.dk"

# Sign certificate
openssl x509 -req -days 365 -sha256 \
    -in proxmox.csr \
    -CA services-intermediate.pem \
    -CAkey services-intermediate.key \
    -CAcreateserial \
    -out proxmox.pem \
    -extfile <(printf "subjectAltName=DNS:proxmox.opkbtn.dk\nkeyUsage=digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth")
```

## Notes

1. You'll be prompted for passwords at various steps:
   - When using the root CA key (ca.key)
   - When creating the intermediate CA keys
   - When creating the PKCS12 file for DNS

2. Certificate chains:
   - For WireGuard: Combine certificates in this order:
     ```bash
     cat wireguard.pem services-intermediate.pem > wireguard-chain.pem
     ```
   - For Proxmox: Combine certificates in this order:
     ```bash
     cat proxmox.pem services-intermediate.pem > proxmox-chain.pem
     ```

3. Security recommendations:
   - Keep all private keys (.key files) secure and backed up
   - The intermediate CA certificates should be distributed to clients that need to trust these services
   - Consider adjusting the validity periods (days) based on your security requirements