#!/usr/bin/env bash
#=============================================================================
# Lab 21: Crear emisor CA
# Crea un ClusterIssuer usando un certificado CA personalizado
#
# Uso: ./create-ca-issuer.sh
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

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly OUTPUT_DIR="${SCRIPT_DIR}/ca-output"

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

print_header "Lab 21: Crear emisor CA"

# --- Paso 1: Verificar requisitos previos ---
print_step "Verificar requisitos previos"

if ! command -v kubectl &>/dev/null; then
  error_exit "kubectl no encontrado"
fi
if ! command -v openssl &>/dev/null; then
  error_exit "openssl no encontrado"
fi
if ! kubectl get namespace cert-manager &>/dev/null; then
  error_exit "cert-manager no instalado. Ejecute ./install-cert-manager.sh primero"
fi
print_success "Verificación de requisitos previos aprobada"
echo

# --- Paso 2: Generar certificado y clave CA ---
print_step "Generar certificado y clave CA"

print_info "Creando CA personalizada en ${OUTPUT_DIR}..."
mkdir -p "${OUTPUT_DIR}"

# Clave de 4096 bits coincide con políticas CA empresariales comunes para realismo del lab
openssl genrsa -out "${OUTPUT_DIR}/ca.key" 4096
openssl req -x509 -new -nodes \
  -key "${OUTPUT_DIR}/ca.key" \
  -sha256 -days 3650 \
  -out "${OUTPUT_DIR}/ca.crt" \
  -subj "/C=US/ST=State/L=City/O=Lab Organization/CN=Lab CA"
print_success "Certificado CA creado"
echo

# --- Paso 3: Almacenar credenciales CA en un secret de Kubernetes ---
print_step "Crear secret de Kubernetes con CA"

print_info "Almacenando cert/clave CA en secret ca-key-pair..."
kubectl delete secret ca-key-pair -n cert-manager 2>/dev/null || true
kubectl create secret tls ca-key-pair \
  -n cert-manager \
  --cert="${OUTPUT_DIR}/ca.crt" \
  --key="${OUTPUT_DIR}/ca.key"
print_success "Secret CA creado"
echo

# --- Paso 4: Crear ClusterIssuer CA ---
print_step "Crear ClusterIssuer CA"

print_info "Aplicando ClusterIssuer que referencia secret ca-key-pair..."
cat <<'EOF' | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: ca-key-pair
EOF
print_success "ClusterIssuer CA creado"
echo

# --- Paso 5: Esperar a que el emisor esté listo ---
print_step "Esperar a que el emisor esté listo"

max_attempts=30
attempt=0
while [[ ${attempt} -lt ${max_attempts} ]]; do
  ready="$(kubectl get clusterissuer ca-issuer \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")"
  if [[ "${ready}" == "True" ]]; then
    print_success "El emisor está listo"
    break
  fi
  attempt=$((attempt + 1))
  sleep 1
done
if [[ "${ready:-}" != "True" ]]; then
  print_warning "El emisor puede seguir inicializándose"
fi
echo

print_success "¡Configuración del emisor CA completada!"

echo
echo "Información del certificado CA"
echo
openssl x509 -in "${OUTPUT_DIR}/ca.crt" -noout -text | grep -A2 "Subject:"
openssl x509 -in "${OUTPUT_DIR}/ca.crt" -noout -text | grep -A2 "Validity"
echo
echo "Estado del emisor CA"
echo
kubectl get clusterissuer ca-issuer
kubectl describe clusterissuer ca-issuer

echo
echo "Uso:"
echo "  Referencie este emisor en recursos Certificate:"
echo "  issuerRef:"
echo "    name: ca-issuer"
echo "    kind: ClusterIssuer"
echo
echo "Próximos pasos:"
echo "  - Ejecute './request-certificate.sh' para solicitar un certificado firmado por CA"
