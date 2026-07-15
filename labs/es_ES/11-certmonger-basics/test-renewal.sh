#!/usr/bin/env bash
#=============================================================================
# Lab 11: Probar renovación
# Fuerza la renovación de un certificado en seguimiento
#
# Uso: ./test-renewal.sh
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

CERT_FILE="/etc/pki/certmonger/self-signed.crt"

print_header "Lab 11: Probar renovación de certificado"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

# Comprobar si el certificado está en seguimiento
if ! getcert list -f "${CERT_FILE}" &>/dev/null; then
  print_error "Error: El certificado ${CERT_FILE} no está en seguimiento"
  echo "Ejecute ./request-self-signed.sh primero"
  exit 1
fi

# Obtener ID de solicitud
REQUEST_ID="$(getcert list -f "${CERT_FILE}" 2>/dev/null | grep "Request ID" | awk '{print $3}' | tr -d "':")"

echo "ID de solicitud: ${REQUEST_ID}"
echo "Certificado: ${CERT_FILE}"
echo

# Mostrar fechas del certificado actual
if [[ -f "${CERT_FILE}" ]]; then
  print_info "Certificado actual:"
  openssl x509 -in "${CERT_FILE}" -noout -dates
  SERIAL_BEFORE="$(openssl x509 -in "${CERT_FILE}" -noout -serial)"
  echo "${SERIAL_BEFORE}"
  echo
fi

# Forzar renovación
print_info "Forzando renovación del certificado..."
getcert resubmit -i "${REQUEST_ID}"

print_success "Solicitud de renovación enviada"
echo

# Esperar la renovación
print_info "Esperando que se complete la renovación..."
sleep 5

# Comprobar nuevo estado
echo "Nuevo estado:"
STATUS="$(getcert list -i "${REQUEST_ID}" 2>/dev/null | grep "status:" | awk '{print $2}')"
echo "  ${STATUS}"

# Comprobar si el certificado fue renovado
if [[ -f "${CERT_FILE}" ]]; then
  echo
  print_info "Certificado renovado:"
  openssl x509 -in "${CERT_FILE}" -noout -dates
  SERIAL_AFTER="$(openssl x509 -in "${CERT_FILE}" -noout -serial)"
  echo "${SERIAL_AFTER}"

  echo
  if [[ "${SERIAL_BEFORE}" != "${SERIAL_AFTER}" ]]; then
    print_success "Certificado renovado (número de serie cambió)"
  else
    print_warning "Número de serie sin cambios (la renovación puede no haberse completado)"
  fi
fi

echo
print_success "Prueba de renovación completada"
echo
echo "Monitorear renovación con:"
echo "  journalctl -u certmonger -f"
echo "  getcert list -i ${REQUEST_ID}"
