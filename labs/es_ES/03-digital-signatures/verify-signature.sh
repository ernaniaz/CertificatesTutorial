#!/usr/bin/env bash
#=============================================================================
# Lab 03: Verificación de firma
# Verifica la firma digital
#
# Uso: ./verify-signature.sh
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

print_header "Lab 03: Verificación de firma digital"

# Verificar requisitos previos
if [[ ! -f "${KEY_DIR}/rsa-2048.pub" ]]; then
  print_error "Error: clave pública no encontrada. Ejecute primero el Lab 02."
  exit 1
fi

if [[ ! -f "${SIGNATURE_FILE}" ]]; then
  print_error "Error: archivo de firma no encontrado. Ejecute primero ./sign-file.sh."
  exit 1
fi

# Verificar firma con clave pública
print_info "Verificando firma con clave pública..."
echo

if openssl dgst -sha256 \
  -verify "${KEY_DIR}/rsa-2048.pub" \
  -signature "${SIGNATURE_FILE}" \
  "${SAMPLE_FILE}"; then
  echo
  print_success "¡Verificación de firma exitosa!"
  echo
  echo "Esto demuestra:"
  echo "  ✓ El archivo fue firmado por el titular de la clave privada"
  echo "  ✓ El archivo no ha sido modificado desde la firma"
  echo "  ✓ La integridad del archivo está intacta"
else
  echo
  print_error "FALLÓ la verificación de firma"
  echo "Esto indica manipulación o clave incorrecta"
  exit 1
fi
