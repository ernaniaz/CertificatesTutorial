#!/usr/bin/env bash
#=============================================================================
# Lab 19: Validar FIPS
# Valida que el modo FIPS esté activo
#
# Uso: ./validate-fips.sh
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

print_header "Lab 19: Validación del modo FIPS"

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
    echo -e "${RED}✗ FALLÓ: ${NC} ${description}"
    ((FAIL+=1))
  fi
}

print_info "Verificaciones del modo FIPS:"
test_check "FIPS habilitado en el kernel" "[[ -f /proc/sys/crypto/fips_enabled && \$(cat /proc/sys/crypto/fips_enabled) -eq 1 ]]"
test_check "Parámetro de arranque FIPS configurado" "grep -q 'fips=1' /proc/cmdline"
test_check "crypto-policy FIPS activa" "update-crypto-policies --show | grep -q FIPS"
test_check "fips-mode-setup reporta habilitado" "fips-mode-setup --check 2>&1 | grep -q 'enabled'"

echo
print_info "OpenSSL FIPS:"
if [[ ${RHEL_VERSION} -le 8 ]]; then
  test_check "Módulo FIPS de OpenSSL activo" "openssl version 2>/dev/null | grep -qi fips"
else
  test_check "Proveedor FIPS de OpenSSL disponible" "openssl list -providers 2>/dev/null | grep -q fips"
fi
test_check "Puede generar clave RSA 2048" "openssl genrsa -out /tmp/fips-test.key 2048"
test_check "No puede usar MD5" "! openssl dgst -md5 /tmp/fips-test.key"

rm -f /tmp/fips-test.key

echo
echo "======================================="
echo "Aprobados: ${PASS}"
echo "Fallidos: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "Modo FIPS totalmente operativo"
  exit 0
else
  print_error "Validación FIPS falló"
  echo "El sistema puede no estar en modo FIPS correcto"
  exit 1
fi
