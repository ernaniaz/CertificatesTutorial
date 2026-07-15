#!/usr/bin/env bash
#=============================================================================
# Lab 05: Prueba
# Validación automatizada (requiere root)
#
# Uso: ./test.sh
# Requisitos previos: RHEL 7, 8, 9, 10, privilegios de root
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

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  print_warning "Nota: algunas pruebas requieren privilegios de root"
  echo "Ejecute: sudo ./test.sh"
  echo
fi

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

print_header "Lab 05: Pruebas automatizadas"

test_check "Existe certificado CA" "[ -f output/test-ca.crt ]"
test_check "Existe clave privada de CA" "[ -f output/test-ca.key ]"
test_check "Certificado CA es X.509 válido" "openssl x509 -in output/test-ca.crt -noout -text"
test_check "CA tiene basicConstraints CA:TRUE" "openssl x509 -in output/test-ca.crt -noout -text | grep -q 'CA:TRUE'"
test_check "Existe certificado de servidor de prueba" "[ -f output/test-server.crt ]"
test_check "Certificado de prueba firmado por CA" "openssl verify -CAfile output/test-ca.crt output/test-server.crt"

echo
echo "======================================="
echo "Aprobadas: ${PASS}"
echo "Fallidas: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "Lab 05 completado correctamente"
  exit 0
else
  print_error "Algunas pruebas fallaron"
  exit 1
fi
