#!/usr/bin/env bash
#=============================================================================
# Lab 07: Probar conexión
# Prueba la conectividad HTTP y HTTPS
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

print_header "Lab 07: Probando NGINX HTTPS"

# Probar HTTP (debe redirigir a HTTPS)
print_info "Probando HTTP (puerto 80)..."
if curl -s -I http://localhost/ | grep -q "301\|302"; then
  print_success "HTTP redirige a HTTPS"
else
  HTTP_RESPONSE="$(curl -s http://localhost/)"
  if echo "${HTTP_RESPONSE}" | grep -q "Lab 07"; then
    print_warning "HTTP funciona pero no hay redirección configurada"
  else
    print_error "Prueba HTTP fallida"
  fi
fi

echo

# Probar HTTPS
print_info "Probando HTTPS (puerto 443)..."
if curl -k -s https://localhost/ | grep -q "Lab 07"; then
  print_success "HTTPS responde correctamente"
else
  print_error "Prueba HTTPS fallida"
  exit 1
fi

echo

# Probar certificado
print_info "Probando certificado..."
CERT_INFO="$(echo | openssl s_client -connect localhost:443 -servername localhost 2>&1)"

if echo "${CERT_INFO}" | grep -q "Verify return code"; then
  print_success "Handshake TLS exitoso"

  # Extraer subject del certificado
  SUBJECT=$(echo "${CERT_INFO}" | grep "subject=" | head -1)
  echo "  ${SUBJECT}"

  # Extraer versión TLS
  TLS_VERSION=$(echo "${CERT_INFO}" | grep "Protocol" | head -1)
  if [[ -n "${TLS_VERSION}" ]]; then
    echo "  ${TLS_VERSION}"
  fi

  # Extraer cifrado
  CIPHER=$(echo "${CERT_INFO}" | grep "Cipher" | head -1)
  if [[ -n "${CIPHER}" ]]; then
    echo "  ${CIPHER}"
  fi
else
  print_error "Prueba de certificado fallida"
  exit 1
fi

echo

# Probar con curl verbose
print_info "Probando detalles TLS..."
TLS_INFO="$(curl -kvs https://localhost/ 2>&1)"

if echo "${TLS_INFO}" | grep -q "SSL connection using"; then
  SSL_LINE=$(echo "${TLS_INFO}" | grep "SSL connection using")
  print_success "${SSL_LINE}"
fi

echo
print_success "Todas las pruebas de conexión pasaron"
echo
echo "Pruebe estos tests manuales:"
echo "  curl -v https://localhost/"
echo "  openssl s_client -connect localhost:443 -servername localhost < /dev/null"
