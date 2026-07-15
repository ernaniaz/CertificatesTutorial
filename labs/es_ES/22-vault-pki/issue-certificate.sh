#!/usr/bin/env bash
#=============================================================================
# Lab 22: Emitir certificado
# Emite certificados usando el rol configurado
#
# Uso: ./issue-certificate.sh
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

# Default values
ROLE_NAME="web-server"
COMMON_NAME="${1:-}"
TTL="${2:-24h}"

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

print_header "Lab 22: Emitir certificados"

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

# --- Paso 2: Verificar que existan rol y CA intermedia ---
print_step "Verificando requisitos previos"

if ! vault read "pki_int/roles/${ROLE_NAME}" &> /dev/null; then
  error_exit "Rol '${ROLE_NAME}' no encontrado. Ejecute ./create-role.sh primero"
fi

if ! vault read pki_int/cert/ca &> /dev/null; then
  error_exit "CA intermedia no encontrada. Ejecute ./configure-intermediate-ca.sh primero"
fi

mkdir -p "${CERTS_DIR}"
print_success "Rol PKI y CA intermedia encontrados"
echo

# --- Paso 3: Emitir certificado(s) ---
print_step "Emitiendo certificados"

if [[ -n "${COMMON_NAME}" ]]; then
  cert_names=("${COMMON_NAME}")
  cert_ttls=("${TTL}")
else
  cert_names=("server01.lab.local" "server02.lab.local" "temp.lab.local")
  cert_ttls=("24h" "24h" "1h")
fi

for i in "${!cert_names[@]}"; do
  cn="${cert_names[${i}]}"
  ttl="${cert_ttls[${i}]}"
  cert_base="${CERTS_DIR}/${cn}"

  print_info "Emitiendo certificado: ${cn} (TTL: ${ttl})..."

  if ! response="$(vault write -format=json "pki_int/issue/${ROLE_NAME}" \
    common_name="${cn}" \
    ttl="${ttl}")"; then
    error_exit "Error al emitir certificado para ${cn}"
  fi

  echo "${response}" | jq -r '.data.certificate' > "${cert_base}.crt"
  echo "${response}" | jq -r '.data.private_key' > "${cert_base}.key"
  echo "${response}" | jq -r '.data.ca_chain[]' > "${cert_base}-chain.crt"
  echo "${response}" | jq -r '.data.issuing_ca' > "${cert_base}-ca.crt"
  cat "${cert_base}.crt" "${cert_base}.key" > "${cert_base}.pem"
  echo "${response}" | jq -r '.data.serial_number' > "${cert_base}.serial"

  chmod 644 "${cert_base}.crt" "${cert_base}.pem" "${cert_base}-chain.crt" "${cert_base}-ca.crt"
  chmod 600 "${cert_base}.key"

  print_success "Certificado emitido: ${cn}"
  print_info "  Certificado: ${cert_base}.crt"
  print_info "  Clave privada: ${cert_base}.key"
  print_info "  Serial: $(cat "${cert_base}.serial")"
  echo
done

if [[ -z "${COMMON_NAME}" ]]; then
  print_success "Todos los certificados de prueba emitidos"
fi
echo

# --- Paso 4: Mostrar resumen de certificados ---
print_step "Resumen de certificados"

print_info "Certificados emitidos:"
if ! ls -lh "${CERTS_DIR}"/*.crt 2>/dev/null | grep -v -- '-chain.crt' | grep -v -- '-ca.crt'; then
  print_warning "No se encontraron certificados"
fi
echo
print_info "Total de certificados: $(find "${CERTS_DIR}" -maxdepth 1 -name '*.crt' ! -name '*-chain.crt' ! -name '*-ca.crt' 2>/dev/null | wc -l)"
echo

# --- Paso 5: Verificar certificados con OpenSSL ---
print_step "Verificando certificados con OpenSSL"

for cert_file in "${CERTS_DIR}"/*.crt; do
  if [[ ! (-f "${cert_file}") ]]; then
    continue
  fi
  if [[ "${cert_file}" =~ -chain\.crt$ ]]; then
    continue
  fi
  if [[ "${cert_file}" =~ -ca\.crt$ ]]; then
    continue
  fi

  cert_base="${cert_file%.crt}"
  print_info "Verificando: $(basename "${cert_file}")"

  if [[ -f "${cert_base}-ca.crt" ]] && openssl verify -CAfile "${cert_base}-ca.crt" "${cert_file}" &> /dev/null; then
    print_success "Certificado válido"
  else
    print_warning "La verificación del certificado tuvo problemas"
  fi

  print_info "Subject y validez:"
  openssl x509 -in "${cert_file}" -noout -subject -dates
done

echo
print_success "¡Emisión de certificados completada!"
echo
echo "Archivos de certificados:"
echo "  *.crt       - Certificado"
echo "  *.key       - Clave privada"
echo "  *.pem       - Paquete certificado + clave"
echo "  *-chain.crt - Cadena de certificados CA"
echo "  *.serial    - Número de serie (para revocación)"
echo
echo "Próximos pasos:"
echo "  - Inspeccionar certificado: openssl x509 -in certs/server01.lab.local.crt -noout -text"
echo "  - Usar certificado: cp certs/server01.lab.local.* /etc/pki/tls/"
echo "  - Ejecute './revoke-certificate.sh' para probar revocación"
