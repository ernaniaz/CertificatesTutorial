#!/usr/bin/env bash
#=============================================================================
# Lab 10: Cleanup
# Remove PostgreSQL and restore system state
#
# Usage: ./cleanup.sh
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

PG_DATA="/var/lib/pgsql/data"

print_header "Lab 10: Cleanup"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

# Confirmation
print_warning "This will remove PostgreSQL and all lab configurations."
print_warning "Database data will be preserved but the service will be removed."
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
  echo "Cleanup cancelled"
  exit 0
fi

echo

# Stop PostgreSQL
if systemctl is-active postgresql &>/dev/null; then
  print_info "Stopping PostgreSQL..."
  systemctl stop postgresql
  systemctl disable postgresql
  print_success "PostgreSQL stopped"
fi

echo

# Restore original configurations
if [[ -f "${PG_DATA}/postgresql.conf.lab-backup" ]]; then
  print_info "Restoring postgresql.conf..."
  mv "${PG_DATA}/postgresql.conf.lab-backup" "${PG_DATA}/postgresql.conf"
  print_success "postgresql.conf restored"
fi

if [[ -f "${PG_DATA}/pg_hba.conf.lab-backup" ]]; then
  print_info "Restoring pg_hba.conf..."
  mv "${PG_DATA}/pg_hba.conf.lab-backup" "${PG_DATA}/pg_hba.conf"
  print_success "pg_hba.conf restored"
fi

echo

# Remove PostgreSQL packages
print_info "Removing PostgreSQL packages..."
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum remove -y postgresql-server postgresql-contrib
else
  dnf remove -y postgresql-server postgresql-contrib
fi

print_success "PostgreSQL removed"
echo

# Remove lab certificates
print_info "Removing lab certificates..."
rm -f "${PG_DATA}/server.crt"
rm -f "${PG_DATA}/server.key"
print_success "Certificates removed"
echo

# Remove firewall rules
print_info "Cleaning firewall rules..."
if command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null; then
  firewall-cmd --permanent --remove-service=postgresql 2>/dev/null || true
  firewall-cmd --reload
  print_success "Firewall rules removed"
fi

echo
print_success "Cleanup complete"
echo
echo "System restored to pre-lab state."
echo "Note: Database data in ${PG_DATA} preserved"
