#!/usr/bin/env bash
#=============================================================================
# Lab 09: Verificar
# Pasos de verificación manual
#
# Uso: ./verify.sh
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

print_header "Lab 09: Verificación LDAPS de OpenLDAP"

print_info "1. Verificando servicio slapd..."
systemctl status slapd --no-pager | head -5
echo

print_info "2. Verificando puertos escuchando..."
ss -tlnp | grep slapd
echo

print_info "3. Verificando configuración TLS en cn=config..."
echo "Archivo de certificado TLS:"
if ! ldapsearch -Y EXTERNAL -H ldapi:/// -b cn=config "(objectClass=olcGlobal)" olcTLSCertificateFile 2>/dev/null | grep "olcTLSCertificateFile"; then
  echo "No configurado"
fi
echo
echo "Archivo de clave TLS:"
if ! ldapsearch -Y EXTERNAL -H ldapi:/// -b cn=config "(objectClass=olcGlobal)" olcTLSCertificateKeyFile 2>/dev/null | grep "olcTLSCertificateKeyFile"; then
  echo "No configurado"
fi
echo

print_info "4. Verificando archivos de certificado..."
if [[ -f /etc/openldap/certs/ldap.crt ]]; then
  print_success "El certificado existe"
  openssl x509 -in /etc/openldap/certs/ldap.crt -noout -subject -dates
else
  echo "Certificado no encontrado"
fi
echo

print_info "5. Verificando clave privada..."
if [[ -f /etc/openldap/certs/ldap.key ]]; then
  print_success "La clave privada existe"
  ls -l /etc/openldap/certs/ldap.key
  PERMS="$(stat -c%a /etc/openldap/certs/ldap.key)"
  if [[ "${PERMS}" == "600" ]]; then
    print_success "Permisos correctos (600)"
  else
    print_warning "Permisos: ${PERMS} (deberían ser 600)"
  fi

  OWNER="$(stat -c%U:%G /etc/openldap/certs/ldap.key)"
  if [[ "${OWNER}" == "ldap:ldap" ]]; then
    print_success "Propietario correcto (ldap:ldap)"
  else
    print_warning "Propietario: ${OWNER} (debería ser ldap:ldap)"
  fi
else
  echo "Clave privada no encontrada"
fi
echo

print_info "6. Verificando configuración SLAPD_URLS..."
if [[ -f /etc/sysconfig/slapd ]]; then
  if ! grep "SLAPD_URLS" /etc/sysconfig/slapd; then
    echo "No configurado"
  fi
else
  echo "Archivo sysconfig no encontrado"
fi
echo

print_info "7. Verificando configuración del cliente..."
if [[ -f /etc/openldap/ldap.conf ]]; then
  echo "Ajustes TLS del cliente:"
  grep -E "^TLS_|^URI" /etc/openldap/ldap.conf | grep -v "^#"
else
  echo "Configuración del cliente no encontrada"
fi
echo

print_info "8. Probando conexión LDAP..."
if ldapsearch -x -H ldap://localhost -b "" -s base &>/dev/null; then
  print_success "Conexión LDAP funciona"
else
  echo "Conexión LDAP fallida"
fi

print_info "9. Probando conexión LDAPS..."
if ldapsearch -x -H ldaps://localhost -b "" -s base &>/dev/null; then
  print_success "Conexión LDAPS funciona"
else
  echo "Conexión LDAPS fallida (puede necesitar habilitar el puerto 636)"
fi

echo
print_success "Verificación completada"
