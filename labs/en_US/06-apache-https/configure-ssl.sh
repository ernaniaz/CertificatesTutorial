#!/usr/bin/env bash
#=============================================================================
# Lab 06: Configure SSL
# Apache SSL configuration
#
# Usage: ./configure-ssl.sh
# Prerequisites: RHEL 7, 8, 9, 10, root privileges
#=============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable

#=============================================================================
# CONFIGURATION
#=============================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

#=============================================================================
# HELPER FUNCTIONS
#=============================================================================

print_header ()
{
  local text="${1}"
  local width=57
  local padding=$(( width - ${#text} ))
  local pad=""
  if [[ ${padding} -gt 0 ]]; then
    pad="$(printf '%*s' "${padding}" '')"
  fi
  echo
  echo -e "${CYAN}┌─$(printf '─%.0s' $(seq 1 ${width}))─┐${NC}"
  echo -e "${CYAN}│${NC} ${BOLD}${text}${NC}${pad} ${CYAN}│${NC}"
  echo -e "${CYAN}└─$(printf '─%.0s' $(seq 1 ${width}))─┘${NC}"
  echo
}

print_step ()
{
  echo
  echo -e "  ${BOLD}▸ ${1}${NC}"
}

print_success ()
{
  echo -e "  ${GREEN}✓${NC} ${1}"
}

print_error ()
{
  echo -e "  ${RED}✗${NC} ${1}"
}

print_warning ()
{
  echo -e "  ${YELLOW}⚠${NC} ${1}"
}

print_info ()
{
  echo -e "  ${BLUE}ℹ${NC} ${1}"
}

error_exit ()
{
  print_error "${1}"
  exit 1
}

trap 'error_exit "Error occurred on line ${LINENO}"' ERR

#=============================================================================
# RHEL VERSION CHECK
#=============================================================================

if ! grep -q '^ID="rhel"$' /etc/os-release 2>/dev/null; then
  error_exit "This script requires Red Hat Enterprise Linux (RHEL)."
fi
readonly RHEL_VERSION="$(grep -oP '^VERSION_ID="\K[0-9]+' /etc/os-release 2>/dev/null)"
if [[ ${RHEL_VERSION} -lt 7 || ${RHEL_VERSION} -gt 10 ]]; then
  error_exit "Unsupported RHEL version. This script requires RHEL 7, 8, 9 or 10."
fi

#=============================================================================
# MAIN
#=============================================================================

CERT_DIR="../04-x509-certificates/output"
KEY_DIR="../02-key-generation/output"

print_header "Lab 06: Configuring Apache SSL"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

# Check prerequisites
if [[ ! -f "${CERT_DIR}/server.crt" || ! -f "${KEY_DIR}/rsa-2048.key" ]]; then
  print_error "Error: Certificates not found. Complete Labs 02 and 04 first."
  exit 1
fi

# RHEL 9+ specific checks
if [[ ${RHEL_VERSION} -ge 9 ]]; then
  # Verify certificate has SANs (required on RHEL 9+)
  if ! openssl x509 -in "${CERT_DIR}/server.crt" -noout -ext subjectAltName 2>/dev/null | grep -q "DNS"; then
    print_warning "Warning: Certificate lacks SANs (required on RHEL 9+)"
    echo "Consider recreating certificate with SANs in Lab 04"
  fi

  # Verify certificate signature algorithm (not SHA-1)
  SIG_ALG=$(openssl x509 -in "${CERT_DIR}/server.crt" -noout -text | grep "Signature Algorithm" | head -1)
  if echo "${SIG_ALG}" | grep -qi "sha1"; then
    print_error "Error: Certificate uses SHA-1 (blocked on RHEL 9+)"
    echo "Recreate certificate with SHA-256+ in Lab 04"
    exit 1
  else
    print_success "Certificate signature algorithm OK (not SHA-1)"
  fi
fi

# Copy certificates
print_info "Copying certificates..."
cp "${CERT_DIR}/server.crt" /etc/pki/tls/certs/lab-server.crt
cp "${KEY_DIR}/rsa-2048.key" /etc/pki/tls/private/lab-server.key
chmod 644 /etc/pki/tls/certs/lab-server.crt
chmod 600 /etc/pki/tls/private/lab-server.key

print_success "Certificates copied"
echo

# Create SSL VirtualHost file
print_info "Creating SSL VirtualHost configuration..."
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  # Create SSL VirtualHost (RHEL 7 requires manual TLS settings)
  cat > /etc/httpd/conf.d/lab-ssl.conf << 'EOF'
#
# Lab 06: Apache HTTPS Configuration (RHEL 7)
# Manual TLS protocol and cipher configuration required
#

<VirtualHost *:443>
    ServerName localhost
    ServerAlias server.example.com
    DocumentRoot /var/www/html

    # Enable SSL/TLS
    SSLEngine on

    # Certificate files
    SSLCertificateFile /etc/pki/tls/certs/lab-server.crt
    SSLCertificateKeyFile /etc/pki/tls/private/lab-server.key

    # RHEL 7: MUST manually configure TLS versions
    # Disable old, insecure protocols
    SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1

    # RHEL 7: MUST manually configure cipher suites
    # Use only strong ciphers
    SSLCipherSuite ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256
    SSLHonorCipherOrder on

    # HSTS (HTTP Strict Transport Security)
    Header always set Strict-Transport-Security "max-age=31536000"

    # Logging
    ErrorLog logs/ssl_error_log
    CustomLog logs/ssl_access_log combined

    <Directory /var/www/html>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
</VirtualHost>
EOF

  print_success "SSL VirtualHost configured (RHEL 7 manual mode)"
fi

if [[ ${RHEL_VERSION} -eq 8 ]]; then
  # Create SSL VirtualHost (RHEL 8 with crypto-policies)
  cat > /etc/httpd/conf.d/lab-ssl.conf << 'EOF'
#
# Lab 06: Apache HTTPS Configuration (RHEL 8)
# Uses crypto-policies for TLS settings
#

<VirtualHost *:443>
    ServerName localhost
    ServerAlias server.example.com
    DocumentRoot /var/www/html

    # Enable SSL/TLS
    SSLEngine on

    # Certificate files
    SSLCertificateFile /etc/pki/tls/certs/lab-server.crt
    SSLCertificateKeyFile /etc/pki/tls/private/lab-server.key

    # RHEL 8: Crypto-policies handle TLS versions and ciphers
    # No need to specify SSLProtocol or SSLCipherSuite

    # HSTS (HTTP Strict Transport Security)
    Header always set Strict-Transport-Security "max-age=31536000"

    # Logging
    ErrorLog logs/ssl_error_log
    CustomLog logs/ssl_access_log combined

    <Directory /var/www/html>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
</VirtualHost>
EOF

  print_success "SSL VirtualHost configured"
fi

if [[ ${RHEL_VERSION} -ge 9 ]]; then
  # Create SSL VirtualHost (RHEL 9+ with crypto-policies)
  cat > /etc/httpd/conf.d/lab-ssl.conf << 'EOF'
#
# Lab 06: Apache HTTPS Configuration (RHEL 9)
# Uses crypto-policies for TLS settings
# OpenSSL 3.x with enhanced security
#

<VirtualHost *:443>
    ServerName localhost
    ServerAlias server.example.com
    DocumentRoot /var/www/html

    # Enable SSL/TLS
    SSLEngine on

    # Certificate files
    SSLCertificateFile /etc/pki/tls/certs/lab-server.crt
    SSLCertificateKeyFile /etc/pki/tls/private/lab-server.key

    # RHEL 9: Crypto-policies handle everything
    # No SSLProtocol or SSLCipherSuite needed
    # Managed by: /etc/crypto-policies/config

    # HSTS (HTTP Strict Transport Security)
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"

    # Logging
    ErrorLog logs/ssl_error_log
    CustomLog logs/ssl_access_log combined

    <Directory /var/www/html>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
</VirtualHost>
EOF

  print_success "SSL VirtualHost configured"
fi

echo

# Create test page
case ${RHEL_VERSION} in
  7)
    echo "<html><body><h1>Lab 06: Apache HTTPS Test</h1><p>RHEL 7 - Manual TLS configuration</p></body></html>" > /var/www/html/index.html
    ;;
  8)
    echo "<html><body><h1>Lab 06: Apache HTTPS Test</h1><p>RHEL 8 - Crypto-policies enabled</p></body></html>" > /var/www/html/index.html
    ;;
  9)
    echo "<html><body><h1>Lab 06: Apache HTTPS Test</h1><p>RHEL 9 - OpenSSL 3.x, SHA-1 blocked, SANs required</p></body></html>" > /var/www/html/index.html
    ;;
  10)
    echo "<html><body><h1>Lab 06: Apache HTTPS Test</h1><p>RHEL 10 - OpenSSL 3.x, SHA-1 blocked, SANs required</p></body></html>" > /var/www/html/index.html
    ;;
