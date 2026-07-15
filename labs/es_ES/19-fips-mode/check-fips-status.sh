#!/usr/bin/env bash
#=============================================================================
# Lab 19: Comprobar estado FIPS
# Verifica si el modo FIPS está habilitado
#
# Uso: ./check-fips-status.sh
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

print_header "Lab 19: Estado del modo FIPS"

# Verificar modo FIPS
print_info "1. Estado del modo FIPS:"
if [[ -f /proc/sys/crypto/fips_enabled ]]; then
  FIPS_ENABLED="$(cat /proc/sys/crypto/fips_enabled)"
  if [[ ${FIPS_ENABLED} -eq 1 ]]; then
    echo -e "  ${GREEN}✓ El modo FIPS está HABILITADO${NC}"
  else
    echo -e "  ${YELLOW}⚠ El modo FIPS está DESHABILITADO${NC}"
  fi
else
  echo "  Archivo de estado FIPS no encontrado"
fi

echo

# Verificar comando fips-mode-setup
print_info "2. Estado de fips-mode-setup:"
if command -v fips-mode-setup &>/dev/null; then
  fips-mode-setup --check
  else
  echo "  Comando fips-mode-setup no encontrado"
fi

echo

# Verificar línea de comandos del kernel
print_info "3. Línea de comandos del kernel:"
if grep -q "fips=1" /proc/cmdline; then
  echo -e "  ${GREEN}✓ fips=1 en los parámetros del kernel${NC}"
  else
  echo "  fips=1 no está en los parámetros del kernel"
fi

echo

# Verificar crypto-policy
print_info "4. Crypto-Policy:"
POLICY="$(update-crypto-policies --show 2>/dev/null)"
echo "  Actual: ${POLICY}"

if [[ ${POLICY} == FIPS ]]; then
  echo -e "  ${GREEN}✓ Usando política FIPS${NC}"
elif [[ ${FIPS_ENABLED} -eq 1 ]]; then
  echo -e "  ${YELLOW}⚠ FIPS habilitado pero sin política FIPS${NC}"
fi

echo

# Estado FIPS de OpenSSL
print_info "5. Estado FIPS de OpenSSL:"
if openssl list -providers 2>/dev/null | grep -q "fips"; then
  echo -e "  ${GREEN}✓ Proveedor FIPS disponible${NC}"
else
  echo "  Proveedor FIPS no detectado"
fi

echo
echo "======================================="

if [[ ${FIPS_ENABLED:-0} -eq 1 ]]; then
  print_success "El sistema está ejecutándose en modo FIPS"
else
  print_warning "El sistema NO está en modo FIPS"
  echo
  echo "Para habilitar el modo FIPS:"
  echo "  sudo ./enable-fips.sh"
fi
