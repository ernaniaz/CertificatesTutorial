#!/usr/bin/env bash
#=============================================================================
# Lab 06: Probar conexión
# Prueba la funcionalidad HTTPS de Apache
#
# Uso: ./test-connection.sh
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

print_header "Lab 06: Probando Apache HTTPS"

# Prueba 1: Verificar si Apache está en ejecución
print_info "Prueba 1: Estado del servicio Apache"
if systemctl is-active httpd &>/dev/null; then
  print_success "Apache está en ejecución"
else
  print_error "Apache no está en ejecución"
  exit 1
fi
echo

# Prueba 2: Verificar puerto 443
print_info "Prueba 2: Puerto 443 escuchando"
if ss -tlnp | grep -q ':443'; then
  print_success "Puerto 443 escuchando"
  ss -tlnp | grep ':443'
else
  print_error "Puerto 443 no escuchando"
  exit 1
fi
echo

# Prueba 3: Conexión HTTP
print_info "Prueba 3: Conexión HTTP (puerto 80)"
if curl -s http://localhost/ &>/dev/null; then
  print_success "Conexión HTTP exitosa"
else
  print_warning "Conexión HTTP fallida (puede ser normal si HTTP está deshabilitado)"
fi
echo

# Prueba 4: Conexión HTTPS
print_info "Prueba 4: Conexión HTTPS (puerto 443)"
if curl -k -s https://localhost/ &>/dev/null; then
  print_success "Conexión HTTPS exitosa"
  echo
  echo "Respuesta:"
  curl -k -s https://localhost/ | head -5
else
  print_error "Conexión HTTPS fallida"
  exit 1
fi
echo

# Prueba 5: Detalles del certificado
print_info "Prueba 5: Certificado servido por Apache"
CERT_INFO=$(echo | openssl s_client -connect localhost:443 -servername localhost 2>/dev/null | openssl x509 -noout -subject -dates 2>/dev/null || echo)

if [[ -n "${CERT_INFO}" ]]; then
  print_success "Certificado obtenido"
  echo "${CERT_INFO}"
else
  print_error "No se pudo obtener el certificado"
fi
echo

# Prueba 6: Versión TLS
print_info "Prueba 6: Versión del protocolo TLS"
TLS_VERSION=$(echo | openssl s_client -connect localhost:443 -servername localhost 2>&1 | grep -E "Protocol|New, TLS" | head -1)
if [[ -n "${TLS_VERSION}" ]]; then
  print_success "${TLS_VERSION}"
else
  print_warning "No se pudo determinar la versión TLS"
fi
echo

# Prueba 7: Cifrado
print_info "Prueba 7: Conjunto de cifrado"
CIPHER=$(echo | openssl s_client -connect localhost:443 -servername localhost 2>&1 | grep "Cipher" | head -1)
if [[ -n "${CIPHER}" ]]; then
  print_success "${CIPHER}"
else
  print_warning "No se pudo determinar el cifrado"
fi

echo
print_success "Pruebas HTTPS de Apache completadas"
