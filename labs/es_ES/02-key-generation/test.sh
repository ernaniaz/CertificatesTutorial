#!/usr/bin/env bash
#=============================================================================
# Lab 02: Prueba
# Validación automatizada de la generación de claves
#
# Uso: ./test.sh
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

PASS=0
FAIL=0

test_check ()
{
  local description="${1}"
  local command="${2}"

  if eval "${command}" &>/dev/null; then
    echo -e "${GREEN}✓ APROBADO: ${NC} ${description}"
    ((PASS+=1))
  else
    echo -e "${RED}✗ FALLIDO: ${NC} ${description}"
    ((FAIL+=1))
  fi
}

print_header "Lab 02: Pruebas automatizadas"

# Ejecutar pruebas
test_check "Existe clave RSA de 2048 bits" "[ -f output/rsa-2048.key ]"
test_check "Existe clave pública RSA de 2048 bits" "[ -f output/rsa-2048.pub ]"
test_check "Existe clave RSA de 4096 bits" "[ -f output/rsa-4096.key ]"
test_check "Existe clave pública RSA de 4096 bits" "[ -f output/rsa-4096.pub ]"
test_check "Existe clave ECC P-256" "[ -f output/ecc-p256.key ]"
test_check "Existe clave pública ECC P-256" "[ -f output/ecc-p256.pub ]"
test_check "Existe clave ECC P-384" "[ -f output/ecc-p384.key ]"
test_check "Existe clave pública ECC P-384" "[ -f output/ecc-p384.pub ]"
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  test_check "Clave RSA 2048 es válida" "openssl rsa -in output/rsa-2048.key -check -noout"
  test_check "Clave ECC P-256 es válida" "openssl ec -in output/ecc-p256.key -noout"
else
  test_check "Clave RSA 2048 es válida" "openssl pkey -in output/rsa-2048.key -check -noout"
  test_check "Clave ECC P-256 es válida" "openssl pkey -in output/ecc-p256.key -check -noout"
fi

echo
print_header "Resultados de las pruebas"
echo "Aprobadas: ${PASS}"
echo "Fallidas: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "¡Todas las pruebas pasaron!"
  print_success "Lab 02 completado correctamente."
  exit 0
else
  print_error "Algunas pruebas fallaron."
  exit 1
fi
