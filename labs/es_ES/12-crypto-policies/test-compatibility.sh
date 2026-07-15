#!/usr/bin/env bash
#=============================================================================
# Lab 12: Probar compatibilidad
# Prueba el comportamiento del sistema bajo la política actual
#
# Uso: ./test-compatibility.sh
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

print_header "Lab 12: Probar compatibilidad"

# Obtener política actual
CURRENT_POLICY="$(update-crypto-policies --show 2>/dev/null || echo "UNKNOWN")"
echo "Probando bajo la política: ${CURRENT_POLICY}"
echo

# Probar cifrados OpenSSL
print_info "1. Cifrados OpenSSL:"
echo "Cantidad de cifrados disponibles:"
CIPHER_COUNT="$(openssl ciphers -v 2>/dev/null | wc -l)"
echo "  ${CIPHER_COUNT} cifrados disponibles"
echo
echo "Cifrados de muestra (primeros 10):"
openssl ciphers -v 2>/dev/null | head -10 | sed 's/^/  /'

echo

# Probar versiones TLS
print_info "2. Versiones TLS/SSL:"
echo "Comprobando qué versiones TLS/SSL están disponibles..."

# Probar TLS 1.0
if echo | openssl s_client -connect www.google.com:443 -tls1 2>/dev/null | grep -q "Protocol.*TLSv1$"; then
  echo -e "  ${GREEN}✓ TLS 1.0 disponible${NC}"
else
  echo "  ✗ TLS 1.0 no disponible"
fi

# Probar TLS 1.1
if echo | openssl s_client -connect www.google.com:443 -tls1_1 2>/dev/null | grep -q "Protocol.*TLSv1.1"; then
  echo -e "  ${GREEN}✓ TLS 1.1 disponible${NC}"
else
  echo "  ✗ TLS 1.1 no disponible"
fi

# Probar TLS 1.2
if echo | openssl s_client -connect www.google.com:443 -tls1_2 2>&1 | grep -q "Protocol.*TLSv1.2"; then
  echo -e "  ${GREEN}✓ TLS 1.2 disponible${NC}"
else
  echo "  ✗ TLS 1.2 no disponible"
fi

# Probar TLS 1.3
if echo | openssl s_client -connect www.google.com:443 -tls1_3 2>&1 | grep -q "Protocol.*TLSv1.3"; then
  echo -e "  ${GREEN}✓ TLS 1.3 disponible${NC}"
else
  echo "  ✗ TLS 1.3 no disponible"
fi

echo

# Probar cifrados SSH
print_info "3. Cifrados SSH:"
if command -v ssh &>/dev/null; then
  SSH_CIPHER_COUNT="$(ssh -Q cipher 2>/dev/null | wc -l)"
  echo "Cifrados SSH disponibles: ${SSH_CIPHER_COUNT}"
  echo "Cifrados SSH de muestra (primeros 5):"
  ssh -Q cipher 2>/dev/null | head -5 | sed 's/^/  /'
else
  echo "SSH no disponible para pruebas"
fi

echo

# Mostrar configuraciones de backend
print_info "4. Configuraciones de backend:"
echo "Configuración OpenSSL:"
if [[ -f /etc/crypto-policies/back-ends/opensslcnf.config ]]; then
  head -5 /etc/crypto-policies/back-ends/opensslcnf.config 2>/dev/null | sed 's/^/  /'
else
  echo "  No encontrado"
fi

echo
echo "Configuración OpenSSH:"
if [[ -f /etc/crypto-policies/back-ends/openssh.config ]]; then
  cat /etc/crypto-policies/back-ends/openssh.config 2>/dev/null | sed 's/^/  /'
else
  echo "  No encontrado"
fi

echo
print_success "Pruebas de compatibilidad completadas"
echo
echo "Política actual: ${CURRENT_POLICY}"
echo
echo "Comparación de políticas:"
echo "  LEGACY: Máxima compatibilidad, menor seguridad"
echo "  DEFAULT: Equilibrada"
echo "  FUTURE: Máxima seguridad, puede romper clientes antiguos"
