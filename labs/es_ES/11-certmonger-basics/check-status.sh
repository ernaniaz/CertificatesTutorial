#!/usr/bin/env bash
#=============================================================================
# Lab 11: Verificar estado
# Muestra el estado de todos los certificados en seguimiento
#
# Uso: ./check-status.sh
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

print_header "Lab 11: Estado de certificados"

# Comprobar servicio certmonger
print_info "Estado del servicio certmonger:"
if systemctl is-active certmonger &>/dev/null; then
  print_success "certmonger está en ejecución"
else
  echo "certmonger no está en ejecución"
  exit 1
fi

echo

# Listar todos los certificados en seguimiento
print_info "Certificados en seguimiento:"
echo

CERT_LIST="$(getcert list 2>/dev/null)"

if [[ -z "${CERT_LIST}" ]]; then
  echo "No hay certificados en seguimiento"
else
  echo "${CERT_LIST}"
fi

echo
echo "======================================="

# Contar certificados
CERT_COUNT="$(getcert list 2>/dev/null | grep -c "Request ID:" || true)"
echo "Total de certificados en seguimiento: ${CERT_COUNT}"

echo

# Mostrar resumen de cada certificado
if [[ ${CERT_COUNT} -gt 0 ]]; then
  print_info "Resumen de certificados:"
  echo

  # Obtener todos los IDs de solicitud
  REQUEST_IDS="$(getcert list 2>/dev/null | grep "Request ID" | awk '{print $3}' | tr -d "':")"

  for REQ_ID in ${REQUEST_IDS}; do
    echo "ID de solicitud: ${REQ_ID}"

    # Obtener detalles clave
    STATUS="$(getcert list -i "${REQ_ID}" 2>/dev/null | grep "status:" | awk '{print $2}')"
    CERT="$(getcert list -i "${REQ_ID}" 2>/dev/null | grep "certificate:" | cut -d: -f2- | xargs)"
    EXPIRES="$(getcert list -i "${REQ_ID}" 2>/dev/null | grep "expires:" | cut -d: -f2-)"
    CA="$(getcert list -i "${REQ_ID}" 2>/dev/null | grep "ca-name:" | awk '{print $2}')"

    echo "  Estado: ${STATUS}"
    echo "  CA: ${CA}"
    echo "  Certificado: ${CERT}"
    echo "  Vence: ${EXPIRES}"
    echo
  done
fi

echo
print_success "Comprobación de estado completada"
echo
echo "Comandos útiles:"
echo "  getcert list"
echo "  getcert list -i <REQUEST_ID>"
echo "  journalctl -u certmonger -f"
