#!/usr/bin/env bash
#=============================================================================
# Lab 22: Iniciar Vault en modo dev
# Inicia el servidor Vault en modo de desarrollo
#
# Uso: ./start-vault-dev.sh
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

# Vault configuration
readonly VAULT_ADDR="http://127.0.0.1:8200"

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

print_header "Lab 22: Iniciar Vault (modo dev)"

# --- Paso 1: Verificar que Vault esté instalado ---
print_step "Verificando requisitos previos"

if ! command -v vault &> /dev/null; then
  error_exit "Vault no encontrado. Ejecute ./install-vault.sh primero"
fi

print_success "Vault encontrado: $(vault version | head -n1)"
echo

# --- Paso 2: Verificar proceso existente de Vault ---
print_step "Verificando proceso existente de Vault"

if pgrep -x vault > /dev/null; then
  print_warning "Vault ya está en ejecución"
  print_info "Para detener Vault existente: pkill vault"
  read -p "¿Detener Vault existente e iniciar uno nuevo? (s/N): " -n 1 -r
  echo
  if [[ ${REPLY} =~ ^[Ss]$ ]]; then
    pkill vault || true
    sleep 2
  else
    exit 0
  fi
fi

print_success "Sin proceso Vault conflictivo"
echo

# --- Paso 3: Iniciar Vault en modo dev ---
print_step "Iniciando Vault en modo dev"

print_warning "¡El modo dev NO es para producción!"
print_info "El modo dev almacena todos los datos en memoria y se desbloquea automáticamente con un token root conocido"
echo

# El proceso en segundo plano libera la terminal del lab mientras Vault atiende solicitudes
nohup vault server -dev \
  -dev-root-token-id="root" \
  -dev-listen-address="127.0.0.1:8200" \
  > "${SCRIPT_DIR}/vault.log" 2>&1 &

vault_pid="${!}"
print_success "Vault iniciado con PID: ${vault_pid}"
echo

# --- Paso 4: Esperar a que Vault esté listo ---
print_step "Esperando a que Vault esté listo"

max_attempts=30
attempt=0
while [[ ${attempt} -lt ${max_attempts} ]]; do
  if VAULT_ADDR="${VAULT_ADDR}" vault status &> /dev/null; then
    print_success "Vault listo"
    break
  fi
  sleep 1
  attempt=$((attempt + 1))
done

if [[ ${attempt} -ge ${max_attempts} ]]; then
  error_exit "Vault no pudo iniciarse — revise vault.log para detalles"
fi
echo

# --- Paso 5: Guardar detalles de conexión para otros scripts del lab ---
print_step "Guardando configuración en vault-env.sh"

cat > "${SCRIPT_DIR}/vault-env.sh" <<EOF
#!/usr/bin/env bash
# Variables de entorno de Vault para Lab 22
# Cargue este archivo: source vault-env.sh

export VAULT_ADDR='${VAULT_ADDR}'
export VAULT_TOKEN='root'
export VAULT_PID='${vault_pid}'
EOF

chmod +x "${SCRIPT_DIR}/vault-env.sh"
print_success "Configuración guardada en vault-env.sh"
echo

# --- Paso 6: Exportar entorno y verificar estado ---
print_step "Verificando estado de Vault"

export VAULT_ADDR="${VAULT_ADDR}"
export VAULT_TOKEN="root"

if ! vault status; then
  error_exit "Verificación de estado de Vault falló"
fi

print_success "Vault en ejecución y desbloqueado"
echo

# --- Paso 7: Mostrar información de acceso ---
print_step "Información de acceso a Vault"

print_warning "IMPORTANTE: ¡Guarde estas credenciales!"
echo
print_info "Dirección de Vault: ${VAULT_ADDR}"
print_info "Token root: root"
print_info "PID del proceso: ${vault_pid}"
echo
print_warning "Advertencias del modo dev:"
echo "  - Todos los datos en memoria (se pierden al reiniciar)"
echo "  - Vault se ejecuta desbloqueado"
echo "  - El token root es 'root' (inseguro)"
echo "  - ¡NO usar en producción!"
echo
print_info "Para configurar su shell:"
echo "  source vault-env.sh"
echo
echo "Próximos pasos:"
echo "  1. Cargar entorno: source vault-env.sh"
echo "  2. Ejecute './enable-pki.sh' para habilitar motor de secretos PKI"
echo
print_info "Registros de Vault: tail -f vault.log"
