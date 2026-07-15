#!/usr/bin/env bash
#=============================================================================
# Lab 16: Restore Backup
# Restore known-good certificates
#
# Usage: ./restore-backup.sh
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

print_header "Lab 16: Restore Certificates from Backup"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

# Find available backups
print_info "Available backups:"
if ls -d /root/cert-backup-* 2>/dev/null; then
  echo
else
  echo "No backups found in /root/cert-backup-*"
  echo
  echo "Checking for .backup files..."
  if ! find /etc/pki/tls -name "*.backup" -o -name "*.old" 2>/dev/null; then
    echo "No backup files found"
  fi
  exit 1
fi

echo
read -p "Enter backup directory path: " BACKUP_DIR

if [[ ! -d "${BACKUP_DIR}" ]]; then
  print_error "Backup directory not found"
  exit 1
fi

echo
echo "Backup directory: ${BACKUP_DIR}"
echo "Contents:"
ls -lh "${BACKUP_DIR}"
echo

read -p "Restore from this backup? (y/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
  echo "Restore cancelled"
  exit 0
fi

echo
print_info "Restoring certificates..."

# Create safety backup of current state
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p /root/cert-before-restore-${TIMESTAMP}
cp -r /etc/pki/tls/certs/* /root/cert-before-restore-${TIMESTAMP}/ 2>/dev/null || true
cp -r /etc/pki/tls/private/* /root/cert-before-restore-${TIMESTAMP}/ 2>/dev/null || true
print_success "Current state backed up to /root/cert-before-restore-${TIMESTAMP}/"

# Restore certificates
for file in "${BACKUP_DIR}"/*.crt; do
  if [[ -f "${file}" ]]; then
    filename="$(basename "${file}")"
    cp "${file}" "${CERT_DIR}/${filename}"
    print_success "Restored ${filename}"
  fi
done

# Restore private keys
for file in "${BACKUP_DIR}"/*.key; do
  if [[ -f "${file}" ]]; then
    filename="$(basename "${file}")"
    cp "${file}" "${KEY_DIR}/${filename}"
    chmod 600 "${KEY_DIR}/${filename}"
    print_success "Restored ${filename}"
  fi
done

echo
print_success "Restore complete"
echo
echo "Restart affected services:"
echo "  systemctl restart httpd"
echo "  systemctl restart nginx"
echo
echo "If restore didn't work, rollback with:"
echo "  cp /root/cert-before-restore-${TIMESTAMP}/* /etc/pki/tls/certs/"
