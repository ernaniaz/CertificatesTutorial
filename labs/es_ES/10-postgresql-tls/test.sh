#!/usr/bin/env bash
#=============================================================================
# Lab 10: Prueba
# Validación automatizada para PostgreSQL TLS
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
PG_DATA="/var/lib/pgsql/data"

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

print_header "Lab 10: Pruebas automatizadas"

test_check "Servicio PostgreSQL en ejecución" "systemctl is-active postgresql"
test_check "Puerto 5432 escuchando" "ss -tlnp | grep -q ':5432'"
test_check "Archivo de certificado existe" "[ -f ${PG_DATA}/server.crt ]"
test_check "Clave privada existe" "[ -f ${PG_DATA}/server.key ]"
test_check "Clave privada con permisos correctos" "[ \$(stat -c%a ${PG_DATA}/server.key) == '600' ]"
test_check "Clave privada propiedad de postgres" "[ \$(stat -c%U ${PG_DATA}/server.key) == 'postgres' ]"
test_check "SSL habilitado en postgresql.conf" "grep -q '^ssl = on' ${PG_DATA}/postgresql.conf"
test_check "SSL habilitado en la base de datos" "[[ \$(sudo -u postgres psql -t -c 'SHOW ssl;' | tr -d '[:space:]') == 'on' ]]"
test_check "Conexión a la base de datos funciona" "sudo -u postgres psql -c 'SELECT 1;'"
test_check "Regla hostssl existe" "grep -q '^hostssl' ${PG_DATA}/pg_hba.conf"

echo
echo "======================================="
echo "Aprobadas: ${PASS}"
echo "Fallidas: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "Lab 10 completado correctamente"
  exit 0
else
  print_error "Algunas pruebas fallaron"
  exit 1
fi
