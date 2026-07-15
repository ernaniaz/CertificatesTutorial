#!/usr/bin/env bash
#=============================================================================
# Lab 18: Backup Certificates
# Comprehensive certificate backup before RHEL 8 to 9 migration
#
# Usage: ./backup-certificates.sh
# Prerequisites: RHEL 8, root privileges
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
if [[ ${RHEL_VERSION} -ne 8 ]]; then
  error_exit "Unsupported RHEL version. This script requires RHEL 8 only."
fi

#=============================================================================
# MAIN
#=============================================================================

BACKUP_DIR="/root/rhel8-cert-backup-$(date +%Y%m%d-%H%M%S)"

print_header "Lab 18: Certificate Backup (RHEL 8)"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

print_info "Creating backup directory..."
mkdir -p "${BACKUP_DIR}"/{pki,configs,crypto-policies}
echo " ${BACKUP_DIR}"
echo

# Backup PKI directory
print_info "Backing up /etc/pki/..."
cp -a /etc/pki "${BACKUP_DIR}/pki/"
print_success "PKI directory backed up"
echo

# Backup service configurations
print_info "Backing up service configurations..."

if [[ -d /etc/httpd ]]; then
  cp -a /etc/httpd "${BACKUP_DIR}/configs/"
  echo "  ✓ Apache configs"
fi

if [[ -d /etc/nginx ]]; then
  cp -a /etc/nginx "${BACKUP_DIR}/configs/"
  echo "  ✓ NGINX configs"
fi

if [[ -d /etc/postfix ]]; then
  cp -a /etc/postfix "${BACKUP_DIR}/configs/"
  echo "  ✓ Postfix configs"
fi

if [[ -d /etc/openldap ]]; then
  cp -a /etc/openldap "${BACKUP_DIR}/configs/"
  echo "  ✓ OpenLDAP configs"
fi

echo

# Backup crypto-policies (RHEL 8 specific, relevant for RHEL 9 migration)
print_info "Backing up crypto-policies..."
CURRENT_POLICY="$(update-crypto-policies --show 2>/dev/null || echo 'unknown')"
echo "${CURRENT_POLICY}" > "${BACKUP_DIR}/crypto-policies/current-policy.txt"

if [[ -d /etc/crypto-policies ]]; then
  cp -a /etc/crypto-policies "${BACKUP_DIR}/crypto-policies/"
  print_success "Crypto-policies backed up (current: ${CURRENT_POLICY})"
else
  print_warning "No /etc/crypto-policies directory found"
fi
echo

# Create inventory
print_info "Creating certificate inventory..."
cat > "${BACKUP_DIR}/inventory.txt" << EOF
RHEL 8 Certificate Backup
Date: $(date)
Hostname: $(hostname)
OpenSSL: $(openssl version)
Crypto-Policy: ${CURRENT_POLICY}

Certificate Files:
EOF

find /etc/pki/tls/certs -name "*.crt" -o -name "*.pem" 2>/dev/null | while read cert; do
  if [[ -f "${cert}" ]]; then
    echo "  ${cert}" >> "${BACKUP_DIR}/inventory.txt"
    if openssl x509 -in "${cert}" -noout -text 2>/dev/null >/dev/null; then
      openssl x509 -in "${cert}" -noout -subject -dates >> "${BACKUP_DIR}/inventory.txt" 2>/dev/null || true
    fi
    echo >> "${BACKUP_DIR}/inventory.txt"
  fi
done

print_success "Inventory created"
echo

# Create tarball
print_info "Creating compressed archive..."
tar czf "${BACKUP_DIR}.tar.gz" -C "$(dirname "${BACKUP_DIR}")" "$(basename "${BACKUP_DIR}")"
print_success "Archive created"
echo

print_success "Backup complete"
echo
echo "Backup location: ${BACKUP_DIR}"
echo "Archive: ${BACKUP_DIR}.tar.gz"
echo
echo "Backup size:"
du -sh "${BACKUP_DIR}"
du -sh "${BACKUP_DIR}.tar.gz"
echo
print_info "Store backup archive in safe location before migration!"
