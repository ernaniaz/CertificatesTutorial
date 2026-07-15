#!/usr/bin/env bash
#=============================================================================
# Lab 21: Solicitar certificado
# Solicita certificados usando distintos emisores
#
# Uso: ./request-certificate.sh
# Requisitos previos: RHEL 8, 9, 10
#=============================================================================

set -e  # Salir en caso de error
set -u  # Salir en variable no definida

#=============================================================================
# CONFIGURACIÓN
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
# FUNCIONES AUXILIARES
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

trap 'error_exit "Error en la línea ${LINENO}"' ERR

#=============================================================================
# VERIFICACIÓN DE VERSIÓN RHEL
#=============================================================================

if ! grep -q '^ID="rhel"$' /etc/os-release 2>/dev/null; then
  error_exit "Este script requiere Red Hat Enterprise Linux (RHEL)."
fi
readonly RHEL_VERSION="$(grep -oP '^VERSION_ID="\K[0-9]+' /etc/os-release 2>/dev/null)"
if [[ ${RHEL_VERSION} -lt 8 || ${RHEL_VERSION} -gt 10 ]]; then
  error_exit "Versión de RHEL no soportada. Este script requiere RHEL 8, 9 o 10."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

print_header "Lab 21: Solicitar certificados"

# --- Paso 1: Verificar requisitos previos ---
print_step "Verificar requisitos previos"

if ! command -v kubectl &>/dev/null; then
  error_exit "kubectl no encontrado"
fi
if ! kubectl get namespace cert-manager &>/dev/null; then
  error_exit "cert-manager no instalado"
fi
if ! kubectl get clusterissuer selfsigned-issuer &>/dev/null; then
  error_exit "Emisor autofirmado no encontrado. Ejecute ./create-selfsigned-issuer.sh primero."
fi
if ! kubectl get clusterissuer ca-issuer &>/dev/null; then
  error_exit "Emisor CA no encontrado. Ejecute ./create-ca-issuer.sh primero."
fi
print_success "Verificación de requisitos previos aprobada"
echo

# --- Paso 2: Solicitar certificado autofirmado ---
print_step "Solicitar certificado autofirmado"

print_info "Aplicando recurso Certificate para selfsigned-issuer..."
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
print_success "Certificado autofirmado solicitado"
echo

# --- Paso 3: Solicitar certificado firmado por CA ---
print_step "Solicitar certificado firmado por CA"

print_info "Aplicando recurso Certificate para ca-issuer..."
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
print_success "Certificado firmado por CA solicitado"
echo

# --- Paso 4: Esperar a que los certificados estén listos ---
print_step "Esperar a que los certificados estén listos"

print_info "Esperando que cert-manager emita certificados (puede tardar 30-60 segundos)..."
for cert in selfsigned-cert ca-signed-cert; do
  if ! kubectl get certificate "${cert}" -n default &>/dev/null; then
    print_warning "Certificado ${cert} no encontrado, omitiendo..."
    continue
  fi

  print_info "Esperando ${cert}..."
  if kubectl wait --for=condition=Ready --timeout=120s \
    "certificate/${cert}" -n default 2>/dev/null; then
    print_success "Certificado ${cert} listo"
  else
    print_error "Certificado ${cert} agotó el tiempo de espera"
    print_info "Verifique el estado: kubectl describe certificate ${cert}"
  fi
done
echo

# --- Paso 5: Verificar que se crearon secrets TLS ---
print_step "Verificar secrets TLS"

for secret in selfsigned-cert-tls ca-signed-cert-tls; do
  if kubectl get secret "${secret}" -n default &>/dev/null; then
    print_success "Secret ${secret} existe"
  else
    print_warning "Secret ${secret} no encontrado"
  fi
done
echo

print_success "¡Solicitudes de certificados completadas!"

echo
echo "Información de certificados"
echo
kubectl get certificates -n default
echo
for cert in selfsigned-cert ca-signed-cert; do
  if kubectl get certificate "${cert}" -n default &>/dev/null; then
    echo "Certificado: ${cert}"
    kubectl describe certificate "${cert}" -n default | grep -A10 "Status:"
    echo
  fi
done

echo "Secrets de certificados"
echo
kubectl get secrets -n default | grep -E "NAME|tls"
echo
if kubectl get secret selfsigned-cert-tls -n default &>/dev/null; then
  echo "Certificado de muestra (selfsigned-cert-tls):"
  kubectl get secret selfsigned-cert-tls -n default \
    -o jsonpath='{.data.tls\.crt}' | base64 -d \
    | openssl x509 -noout -text | grep -A2 "Subject:\|Issuer:\|Validity\|DNS:"
fi

echo
echo "Próximos pasos:"
echo "  - Ejecute './test-ingress-tls.sh' para probar certificados con Ingress"
echo "  - Ver certificado: kubectl describe certificate <name>"
echo "  - Ver secret: kubectl get secret <name>-tls -o yaml"
