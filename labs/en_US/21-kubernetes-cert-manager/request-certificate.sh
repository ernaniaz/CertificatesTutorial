#!/usr/bin/env bash
#=============================================================================
# Lab 21: Request Certificate
# Request certificates using different issuers
#
# Usage: ./request-certificate.sh
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

print_header "Lab 21: Request Certificates"

# --- Step 1: Check prerequisites ---
print_step "Check prerequisites"

if ! command -v kubectl &>/dev/null; then
  error_exit "kubectl not found"
fi
if ! kubectl get namespace cert-manager &>/dev/null; then
  error_exit "cert-manager not installed"
fi
if ! kubectl get clusterissuer selfsigned-issuer &>/dev/null; then
  error_exit "Self-signed issuer not found. Run ./create-selfsigned-issuer.sh first."
fi
if ! kubectl get clusterissuer ca-issuer &>/dev/null; then
  error_exit "CA issuer not found. Run ./create-ca-issuer.sh first."
fi
print_success "Prerequisites check passed"
echo

# --- Step 2: Request self-signed certificate ---
print_step "Request self-signed certificate"

print_info "Applying Certificate resource for selfsigned-issuer..."
cat <<'EOF' | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: selfsigned-cert
  namespace: default
spec:
  secretName: selfsigned-cert-tls
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
  commonName: selfsigned.example.com
  dnsNames:
  - selfsigned.example.com
  - www.selfsigned.example.com
  duration: 2160h
  renewBefore: 360h
EOF
print_success "Self-signed certificate requested"
echo

# --- Step 3: Request CA-signed certificate ---
print_step "Request CA-signed certificate"

print_info "Applying Certificate resource for ca-issuer..."
cat <<'EOF' | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ca-signed-cert
  namespace: default
spec:
  secretName: ca-signed-cert-tls
  issuerRef:
    name: ca-issuer
    kind: ClusterIssuer
  commonName: ca-signed.example.com
  dnsNames:
  - ca-signed.example.com
  - www.ca-signed.example.com
  - api.ca-signed.example.com
  duration: 2160h
  renewBefore: 360h
  usages:
  - digital signature
  - key encipherment
  - server auth
  - client auth
EOF
print_success "CA-signed certificate requested"
echo

# --- Step 4: Wait for certificates to be ready ---
print_step "Wait for certificates to be ready"

print_info "Waiting for cert-manager to issue certificates (may take 30-60 seconds)..."
for cert in selfsigned-cert ca-signed-cert; do
  if ! kubectl get certificate "${cert}" -n default &>/dev/null; then
    print_warning "Certificate ${cert} not found, skipping..."
    continue
  fi

  print_info "Waiting for ${cert}..."
  if kubectl wait --for=condition=Ready --timeout=120s \
    "certificate/${cert}" -n default 2>/dev/null; then
    print_success "Certificate ${cert} is ready"
  else
    print_error "Certificate ${cert} timed out"
    print_info "Check status: kubectl describe certificate ${cert}"
  fi
done
echo

# --- Step 5: Verify TLS secrets were created ---
print_step "Verify TLS secrets"

for secret in selfsigned-cert-tls ca-signed-cert-tls; do
  if kubectl get secret "${secret}" -n default &>/dev/null; then
    print_success "Secret ${secret} exists"
  else
    print_warning "Secret ${secret} not found"
  fi
done
echo

print_success "Certificate requests complete!"

echo
echo "Certificate Information"
echo
kubectl get certificates -n default
echo
for cert in selfsigned-cert ca-signed-cert; do
  if kubectl get certificate "${cert}" -n default &>/dev/null; then
    echo "Certificate: ${cert}"
    kubectl describe certificate "${cert}" -n default | grep -A10 "Status:"
    echo
  fi
done

echo "Certificate Secrets"
echo
kubectl get secrets -n default | grep -E "NAME|tls"
echo
if kubectl get secret selfsigned-cert-tls -n default &>/dev/null; then
  echo "Sample certificate (selfsigned-cert-tls):"
  kubectl get secret selfsigned-cert-tls -n default \
    -o jsonpath='{.data.tls\.crt}' | base64 -d \
    | openssl x509 -noout -text | grep -A2 "Subject:\|Issuer:\|Validity\|DNS:"
fi

echo
echo "Next steps:"
echo "  - Run './test-ingress-tls.sh' to test certificates with Ingress"
echo "  - View certificate: kubectl describe certificate <name>"
echo "  - View secret: kubectl get secret <name>-tls -o yaml"
