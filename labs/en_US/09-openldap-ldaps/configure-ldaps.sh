#!/usr/bin/env bash
#=============================================================================
# Lab 09: Configure LDAPS
# Configure OpenLDAP with TLS certificates
#
# Usage: ./configure-ldaps.sh
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

print_header "Lab 09: Configuring OpenLDAP LDAPS"

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

# Create certificate directory for OpenLDAP
print_info "Creating certificate directories..."
mkdir -p /etc/openldap/certs
chmod 755 /etc/openldap/certs

# Copy certificates
print_info "Copying certificates..."
cp "${CERT_DIR}/server.crt" /etc/openldap/certs/ldap.crt
cp "${KEY_DIR}/rsa-2048.key" /etc/openldap/certs/ldap.key
chmod 644 /etc/openldap/certs/ldap.crt
chmod 600 /etc/openldap/certs/ldap.key
chown ldap:ldap /etc/openldap/certs/ldap.crt
chown ldap:ldap /etc/openldap/certs/ldap.key

print_success "Certificates copied"
echo

# Fix SELinux contexts
print_info "Setting SELinux contexts..."
restorecon -Rv /etc/openldap/certs/ 2>/dev/null || true

# Configure TLS in cn=config
print_info "Configuring TLS in cn=config..."

# Create LDIF to configure TLS
cat > /tmp/tls-config.ldif << EOF
dn: cn=config
changetype: modify
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/openldap/certs/ldap.crt
-
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/openldap/certs/ldap.key
-
add: olcTLSProtocolMin
olcTLSProtocolMin: 3.3
-
add: olcTLSCipherSuite
olcTLSCipherSuite: HIGH:!aNULL:!MD5
EOF

# Apply TLS configuration
if ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/tls-config.ldif 2>/dev/null; then
  print_success "TLS configuration applied"
else
  print_warning "TLS may already be configured, continuing..."
fi

rm -f /tmp/tls-config.ldif
echo

# Enable LDAPS (port 636)
print_info "Enabling LDAPS on port 636..."

# Check current SLAPD_URLS
if [[ -f /etc/sysconfig/slapd ]]; then
  # Backup original
  if [[ ! -f /etc/sysconfig/slapd.lab-backup ]]; then
    cp /etc/sysconfig/slapd /etc/sysconfig/slapd.lab-backup
  fi

  # Update SLAPD_URLS to include ldaps://
  if grep -q "^SLAPD_URLS=" /etc/sysconfig/slapd; then
    sed -i 's|^SLAPD_URLS=.*|SLAPD_URLS="ldapi:/// ldap:/// ldaps:///"|' /etc/sysconfig/slapd
  else
    echo 'SLAPD_URLS="ldapi:/// ldap:/// ldaps:///"' >> /etc/sysconfig/slapd
  fi
  print_success "LDAPS enabled in configuration"
fi

echo

# Restart slapd
print_info "Restarting slapd..."
systemctl restart slapd

if systemctl is-active slapd &>/dev/null; then
  print_success "slapd restarted successfully"
else
  print_error "slapd failed to restart"
  journalctl -xeu slapd | tail -20
  exit 1
fi

echo

# Verify ports
print_info "Verifying listening ports..."
sleep 2  # Give slapd time to bind ports

if ss -tlnp | grep -q ':389'; then
  print_success "LDAP port 389 listening"
fi

if ss -tlnp | grep -q ':636'; then
  print_success "LDAPS port 636 listening"
else
  print_warning "LDAPS port 636 not listening"
  echo "Check /etc/sysconfig/slapd configuration"
fi

echo
print_success "LDAPS configuration complete"
echo
echo "Test LDAPS connection:"
echo "  ldapsearch -x -H ldaps://localhost -b \"\" -s base"
echo "  openssl s_client -connect localhost:636"
