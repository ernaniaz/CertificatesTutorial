#!/usr/bin/env bash
#=============================================================================
# Lab 22: Limpieza
# Detiene Vault y elimina todos los archivos del lab
#
# Uso: ./cleanup.sh
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

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Keep Vault flag
KEEP_VAULT=false
if [[ "${1:-}" == "--keep-vault" ]]; then
  KEEP_VAULT=true
fi

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

print_header "Lab 22: Limpieza"

# --- Paso 1: Confirmar limpieza con el usuario ---
print_step "Confirmando limpieza"

print_warning "Esto detendrá Vault y eliminará todos los archivos del lab"
read -p "¿Continuar? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  print_info "Limpieza cancelada"
  exit 0
fi
echo

# --- Paso 2: Detener proceso de Vault ---
print_step "Deteniendo Vault"

if [[ -f "${SCRIPT_DIR}/vault-env.sh" ]]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/vault-env.sh"
fi

if [[ -n "${VAULT_PID:-}" ]] && kill -0 "${VAULT_PID}" 2>/dev/null; then
  kill "${VAULT_PID}" || true
  sleep 2
  print_success "Vault detenido (PID ${VAULT_PID})"
elif pgrep -x vault > /dev/null; then
  pkill vault || true
  sleep 2
  if pgrep -x vault > /dev/null; then
    pkill -9 vault || true
  fi
  print_success "Vault detenido"
else
  print_info "Vault no en ejecución"
fi
echo

# --- Paso 3: Eliminar archivos de certificados ---
print_step "Eliminando archivos de certificados"

if [[ -d "${SCRIPT_DIR}/certs" ]]; then
  rm -rf "${SCRIPT_DIR}/certs"
  print_success "Directorio de certificados eliminado"
fi

rm -f "${SCRIPT_DIR}/root-ca.crt"
rm -f "${SCRIPT_DIR}/intermediate.csr"
rm -f "${SCRIPT_DIR}/intermediate.crt"
rm -f "${SCRIPT_DIR}/crl.pem"
print_success "Archivos CA y CRL eliminados"
echo

# --- Paso 4: Eliminar archivos de configuración de Vault ---
print_step "Eliminando archivos de configuración de Vault"

rm -f "${SCRIPT_DIR}/vault-env.sh"
rm -f "${SCRIPT_DIR}/vault.log"
print_success "Archivos de configuración eliminados"
echo

# --- Paso 5: Eliminar binario de Vault opcionalmente ---
if [[ ${KEEP_VAULT} == false ]]; then
  print_step "Eliminando binario de Vault"

  if command -v vault &> /dev/null; then
    read -p "¿Eliminar Vault de /usr/local/bin/vault? (s/N): " -n 1 -r
    echo
    if [[ ${REPLY} =~ ^[Ss]$ ]]; then
      sudo rm -f /usr/local/bin/vault
      print_success "Binario de Vault eliminado"
    else
      print_info "Binario de Vault conservado"
    fi
  else
    print_info "Binario de Vault no encontrado"
  fi
  echo
else
  print_info "Conservando binario de Vault (--keep-vault)"
  echo
fi

# --- Paso 6: Mostrar resumen de limpieza ---
print_step "Resumen de limpieza"

print_success "Limpieza completada"
echo "  - Vault detenido"
echo "  - Certificados eliminados"
echo "  - Archivos de configuración eliminados"
if [[ ${KEEP_VAULT} == false ]]; then
  echo "  - Se ofreció eliminar el binario de Vault"
else
  echo "  - Binario de Vault conservado"
fi
echo
print_warning "Nota: en modo dev, todos los datos de Vault estaban en memoria"
print_info "Todos los datos PKI se han perdido (comportamiento esperado)"

echo
echo "Para ejecutar el lab de nuevo:"
echo "  1. ./start-vault-dev.sh"
echo "  2. ./enable-pki.sh"
echo "  3. Continúe con los scripts restantes"
echo
echo "O para comenzar completamente de cero:"
echo "  ./install-vault.sh"
