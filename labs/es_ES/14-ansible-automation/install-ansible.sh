#!/usr/bin/env bash
#=============================================================================
# Lab 14: Instalar Ansible
# Instala el nodo de control de Ansible
#
# Uso: ./install-ansible.sh
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

print_header "Lab 14: Instalación de Ansible"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

# Detectar versión de RHEL
echo "Versión de RHEL: ${RHEL_VERSION}"
echo

# Instalar Ansible
print_info "Instalando Ansible..."

if [[ ${RHEL_VERSION} -eq 7 || ${RHEL_VERSION} -eq 8 ]]; then
  # RHEL 7 y 8: paquete ansible
  if [[ ${RHEL_VERSION} -eq 7 ]]; then
    # Habilitar EPEL para RHEL 7
    if ! rpm -q epel-release &>/dev/null; then
      echo "Instalando repositorio EPEL..."
      yum install -y epel-release
    fi
    yum install -y ansible
  else
    dnf install -y ansible
  fi
else
  # RHEL 9+: ansible-core
  dnf install -y ansible-core
fi

print_success "Ansible instalado"
echo

# Mostrar versión de Ansible
ansible --version | head -1

echo

# Crear directorio de configuración de ansible
if [[ ! -d /etc/ansible ]]; then
  mkdir -p /etc/ansible
  print_success "Directorio /etc/ansible creado"
fi

# Crear ansible.cfg básico si no existe
if [[ ! -f /etc/ansible/ansible.cfg ]]; then
  cat > /etc/ansible/ansible.cfg << 'EOF'
[defaults]
inventory = /etc/ansible/hosts
host_key_checking = False
retry_files_enabled = False

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False
EOF
  print_success "ansible.cfg creado"
fi

echo
print_success "Instalación de Ansible completada"
echo
echo "Comandos de Ansible:"
echo "  ansible --version"
echo "  ansible all -m ping"
echo "  ansible-playbook playbook-apache.yml"
echo "  ansible-galaxy list"