esac

# Check current crypto-policy
if [[ ${RHEL_VERSION} -ge 8 ]]; then
  POLICY=$(update-crypto-policies --show 2>/dev/null || echo "DEFAULT")
  echo "Current crypto-policy: ${POLICY}"
  echo
fi

# Test configuration
print_info "Testing configuration..."
if apachectl configtest 2>&1 | grep -q "Syntax OK"; then
  print_success "Configuration syntax OK"
else
  print_error "Configuration syntax error"
  apachectl configtest
  exit 1
fi

# Restart Apache
echo
print_info "Restarting Apache..."
systemctl restart httpd

if systemctl is-active httpd &>/dev/null; then
  print_success "Apache restarted successfully"
else
  print_error "Apache failed to restart"
  journalctl -xeu httpd | tail -20
  exit 1
fi

echo
print_success "SSL configuration complete"
echo

case ${RHEL_VERSION} in
  7)
    echo "RHEL 7 Configuration Notes:"
    echo "  - TLS protocols manually configured (no TLS 1.0/1.1)"
    echo "  - Cipher suites explicitly set"
    echo "  - crypto-policies not available on RHEL 7"
    ;;
  8)
    echo "Test your HTTPS setup:"
    echo "  curl https://localhost/ --insecure"
    echo "  openssl s_client -connect localhost:443 -servername localhost"
    ;;
  9|10)
    echo "RHEL 9/10 Configuration Notes:"
    echo "  - OpenSSL 3.x active"
    echo "  - SHA-1 signatures blocked"
    echo "  - SANs required for hostname validation"
    echo "  - crypto-policies: ${POLICY}"
    ;;
esac
