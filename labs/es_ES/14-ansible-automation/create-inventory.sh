#!/usr/bin/env bash
#=============================================================================
# Lab 14: Crear inventario
# Configura el inventario de Ansible para el lab
#
# Uso: ./create-inventory.sh
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_header "Lab 14: Crear inventario de Ansible"

# Crear archivo de inventario
print_info "Creando archivo de inventario..."

cat > "${SCRIPT_DIR}/inventory.ini" << 'EOF'
# Lab 14: Inventario de automatización de certificados con Ansible

[control]
localhost ansible_connection=local

[webservers]
localhost ansible_connection=local

[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_user=root
EOF

print_success "Archivo de inventario creado"
echo

# Mostrar inventario
echo "Contenido del archivo de inventario:"
cat "${SCRIPT_DIR}/inventory.ini"

echo

# Probar inventario
print_info "Probando inventario..."
if command -v ansible &>/dev/null; then
  if ! ansible all -i "${SCRIPT_DIR}/inventory.ini" -m ping; then
    echo -e "${YELLOW}Prueba ping falló (puede requerir configuración SSH)${NC}"
  fi
else
  echo "Instale Ansible primero para probar el inventario"
fi

echo
print_success "Creación de inventario completada"
echo
echo "Archivo de inventario: ${SCRIPT_DIR}/inventory.ini"
echo
echo "Uso:"
echo "  ansible all -i inventory.ini -m ping"
echo "  ansible-playbook -i inventory.ini playbook-apache.yml"
