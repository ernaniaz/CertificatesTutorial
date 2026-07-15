#!/usr/bin/env bash
#=============================================================================
# Lab 10: Configure TLS
# Configure SSL/TLS for PostgreSQL
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
PG_DATA="/var/lib/pgsql/data"

print_header "Lab 10: Configuring PostgreSQL TLS"

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
if [[ ! -f "${PG_DATA}/postgresql.conf.lab-backup" ]]; then
  cp "${PG_DATA}/postgresql.conf" "${PG_DATA}/postgresql.conf.lab-backup"
  print_success "postgresql.conf backed up"
fi

if [[ ! -f "${PG_DATA}/pg_hba.conf.lab-backup" ]]; then
  cp "${PG_DATA}/pg_hba.conf" "${PG_DATA}/pg_hba.conf.lab-backup"
  print_success "pg_hba.conf backed up"
fi

echo

# Copy certificates to PostgreSQL data directory
print_info "Copying certificates..."
cp "${CERT_DIR}/server.crt" "${PG_DATA}/server.crt"
cp "${KEY_DIR}/rsa-2048.key" "${PG_DATA}/server.key"
chmod 644 "${PG_DATA}/server.crt"
chmod 600 "${PG_DATA}/server.key"
chown postgres:postgres "${PG_DATA}/server.crt"
chown postgres:postgres "${PG_DATA}/server.key"

print_success "Certificates copied"
echo

# Enable SSL in postgresql.conf
print_info "Enabling SSL in postgresql.conf..."

# Remove any existing ssl settings to avoid duplicates
sed -i '/^ssl = /d' "${PG_DATA}/postgresql.conf"
sed -i '/^ssl_cert_file = /d' "${PG_DATA}/postgresql.conf"
sed -i '/^ssl_key_file = /d' "${PG_DATA}/postgresql.conf"
sed -i '/^ssl_ciphers = /d' "${PG_DATA}/postgresql.conf"
sed -i '/^ssl_prefer_server_ciphers = /d' "${PG_DATA}/postgresql.conf"
sed -i '/^ssl_min_protocol_version = /d' "${PG_DATA}/postgresql.conf"

# Detect PostgreSQL version number (e.g. 90209, 100019, 120015)
PG_VERSION_NUM="$(sudo -u postgres psql -t -c "SHOW server_version_num;" 2>/dev/null | tr -d '[:space:]')"
PG_VERSION_NUM="${PG_VERSION_NUM:-0}"

# Add SSL configuration
cat >> "${PG_DATA}/postgresql.conf" << 'EOF'

# Lab 10: SSL/TLS Configuration
ssl = on
ssl_cert_file = 'server.crt'
ssl_key_file = 'server.key'
ssl_ciphers = 'HIGH:MEDIUM:+3DES:!aNULL'
EOF

# ssl_prefer_server_ciphers requires PostgreSQL 9.4+ (90400)
if [[ ${PG_VERSION_NUM} -ge 90400 ]]; then
  echo "ssl_prefer_server_ciphers = on" >> "${PG_DATA}/postgresql.conf"
fi

# ssl_min_protocol_version requires PostgreSQL 12+ (120000)
if [[ ${PG_VERSION_NUM} -ge 120000 ]]; then
  echo "ssl_min_protocol_version = 'TLSv1.2'" >> "${PG_DATA}/postgresql.conf"
fi

print_success "SSL enabled in postgresql.conf"
echo

# Configure pg_hba.conf to support SSL connections
print_info "Configuring pg_hba.conf for SSL..."

# Add hostssl rules (allow both SSL and non-SSL for lab flexibility)
cat >> "${PG_DATA}/pg_hba.conf" << 'EOF'

# Lab 10: SSL connections
hostssl    all    all    127.0.0.1/32    md5
hostssl    all    all    ::1/128         md5
EOF

print_success "pg_hba.conf configured"
echo

# Restart PostgreSQL
print_info "Restarting PostgreSQL..."
systemctl restart postgresql

if systemctl is-active postgresql &>/dev/null; then
  print_success "PostgreSQL restarted successfully"
else
  print_error "PostgreSQL failed to restart"
  journalctl -xeu postgresql | tail -20
  exit 1
fi

echo

# Verify SSL is enabled
print_info "Verifying SSL configuration..."
SSL_STATUS="$(sudo -u postgres psql -t -c "SHOW ssl;" 2>/dev/null | tr -d '[:space:]')"

if [[ ${SSL_STATUS} == on ]]; then
  print_success "SSL is enabled"
else
  print_error "SSL is not enabled"
  exit 1
fi

echo
print_success "PostgreSQL TLS configuration complete"
echo
echo "Test SSL connection:"
echo "  psql \"host=localhost sslmode=require user=postgres\""
echo "  sudo -u postgres psql -c \"SELECT * FROM pg_stat_ssl WHERE pid = pg_backend_pid();\""
