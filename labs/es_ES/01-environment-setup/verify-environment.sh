#!/usr/bin/env bash
#=============================================================================
# Lab 01: Verificación del entorno
# Valida que todas las herramientas de certificados estén instaladas correctamente
#
# Uso: ./verify-environment.sh
# Requisitos previos: RHEL 7, 8, 9, 10
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

print_header "Lab 01: Verificación del entorno"

# Verificar versión de RHEL
echo "Versión de RHEL: ${RHEL_VERSION}"
echo

# Verificar OpenSSL
if command -v openssl &> /dev/null; then
  print_success "OpenSSL: $(openssl version)"
else
  print_error "OpenSSL no encontrado"
  exit 1
fi

# Verificar certutil
if command -v certutil &> /dev/null; then
  print_success "certutil disponible"
else
  print_error "certutil no encontrado"
  exit 1
fi

# Verificar certmonger
if command -v getcert &> /dev/null; then
  print_success "certmonger disponible"
else
  print_warning "certmonger no encontrado (opcional para RHEL 7)"
fi

# Verificar crypto-policies (RHEL 8+)
if command -v update-crypto-policies &> /dev/null; then
  POLICY="$(update-crypto-policies --show 2>/dev/null || echo "DEFAULT")"
  print_success "Crypto-policies: ${POLICY}"
fi

echo
echo "Directorios de certificados:"

# Verificar directorios
for dir in /etc/pki/tls/certs /etc/pki/tls/private /etc/pki/ca-trust; do
  if [[ -d "${dir}" ]]; then
    print_success "${dir}"
  else
    print_error "${dir} no encontrado"
    exit 1
  fi
done

# Verificar bundle de CA
if [[ -f "/etc/pki/tls/certs/ca-bundle.crt" ]]; then
  BUNDLE_SIZE=$(wc -l < /etc/pki/tls/certs/ca-bundle.crt)
  print_success "Bundle de CA: ${BUNDLE_SIZE} líneas"
else
  print_error "Bundle de CA no encontrado"
  exit 1
fi

echo
print_success "¡Todas las validaciones pasaron!"
print_success "Lab 01 completado correctamente."
echo
echo "Siguiente: continúe con Lab 02: Generación de claves"
echo
