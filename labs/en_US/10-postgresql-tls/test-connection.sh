#!/usr/bin/env bash
#=============================================================================
# Lab 10: Test connection
# Test database connections with and without SSL
#
# Usage: ./test-connection.sh
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

print_header "Lab 10: Testing PostgreSQL SSL"

# Test basic connection
print_info "1. Testing basic connection..."
if sudo -u postgres psql -c "SELECT version();" &>/dev/null; then
  print_success "Basic connection successful"
else
  print_error "Basic connection failed"
  exit 1
fi

echo

# Test SSL status
print_info "2. Checking SSL status..."
SSL_STATUS="$(sudo -u postgres psql -t -c "SHOW ssl;" | tr -d '[:space:]')"

if [[ ${SSL_STATUS} == on ]]; then
  print_success "SSL is enabled (ssl=${SSL_STATUS})"
else
  print_error "SSL is not enabled"
  exit 1
fi

echo

# Test connection with sslmode=require
print_info "3. Testing connection with sslmode=require..."
if sudo -u postgres psql "sslmode=require" -c "SELECT 1;" &>/dev/null; then
  print_success "SSL connection successful"
else
  print_warning "SSL connection with sslmode=require failed"
fi

echo

# Query SSL server configuration
print_info "4. Querying SSL server configuration..."
if sudo -u postgres psql -t -c "SELECT 1 FROM pg_stat_ssl LIMIT 0;" &>/dev/null; then
  SSL_STATUS="$(sudo -u postgres psql -t -c "SHOW ssl;" 2>/dev/null | tr -d '[:space:]')"
  SSL_CERT="$(sudo -u postgres psql -t -c "SHOW ssl_cert_file;" 2>/dev/null | tr -d '[:space:]')"
  SSL_KEY="$(sudo -u postgres psql -t -c "SHOW ssl_key_file;" 2>/dev/null | tr -d '[:space:]')"
  if [[ "${SSL_STATUS}" == "on" ]]; then
    print_success "SSL server configuration:"
    echo "  ssl = ${SSL_STATUS}"
    echo "  ssl_cert_file = ${SSL_CERT}"
    echo "  ssl_key_file = ${SSL_KEY}"
  else
    print_warning "SSL is not enabled on the server"
  fi
else
  print_warning "pg_stat_ssl not available (requires PostgreSQL 9.5+)"
  SSL_STATUS="$(sudo -u postgres psql -t -c "SHOW ssl;" 2>/dev/null | tr -d '[:space:]')"
  if [[ "${SSL_STATUS}" == "on" ]]; then
    print_success "SSL is enabled (verified via SHOW ssl)"
  fi
fi

echo

# Test SSL with psql environment variable
print_info "5. Testing with PGSSLMODE environment variable..."
if PGSSLMODE=require sudo -u postgres psql -c "SELECT 'SSL test';" &>/dev/null; then
  print_success "Connection with PGSSLMODE=require successful"
else
  print_warning "Connection with PGSSLMODE=require failed"
fi

echo

# Display all current SSL connections
print_info "6. Displaying SSL connection statistics..."
echo "Active SSL connections:"
if ! sudo -u postgres psql -c "SELECT datname, usename, ssl, version, cipher FROM pg_stat_ssl JOIN pg_stat_activity USING (pid) WHERE ssl = true;" 2>/dev/null; then
  echo "No SSL connections or pg_stat_ssl not available"
fi

echo
print_success "SSL testing complete"
echo
echo "Manual test commands:"
echo "  sudo -u postgres psql \"sslmode=require\""
echo "  sudo -u postgres psql -c \"SHOW ssl;\""
echo "  sudo -u postgres psql -c \"SELECT * FROM pg_stat_ssl WHERE pid = pg_backend_pid();\""
