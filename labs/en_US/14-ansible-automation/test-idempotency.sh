#!/usr/bin/env bash
#=============================================================================
# Lab 14: Test Idempotency
# Test whether playbooks are idempotent
#
# Usage: ./test-idempotency.sh
# Prerequisites: RHEL 8, 9, 10
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
if [[ ${RHEL_VERSION} -lt 8 || ${RHEL_VERSION} -gt 10 ]]; then
  error_exit "Unsupported RHEL version. This script requires RHEL 8, 9 or 10."
fi

#=============================================================================
# MAIN
#=============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_header "Lab 14: Test Idempotency"

# Check prerequisites
if ! command -v ansible-playbook &>/dev/null; then
  print_error "Error: ansible-playbook not found"
  exit 1
fi

if [[ ! -f "${SCRIPT_DIR}/playbook-apache.yml" ]]; then
  print_error "Error: playbook-apache.yml not found"
  exit 1
fi

print_info "Running playbook first time..."
echo

ansible-playbook -i "${SCRIPT_DIR}/inventory.ini" "${SCRIPT_DIR}/playbook-apache.yml" | tee /tmp/ansible-run1.log

echo
print_info "Running playbook second time (should show no changes)..."
echo

ansible-playbook -i "${SCRIPT_DIR}/inventory.ini" "${SCRIPT_DIR}/playbook-apache.yml" | tee /tmp/ansible-run2.log

echo
print_info "Analyzing idempotency..."
echo

# Check for changed tasks in second run
CHANGED_COUNT="$(grep -c "changed=" /tmp/ansible-run2.log | tail -1 || true)"

if grep -q "changed=0" /tmp/ansible-run2.log; then
  print_success "Playbook is idempotent"
  echo "  Second run made no changes"
else
  print_warning "Some tasks reported changes on second run"
  echo "  Check /tmp/ansible-run2.log for details"
  echo
  echo "Common causes:"
  echo "  - Using 'command' or 'shell' without 'creates' or 'changed_when'"
  echo "  - Templates with dynamic content"
  echo "  - Non-idempotent modules"
fi

echo
print_success "Idempotency test complete"
echo
echo "Logs:"
echo "  First run:  /tmp/ansible-run1.log"
echo "  Second run: /tmp/ansible-run2.log"
