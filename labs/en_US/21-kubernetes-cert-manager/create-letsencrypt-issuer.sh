#!/usr/bin/env bash
#=============================================================================
# Lab 21: Create Letsencrypt Issuer
# Create ClusterIssuer for Let's Encrypt ACME certificates
#
# Usage: ./create-letsencrypt-issuer.sh
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

# Default email (can be overridden)
EMAIL="${1:-admin@example.com}"

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

print_header "Lab 21: Create Let's Encrypt Issuer"

# --- Step 1: Check prerequisites ---
print_step "Check prerequisites"

if ! command -v kubectl &>/dev/null; then
  error_exit "kubectl not found"
fi
if ! kubectl get namespace cert-manager &>/dev/null; then
  error_exit "cert-manager not installed. Run ./install-cert-manager.sh first"
fi
print_success "Prerequisites check passed"
echo

# --- Step 2: Create staging ClusterIssuer ---
print_step "Create Let's Encrypt staging ClusterIssuer"

print_info "Applying staging issuer (ACME HTTP-01 with nginx ingress class)..."
print_warning "Using STAGING environment — certificates are not browser-trusted"
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ${EMAIL}
    privateKeySecretRef:
      name: letsencrypt-staging-account
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
print_success "Let's Encrypt staging issuer created"
echo

# --- Step 3: Create production template (not applied) ---
print_step "Create production issuer template"

print_info "Saving production template — requires a real public domain to use safely..."
cat <<'EOF' > letsencrypt-production-template.yaml
# Let's Encrypt Production Issuer (TEMPLATE)
# WARNING: Only use when you have a valid public domain
# Production has strict rate limits!
#
# To apply: kubectl apply -f letsencrypt-production-template.yaml

apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-production-account
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
print_success "Production issuer template saved to letsencrypt-production-template.yaml"
echo

# --- Step 4: Wait for staging issuer to be ready ---
print_step "Wait for staging issuer to be ready"

print_info "ACME account registration may take a moment..."
max_attempts=60
attempt=0
while [[ ${attempt} -lt ${max_attempts} ]]; do
  ready="$(kubectl get clusterissuer letsencrypt-staging \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")"
  if [[ "${ready}" == "True" ]]; then
    print_success "Issuer is ready"
    break
  fi
  attempt=$((attempt + 1))
  sleep 1
done
if [[ "${ready:-}" != "True" ]]; then
  print_warning "Issuer initialization may still be in progress"
  print_info "Check status with: kubectl describe clusterissuer letsencrypt-staging"
fi
echo

print_success "Let's Encrypt issuer setup complete!"

echo
echo "Let's Encrypt Issuer Status"
echo
kubectl get clusterissuer letsencrypt-staging
kubectl describe clusterissuer letsencrypt-staging

echo
echo "Let's Encrypt Usage Information"
echo
print_info "Staging Environment"
echo "  - Use for testing"
echo "  - No rate limits"
echo "  - Certificates not trusted by browsers"
echo "  - issuerRef.name: letsencrypt-staging"
echo
print_warning "Production Environment"
echo "  - Requires valid public domain"
echo "  - Rate limits: 50 certs/week per domain"
echo "  - Certificates trusted by all browsers"
echo "  - Edit letsencrypt-production-template.yaml before applying"
echo
print_info "HTTP-01 Challenge Requirements:"
echo "  - Ingress must be publicly accessible"
echo "  - Port 80 must be open"
echo "  - Domain must resolve to your cluster"
echo
print_info "For local testing:"
echo "  - Use self-signed or CA issuer instead"
echo "  - Let's Encrypt requires public DNS"

echo
echo "Next steps:"
echo "  - For local testing, use self-signed or CA issuer"
echo "  - For production with valid domain, edit and apply the template"
