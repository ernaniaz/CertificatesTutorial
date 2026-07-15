#!/usr/bin/env bash
#=============================================================================
# Lab 22: Configurar CA raíz
# Genera y configura la CA raíz
#
# Uso: ./configure-root-ca.sh
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

print_header "Lab 22: Configurar CA raíz"

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

# --- Paso 2: Verificar que el motor PKI esté habilitado ---
print_step "Verificando requisitos previos"

if ! vault secrets list | grep -q "^pki/"; then
  error_exit "Motor de secretos PKI no habilitado. Ejecute ./enable-pki.sh primero"
fi

print_success "Motor de secretos PKI encontrado"
echo

# --- Paso 3: Generar CA raíz interna ---
print_step "Generando certificado CA raíz"

# La generación interna mantiene la clave privada dentro de Vault — nunca se exporta a disco
if ! vault write -field=certificate pki/root/generate/internal \
  common_name="Lab Root CA" \
  issuer_name="root-2025" \
  ttl=87600h \
  > "${SCRIPT_DIR}/root-ca.crt"; then
  error_exit "Error al generar CA raíz"
fi

print_success "CA raíz generada"
print_info "CA raíz guardada en: root-ca.crt"
echo

# --- Paso 4: Configurar URLs de CA y distribución CRL ---
print_step "Configurando URLs de CA"

# Los clientes necesitan estas URLs para construir cadenas de confianza y verificar revocación
if ! vault write pki/config/urls \
  issuing_certificates="http://127.0.0.1:8200/v1/pki/ca" \
  crl_distribution_points="http://127.0.0.1:8200/v1/pki/crl"; then
  error_exit "Error al configurar URLs de CA"
fi

print_success "URLs de CA configuradas"
echo

print_success "Configuración de CA raíz completada"
echo

# --- Paso 5: Mostrar información de CA raíz ---
print_step "Información de CA raíz"

print_info "Detalles del certificado:"
openssl x509 -in "${SCRIPT_DIR}/root-ca.crt" -noout -text | grep -A2 "Subject:\|Issuer:\|Validity"
echo
print_info "Configuración de URLs de CA:"
vault read pki/config/urls
echo
print_info "CA raíz desde Vault:"
vault read pki/cert/ca

echo
echo "Próximos pasos:"
echo "  - Ejecute './configure-intermediate-ca.sh' para crear CA intermedia"
echo "  - Ver CA: vault read pki/cert/ca"
