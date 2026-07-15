#!/usr/bin/env bash
#=============================================================================
# Lab 21: Crear emisor Let's Encrypt
# Crea un ClusterIssuer para certificados ACME de Let's Encrypt
#
# Uso: ./create-letsencrypt-issuer.sh
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

# Default email (can be overridden)
EMAIL="${1:-admin@example.com}"

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

print_header "Lab 21: Crear emisor Let's Encrypt"

# --- Paso 1: Verificar requisitos previos ---
print_step "Verificar requisitos previos"

if ! command -v kubectl &>/dev/null; then
  error_exit "kubectl no encontrado"
fi
if ! kubectl get namespace cert-manager &>/dev/null; then
  error_exit "cert-manager no instalado. Ejecute ./install-cert-manager.sh primero"
fi
print_success "Verificación de requisitos previos aprobada"
echo

# --- Paso 2: Crear ClusterIssuer de staging ---
print_step "Crear ClusterIssuer de staging de Let's Encrypt"

print_info "Aplicando emisor de staging (ACME HTTP-01 con clase ingress nginx)..."
print_warning "Usando entorno STAGING — los certificados no son confiables para navegadores"
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
print_success "Emisor de staging Let's Encrypt creado"
echo

# --- Paso 3: Crear plantilla de producción (no aplicada) ---
print_step "Crear plantilla de emisor de producción"

print_info "Guardando plantilla de producción — requiere un dominio público real para uso seguro..."
cat <<'EOF' > letsencrypt-production-template.yaml
# Emisor de producción Let's Encrypt (PLANTILLA)
# ADVERTENCIA: use solo cuando tenga un dominio público válido
# ¡La producción tiene límites de tasa estrictos!
#
# Para aplicar: kubectl apply -f letsencrypt-production-template.yaml

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
print_success "Plantilla de emisor de producción guardada en letsencrypt-production-template.yaml"
echo

# --- Paso 4: Esperar a que el emisor de staging esté listo ---
print_step "Esperar a que el emisor de staging esté listo"

print_info "El registro de cuenta ACME puede tardar un momento..."
max_attempts=60
attempt=0
while [[ ${attempt} -lt ${max_attempts} ]]; do
  ready="$(kubectl get clusterissuer letsencrypt-staging \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")"
  if [[ "${ready}" == "True" ]]; then
    print_success "El emisor está listo"
    break
  fi
  attempt=$((attempt + 1))
  sleep 1
done
if [[ "${ready:-}" != "True" ]]; then
  print_warning "La inicialización del emisor puede seguir en curso"
  print_info "Verifique el estado con: kubectl describe clusterissuer letsencrypt-staging"
fi
echo

print_success "¡Configuración del emisor Let's Encrypt completada!"

echo
echo "Estado del emisor Let's Encrypt"
echo
kubectl get clusterissuer letsencrypt-staging
kubectl describe clusterissuer letsencrypt-staging

echo
echo "Información de uso de Let's Encrypt"
echo
print_info "Entorno de staging"
echo "  - Use para pruebas"
echo "  - Sin límites de tasa"
echo "  - Certificados no confiables para navegadores"
echo "  - issuerRef.name: letsencrypt-staging"
echo
print_warning "Entorno de producción"
echo "  - Requiere dominio público válido"
echo "  - Límites de tasa: 50 cert/semana por dominio"
echo "  - Certificados confiables para todos los navegadores"
echo "  - Edite letsencrypt-production-template.yaml antes de aplicar"
echo
print_info "Requisitos del desafío HTTP-01:"
echo "  - Ingress debe ser accesible públicamente"
echo "  - El puerto 80 debe estar abierto"
echo "  - El dominio debe resolver al clúster"
echo
print_info "Para pruebas locales:"
echo "  - Use emisor autofirmado o CA en su lugar"
echo "  - Let's Encrypt requiere DNS público"

echo
echo "Próximos pasos:"
echo "  - Para pruebas locales, use emisor autofirmado o CA"
echo "  - Para producción con dominio válido, edite y aplique la plantilla"
