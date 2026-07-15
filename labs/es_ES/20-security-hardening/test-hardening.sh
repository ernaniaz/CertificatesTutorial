#!/usr/bin/env bash
#=============================================================================
# Lab 20: Probar endurecimiento
# Prueba las medidas de seguridad aplicadas
#
# Uso: ./test-hardening.sh
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

print_header "Lab 20: Pruebas de endurecimiento de seguridad"

# Probar Apache si está en ejecución
if systemctl is-active httpd &>/dev/null; then
  print_info "Probando HTTPS de Apache..."

  # Verificar encabezado HSTS
  if curl -k -I https://localhost/ 2>/dev/null | grep -qi "strict-transport-security"; then
    echo -e "  ${GREEN}✓ Encabezado HSTS presente${NC}"
  else
    echo -e "  ${YELLOW}⚠ Encabezado HSTS no encontrado${NC}"
  fi

  # Verificar X-Frame-Options
  if curl -k -I https://localhost/ 2>/dev/null | grep -qi "x-frame-options"; then
    echo -e "  ${GREEN}✓ X-Frame-Options presente${NC}"
  else
    echo -e "  ${YELLOW}⚠ X-Frame-Options no encontrado${NC}"
  fi

  # Probar TLS 1.0 (debería fallar)
  if echo | openssl s_client -connect localhost:443 -tls1 2>&1 | grep -q "Cipher.*is.*none"; then
    echo -e "  ${GREEN}✓ TLS 1.0 bloqueado${NC}"
  else
    echo -e "  ${YELLOW}⚠ TLS 1.0 puede estar permitido${NC}"
  fi

  echo
fi

# Probar NGINX si está en ejecución
if systemctl is-active nginx &>/dev/null; then
  print_info "Probando HTTPS de NGINX..."

  # Verificar encabezados
  if curl -k -I https://localhost/ 2>/dev/null | grep -qi "strict-transport-security"; then
    echo -e "  ${GREEN}✓ Encabezado HSTS presente${NC}"
  else
    echo -e "  ${YELLOW}⚠ Encabezado HSTS no encontrado${NC}"
  fi

  echo
fi

# Probar cifras disponibles
print_info "Probando fortaleza de cifras..."
CIPHER_COUNT="$(openssl ciphers -v 2>/dev/null | wc -l)"
echo "  Cifras disponibles: ${CIPHER_COUNT}"

# Verificar cifras débiles
WEAK="$(openssl ciphers -v 2>/dev/null | grep -iE "DES|RC4|MD5|NULL|EXPORT" | wc -l)"
if [[ ${WEAK} -eq 0 ]]; then
  echo -e "  ${GREEN}✓ No se detectaron cifras débiles${NC}"
else
  echo -e "  ${YELLOW}⚠ ${WEAK} cifras débiles disponibles${NC}"
fi

echo
print_success "Pruebas de seguridad completadas"
echo
echo "Para pruebas exhaustivas, use:"
echo "  https://www.ssllabs.com/ssltest/ (para sitios públicos)"
echo "  testssl.sh localhost:443 (herramienta de línea de comandos)"
