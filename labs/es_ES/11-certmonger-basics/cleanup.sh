#!/usr/bin/env bash
#=============================================================================
# Lab 11: Limpieza
# Elimina certmonger y los certificados en seguimiento
#
# Uso: ./cleanup.sh
# Requisitos previos: RHEL 7, 8, 9, 10, privilegios de root
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

print_header "Lab 11: Limpieza"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

# Confirmación
print_warning "Esto eliminará certmonger y todos los certificados en seguimiento."
read -p "¿Continuar? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Limpieza cancelada"
  exit 0
fi

echo

# Detener seguimiento de todos los certificados
print_info "Deteniendo el seguimiento de todos los certificados..."
REQUEST_IDS="$(getcert list 2>/dev/null | grep "Request ID" | awk '{print $3}' | tr -d "':" || echo)"

if [[ -n "${REQUEST_IDS}" ]]; then
  for REQ_ID in ${REQUEST_IDS}; do
    echo "Deteniendo seguimiento: ${REQ_ID}"
    getcert stop-tracking -i "${REQ_ID}" 2>/dev/null || true
  done
  print_success "Seguimiento de certificados detenido"
else
  echo "No hay certificados en seguimiento"
fi

echo

# Detener certmonger
if systemctl is-active certmonger &>/dev/null; then
  print_info "Deteniendo certmonger..."
  systemctl stop certmonger
  systemctl disable certmonger
  print_success "certmonger detenido"
fi

echo

# Eliminar paquete certmonger
print_info "Eliminando paquete certmonger..."

if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum remove -y certmonger
else
  dnf remove -y certmonger
fi

print_success "certmonger eliminado"
echo

# Eliminar archivos de certificados
print_info "Eliminando archivos de certificados..."
if [[ -d /etc/pki/certmonger ]]; then
  rm -rf /etc/pki/certmonger
  print_success "Archivos de certificados eliminados"
fi

echo
print_success "Limpieza completada"
echo
echo "Sistema restaurado al estado previo al lab."
