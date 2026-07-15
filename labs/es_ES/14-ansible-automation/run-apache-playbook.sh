#!/usr/bin/env bash
#=============================================================================
# Lab 14: Ejecutar playbook de Apache
# Ejecuta el playbook de Ansible para Apache SSL
#
# Uso: ./run-apache-playbook.sh
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

print_header "Lab 14: Ejecutar playbook de Apache"

# Comprobar requisitos previos
if ! command -v ansible-playbook &>/dev/null; then
  print_error "Error: ansible-playbook no encontrado"
  echo "Ejecute ./install-ansible.sh primero"
  exit 1
fi

if [[ ! -f "${SCRIPT_DIR}/inventory.ini" ]]; then
  print_error "Error: inventory.ini no encontrado"
  echo "Ejecute ./create-inventory.sh primero"
  exit 1
fi

if [[ ! -f "${SCRIPT_DIR}/playbook-apache.yml" ]]; then
  print_error "Error: playbook-apache.yml no encontrado"
  exit 1
fi

# Ejecutar playbook
print_info "Ejecutando playbook SSL de Apache..."
echo

if ansible-playbook -i "${SCRIPT_DIR}/inventory.ini" "${SCRIPT_DIR}/playbook-apache.yml"; then
  echo
  print_success "Playbook ejecutado correctamente"
else
  echo
  print_error "Falló la ejecución del playbook"
  exit 1
fi

echo
print_success "Despliegue SSL de Apache completado"
echo
echo "Verificar con:"
echo "  curl -k https://localhost/"
echo "  openssl s_client -connect localhost:443"
echo "  systemctl status httpd"
