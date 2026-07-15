#!/usr/bin/env bash
#=============================================================================
# Lab 15: Verificar corrección
# Escenario 01: Verificar corrección
#
# Uso: ./verify-fix.sh
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
  error_exit "Versión de RHEL no soportada. Este script requiere RHEL 7, 8, 9, 10."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

CERT_FILE="/etc/pki/tls/certs/expired.crt"

print_header "Escenario 01: Verificar corrección"

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

test_check "Archivo de certificado existe" "[ -f ${CERT_FILE} ]"
test_check "Certificado válido (no vencido)" "openssl x509 -in ${CERT_FILE} -noout -checkend 0"
test_check "Certificado válido por 30+ días" "openssl x509 -in ${CERT_FILE} -noout -checkend 2592000"
test_check "Certificado tiene subject correcto" "openssl x509 -in ${CERT_FILE} -noout -subject | grep -q expired.example.com"

echo
echo "Validez del certificado:"
openssl x509 -in "${CERT_FILE}" -noout -dates

echo
echo "======================================="
echo "Aprobados: ${PASS}"
echo "Fallidos: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "Escenario 01 completado correctamente"
  echo
  echo "Aprendizajes clave:"
  echo "  - Siempre comprobar las fechas de vencimiento del certificado"
  echo "  - Implementar monitoreo antes del vencimiento"
  echo "  - Usar automatización para la renovación"
  echo "  - Probar el proceso de renovación regularmente"
  exit 0
else
  print_error "Algunas comprobaciones fallaron"
  exit 1
fi
