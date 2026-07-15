#!/usr/bin/env bash
#=============================================================================
# Lab 22: Crear rol
# Crea un rol para la emisión de certificados
#
# Uso: ./create-role.sh
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

# Role configuration
ROLE_NAME="${1:-web-server}"

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

print_header "Lab 22: Crear rol PKI"

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

# --- Paso 2: Verificar que CA intermedia esté lista ---
print_step "Verificando requisitos previos"

if ! vault read pki_int/cert/ca &> /dev/null; then
  error_exit "CA intermedia no encontrada. Ejecute ./configure-intermediate-ca.sh primero"
fi

print_success "CA intermedia encontrada"
echo

# --- Paso 3: Crear rol PKI ---
print_step "Creando rol PKI: ${ROLE_NAME}"

# Los roles restringen qué certificados puede emitir Vault — dominios, TTL, tipo de clave, etc.
if ! vault write "pki_int/roles/${ROLE_NAME}" \
  allowed_domains="example.com,lab.local" \
  allow_subdomains=true \
  max_ttl="72h" \
  ttl="24h" \
  key_type="rsa" \
  key_bits=2048 \
  allow_ip_sans=true \
  server_flag=true \
  client_flag=true \
  code_signing_flag=false \
  email_protection_flag=false; then
  error_exit "Error al crear rol PKI '${ROLE_NAME}'"
fi

print_success "Rol PKI '${ROLE_NAME}' creado"
echo

print_success "Configuración de rol PKI completada"
echo

# --- Paso 4: Mostrar información del rol ---
print_step "Información del rol PKI"

print_info "Rol: ${ROLE_NAME}"
echo
vault read "pki_int/roles/${ROLE_NAME}"
echo

# --- Paso 5: Mostrar ejemplos de uso ---
print_step "Ejemplos de uso"

print_info "Emitir un certificado:"
echo "  vault write pki_int/issue/${ROLE_NAME} \\"
echo "    common_name=\"server01.lab.local\" \\"
echo "    ttl=\"24h\""
echo
print_info "Emitir con SAN IP:"
echo "  vault write pki_int/issue/${ROLE_NAME} \\"
echo "    common_name=\"server02.lab.local\" \\"
echo "    ip_sans=\"192.168.1.100\" \\"
echo "    ttl=\"24h\""
echo
print_info "Emitir certificado de corta duración:"
echo "  vault write pki_int/issue/${ROLE_NAME} \\"
echo "    common_name=\"temp.lab.local\" \\"
echo "    ttl=\"1h\""

echo
echo "Próximos pasos:"
echo "  - Ejecute './issue-certificate.sh' para emitir certificados"
echo "  - Listar roles: vault list pki_int/roles"
echo "  - Leer rol: vault read pki_int/roles/${ROLE_NAME}"
