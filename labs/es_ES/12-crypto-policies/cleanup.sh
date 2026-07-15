#!/usr/bin/env bash
#=============================================================================
# Lab 12: Limpieza
# Restaura la crypto-policy DEFAULT
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

print_header "Lab 12: Limpieza"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

# Comprobar versión de RHEL
if [[ ${RHEL_VERSION} -lt 8 ]]; then
  echo "crypto-policies no aplica a RHEL ${RHEL_VERSION}"
  exit 0
fi

# Obtener política actual
CURRENT_POLICY="$(update-crypto-policies --show 2>/dev/null)"
echo "Política actual: ${CURRENT_POLICY}"

if [[ ${CURRENT_POLICY} == DEFAULT ]]; then
  print_success "Ya se usa la política DEFAULT"
  echo "No se requiere limpieza"
  exit 0
fi

echo
print_info "Restaurando política DEFAULT..."

# Restaurar DEFAULT
if update-crypto-policies --set DEFAULT; then
  print_success "Política restaurada a DEFAULT"
else
  print_error "No se pudo restaurar la política DEFAULT"
  exit 1
fi

echo

# Reiniciar servicios
print_info "Reiniciando servicios afectados..."
SERVICES="sshd httpd nginx postfix"
for service in ${SERVICES}; do
  if systemctl is-active "${service}" &>/dev/null; then
    echo "  Reiniciando ${service}..."
    if ! systemctl restart "${service}" 2>/dev/null; then
      echo "    (falló el reinicio o no está instalado)"
    fi
  fi
done

echo
print_success "Limpieza completada"
echo
echo "Sistema restaurado a la crypto-policy DEFAULT"
