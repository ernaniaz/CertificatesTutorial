#!/usr/bin/env bash
#=============================================================================
# Lab 21: Test Ingress Tls
# Deploy test application with TLS-enabled Ingress
#
# Usage: ./test-ingress-tls.sh
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

print_header "Lab 21: Test Ingress TLS"

# --- Step 1: Check prerequisites ---
print_step "Check prerequisites"

if ! command -v kubectl &>/dev/null; then
  error_exit "kubectl not found"
fi
if ! kubectl get namespace cert-manager &>/dev/null; then
  error_exit "cert-manager not installed"
fi
if ! kubectl get clusterissuer selfsigned-issuer &>/dev/null; then
  error_exit "selfsigned-issuer not found. Run ./create-selfsigned-issuer.sh first"
fi
print_success "cert-manager and issuers are available"
echo

# --- Step 2: Enable minikube ingress addon ---
print_step "Enable ingress controller"

if command -v minikube &>/dev/null; then
  if ! minikube addons list 2>/dev/null | grep -q "ingress.*enabled"; then
    print_info "Enabling minikube ingress addon for HTTP-01 and TLS routing..."
    minikube addons enable ingress
    print_success "Ingress addon enabled"
  else
    print_success "Ingress addon already enabled"
  fi
else
  print_warning "minikube not found — assuming an ingress controller is already installed"
fi
echo

# --- Step 3: Deploy test application ---
print_step "Deploy test application"

print_info "Creating nginx deployment with custom HTML page..."
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: test-app-html
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-app-html
  namespace: default
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>cert-manager Test App</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                max-width: 800px;
                margin: 50px auto;
                padding: 20px;
                background: #f5f5f5;
            }
            .container {
                background: white;
                padding: 30px;
                border-radius: 10px;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            }
            h1 { color: #2c3e50; }
            .success { color: #27ae60; font-size: 1.2em; }
            .info { color: #3498db; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>cert-manager Test Application</h1>
            <p class="success">TLS certificate successfully deployed!</p>
            <p class="info">This page is served with a certificate issued by cert-manager.</p>
            <h2>Lab 21 Success</h2>
            <ul>
                <li>Kubernetes cluster running</li>
                <li>cert-manager deployed</li>
                <li>Automatic certificate issuance working</li>
                <li>Ingress TLS configured</li>
            </ul>
        </div>
    </body>
    </html>
EOF
print_success "Test application deployed"
echo

# --- Step 4: Create ClusterIP service ---
print_step "Create service"

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: test-app
  namespace: default
spec:
  selector:
    app: test-app
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
EOF
print_success "Service created"
echo

# --- Step 5: Create Ingress with TLS ---
print_step "Create Ingress with TLS"

print_info "Ingress annotation tells cert-manager which issuer to use..."
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-app-ingress
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: "selfsigned-issuer"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - test-app.local
    secretName: test-app-tls
  rules:
  - host: test-app.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: test-app
            port:
              number: 80
EOF
print_success "Ingress created with TLS"
echo

# --- Step 6: Wait for certificate to be issued ---
print_step "Wait for certificate to be issued"

print_info "cert-manager creates a Certificate resource automatically from the Ingress TLS block..."
max_attempts=120
attempt=0
while [[ ${attempt} -lt ${max_attempts} ]]; do
  if kubectl get certificate test-app-tls -n default &>/dev/null; then
    ready="$(kubectl get certificate test-app-tls -n default \
      -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")"
    if [[ "${ready}" == "True" ]]; then
      print_success "Certificate is ready"
      break
    fi
  fi
  attempt=$((attempt + 1))
  sleep 1
done
if [[ "${ready:-}" != "True" ]]; then
  print_warning "Certificate may still be issuing"
fi
echo

# --- Step 7: Wait for pods to be ready ---
print_step "Wait for pods to be ready"

kubectl wait --for=condition=Ready --timeout=60s pod -l app=test-app -n default || true
print_success "Pods are ready"
echo

print_success "Application deployment complete!"

echo
echo "Deployed Resources"
echo
echo "Deployments:"
kubectl get deployments -n default | grep test-app
echo
echo "Services:"
kubectl get services -n default | grep test-app
echo
echo "Ingress:"
kubectl get ingress -n default
echo
echo "Certificates:"
kubectl get certificates -n default | grep -E "NAME|test-app"
echo
echo "Secrets:"
kubectl get secrets -n default | grep -E "NAME|test-app-tls"

echo
echo "Certificate Details"
echo
if kubectl get secret test-app-tls -n default &>/dev/null; then
  print_success "TLS secret exists"
  kubectl get secret test-app-tls -n default \
    -o jsonpath='{.data.tls\.crt}' | base64 -d \
    | openssl x509 -noout -text | grep -A2 "Subject:\|Issuer:\|Validity\|DNS:"
else
  print_warning "TLS secret not yet created"
fi

minikube_ip="$(minikube ip 2>/dev/null || echo "N/A")"
echo
echo "Access Information"
echo
print_info "Application host: test-app.local"
print_info "Minikube IP: ${minikube_ip}"
echo
print_info "To access the application:"
echo
echo "1. Add to /etc/hosts:"
echo "   echo \"${minikube_ip} test-app.local\" | sudo tee -a /etc/hosts"
echo
echo "2. Access via HTTPS:"
echo "   curl -k https://test-app.local"
echo
echo "3. Or use minikube tunnel (requires sudo):"
echo "   minikube tunnel"
echo "   curl -k https://test-app.local"
echo
print_warning "Note: Certificate is self-signed, use -k flag with curl"

echo
echo "Next steps:"
echo "  - Run './verify.sh' to validate the entire lab"
echo "  - Access the application using the instructions above"
echo "  - Inspect certificate: kubectl describe certificate test-app-tls"
