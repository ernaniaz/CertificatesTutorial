#!/usr/bin/env bash
#=============================================================================
# Lab 19: Deshabilitar FIPS
# Deshabilita el modo FIPS (si es necesario)
#
# Uso: ./disable-fips.sh
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

print_header "Lab 19: Deshabilitar modo FIPS"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: este script debe ejecutarse como root (use sudo)"
  exit 1
fi

if [[ ${RHEL_VERSION} -ge 10 ]]; then
  print_error "RHEL 10+ no permite deshabilitar FIPS después de la instalación."
  echo
  echo "En RHEL 10, el modo FIPS se establece en la instalación y no puede"
  echo "cambiarse después. Se requiere una reinstalación sin el parámetro"
  echo "de kernel fips=1 para ejecutar sin FIPS."
  echo
  echo "Estado actual de FIPS:"
  fips-mode-setup --check 2>/dev/null || cat /proc/sys/crypto/fips_enabled
  exit 1
fi

print_warning "ADVERTENCIA: deshabilitar modo FIPS"
echo
echo "Esto solo debe hacerse si:"
echo "  - No se requiere cumplimiento FIPS"
echo "  - Entorno de prueba/laboratorio"
echo "  - Solución de problemas FIPS"
echo

read -p "¿Deshabilitar modo FIPS? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Operación cancelada"
  exit 0
fi

echo

# Verificar si FIPS está habilitado
if [[ ! -f /proc/sys/crypto/fips_enabled || "$(cat /proc/sys/crypto/fips_enabled)" != "1" ]]; then
  print_success "Modo FIPS ya deshabilitado"
  exit 0
fi

# Deshabilitar FIPS
print_info "Deshabilitando modo FIPS..."

if command -v fips-mode-setup &>/dev/null; then
  fips-mode-setup --disable
  print_success "Modo FIPS deshabilitado"
else
  print_error "Comando fips-mode-setup no encontrado"
  exit 1
fi

echo
print_error "⚠ REINICIO REQUERIDO"
echo
echo "Después del reinicio, el modo FIPS estará deshabilitado"
echo
echo "Para reiniciar ahora:"
echo "  sudo reboot"
