#!/usr/bin/env bash
#=============================================================================
# Lab 22: Habilitar PKI
# Habilita y configura el motor de secretos PKI
#
# Uso: ./enable-pki.sh
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

print_header "Lab 22: Habilitar motor de secretos PKI"

# --- Paso 1: Cargar detalles de conexión de Vault ---
print_step "Cargando entorno de Vault"

if [[ -f "${SCRIPT_DIR}/vault-env.sh" ]]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/vault-env.sh"
  print_success "Entorno cargado desde vault-env.sh"
else
  print_warning "vault-env.sh no encontrado — usando valores predeterminados"
  export VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
  export VAULT_TOKEN="${VAULT_TOKEN:-root}"
fi
echo

# --- Paso 2: Verificar que Vault esté en ejecución y desbloqueado ---
print_step "Verificando estado de Vault"

if ! command -v vault &> /dev/null; then
  error_exit "Vault no encontrado. Ejecute ./install-vault.sh primero"
fi

if ! vault status &> /dev/null; then
  error_exit "Vault no está en ejecución. Ejecute ./start-vault-dev.sh primero"
fi

print_success "Vault en ejecución y accesible"
echo

# --- Paso 3: Habilitar motor de secretos PKI ---
print_step "Habilitando motor de secretos PKI"

if vault secrets list | grep -q "^pki/"; then
  print_warning "Motor de secretos PKI ya habilitado"
else
  if ! vault secrets enable pki; then
    error_exit "Error al habilitar motor de secretos PKI"
  fi
  print_success "Motor de secretos PKI habilitado en: pki/"
fi
echo

# --- Paso 4: Configurar TTL máximo de lease ---
print_step "Configurando TTL máximo de lease"

# Root CA certificates need a long TTL to avoid frequent re-issuance in labs
if ! vault secrets tune -max-lease-ttl=87600h pki; then
  error_exit "Error al ajustar TTL máximo de lease PKI"
fi

print_success "TTL máximo de lease configurado en: 87600h (10 años)"
echo

print_success "Motor de secretos PKI listo"
echo

# --- Paso 5: Mostrar información del motor PKI ---
print_step "Información del motor de secretos PKI"

print_info "Motores de secretos habilitados:"
vault secrets list | grep -E "Path|pki"
echo
print_info "Configuración del mount PKI:"
vault read sys/mounts/pki

echo
echo "Próximos pasos:"
echo "  - Ejecute './configure-root-ca.sh' para crear CA raíz"
echo "  - Ejecute 'vault read pki/config' para ver configuración"
