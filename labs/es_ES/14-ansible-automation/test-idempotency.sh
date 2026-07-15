#!/usr/bin/env bash
#=============================================================================
# Lab 14: Probar idempotencia
# Prueba si los playbooks son idempotentes
#
# Uso: ./test-idempotency.sh
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

print_header "Lab 14: Probar idempotencia"

# Comprobar requisitos previos
if ! command -v ansible-playbook &>/dev/null; then
  print_error "Error: ansible-playbook no encontrado"
  exit 1
fi

if [[ ! -f "${SCRIPT_DIR}/playbook-apache.yml" ]]; then
  print_error "Error: playbook-apache.yml no encontrado"
  exit 1
fi

print_info "Ejecutando playbook por primera vez..."
echo

ansible-playbook -i "${SCRIPT_DIR}/inventory.ini" "${SCRIPT_DIR}/playbook-apache.yml" | tee /tmp/ansible-run1.log

echo
print_info "Ejecutando playbook por segunda vez (no debería haber cambios)..."
echo

ansible-playbook -i "${SCRIPT_DIR}/inventory.ini" "${SCRIPT_DIR}/playbook-apache.yml" | tee /tmp/ansible-run2.log

echo
print_info "Analizando idempotencia..."
echo

# Comprobar tareas modificadas en la segunda ejecución
CHANGED_COUNT="$(grep -c "changed=" /tmp/ansible-run2.log | tail -1 || true)"

if grep -q "changed=0" /tmp/ansible-run2.log; then
  print_success "El playbook es idempotente"
  echo "  La segunda ejecución no hizo cambios"
else
  print_warning "Algunas tareas reportaron cambios en la segunda ejecución"
  echo "  Consulte /tmp/ansible-run2.log para más detalles"
  echo
  echo "Causas comunes:"
  echo "  - Usar 'command' o 'shell' sin 'creates' o 'changed_when'"
  echo "  - Plantillas con contenido dinámico"
  echo "  - Módulos no idempotentes"
fi

echo
print_success "Prueba de idempotencia completada"
echo
echo "Registros:"
echo "  Primera ejecución:  /tmp/ansible-run1.log"
echo "  Segunda ejecución: /tmp/ansible-run2.log"
