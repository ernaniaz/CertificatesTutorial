#!/usr/bin/env bash
#=============================================================================
# Lab 09: Prueba
# Validación automatizada para OpenLDAP LDAPS
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
    echo -e "${GREEN}✓ PASS: ${NC} ${description}"
    ((PASS+=1))
  else
    echo -e "${RED}✗ FAIL: ${NC} ${description}"
    ((FAIL+=1))
  fi
}

print_header "Lab 09: Pruebas automatizadas"

test_check "Servicio slapd en ejecución" "systemctl is-active slapd"
test_check "Puerto 389 escuchando" "ss -tlnp | grep -q ':389'"
test_check "Archivo de certificado existe" "[ -f /etc/openldap/certs/ldap.crt ]"
test_check "Clave privada existe" "[ -f /etc/openldap/certs/ldap.key ]"
test_check "Clave privada con permisos correctos" "[ \$(stat -c%a /etc/openldap/certs/ldap.key) == '600' ]"
test_check "Clave privada propiedad de ldap" "[ \$(stat -c%U /etc/openldap/certs/ldap.key) == 'ldap' ]"
test_check "Certificado TLS configurado en cn=config" "ldapsearch -Y EXTERNAL -H ldapi:/// -b cn=config '(objectClass=olcGlobal)' olcTLSCertificateFile 2>&1 | grep -q olcTLSCertificateFile"
test_check "Conexión LDAP funciona" "ldapsearch -x -H ldap://localhost -b '' -s base"
test_check "Configuración del cliente existe" "[ -f /etc/openldap/ldap.conf ]"

# Opcional: Puerto 636 (puede no estar habilitado por defecto)
if ss -tlnp | grep -q ':636'; then
  test_check "Conexión LDAPS funciona" "timeout 5 ldapsearch -x -H ldaps://localhost -b '' -s base"
fi

echo
echo "======================================="
echo "Aprobadas: ${PASS}"
echo "Fallidas: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "Lab 09 completado correctamente"
  exit 0
else
  print_error "Algunas pruebas fallaron"
  exit 1
fi
