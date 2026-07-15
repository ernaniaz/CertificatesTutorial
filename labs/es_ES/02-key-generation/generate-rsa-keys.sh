#!/usr/bin/env bash
#=============================================================================
# Lab 02: Generación de claves RSA
# Genera pares de claves RSA de distintos tamaños
#
# Uso: ./generate-rsa-keys.sh
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
mkdir -p "${OUTPUT_DIR}"

print_header "Lab 02: Generación de claves RSA"

# Generar clave RSA de 2048 bits (mínimo para producción)
print_info "Generando clave RSA de 2048 bits..."
openssl genpkey -algorithm RSA \
  -out "${OUTPUT_DIR}/rsa-2048.key" \
  -pkeyopt rsa_keygen_bits:2048

# Extraer clave pública
openssl pkey -in "${OUTPUT_DIR}/rsa-2048.key" \
  -pubout -out "${OUTPUT_DIR}/rsa-2048.pub"

print_success "Par de claves RSA de 2048 bits generado"
echo

# Generar clave RSA de 4096 bits (recomendada para alta seguridad)
print_info "Generando clave RSA de 4096 bits..."
openssl genpkey -algorithm RSA \
  -out "${OUTPUT_DIR}/rsa-4096.key" \
  -pkeyopt rsa_keygen_bits:4096

# Extraer clave pública
openssl pkey -in "${OUTPUT_DIR}/rsa-4096.key" \
  -pubout -out "${OUTPUT_DIR}/rsa-4096.pub"

print_success "Par de claves RSA de 4096 bits generado"
echo

# Permisos seguros
chmod 600 "${OUTPUT_DIR}"/*.key 2>/dev/null || true
chmod 644 "${OUTPUT_DIR}"/*.pub 2>/dev/null || true

echo "Claves generadas en ${OUTPUT_DIR}/"
echo "  Claves privadas: rsa-2048.key, rsa-4096.key (modo 600)"
echo "  Claves públicas:  rsa-2048.pub, rsa-4096.pub (modo 644)"
echo
print_success "Generación de claves RSA completada"
