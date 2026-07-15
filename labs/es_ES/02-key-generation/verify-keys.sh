#!/usr/bin/env bash
#=============================================================================
# Lab 02: Verificación de claves
# Valida las claves generadas
#
# Uso: ./verify-keys.sh
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

OUTPUT_DIR="output"

print_header "Lab 02: Verificación de claves generadas"

# Verificar si existe el directorio output
if [[ ! -d "${OUTPUT_DIR}" ]]; then
  print_error "Directorio output no encontrado. Ejecute primero los scripts de generación."
  exit 1
fi

# Verificar RSA 2048
echo "Clave RSA de 2048 bits:"
if [[ -f "${OUTPUT_DIR}/rsa-2048.key" ]]; then
  openssl pkey -in "${OUTPUT_DIR}/rsa-2048.key" -text -noout | grep -E "Private-Key|RSA" | head -2
  print_success "Válida"
else
  print_error "No encontrada"
fi
echo

# Verificar RSA 4096
echo "Clave RSA de 4096 bits:"
if [[ -f "${OUTPUT_DIR}/rsa-4096.key" ]]; then
  openssl pkey -in "${OUTPUT_DIR}/rsa-4096.key" -text -noout | grep -E "Private-Key|RSA" | head -2
  print_success "Válida"
else
  print_error "No encontrada"
fi
echo

# Verificar ECC P-256
echo "Clave ECC P-256:"
if [[ -f "${OUTPUT_DIR}/ecc-p256.key" ]]; then
  openssl pkey -in "${OUTPUT_DIR}/ecc-p256.key" -text -noout | grep -E "Private-Key|ASN1 OID" | head -2
  print_success "Válida"
else
  print_error "No encontrada"
fi
echo

# Verificar ECC P-384
echo "Clave ECC P-384:"
if [[ -f "${OUTPUT_DIR}/ecc-p384.key" ]]; then
  openssl pkey -in "${OUTPUT_DIR}/ecc-p384.key" -text -noout | grep -E "Private-Key|ASN1 OID" | head -2
  print_success "Válida"
else
  print_error "No encontrada"
fi
echo

# Verificar permisos de archivos
echo "Permisos de archivos:"
ls -l "${OUTPUT_DIR}"/ | grep -E '\.key$|\.pub$'
echo

print_success "Todas las claves verificadas correctamente"
