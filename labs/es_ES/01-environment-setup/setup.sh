#!/usr/bin/env bash
#=============================================================================
# Lab 01: Configuración
# Instala herramientas de gestión de certificados
#
# Uso: ./setup.sh
# Requisitos previos: RHEL 7, 8, 9, 10, privilegios de root
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
if [[ ${RHEL_VERSION} -lt 7 || ${RHEL_VERSION} -gt 10 ]]; then
  error_exit "Versión de RHEL no soportada. Este script requiere RHEL 7, 8, 9 o 10."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

print_header "Lab 01: Configuración del entorno (RHEL ${RHEL_VERSION})"

print_success "RHEL ${RHEL_VERSION} detectado: $(cat /etc/redhat-release)"
echo

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Este script debe ejecutarse como root (use sudo)"
fi

# Instalar paquetes
print_info "Instalando herramientas de gestión de certificados..."
echo

if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum install -y \
    openssl \
    nss-tools \
    certmonger \
    ca-certificates \
    mod_ssl
else
  dnf install -y \
    openssl \
    nss-tools \
    certmonger \
    ca-certificates \
    mod_ssl
fi

echo
print_success "Instalación de paquetes completada"
echo

# Verificar instalaciones
print_info "Verificando instalaciones..."

if command -v openssl &> /dev/null; then
  print_success "OpenSSL: $(openssl version)"
else
  error_exit "Falló la instalación de OpenSSL"
fi

if command -v certutil &> /dev/null; then
  print_success "certutil (NSS tools) instalado"
else
  error_exit "Falló la instalación de NSS tools"
fi

if command -v getcert &> /dev/null; then
  print_success "certmonger instalado"
else
  print_error "certmonger no disponible (opcional, puede requerir EPEL)"
fi

# Verificar estructura de /etc/pki/
if [[ -d "/etc/pki" ]]; then
  print_success "El directorio /etc/pki/ existe"
else
  error_exit "/etc/pki/ no encontrado"
fi

echo
print_success "=== Configuración completada ==="
echo
echo "Siguiente paso: ejecute './verify-environment.sh' para validar la instalación"
echo
