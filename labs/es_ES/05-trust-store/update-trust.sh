#!/usr/bin/env bash
#=============================================================================
# Lab 05: Actualizar confianza
# Ejecuta update-ca-trust para reconstruir el almacén de confianza del sistema
#
# Uso: ./update-trust.sh
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

TRUST_ANCHOR="/etc/pki/ca-trust/source/anchors/lab-test-ca.crt"

print_header "Lab 05: Actualización del almacén de confianza del sistema"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: este script debe ejecutarse como root (use sudo)"
  exit 1
fi

# Verificar si se agregó la CA
if [[ ! -f "${TRUST_ANCHOR}" ]]; then
  print_error "Error: CA personalizada no encontrada en trust anchors"
  echo "Ejecute primero ./add-custom-ca.sh"
  exit 1
fi

# Contar CAs antes de actualizar
BEFORE=$(grep -c "BEGIN CERTIFICATE" /etc/pki/tls/certs/ca-bundle.crt || true)

print_info "Ejecutando update-ca-trust extract..."
update-ca-trust extract

# Contar CAs después de actualizar
AFTER=$(grep -c "BEGIN CERTIFICATE" /etc/pki/tls/certs/ca-bundle.crt || true)

print_success "Almacén de confianza del sistema actualizado"
echo
echo "Estadísticas del bundle de CA:"
echo "  Antes: ${BEFORE} certificados"
echo "  Después:  ${AFTER} certificados"
echo "  Cambio: + $((AFTER - BEFORE)) certificado(s)"
echo
echo "Archivos actualizados:"
echo "  /etc/pki/tls/certs/ca-bundle.crt"
echo "  /etc/pki/tls/certs/ca-bundle.trust.crt"
echo
print_success "La CA personalizada ahora es confiable en todo el sistema"
