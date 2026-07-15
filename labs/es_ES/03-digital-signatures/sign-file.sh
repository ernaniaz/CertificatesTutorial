#!/usr/bin/env bash
#=============================================================================
# Lab 03: Firma de archivo
# Crea la firma digital de un archivo de ejemplo
#
# Uso: ./sign-file.sh
# Requisitos previos: RHEL 7, 8, 9, 10
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
if [[ ${RHEL_VERSION} -lt 7 || ${RHEL_VERSION} -gt 10 ]]; then
  error_exit "Versión de RHEL no soportada. Este script requiere RHEL 7, 8, 9 o 10."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

KEY_DIR="../02-key-generation/output"
SAMPLE_FILE="sample-data.txt"
SIGNATURE_FILE="sample-data.sig"

print_header "Lab 03: Creación de firma digital"

# Verificar requisitos previos
if [[ ! -f "${KEY_DIR}/rsa-2048.key" ]]; then
  print_error "Error: clave RSA no encontrada. Ejecute primero el Lab 02."
  exit 1
fi

if [[ ! -f "${SAMPLE_FILE}" ]]; then
  print_error "Error: archivo de ejemplo no encontrado."
  exit 1
fi

# Firmar el archivo con clave privada RSA usando SHA-256
print_info "Firmando ${SAMPLE_FILE} con clave RSA-2048..."
openssl dgst -sha256 \
  -sign "${KEY_DIR}/rsa-2048.key" \
  -out "${SIGNATURE_FILE}" \
  "${SAMPLE_FILE}"

print_success "Archivo firmado: ${SIGNATURE_FILE}"
echo
echo "Detalles de la firma:"
echo "  Algoritmo: SHA-256 con RSA"
echo "  Tamaño: $(stat -f%z "${SIGNATURE_FILE}" 2>/dev/null || stat -c%s "${SIGNATURE_FILE}") bytes"
echo
echo "Firma (primeros 80 bytes en hex):"
hexdump -C "${SIGNATURE_FILE}" | head -n 5
echo
print_success "Creación de firma completada"
echo
echo "Siguiente: ejecute ./verify-signature.sh para verificar"
