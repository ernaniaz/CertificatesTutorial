#!/usr/bin/env bash
#=============================================================================
# Lab 10: Verify
# Manual verification steps
#
# Usage: ./verify.sh
# Prerequisites: RHEL 7, 8, 9, 10
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

print_header "Lab 10: PostgreSQL TLS Verification"

print_info "1. Checking PostgreSQL service..."
systemctl status postgresql --no-pager | head -5
echo

print_info "2. Checking listening port..."
ss -tlnp | grep 5432
echo

print_info "3. Checking SSL configuration..."
echo "SSL setting in postgresql.conf:"
if ! grep "^ssl = " "${PG_DATA}/postgresql.conf"; then
  echo "Not configured"
fi
echo
echo "SSL certificate file:"
if ! grep "^ssl_cert_file = " "${PG_DATA}/postgresql.conf"; then
  echo "Not configured"
fi
echo
echo "SSL key file:"
if ! grep "^ssl_key_file = " "${PG_DATA}/postgresql.conf"; then
  echo "Not configured"
fi
echo

print_info "4. Checking certificate files..."
if [[ -f "${PG_DATA}/server.crt" ]]; then
  print_success "Certificate exists"
  openssl x509 -in "${PG_DATA}/server.crt" -noout -subject -dates
else
  echo "Certificate not found"
fi
echo

print_info "5. Checking private key..."
if [[ -f "${PG_DATA}/server.key" ]]; then
  print_success "Private key exists"
  ls -l "${PG_DATA}/server.key"
  PERMS="$(stat -c%a "${PG_DATA}/server.key")"
  if [[ "${PERMS}" == "600" ]]; then
    print_success "Permissions correct (600)"
  else
    print_warning "Permissions: ${PERMS} (should be 600)"
  fi

  OWNER="$(stat -c%U "${PG_DATA}/server.key")"
  if [[ "${OWNER}" == "postgres" ]]; then
    print_success "Owner correct (postgres)"
  else
    print_warning "Owner: ${OWNER} (should be postgres)"
  fi
else
  echo "Private key not found"
fi
echo

print_info "6. Checking SSL status in database..."
SSL_STATUS="$(sudo -u postgres psql -t -c "SHOW ssl;" 2>/dev/null | tr -d '[:space:]')"
if [[ ${SSL_STATUS} == on ]]; then
  print_success "SSL enabled in database (ssl=${SSL_STATUS})"
else
  echo "SSL status: ${SSL_STATUS}"
fi
echo

print_info "7. Checking pg_hba.conf for SSL rules..."
echo "SSL connection rules:"
if ! grep "^hostssl" "${PG_DATA}/pg_hba.conf"; then
  echo "No hostssl rules configured"
fi
echo

print_info "8. Testing database connection..."
if sudo -u postgres psql -c "SELECT 'Connection OK';" &>/dev/null; then
  print_success "Database connection works"
fi

print_info "9. Querying SSL server info..."
if sudo -u postgres psql -t -c "SELECT 1 FROM pg_stat_ssl LIMIT 0;" &>/dev/null; then
  SSL_CONNS="$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_stat_ssl WHERE ssl = true;" 2>/dev/null | tr -d '[:space:]')"
  echo "  Active SSL connections: ${SSL_CONNS:-0}"
  sudo -u postgres psql -c "SHOW ssl; SHOW ssl_cert_file; SHOW ssl_key_file;" 2>/dev/null
else
  echo "  pg_stat_ssl not available (requires PostgreSQL 9.5+)"
  sudo -u postgres psql -c "SHOW ssl;" 2>/dev/null || echo "  SSL info not available"
fi

echo
print_success "Verification complete"
