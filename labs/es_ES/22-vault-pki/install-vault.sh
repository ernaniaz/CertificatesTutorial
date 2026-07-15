#!/usr/bin/env bash
#=============================================================================
# Lab 22: Instalar Vault
# Descarga e instala HashiCorp Vault
#
# Uso: ./install-vault.sh
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

# Vault configuration
readonly VAULT_VERSION="1.15.4"
readonly VAULT_URL="https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip"

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

print_header "Lab 22: Instalar Vault"

print_success "RHEL ${RHEL_VERSION} detected"
echo

# --- Paso 1: Verificar instalación existente ---
print_step "Verificando instalación existente de Vault"

if command -v vault &> /dev/null; then
  existing_version="$(vault version | head -n1)"
  print_warning "Vault ya instalado: ${existing_version}"
  read -p "¿Reinstalar? (s/N): " -n 1 -r
  echo
  if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
    print_info "Usando instalación existente"
    echo
    print_info "Vault listo para usar"
    echo
    echo "Comandos rápidos:"
    echo "  vault version         - Mostrar versión de Vault"
    echo "  vault --help          - Mostrar ayuda"
    echo
    echo "Próximos pasos:"
    echo "  - Ejecute './start-vault-dev.sh' para iniciar Vault en modo dev"
    echo "  - Ejecute 'vault server --help' para opciones del servidor"
    exit 0
  fi
fi

print_success "Procediendo con la instalación de Vault"
echo

# --- Paso 2: Instalar dependencias ---
print_step "Instalando dependencias"

# unzip y jq son necesarios para extraer el binario y analizar JSON en labs posteriores
if ! command -v unzip &> /dev/null; then
  sudo dnf install -y unzip
fi

if ! command -v curl &> /dev/null; then
  sudo dnf install -y curl
fi

if ! command -v jq &> /dev/null; then
  sudo dnf install -y jq
fi

print_success "Dependencias instaladas"
echo

# --- Paso 3: Detectar arquitectura y descargar Vault ---
print_step "Descargando Vault ${VAULT_VERSION}"

vault_arch="amd64"
if [[ "$(uname -m)" == "aarch64" ]] || [[ "$(uname -m)" == "arm64" ]]; then
  vault_arch="arm64"
fi

vault_download_url="https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${vault_arch}.zip"
print_info "Arquitectura: ${vault_arch}"
print_info "URL de descarga: ${vault_download_url}"

temp_dir="$(mktemp -d)"
if ! curl -sSL -o "${temp_dir}/vault.zip" "${vault_download_url}"; then
  rm -rf "${temp_dir}"
  error_exit "Error al descargar Vault desde releases.hashicorp.com"
fi

print_success "Vault descargado"
echo

# --- Paso 4: Instalar binario de Vault ---
print_step "Instalando Vault en /usr/local/bin"

if ! unzip -q "${temp_dir}/vault.zip" -d "${temp_dir}"; then
  rm -rf "${temp_dir}"
  error_exit "Error al extraer archivo de Vault"
fi

chmod +x "${temp_dir}/vault"
if ! sudo mv "${temp_dir}/vault" /usr/local/bin/vault; then
  rm -rf "${temp_dir}"
  error_exit "Error al instalar binario de Vault"
fi

rm -rf "${temp_dir}"
print_success "Vault instalado en /usr/local/bin/vault"
echo

# --- Paso 5: Verificar instalación ---
print_step "Verificando instalación"

if ! command -v vault &> /dev/null; then
  error_exit "Instalación de Vault falló — binario no encontrado en PATH"
fi

installed_version="$(vault version)"
print_success "Versión de Vault: ${installed_version}"
echo

# --- Paso 6: Mostrar instrucciones de uso ---
print_step "Instalación completada"

print_info "Vault listo para usar"
echo
echo "Comandos rápidos:"
echo "  vault version         - Mostrar versión de Vault"
echo "  vault --help          - Mostrar ayuda"
echo
echo "Próximos pasos:"
echo "  - Ejecute './start-vault-dev.sh' para iniciar Vault en modo dev"
echo "  - Ejecute 'vault server --help' para opciones del servidor"
