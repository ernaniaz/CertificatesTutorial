#!/usr/bin/env bash
#=============================================================================
# Lab 15: Limpieza general
# Elimina todos los artefactos de los escenarios
#
# Uso: ./cleanup-all.sh
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

print_header "Lab 15: Limpiar todos los escenarios"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

print_info "Eliminando certificados y archivos del escenario..."

# Escenario 01: Certificado vencido
rm -f /etc/pki/tls/certs/expired.crt
rm -f /etc/pki/tls/certs/expired.crt.old
rm -f /etc/pki/tls/private/expired.key

# Escenario 02: Certificado incorrecto
rm -f /etc/pki/tls/certs/wrong.crt
rm -f /etc/pki/tls/private/wrong.key

# Escenario 04: SELinux
rm -f /etc/pki/tls/certs/selinux-test.crt
rm -f /etc/pki/tls/private/selinux-test.key

# Escenario 05: Nombre de host no coincide
rm -f /etc/pki/tls/certs/mismatch.crt
rm -f /etc/pki/tls/private/mismatch.key

# Escenario 08: Permisos
rm -f /etc/pki/tls/certs/perms-test.crt
rm -f /etc/pki/tls/private/perms-test.key

print_success "Todos los archivos del escenario eliminados"
echo
echo "Sistema restaurado al estado previo al lab"
