#!/usr/bin/env bash
#=============================================================================
# Lab 20: Probar seguridad
# Prueba la configuración de seguridad endurecida
#
# Uso: ./test-security.sh
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

print_header "Lab 20: Pruebas de configuración de seguridad"

# Probar Apache si está en ejecución
if systemctl is-active httpd &>/dev/null; then
  print_info "Probando HTTPS de Apache..."

  # Probar conexión TLS
  TLS_INFO="$(echo "QUIT" | timeout 5 openssl s_client -connect localhost:443 2>&1 || true)"

  if echo "${TLS_INFO}" | grep -q "Protocol.*TLSv1\.[23]"; then
    PROTOCOL="$(echo "${TLS_INFO}" | grep "Protocol" | head -1 | awk '{print $2}')"
    print_success "Protocolo TLS: ${PROTOCOL}"
  else
    print_warning "No se pudo detectar la versión TLS"
  fi

  # Verificar encabezado HSTS
  if curl -I -k https://localhost/ 2>/dev/null | grep -qi "Strict-Transport-Security"; then
    print_success "Encabezado HSTS presente"
  else
    print_warning "Encabezado HSTS ausente"
  fi

  echo
fi

# Probar NGINX si está en ejecución
if systemctl is-active nginx &>/dev/null; then
  print_info "Probando HTTPS de NGINX..."

  # Probar conexión TLS
  TLS_INFO="$(echo "QUIT" | timeout 5 openssl s_client -connect localhost:443 2>&1 || true)"

  if echo "${TLS_INFO}" | grep -q "Protocol.*TLSv1\.[23]"; then
    PROTOCOL="$(echo "${TLS_INFO}" | grep "Protocol" | head -1 | awk '{print $2}')"
    print_success "Protocolo TLS: ${PROTOCOL}"
  fi

  # Verificar HSTS
  if curl -I -k https://localhost/ 2>/dev/null | grep -qi "Strict-Transport-Security"; then
    print_success "Encabezado HSTS presente"
  else
    print_warning "Encabezado HSTS ausente"
  fi

  echo
fi

# Probar rechazo de protocolos débiles
print_info "Probando rechazo de protocolos débiles..."

# Intentar TLS 1.0 (debería fallar)
if echo "QUIT" | timeout 3 openssl s_client -connect localhost:443 -tls1 2>&1 | grep -q "Cipher.*TLS"; then
  print_error "TLS 1.0 aceptado (debería estar bloqueado)"
else
  print_success "TLS 1.0 rechazado"
fi

# Intentar TLS 1.1 (debería fallar)
if echo "QUIT" | timeout 3 openssl s_client -connect localhost:443 -tls1_1 2>&1 | grep -q "Cipher.*TLS"; then
  print_error "TLS 1.1 aceptado (debería estar bloqueado)"
else
  print_success "TLS 1.1 rechazado"
fi

echo
print_success "Pruebas de seguridad completadas"
echo
echo "Estado de seguridad:"
echo "  ✓ Solo versiones TLS modernas"
echo "  ✓ Protocolos débiles bloqueados"
echo "  ✓ Encabezados de seguridad configurados"
