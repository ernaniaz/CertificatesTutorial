#!/usr/bin/env bash
#=============================================================================
# Lab 19: Habilitar FIPS
# Script para habilitar FIPS del Lab 19
#
# Uso: ./enable-fips.sh
# Requisitos previos: RHEL 8, 9, 10, privilegios de root
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

print_header "Lab 19: Habilitar modo FIPS"

if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: este script debe ejecutarse como root"
  exit 1
fi

if [[ ${RHEL_VERSION} -ge 10 ]]; then
  print_error "RHEL 10+ no permite habilitar FIPS después de la instalación."
  echo
  echo "En RHEL 10, el modo FIPS debe habilitarse durante la instalación del SO."
  echo "Para reinstalar con FIPS habilitado, agregue el siguiente parámetro de kernel"
  echo "en la línea de comandos de arranque del instalador:"
  echo "  fips=1"
  echo
  echo "O seleccione la opción FIPS en la política de seguridad del instalador Anaconda."
  echo
  echo "Para verificar el estado actual de FIPS:"
  echo "  fips-mode-setup --check"
  exit 1
fi

print_warning "ADVERTENCIA: habilitar modo FIPS:"
echo "  - Requerirá reiniciar el sistema"
echo "  - Bloqueará algoritmos no FIPS"
echo "  - Puede afectar algunas aplicaciones"
echo

read -p "¿Continuar? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Cancelado"
  exit 0
fi

echo
print_info "Habilitando modo FIPS..."

if command -v fips-mode-setup &>/dev/null; then
  fips-mode-setup --enable
  echo
  print_success "El modo FIPS se habilitará después del reinicio"
  echo
  read -p "¿Reiniciar ahora? (s/N): " -n 1 -r
  echo
  if [[ ${REPLY} =~ ^[Ss]$ ]]; then
    reboot
  fi
else
  print_error "fips-mode-setup no disponible"
  exit 1
fi
