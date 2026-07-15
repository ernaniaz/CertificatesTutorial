#!/usr/bin/env bash
#=============================================================================
# Lab 17: Validar migración
# Validación en RHEL 8 ya actualizado
#
# Uso: ./validate-migration.sh
# Requisitos previos: RHEL 8
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
if [[ ${RHEL_VERSION} -ne 8 ]]; then
  error_exit "Versión de RHEL no soportada. Este script requiere solo RHEL 8."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

print_header "Lab 17: Validación posterior a la actualización a RHEL 8"

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

print_info "Validación del sistema:"
test_check "Ejecutando RHEL 8" "grep -q 'release 8' /etc/redhat-release"
test_check "crypto-policies disponible" "command -v update-crypto-policies"
test_check "crypto-policy configurada" "update-crypto-policies --show"

echo
print_info "Validación de certificados:"
test_check "Existe el directorio de certificados" "[ -d /etc/pki/tls/certs ]"
test_check "Hay certificados presentes" "ls /etc/pki/tls/certs/*.crt 2>/dev/null | grep -q ."
test_check "Almacén de confianza intacto" "[ -d /etc/pki/ca-trust ]"

echo
print_info "Validación de servicios:"
for svc in httpd nginx postfix; do
  if systemctl list-unit-files | grep -q "^${svc}.service"; then
    test_check "Existe el archivo de servicio ${svc}" "systemctl cat ${svc}"
  fi
done

echo
echo "======================================="
echo "Aprobados: ${PASS}"
echo "Fallidos: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "Validación posterior a la actualización RHEL 7→8 exitosa"
  echo
  echo "¡Migración RHEL 7→8 completada!"
  exit 0
else
  print_error "Algunas verificaciones de validación fallaron"
  echo "Revise y corrija los problemas"
  exit 1
fi
