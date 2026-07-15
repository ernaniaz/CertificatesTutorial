#!/usr/bin/env bash
#=============================================================================
# Lab 22: Revocar certificado
# Demuestra la revocación de certificados
#
# Uso: ./revoke-certificate.sh
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
readonly CERTS_DIR="${SCRIPT_DIR}/certs"

# Serial number
SERIAL_NUMBER="${1:-}"

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

print_header "Lab 22: Revocar certificado"

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

# --- Paso 2: Verificar que Vault esté en ejecución ---
print_step "Verificando estado de Vault"

if ! vault status &> /dev/null; then
  error_exit "Vault no está en ejecución. Ejecute ./start-vault-dev.sh primero"
fi

print_success "Vault en ejecución"
echo

# --- Paso 3: Buscar número de serie si no se proporciona ---
if [[ -z "${SERIAL_NUMBER}" ]]; then
  print_step "Buscando certificado para revocar"

  latest_serial_file="$(find "${CERTS_DIR}" -maxdepth 1 -name '*.serial' -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -n1 | awk '{print $2}')"

  if [[ -z "${latest_serial_file}" ]] || [[ ! -f "${latest_serial_file}" ]]; then
    error_exit "No se encontraron certificados. Ejecute ./issue-certificate.sh primero"
  fi

  SERIAL_NUMBER="$(cat "${latest_serial_file}")"
  print_success "Usando certificado más reciente: $(basename "${latest_serial_file%.serial}")"
  echo
fi

print_info "Número de serie: ${SERIAL_NUMBER}"
echo

# --- Paso 4: Confirmar revocación con el usuario ---
print_step "Confirmando revocación"

print_warning "¡Esto revocará el certificado!"
read -p "¿Continuar? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  print_info "Revocación cancelada"
  exit 0
fi
echo

# --- Paso 5: Revocar certificado ---
print_step "Revocando certificado"

if ! vault write pki_int/revoke serial_number="${SERIAL_NUMBER}"; then
  error_exit "Error al revocar certificado ${SERIAL_NUMBER}"
fi

print_success "Certificado revocado"
echo

# --- Paso 6: Leer y mostrar CRL ---
print_step "Leyendo lista de revocación de certificados"

if ! vault read -field=certificate pki_int/cert/crl > "${SCRIPT_DIR}/crl.pem"; then
  error_exit "Error al leer CRL desde Vault"
fi

print_success "CRL guardada en: crl.pem"
echo
print_info "Contenido de CRL:"
openssl crl -in "${SCRIPT_DIR}/crl.pem" -noout -text | head -n 20
echo

# --- Paso 7: Verificar revocación en CRL ---
print_step "Verificando revocación"

print_info "Verificando si el serial ${SERIAL_NUMBER} aparece en la CRL..."

if openssl crl -in "${SCRIPT_DIR}/crl.pem" -noout -text | grep -q "${SERIAL_NUMBER}"; then
  print_success "Certificado encontrado en CRL (revocado)"
else
  print_warning "Certificado no encontrado en CRL"
fi
echo

# --- Paso 8: Mostrar información de revocación ---
print_step "Información de revocación"

print_info "Revocación de certificados:"
echo "  - Los certificados revocados se agregan a la CRL"
echo "  - CRL URL: http://127.0.0.1:8200/v1/pki_int/crl"
echo "  - Las aplicaciones deben verificar CRL o usar OCSP"
echo
print_info "Descargar CRL:"
echo "  curl http://127.0.0.1:8200/v1/pki_int/crl > crl.pem"
echo
print_info "Ver CRL:"
echo "  openssl crl -in crl.pem -noout -text"

echo
print_success "Revocación de certificados demostrada"
echo
echo "Próximos pasos:"
echo "  - Ejecute './verify.sh' para validar todo el lab"
echo "  - Emitir nuevos certificados: ./issue-certificate.sh"
