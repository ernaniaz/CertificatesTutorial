#!/usr/bin/env bash
#=============================================================================
# Lab 06: Limpieza
# Elimina Apache y restaura el sistema
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

print_header "Lab 06: Limpieza"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

echo "Esto hará:"
echo "  - Detener Apache"
echo "  - Eliminar paquetes de Apache"
echo "  - Eliminar configuración SSL"
echo "  - Eliminar certificados del sistema"
echo
read -p "¿Continuar con la limpieza? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Limpieza cancelada."
  exit 0
fi

# Detener Apache
echo
echo "Deteniendo Apache..."
systemctl stop httpd || true
systemctl disable httpd || true

# Eliminar paquetes
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum remove -y httpd mod_ssl || true
else
  dnf remove -y httpd mod_ssl || true
fi

# Eliminar configuración
if [[ -f /etc/httpd/conf.d/lab-ssl.conf ]]; then
  rm -f /etc/httpd/conf.d/lab-ssl.conf
  print_success "Configuración SSL eliminada"
fi

# Eliminar certificados
rm -f /etc/pki/tls/certs/lab-server.crt
rm -f /etc/pki/tls/private/lab-server.key

# Eliminar reglas del firewall
if command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null; then
  firewall-cmd --permanent --remove-service=http 2>/dev/null || true
  firewall-cmd --permanent --remove-service=https 2>/dev/null || true
  firewall-cmd --reload
  print_success "Reglas del firewall eliminadas"
fi

echo
print_success "Limpieza completada"
