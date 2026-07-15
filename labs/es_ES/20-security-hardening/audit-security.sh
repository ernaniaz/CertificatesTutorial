#!/usr/bin/env bash
#=============================================================================
# Lab 20: Auditar seguridad
# Script de auditoría de seguridad para el Lab 20
#
# Uso: ./audit-security.sh
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

print_header "Lab 20: Auditoría de seguridad"

PASS=0
FAIL=0

test_check ()
{
  if eval "${2}" &>/dev/null; then
    echo -e "${GREEN}✓ APROBADO: ${NC} ${1}"
    ((PASS+=1))
  else
    echo -e "${RED}✗ FALLÓ: ${NC} ${1}"
    ((FAIL+=1))
  fi
}

if [[ -f /etc/httpd/conf.d/ssl-hardening.conf ]]; then
  test_check "Configuración de endurecimiento de Apache" "[[ -f /etc/httpd/conf.d/ssl-hardening.conf ]]"
fi
if [[ -f /etc/nginx/conf.d/ssl-hardening.conf ]]; then
  test_check "Configuración de endurecimiento de NGINX" "[[ -f /etc/nginx/conf.d/ssl-hardening.conf ]]"
fi

echo
echo "Aprobados: ${PASS} | Fallidos: ${FAIL}"
if [[ ${FAIL} -eq 0 ]]; then
  echo -e "${GREEN}✓ Endurecimiento de seguridad completado${NC}"
fi
