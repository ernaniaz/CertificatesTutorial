#!/usr/bin/env bash
#=============================================================================
# Lab 11: Check Status
# Show status of all tracked certificates
#
# Usage: ./check-status.sh
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

print_header "Lab 11: Certificate Status"

# Check certmonger service
print_info "certmonger service status:"
if systemctl is-active certmonger &>/dev/null; then
  print_success "certmonger is running"
else
  echo "certmonger is not running"
  exit 1
fi

echo

# List all tracked certificates
print_info "Tracked certificates:"
echo

CERT_LIST="$(getcert list 2>/dev/null)"

if [[ -z "${CERT_LIST}" ]]; then
  echo "No certificates are being tracked"
else
  echo "${CERT_LIST}"
fi

echo
echo "======================================="

# Count certificates
CERT_COUNT="$(getcert list 2>/dev/null | grep -c "Request ID:" || true)"
echo "Total tracked certificates: ${CERT_COUNT}"

echo

# Show summary of each certificate
if [[ ${CERT_COUNT} -gt 0 ]]; then
  print_info "Certificate summary:"
  echo

  # Get all request IDs
  REQUEST_IDS="$(getcert list 2>/dev/null | grep "Request ID" | awk '{print $3}' | tr -d "':")"

  for REQ_ID in ${REQUEST_IDS}; do
    echo "Request ID: ${REQ_ID}"

    # Get key details
    STATUS="$(getcert list -i "${REQ_ID}" 2>/dev/null | grep "status:" | awk '{print $2}')"
    CERT="$(getcert list -i "${REQ_ID}" 2>/dev/null | grep "certificate:" | cut -d: -f2- | xargs)"
    EXPIRES="$(getcert list -i "${REQ_ID}" 2>/dev/null | grep "expires:" | cut -d: -f2-)"
    CA="$(getcert list -i "${REQ_ID}" 2>/dev/null | grep "ca-name:" | awk '{print $2}')"

    echo "  Status: ${STATUS}"
    echo "  CA: ${CA}"
    echo "  Certificate: ${CERT}"
    echo "  Expires: ${EXPIRES}"
    echo
  done
fi

echo
print_success "Status check complete"
echo
echo "Useful commands:"
echo "  getcert list"
echo "  getcert list -i <REQUEST_ID>"
echo "  journalctl -u certmonger -f"
