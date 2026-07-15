#!/usr/bin/env bash
#=============================================================================
# Lab 07: Verificar
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

print_header "Lab 07: Verificación SSL de NGINX"

print_info "1. Verificando servicio NGINX..."
systemctl status nginx --no-pager | head -5
echo

print_info "2. Verificando puertos escuchando..."
ss -tlnp | grep nginx
echo

print_info "3. Verificando configuración NGINX..."
nginx -t
echo

print_info "4. Verificando archivos de certificado..."
if [[ -f /etc/pki/nginx/server.crt ]]; then
  print_success "El certificado existe"
  openssl x509 -in /etc/pki/nginx/server.crt -noout -subject -dates
else
  echo "Certificado no encontrado"
fi
echo

print_info "5. Verificando clave privada..."
if [[ -f /etc/pki/nginx/private/server.key ]]; then
  print_success "La clave privada existe"
  ls -l /etc/pki/nginx/private/server.key
  PERMS=$(stat -c%a /etc/pki/nginx/private/server.key)
  if [[ "${PERMS}" == "600" ]]; then
    print_success "Permisos correctos (600)"
  else
    print_warning "Permisos: ${PERMS} (deberían ser 600)"
  fi
else
  echo "Clave privada no encontrada"
fi
echo

print_info "6. Verificando configuración SSL..."
if [[ -f /etc/nginx/conf.d/lab-ssl.conf ]]; then
  print_success "La configuración SSL existe"
  echo
  echo "Directivas SSL:"
  grep -E "ssl_|listen 443" /etc/nginx/conf.d/lab-ssl.conf | grep -v "^#"
else
  echo "Configuración SSL no encontrada"
fi
echo

print_info "7. Probando conexión HTTPS..."
if curl -k -s https://localhost/ | grep -q "Lab 07"; then
  print_success "HTTPS funcionando"
  curl -k -s https://localhost/ | head -3
else
  echo "Prueba HTTPS fallida"
fi

echo
print_success "Verificación completada"
