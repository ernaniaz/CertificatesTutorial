#!/usr/bin/env bash
#=============================================================================
# Lab 11: Verificar
# Pasos de verificación
#
# Uso: ./verify.sh
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

print_header "Lab 11: Verificación de certmonger"

print_info "1. Comprobando servicio certmonger..."
systemctl status certmonger --no-pager | head -5
echo

print_info "2. Comprobando versión de certmonger..."
rpm -q certmonger
echo

print_info "3. Listando certificados en seguimiento..."
CERT_COUNT="$(getcert list 2>/dev/null | grep -c "Request ID:" || true)"
echo "Certificados en seguimiento: ${CERT_COUNT}"
echo

if [[ ${CERT_COUNT} -gt 0 ]]; then
  getcert list 2>/dev/null | grep -E "Request ID:|status:|certificate:|expires:" | head -20
fi

echo

print_info "4. Comprobando CAs disponibles..."
getcert list-cas
echo

print_info "5. Comprobando archivos de certificados..."
for cert in /etc/pki/certmonger/*.crt; do
  if [[ -f "${cert}" ]]; then
    echo "Certificado: ${cert}"
    if ! openssl x509 -in "${cert}" -noout -subject -dates 2>/dev/null; then
      echo "  No se pudo leer el certificado"
    fi
    echo
  fi
done

print_info "6. Comprobando registros de certmonger (últimas 10 entradas)..."
journalctl -u certmonger --no-pager | tail -10

echo
print_success "Verificación completada"
