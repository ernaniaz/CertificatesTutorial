#!/usr/bin/env bash
#=============================================================================
# Lab 07: Configure SSL
# NGINX SSL configuration
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

print_header "Lab 07: Configuring NGINX SSL"

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

# Create certificate directories
print_info "Creating certificate directories..."
mkdir -p /etc/pki/nginx
mkdir -p /etc/pki/nginx/private

# Copy certificates to system locations
print_info "Copying certificates..."
cp "${CERT_DIR}/server.crt" /etc/pki/nginx/server.crt
cp "${KEY_DIR}/rsa-2048.key" /etc/pki/nginx/private/server.key
chmod 644 /etc/pki/nginx/server.crt
chmod 600 /etc/pki/nginx/private/server.key

# Fix SELinux contexts for RHEL 9+
if [[ ${RHEL_VERSION} -ge 9 ]]; then
  print_info "Setting SELinux contexts..."
  restorecon -Rv /etc/pki/nginx/ 2>/dev/null || true
fi

print_success "Certificates copied"
echo

# Check current crypto-policy
if [[ ${RHEL_VERSION} -ge 8 ]]; then
  POLICY="$(update-crypto-policies --show 2>/dev/null || echo "DEFAULT")"
  echo "Current crypto-policy: ${POLICY}"
  echo
fi

# Create SSL server block configuration
print_info "Creating SSL server block configuration..."

if [[ ${RHEL_VERSION} -eq 7 ]]; then
  cat > /etc/nginx/conf.d/lab-ssl.conf << 'EOF'
#
# Lab 07: NGINX HTTPS Configuration (RHEL 7)
# Manual TLS protocol and cipher configuration
#

server {
    listen 443 ssl;
    server_name localhost server.example.com;

    # Root directory
    root /usr/share/nginx/html;
    index index.html;

    # Certificate files
    ssl_certificate /etc/pki/nginx/server.crt;
    ssl_certificate_key /etc/pki/nginx/private/server.key;

    # RHEL 7: Manual TLS configuration
    # Disable older protocols, use TLS 1.2+
    ssl_protocols TLSv1.2 TLSv1.3;

    # Strong cipher suites
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers on;

    # SSL session cache
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # HSTS (HTTP Strict Transport Security)
    add_header Strict-Transport-Security "max-age=31536000" always;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Logging
    access_log /var/log/nginx/ssl_access.log;
    error_log /var/log/nginx/ssl_error.log;

    location / {
        try_files $uri $uri/ =404;
    }
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name localhost server.example.com;
    return 301 https://${server_name}${request_uri};
}
EOF
fi
if [[ ${RHEL_VERSION} -eq 8 ]]; then
  cat > /etc/nginx/conf.d/lab-ssl.conf << 'EOF'
#
# Lab 07: NGINX HTTPS Configuration (RHEL 8)
# Uses crypto-policies but NGINX requires explicit SSL config
#

server {
    listen 443 ssl;
    server_name localhost server.example.com;

    # Root directory
    root /usr/share/nginx/html;
    index index.html;

    # Certificate files
    ssl_certificate /etc/pki/nginx/server.crt;
    ssl_certificate_key /etc/pki/nginx/private/server.key;

    # RHEL 8: Still specify protocols (crypto-policies influence available options)
    ssl_protocols TLSv1.2 TLSv1.3;

    # Let crypto-policies influence cipher selection
    # But can still specify preferences
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers off;

    # SSL session cache
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # HSTS (HTTP Strict Transport Security)
    add_header Strict-Transport-Security "max-age=31536000" always;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Logging
    access_log /var/log/nginx/ssl_access.log;
    error_log /var/log/nginx/ssl_error.log;

    location / {
        try_files $uri $uri/ =404;
    }
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name localhost server.example.com;
    return 301 https://${server_name}${request_uri};
}
EOF
fi
if [[ ${RHEL_VERSION} -ge 9 ]]; then
  cat > /etc/nginx/conf.d/lab-ssl.conf << 'EOF'
#
# Lab 07: NGINX HTTPS Configuration (RHEL 9)
# OpenSSL 3.x with stricter defaults
#

server {
    listen 443 ssl;
    server_name localhost server.example.com;

    # Root directory
    root /usr/share/nginx/html;
    index index.html;

    # Certificate files
    ssl_certificate /etc/pki/nginx/server.crt;
    ssl_certificate_key /etc/pki/nginx/private/server.key;

    # RHEL 9: TLS 1.2 and 1.3 only (1.3 preferred)
    ssl_protocols TLSv1.2 TLSv1.3;

    # Modern cipher suites (RHEL 9 blocks weak ciphers)
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305';
    ssl_prefer_server_ciphers off;

    # SSL session cache
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # HSTS (HTTP Strict Transport Security)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Logging
    access_log /var/log/nginx/ssl_access.log;
    error_log /var/log/nginx/ssl_error.log;

    location / {
        try_files $uri $uri/ =404;
    }
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name localhost server.example.com;
    return 301 https://${server_name}${request_uri};
}
EOF
fi

print_success "SSL server block configured"
echo

# Create test page
case ${RHEL_VERSION} in
  7)
    echo "<html><body><h1>Lab 07: NGINX HTTPS Test</h1><p>RHEL 7 - Manual TLS configuration</p></body></html>" > /usr/share/nginx/html/index.html
    ;;
  8)
    echo "<html><body><h1>Lab 07: NGINX HTTPS Test</h1><p>RHEL 8 - Crypto-policies enabled</p></body></html>" > /usr/share/nginx/html/index.html
    ;;
  9)
    echo "<html><body><h1>Lab 07: NGINX HTTPS Test</h1><p>RHEL 9 - OpenSSL 3.x with strict security</p></body></html>" > /usr/share/nginx/html/index.html
    ;;
  10)
    echo "<html><body><h1>Lab 07: NGINX HTTPS Test</h1><p>RHEL 10 - OpenSSL 3.x with strict security</p></body></html>" > /usr/share/nginx/html/index.html
    ;;
esac

# Test configuration
print_info "Testing configuration..."
if nginx -t; then
  print_success "Configuration syntax OK"
else
  print_error "Configuration syntax error"
  exit 1
fi

# Restart NGINX
echo
print_info "Restarting NGINX..."
systemctl restart nginx

if systemctl is-active nginx &>/dev/null; then
  print_success "NGINX restarted successfully"
else
  print_error "NGINX failed to restart"
  journalctl -xeu nginx | tail -20
  exit 1
fi

echo
print_success "SSL configuration complete"
echo
echo "Test your HTTPS setup:"
echo "  curl https://localhost/ --insecure"
echo "  openssl s_client -connect localhost:443 -servername localhost"
