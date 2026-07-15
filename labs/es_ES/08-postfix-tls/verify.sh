#!/usr/bin/env bash
#=============================================================================
# Lab 08: Verificar
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

print_header "Lab 08: Verificación TLS de Postfix"

print_info "1. Verificando servicio Postfix..."
systemctl status postfix --no-pager | head -5
echo

print_info "2. Verificando puertos escuchando..."
ss -tlnp | grep master
echo

print_info "3. Verificando configuración TLS..."
echo "Certificado y clave TLS:"
postconf -n | grep -E "smtpd_tls_cert_file|smtpd_tls_key_file" || print_warning "Aún no configurado"
echo
echo "Niveles de seguridad TLS:"
postconf -n | grep -E "smtpd_tls_security_level|smtp_tls_security_level" || print_warning "Aún no configurado"
echo
echo "Protocolos TLS:"
postconf -n | grep -E "smtpd_tls_protocols" || print_warning "Aún no configurado"
echo

print_info "4. Verificando archivos de certificado..."
if [[ -f /etc/pki/tls/certs/postfix.crt ]]; then
  print_success "El certificado existe"
  openssl x509 -in /etc/pki/tls/certs/postfix.crt -noout -subject -dates
else
  echo "Certificado no encontrado"
fi
echo

print_info "5. Verificando clave privada..."
if [[ -f /etc/pki/tls/private/postfix.key ]]; then
  print_success "La clave privada existe"
  ls -l /etc/pki/tls/private/postfix.key
  PERMS="$(stat -c%a /etc/pki/tls/private/postfix.key)"
  if [[ "${PERMS}" == "600" ]]; then
    print_success "Permisos correctos (600)"
  else
    print_warning "Permisos: ${PERMS} (deberían ser 600)"
  fi
else
  echo "Clave privada no encontrada"
fi
echo

print_info "6. Verificando capacidad STARTTLS..."
EHLO_TEST="$(echo -e "EHLO localhost\nQUIT" | nc localhost 25 2>/dev/null || true)"
if echo "${EHLO_TEST}" | grep -q "STARTTLS"; then
  print_success "STARTTLS anunciado en el puerto 25"
else
  if ! command -v nc &>/dev/null; then
    print_warning "nc (netcat) no instalado, omitiendo verificación STARTTLS"
  else
    print_warning "STARTTLS no anunciado en el puerto 25"
  fi
fi
echo

print_info "7. Verificando puerto submission..."
if ss -tlnp | grep -q ':587'; then
  print_success "Puerto 587 activo"
  if grep -q "smtpd_tls_security_level=encrypt" /etc/postfix/master.cf; then
    print_success "Cifrado obligatorio configurado"
  fi
else
  echo "Puerto 587 no escuchando"
fi
echo

print_info "8. Verificando registros recientes..."
echo "Entradas recientes del registro TLS de Postfix:"
if [[ -f /var/log/maillog ]]; then
  if ! grep -i "tls\|starttls" /var/log/maillog 2>/dev/null | tail -5; then
    echo "Aún no hay registros TLS"
  fi
elif [[ -f /var/log/messages ]]; then
  if ! grep -i "postfix.*tls" /var/log/messages 2>/dev/null | tail -5; then
    echo "Aún no hay registros TLS"
  fi
else
  if ! journalctl -u postfix --no-pager | grep -i tls | tail -5; then
    echo "Aún no hay registros TLS"
  fi
fi

echo
print_success "Verificación completada"
