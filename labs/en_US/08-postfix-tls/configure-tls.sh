#!/usr/bin/env bash
#=============================================================================
# Lab 08: Configure TLS
# Configure TLS for SMTP and submission
#
# Usage: ./configure-tls.sh
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

print_header "Lab 08: Configuring Postfix TLS"

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

# Backup original configuration
print_info "Backing up original configuration..."
if [[ ! -f /etc/postfix/main.cf.lab-backup ]]; then
  cp /etc/postfix/main.cf /etc/postfix/main.cf.lab-backup
  print_success "Configuration backed up"
else
  echo "Backup already exists"
fi
echo

# Copy certificates to system locations
print_info "Copying certificates..."
cp "${CERT_DIR}/server.crt" /etc/pki/tls/certs/postfix.crt
cp "${KEY_DIR}/rsa-2048.key" /etc/pki/tls/private/postfix.key
chmod 644 /etc/pki/tls/certs/postfix.crt
chmod 600 /etc/pki/tls/private/postfix.key
chown root:root /etc/pki/tls/private/postfix.key

print_success "Certificates copied"
echo

# Configure TLS in main.cf
print_info "Configuring TLS parameters..."

# Remove any existing TLS configuration to avoid duplicates
sed -i '/^smtpd_tls_/d' /etc/postfix/main.cf
sed -i '/^smtp_tls_/d' /etc/postfix/main.cf
sed -i '/^tls_ssl_options/d' /etc/postfix/main.cf

# Add TLS configuration
cat >> /etc/postfix/main.cf << 'EOF'

# Lab 08: TLS Configuration
# Server TLS (incoming connections)
smtpd_tls_cert_file = /etc/pki/tls/certs/postfix.crt
smtpd_tls_key_file = /etc/pki/tls/private/postfix.key
smtpd_tls_security_level = may
smtpd_tls_loglevel = 1
smtpd_tls_session_cache_database = btree:/var/lib/postfix/smtpd_tls_cache
smtpd_tls_received_header = yes

# Client TLS (outgoing connections)
smtp_tls_security_level = may
smtp_tls_loglevel = 1
smtp_tls_session_cache_database = btree:/var/lib/postfix/smtp_tls_cache

# TLS protocols (disable old versions)
smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtp_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1

# Strong ciphers only
smtpd_tls_ciphers = high
smtpd_tls_exclude_ciphers = aNULL, MD5, DES, 3DES, RC4
smtpd_tls_mandatory_ciphers = high

EOF

# Disable compression (CRIME attack) - requires Postfix 2.11+ (RHEL 8+)
if [[ ${RHEL_VERSION} -ge 8 ]]; then
  postconf -e "tls_ssl_options = NO_COMPRESSION"
fi

print_success "TLS parameters configured"
echo

# Configure submission port (587) in master.cf
print_info "Configuring submission port (587)..."

# Check if submission is already uncommented
if grep -q "^submission inet" /etc/postfix/master.cf; then
  echo "Submission already enabled"
else
  # Uncomment submission lines
  sed -i '/^#submission inet/,/^#  -o smtpd_reject_unlisted_recipient=no/ s/^#//' /etc/postfix/master.cf

  # If that didn't work, add submission manually
  if ! grep -q "^submission inet" /etc/postfix/master.cf; then
    cat >> /etc/postfix/master.cf << 'EOF'

# Lab 08: Submission port configuration
submission inet n       -       n       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_reject_unlisted_recipient=no
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
EOF
  fi
fi

print_success "Submission port configured"
echo

# Check configuration
print_info "Checking configuration..."
if postfix check; then
  print_success "Configuration OK"
else
  print_error "Configuration error"
  exit 1
fi

# Restart Postfix
echo
print_info "Restarting Postfix..."
systemctl restart postfix

if systemctl is-active postfix &>/dev/null; then
  print_success "Postfix restarted successfully"
else
  print_error "Postfix failed to restart"
  journalctl -xeu postfix | tail -20
  exit 1
fi

echo
print_success "TLS configuration complete"
echo
echo "TLS settings:"
postconf -n | grep tls

echo
echo "Test STARTTLS:"
echo "  openssl s_client -connect localhost:25 -starttls smtp"
