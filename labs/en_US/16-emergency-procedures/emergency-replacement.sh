#!/usr/bin/env bash
#=============================================================================
# Lab 16: Emergency Replacement
# Quick certificate replacement for production emergencies
#
# Usage: ./emergency-replacement.sh
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

CERT_DIR="/etc/pki/tls/certs"
KEY_DIR="/etc/pki/tls/private"
CERT_NAME="emergency"

print_header "Lab 16: Emergency Certificate Replacement"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

print_warning "EMERGENCY PROCEDURE"
echo "This creates and deploys a new certificate immediately"
echo

read -p "Continue with emergency replacement? (y/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
  echo "Operation cancelled"
  exit 0
fi

echo

# Step 1: Backup existing certificates
print_info "Step 1: Backing up existing certificates..."
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p "/root/cert-backup-${TIMESTAMP}"

if [[ -f "${CERT_DIR}/${CERT_NAME}.crt" ]]; then
  cp "${CERT_DIR}/${CERT_NAME}.crt" "/root/cert-backup-${TIMESTAMP}/"
  print_success "Backed up certificate"
fi

if [[ -f "${KEY_DIR}/${CERT_NAME}.key" ]]; then
  cp "${KEY_DIR}/${CERT_NAME}.key" "/root/cert-backup-${TIMESTAMP}/"
  print_success "Backed up private key"
fi

echo "  Backup location: /root/cert-backup-${TIMESTAMP}/"
echo

# Step 2: Generate new certificate
print_info "Step 2: Generating new certificate..."
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "${KEY_DIR}/${CERT_NAME}.key" \
  -out "${CERT_DIR}/${CERT_NAME}.crt" \
  -days 90 \
  -subj "/CN=$(hostname)" \
  -extensions v3_req \
  -config <(cat /etc/pki/tls/openssl.cnf <(printf "[v3_req]\nsubjectAltName=DNS:$(hostname),DNS:localhost")) 2>/dev/null

chmod 644 "${CERT_DIR}/${CERT_NAME}.crt"
chmod 600 "${KEY_DIR}/${CERT_NAME}.key"

print_success "New certificate generated"
echo

# Step 3: Verify new certificate
print_info "Step 3: Verifying new certificate..."
if openssl x509 -in "${CERT_DIR}/${CERT_NAME}.crt" -noout -checkend 0 2>/dev/null; then
  print_success "Certificate is valid"
  openssl x509 -in "${CERT_DIR}/${CERT_NAME}.crt" -noout -subject -dates
else
  print_error "Certificate validation failed"
  exit 1
fi

echo

# Step 4: Instructions for service restart
print_info "Step 4: Restart affected services"
echo
echo "Services that may need restart:"
echo "  systemctl restart httpd"
echo "  systemctl restart nginx"
echo "  systemctl restart postfix"
echo

print_success "Emergency replacement complete"
echo
echo "Certificate: ${CERT_DIR}/${CERT_NAME}.crt"
echo "Private key: ${KEY_DIR}/${CERT_NAME}.key"
echo "Backup: /root/cert-backup-${TIMESTAMP}/"
echo
print_warning "IMPORTANT: This is a temporary 90-day certificate"
echo "Obtain proper certificate from CA as soon as possible"
