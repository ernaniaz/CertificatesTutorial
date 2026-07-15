#!/usr/bin/env bash
#=============================================================================
# Lab 22: Configurar CA intermedia
# Crea y configura una CA intermedia
#
# Uso: ./configure-intermediate-ca.sh
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

print_header "Lab 22: Configurar CA intermedia"

# --- Paso 1: Cargar detalles de conexión de Vault ---
print_step "Cargando entorno de Vault"

if [[ -f "${SCRIPT_DIR}/vault-env.sh" ]]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/vault-env.sh"
  print_success "Entorno cargado desde vault-env.sh"
else
  export VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
  export VAULT_TOKEN="${VAULT_TOKEN:-root}"
fi
echo

# --- Paso 2: Verificar que existe CA raíz ---
print_step "Verificando requisitos previos"

if ! vault read pki/cert/ca &> /dev/null; then
  error_exit "CA raíz no encontrada. Ejecute ./configure-root-ca.sh primero"
fi

print_success "CA raíz encontrada"
echo

# --- Paso 3: Habilitar motor PKI intermedio ---
print_step "Habilitando motor de secretos PKI intermedio"

if vault secrets list | grep -q "^pki_int/"; then
  print_warning "PKI intermedio ya habilitado"
else
  if ! vault secrets enable -path=pki_int pki; then
    error_exit "Error al habilitar motor de secretos PKI intermedio"
  fi
  print_success "PKI intermedio habilitado en: pki_int/"
fi
echo

# --- Paso 4: Ajustar TTL de lease del PKI intermedio ---
print_step "Configurando TTL de lease del PKI intermedio"

# Las CA intermedias suelen tener vidas útiles más cortas que la raíz
if ! vault secrets tune -max-lease-ttl=43800h pki_int; then
  error_exit "Error al ajustar TTL máximo de lease PKI intermedio"
fi

print_success "TTL máximo de lease configurado en: 43800h (5 años)"
echo

# --- Paso 5: Generar CSR de CA intermedia ---
print_step "Generando CSR de CA intermedia"

if ! vault write -field=csr pki_int/intermediate/generate/internal \
  common_name="Lab Intermediate CA" \
  issuer_name="intermediate-2025" \
  > "${SCRIPT_DIR}/intermediate.csr"; then
  error_exit "Error al generar CSR de CA intermedia"
fi

print_success "CSR intermedia generada"
print_info "CSR guardada en: intermediate.csr"
echo

# --- Paso 6: Firmar CSR con CA raíz ---
print_step "Firmando CSR intermedia con CA raíz"

# La raíz firma la intermedia — jerarquía PKI estándar de dos niveles
if ! vault write -field=certificate pki/root/sign-intermediate \
  issuer_ref="root-2025" \
  csr=@"${SCRIPT_DIR}/intermediate.csr" \
  format=pem_bundle \
  ttl=43800h \
  > "${SCRIPT_DIR}/intermediate.crt"; then
  error_exit "Error al firmar CSR intermedia"
fi

print_success "Certificado intermedio firmado"
print_info "Certificado guardado en: intermediate.crt"
echo

# --- Paso 7: Importar certificado firmado al motor intermedio ---
print_step "Estableciendo certificado intermedio"

if ! vault write pki_int/intermediate/set-signed \
  certificate=@"${SCRIPT_DIR}/intermediate.crt"; then
  error_exit "Error al establecer certificado intermedio"
fi

print_success "Certificado intermedio establecido"
echo

# --- Paso 8: Configurar URLs de CA intermedia ---
print_step "Configurando URLs de CA intermedia"

if ! vault write pki_int/config/urls \
  issuing_certificates="http://127.0.0.1:8200/v1/pki_int/ca" \
  crl_distribution_points="http://127.0.0.1:8200/v1/pki_int/crl"; then
  error_exit "Error al configurar URLs de CA intermedia"
fi

print_success "URLs intermedias configuradas"
echo

print_success "Configuración de CA intermedia completada"
echo

# --- Paso 9: Mostrar info de CA intermedia y verificar cadena ---
print_step "Información de CA intermedia"

print_info "Detalles del certificado:"
openssl x509 -in "${SCRIPT_DIR}/intermediate.crt" -noout -text | grep -A2 "Subject:\|Issuer:\|Validity"
echo
print_info "Configuración de URLs de CA:"
vault read pki_int/config/urls
echo
print_info "CA intermedia desde Vault:"
vault read pki_int/cert/ca
echo

print_step "Verificando cadena de certificados"

if openssl verify -CAfile "${SCRIPT_DIR}/root-ca.crt" "${SCRIPT_DIR}/intermediate.crt" &> /dev/null; then
  print_success "La cadena de certificados es válida"
else
  print_warning "La verificación de cadena de certificados tuvo problemas (puede ser normal en modo dev)"
fi

echo
echo "Próximos pasos:"
echo "  - Ejecute './create-role.sh' para crear un rol PKI"
echo "  - Ver CA intermedia: vault read pki_int/cert/ca"
