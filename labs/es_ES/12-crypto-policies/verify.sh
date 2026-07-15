#!/usr/bin/env bash
#=============================================================================
# Lab 12: Verificar
# Pasos de verificación
#
# Uso: ./verify.sh
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

print_header "Lab 12: Verificación de crypto-policy"

# Comprobar versión de RHEL
echo "Versión de RHEL: ${RHEL_VERSION}"

if [[ ${RHEL_VERSION} -lt 8 ]]; then
  echo "Nota: crypto-policies requiere RHEL 8+"
  exit 0
fi

echo

print_info "1. Política actual:"
POLICY="$(update-crypto-policies --show 2>/dev/null)"
echo "  ${POLICY}"

echo

print_info "2. Archivo de configuración:"
if [[ -f /etc/crypto-policies/config ]]; then
  echo "  Contenido: $(cat /etc/crypto-policies/config)"
else
  echo "  No encontrado"
fi

echo

print_info "3. Políticas disponibles:"
if ! ls -1 /usr/share/crypto-policies/policies/*.pol 2>/dev/null | sed 's|.*/||;s|\.pol$||' | sed 's/^/  /'; then
  echo "  Ninguno encontrado"
fi

echo

print_info "4. Configuraciones de backend:"
if ! ls -1 /etc/crypto-policies/back-ends/ 2>/dev/null | sed 's/^/  /'; then
  echo "  Ninguno encontrado"
fi

echo

print_info "5. Cantidad de cifrados OpenSSL:"
CIPHER_COUNT="$(openssl ciphers -v 2>/dev/null | wc -l)"
echo "  ${CIPHER_COUNT} cifrados"

echo

print_info "6. Cifrados SSH disponibles:"
if command -v ssh &>/dev/null; then
  SSH_COUNT="$(ssh -Q cipher 2>/dev/null | wc -l)"
  echo "  ${SSH_COUNT} cifrados SSH"
else
  echo "  SSH no instalado"
fi

echo
print_success "Verificación completada"
