#!/usr/bin/env bash
#=============================================================================
# Lab 12: Prueba
# Validación automatizada de crypto-policies
#
# Uso: ./test.sh
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

PASS=0
FAIL=0

test_check ()
{
  local description="${1}"
  local command="${2}"

  if eval "${command}" &>/dev/null; then
    echo -e "${GREEN}✓ PASS: ${NC} ${description}"
    ((PASS+=1))
  else
    echo -e "${RED}✗ FAIL: ${NC} ${description}"
    ((FAIL+=1))
  fi
}

print_header "Lab 12: Pruebas automatizadas"

# Comprobar versión de RHEL
if [[ ${RHEL_VERSION} -lt 8 ]]; then
  print_warning "crypto-policies requiere RHEL 8+"
  echo "Versión actual: RHEL ${RHEL_VERSION}"
  echo "Omitiendo pruebas"
  exit 0
fi

test_check "Comando update-crypto-policies disponible" "command -v update-crypto-policies"
test_check "Se puede consultar la política actual" "update-crypto-policies --show"
test_check "Archivo de configuración existe" "[ -f /etc/crypto-policies/config ]"
test_check "Directorio de políticas existe" "[ -d /usr/share/crypto-policies/policies/ ]"
test_check "Directorio de configuraciones de backend existe" "[ -d /etc/crypto-policies/back-ends/ ]"
test_check "Archivo de política DEFAULT existe" "[ -f /usr/share/crypto-policies/policies/DEFAULT.pol ]"
test_check "Cifrados OpenSSL disponibles" "openssl ciphers -v | grep -q ."
test_check "La política actual es DEFAULT" "[[ \$(update-crypto-policies --show) == 'DEFAULT' ]]"

echo
echo "======================================="
echo "Aprobados: ${PASS}"
echo "Fallidos: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "Lab 12 completado correctamente"
  exit 0
else
  print_error "Algunas pruebas fallaron"
  exit 1
fi
