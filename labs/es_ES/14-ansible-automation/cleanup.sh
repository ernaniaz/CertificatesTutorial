#!/usr/bin/env bash
#=============================================================================
# Lab 14: Limpieza
# Elimina Ansible y las configuraciones del lab
#
# Uso: ./cleanup.sh
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

print_header "Lab 14: Limpieza"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Confirmación
print_warning "Esto deshará todas las tareas del lab: eliminar Apache, Ansible, certificados y configuraciones."
read -p "¿Continuar? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Limpieza cancelada"
  exit 0
fi

echo

# Detener y deshabilitar Apache
print_info "Deteniendo y deshabilitando Apache..."
if systemctl is-active httpd &>/dev/null; then
  systemctl stop httpd
fi
systemctl disable httpd 2>/dev/null || true
print_success "Apache detenido y deshabilitado"

echo

# Eliminar configuración SSL de Apache
print_info "Eliminando configuración SSL de Apache..."
rm -f /etc/httpd/conf.d/ansible-ssl.conf
print_success "Configuración SSL de Apache eliminada"

echo

# Eliminar página de prueba creada por el playbook
print_info "Eliminando página de prueba..."
rm -f /var/www/html/index.html
print_success "Página de prueba eliminada"

echo

# Eliminar certificados desplegados
print_info "Eliminando certificados desplegados..."
rm -f /etc/pki/tls/certs/lab-ansible.crt
rm -f /etc/pki/tls/private/lab-ansible.key
print_success "Certificados eliminados"

echo

# Eliminar paquetes Apache instalados por el playbook
print_info "Eliminando paquetes Apache (httpd, mod_ssl)..."
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum remove -y httpd mod_ssl 2>/dev/null || true
else
  dnf remove -y httpd mod_ssl 2>/dev/null || true
fi
print_success "Paquetes Apache eliminados"

echo

# Eliminar directorio de configuración de Ansible
print_info "Eliminando configuración de Ansible..."
rm -rf /etc/ansible
print_success "Configuración de Ansible eliminada"

echo

# Eliminar archivo de inventario
print_info "Eliminando archivo de inventario..."
rm -f "${SCRIPT_DIR}/inventory.ini"
print_success "Archivo de inventario eliminado"

echo

# Eliminar paquete Ansible
print_info "Eliminando paquete Ansible..."
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum remove -y ansible 2>/dev/null || true
elif [[ ${RHEL_VERSION} -eq 8 ]]; then
  dnf remove -y ansible 2>/dev/null || true
else
  dnf remove -y ansible-core 2>/dev/null || true
fi
print_success "Ansible eliminado"

echo
print_success "Limpieza completada"
echo
echo "Todas las tareas del lab han sido deshechas:"
echo "  - Apache (httpd, mod_ssl) eliminado"
echo "  - Configuración SSL y página de prueba eliminadas"
echo "  - Certificados eliminados"
echo "  - Configuración de Ansible eliminada"
echo "  - Paquete Ansible eliminado"
