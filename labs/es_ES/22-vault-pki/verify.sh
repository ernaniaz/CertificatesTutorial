#!/usr/bin/env bash
#=============================================================================
# Lab 22: Verificar
# Valida que todos los componentes del lab estén configurados correctamente
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

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Counters
PASS=0
FAIL=0

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

print_header "Lab 22: Verificación"

# --- Paso 1: Cargar detalles de conexión de Vault ---
print_step "Cargando entorno de Vault"

if [[ -f "${SCRIPT_DIR}/vault-env.sh" ]]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/vault-env.sh"
  print_success "Entorno cargado desde vault-env.sh"
else
  export VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
  export VAULT_TOKEN="${VAULT_TOKEN:-root}"
  print_warning "vault-env.sh no encontrado — usando valores predeterminados"
fi
echo

# --- Paso 2: Ejecutar pruebas de verificación ---
print_step "Ejecutando pruebas de verificación"

if pgrep -x vault &> /dev/null; then
  print_success "APROBADO: Vault en ejecución"
  PASS=$((PASS + 1))
else
  print_error "FALLÓ: Vault en ejecución"
  FAIL=$((FAIL + 1))
fi

if vault status &> /dev/null; then
  print_success "APROBADO: Vault accesible y desbloqueado"
  PASS=$((PASS + 1))
else
  print_error "FALLÓ: Vault accesible y desbloqueado"
  FAIL=$((FAIL + 1))
fi

if vault secrets list | grep -q '^pki/'; then
  print_success "APROBADO: motor de secretos PKI habilitado"
  PASS=$((PASS + 1))
else
  print_error "FALLÓ: motor de secretos PKI habilitado"
  FAIL=$((FAIL + 1))
fi

if vault read pki/cert/ca &> /dev/null; then
  print_success "APROBADO: CA raíz existe"
  PASS=$((PASS + 1))
else
  print_error "FALLÓ: CA raíz existe"
  FAIL=$((FAIL + 1))
fi

if vault read pki_int/cert/ca &> /dev/null; then
  print_success "APROBADO: CA intermedia existe"
  PASS=$((PASS + 1))
else
  print_error "FALLÓ: CA intermedia existe"
  FAIL=$((FAIL + 1))
fi

if vault read pki_int/roles/web-server &> /dev/null; then
  print_success "APROBADO: rol PKI 'web-server' existe"
  PASS=$((PASS + 1))
else
  print_error "FALLÓ: rol PKI 'web-server' existe"
  FAIL=$((FAIL + 1))
fi

if [[ -n "$(find "${SCRIPT_DIR}/certs" -maxdepth 1 -name '*.crt' ! -name '*-chain.crt' ! -name '*-ca.crt' 2>/dev/null)" ]]; then
  print_success "APROBADO: certificados emitidos"
  PASS=$((PASS + 1))
else
  print_error "FALLÓ: certificados emitidos"
  FAIL=$((FAIL + 1))
fi

echo

# --- Paso 3: Mostrar resumen de aprobados/fallidos ---
print_step "Resumen de verificación"

echo
echo "Aprobados: ${PASS}"
echo "Fallidos: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "¡Todas las validaciones pasaron!"
  print_success "Lab 22 completado exitosamente."
  echo
  echo "Ha completado exitosamente:"
  echo "  - Instaló HashiCorp Vault"
  echo "  - Configuró motor de secretos PKI"
  echo "  - Creó jerarquía de CA raíz e intermedia"
  echo "  - Creó roles PKI y emitió certificados dinámicos"
  echo "  - Comprendió la revocación de certificados"
  exit 0
else
  print_error "Algunas validaciones fallaron."
  echo
  echo "Solución de problemas:"
  echo "  - Verifique que Vault esté en ejecución: vault status"
  echo "  - Verifique registros de Vault: cat vault.log"
  echo "  - Verifique entorno: source vault-env.sh"
  echo "  - Vuelva a ejecutar los scripts del lab que fallaron"
  exit 1
fi
