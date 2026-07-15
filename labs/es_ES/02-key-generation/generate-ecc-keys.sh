#!/usr/bin/env bash
#=============================================================================
# Lab 02: Generación de claves ECC
# Genera pares de claves de curva elíptica
#
# Uso: ./generate-ecc-keys.sh
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

print_header "Lab 02: Generación de claves ECC"

# Generar clave P-256 (secp256r1)
print_info "Generando clave ECC P-256 (secp256r1)..."
openssl ecparam -genkey -name prime256v1 \
    -out "${OUTPUT_DIR}/ecc-p256.key"

# Extraer clave pública
openssl pkey -in "${OUTPUT_DIR}/ecc-p256.key" \
    -pubout -out "${OUTPUT_DIR}/ecc-p256.pub"

print_success "Par de claves ECC P-256 generado"
echo

# Generar clave P-384 (secp384r1)
print_info "Generando clave ECC P-384 (secp384r1)..."
openssl ecparam -genkey -name secp384r1 \
    -out "${OUTPUT_DIR}/ecc-p384.key"

# Extraer clave pública
openssl pkey -in "${OUTPUT_DIR}/ecc-p384.key" \
    -pubout -out "${OUTPUT_DIR}/ecc-p384.pub"

print_success "Par de claves ECC P-384 generado"
echo

# Permisos seguros
chmod 600 "${OUTPUT_DIR}"/*.key 2>/dev/null || true
chmod 644 "${OUTPUT_DIR}"/*.pub 2>/dev/null || true

echo "Claves generadas en ${OUTPUT_DIR}/"
echo "  Claves privadas: ecc-p256.key, ecc-p384.key (modo 600)"
echo "  Claves públicas:  ecc-p256.pub, ecc-p384.pub (modo 644)"
echo
print_success "Generación de claves ECC completada"
