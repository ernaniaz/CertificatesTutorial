#!/usr/bin/env bash
#=============================================================================
# Lab 04: Prueba
# Validación automatizada
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

print_header "Lab 04: Pruebas automatizadas"

test_check "Existe archivo de certificado" "[ -f output/server.crt ]"
test_check "Existe archivo CSR" "[ -f output/server.csr ]"
test_check "Existe archivo DER" "[ -f output/server.der ]"
test_check "El certificado es X.509 válido" "openssl x509 -in output/server.crt -noout -text"
test_check "El certificado no ha expirado" "openssl x509 -in output/server.crt -noout -checkend 0"
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  test_check "El certificado tiene SANs" "openssl x509 -in output/server.crt -noout -text | grep -q 'Subject Alternative Name'"
else
  test_check "El certificado tiene SANs" "openssl x509 -in output/server.crt -noout -ext subjectAltName"
fi
test_check "El CSR es válido" "openssl req -in output/server.csr -noout -text"
test_check "Formato DER válido" "openssl x509 -in output/server.der -inform DER -noout -text"
test_check "PEM y DER coinciden" "pem=\$(openssl x509 -in output/server.crt -noout -fingerprint -sha256) && der=\$(openssl x509 -in output/server.der -inform DER -noout -fingerprint -sha256) && [[ -n \"\${pem}\" && \"\${pem}\" == \"\${der}\" ]]"

echo
echo "======================================="
echo "Aprobadas: ${PASS}"
echo "Fallidas: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "Lab 04 completado correctamente"
  exit 0
else
  print_error "Algunas pruebas fallaron"
  exit 1
fi
