#!/usr/bin/env bash
#=============================================================================
# Lab 14: Verificar
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_header "Lab 14: Verificación de Ansible"

print_info "1. Versión de Ansible:"
if command -v ansible &>/dev/null; then
  ansible --version | head -3
else
  echo "Ansible no instalado"
fi

echo

print_info "2. Archivo de inventario:"
if [[ -f "${SCRIPT_DIR}/inventory.ini" ]]; then
  print_success "El inventario existe"
  echo "Archivo: ${SCRIPT_DIR}/inventory.ini"
else
  echo "Inventario no encontrado"
fi

echo

print_info "3. Archivos de playbook:"
for playbook in "${SCRIPT_DIR}"/playbook-*.yml; do
  if [[ -f "${playbook}" ]]; then
    echo "  $(basename "${playbook}")"
  fi
done

echo

print_info "4. Probando conexión del inventario:"
if command -v ansible &>/dev/null && [ -f "${SCRIPT_DIR}/inventory.ini" ]; then
  ansible all -i "${SCRIPT_DIR}/inventory.ini" -m ping 2>&1 | head -10
else
  echo "No se puede probar (falta ansible o inventario)"
fi

echo

print_info "5. Comprobando certificados desplegados:"
if [[ -f /etc/pki/tls/certs/lab-ansible.crt ]]; then
  print_success "Certificado desplegado"
  openssl x509 -in /etc/pki/tls/certs/lab-ansible.crt -noout -subject -dates
else
  echo "Certificado aún no desplegado"
fi

echo

print_info "6. Comprobando configuración de Apache:"
if [[ -f /etc/httpd/conf.d/ansible-ssl.conf ]]; then
  print_success "La configuración SSL de Apache existe"
else
  echo "Configuración SSL de Apache no encontrada"
fi

echo
print_success "Verificación completada"
