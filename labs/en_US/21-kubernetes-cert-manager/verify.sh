#!/usr/bin/env bash
#=============================================================================
# Lab 21: Verify
# Validate that all lab components are configured correctly
#
# Usage: ./verify.sh
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

# Counters
PASS=0
FAIL=0

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

print_header "Lab 21: Verification"

# --- Step 1: Test minikube and kubectl ---
print_step "Test minikube and kubectl"

print_info "Running validation tests..."
echo

if minikube status &>/dev/null; then
  print_success "PASS: Minikube is running"
  PASS=$((PASS + 1))
else
  print_error "FAIL: Minikube is running"
  FAIL=$((FAIL + 1))
fi

if kubectl cluster-info &>/dev/null; then
  print_success "PASS: kubectl is configured"
  PASS=$((PASS + 1))
else
  print_error "FAIL: kubectl is configured"
  FAIL=$((FAIL + 1))
fi

# --- Step 2: Test cert-manager pods ---
print_step "Test cert-manager pods"

if kubectl get namespace cert-manager &>/dev/null; then
  print_success "PASS: cert-manager namespace exists"
  PASS=$((PASS + 1))
else
  print_error "FAIL: cert-manager namespace exists"
  FAIL=$((FAIL + 1))
fi

if kubectl get pods -n cert-manager 2>/dev/null | grep -q Running; then
  print_success "PASS: cert-manager pods are running"
  PASS=$((PASS + 1))
else
  print_error "FAIL: cert-manager pods are running"
  FAIL=$((FAIL + 1))
fi

for deployment in cert-manager cert-manager-webhook cert-manager-cainjector; do
  if kubectl get deployment "${deployment}" -n cert-manager \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null | grep -q 1; then
    print_success "PASS: ${deployment} is ready"
    PASS=$((PASS + 1))
  else
    print_error "FAIL: ${deployment} is ready"
    FAIL=$((FAIL + 1))
  fi
done

for crd in certificates.cert-manager.io issuers.cert-manager.io clusterissuers.cert-manager.io; do
  if kubectl get crd "${crd}" &>/dev/null; then
    print_success "PASS: CRD ${crd} exists"
    PASS=$((PASS + 1))
  else
    print_error "FAIL: CRD ${crd} exists"
    FAIL=$((FAIL + 1))
  fi
done

# --- Step 3: Test issuers exist and are ready ---
print_step "Test issuers"

for issuer in selfsigned-issuer ca-issuer letsencrypt-staging; do
  if kubectl get clusterissuer "${issuer}" &>/dev/null; then
    print_success "PASS: ClusterIssuer ${issuer} exists"
    PASS=$((PASS + 1))
  else
    print_error "FAIL: ClusterIssuer ${issuer} exists"
    FAIL=$((FAIL + 1))
  fi

  if kubectl get clusterissuer "${issuer}" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q True; then
    print_success "PASS: ClusterIssuer ${issuer} is Ready"
    PASS=$((PASS + 1))
  else
    print_error "FAIL: ClusterIssuer ${issuer} is Ready"
    FAIL=$((FAIL + 1))
  fi
done

# --- Step 4: Test certificates exist and are ready ---
print_step "Test certificates"

for cert in selfsigned-cert ca-signed-cert test-app-tls; do
  if kubectl get certificate "${cert}" -n default &>/dev/null; then
    print_success "PASS: Certificate ${cert} exists"
    PASS=$((PASS + 1))
  else
    print_error "FAIL: Certificate ${cert} exists"
    FAIL=$((FAIL + 1))
  fi

  if kubectl get certificate "${cert}" -n default \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q True; then
    print_success "PASS: Certificate ${cert} is Ready"
    PASS=$((PASS + 1))
  else
    print_error "FAIL: Certificate ${cert} is Ready"
    FAIL=$((FAIL + 1))
  fi
done

# --- Step 5: Test TLS secrets and ingress resources ---
print_step "Test TLS secrets and application resources"

for secret in selfsigned-cert-tls ca-signed-cert-tls test-app-tls; do
  if kubectl get secret "${secret}" -n default &>/dev/null; then
    print_success "PASS: TLS secret ${secret} exists"
    PASS=$((PASS + 1))
  else
    print_error "FAIL: TLS secret ${secret} exists"
    FAIL=$((FAIL + 1))
  fi
done

if kubectl get deployment test-app -n default &>/dev/null; then
  print_success "PASS: Test application deployment exists"
  PASS=$((PASS + 1))
else
  print_error "FAIL: Test application deployment exists"
  FAIL=$((FAIL + 1))
fi

if kubectl get pods -l app=test-app -n default 2>/dev/null | grep -q Running; then
  print_success "PASS: Test application pods are running"
  PASS=$((PASS + 1))
else
  print_error "FAIL: Test application pods are running"
  FAIL=$((FAIL + 1))
fi

if kubectl get service test-app -n default &>/dev/null; then
  print_success "PASS: Test application service exists"
  PASS=$((PASS + 1))
else
  print_error "FAIL: Test application service exists"
  FAIL=$((FAIL + 1))
fi

if kubectl get ingress test-app-ingress -n default &>/dev/null; then
  print_success "PASS: Test application ingress exists"
  PASS=$((PASS + 1))
else
  print_error "FAIL: Test application ingress exists"
  FAIL=$((FAIL + 1))
fi

# --- Step 6: Display pass/fail summary ---
print_step "Display summary"

echo
echo "Test Summary"
echo
echo "Passed: ${PASS}"
echo "Failed: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "All validations passed!"
  print_success "Lab 21 completed successfully."
  echo
  echo "You have successfully:"
  echo "  - Installed and configured minikube"
  echo "  - Deployed cert-manager"
  echo "  - Created multiple certificate issuers"
  echo "  - Requested and issued certificates"
  echo "  - Configured TLS for Kubernetes Ingress"
  echo
  echo "Next steps:"
  echo "  - Proceed to Lab 22: HashiCorp Vault PKI"
  echo "  - Experiment with different issuer types"
  echo "  - Deploy your own applications with TLS"
  exit 0
else
  print_error "Some validations failed."
  echo
  echo "Troubleshooting:"
  echo "  - Check pod status: kubectl get pods --all-namespaces"
  echo "  - Check cert-manager logs: kubectl logs -n cert-manager deployment/cert-manager"
  echo "  - Check certificate status: kubectl describe certificate <name>"
  echo "  - Rerun failed lab scripts"
  exit 1
fi
