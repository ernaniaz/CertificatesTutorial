#!/usr/bin/env bash
#=============================================================================
# Lab 11: Solicitar autofirmado
# Usa certmonger para el seguimiento de un certificado autofirmado
#
# Uso: ./request-self-signed.sh
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

CERT_DIR="/etc/pki/certmonger"
CERT_FILE="${CERT_DIR}/self-signed.crt"
KEY_FILE="${CERT_DIR}/self-signed.key"

print_header "Lab 11: Solicitud de certificado autofirmado"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

# Crear directorio
print_info "Creando directorio de certificados..."
mkdir -p "${CERT_DIR}"
chmod 755 "${CERT_DIR}"

# Comprobar si ya se solicitó
if getcert list -f "${CERT_FILE}" &>/dev/null; then
  print_warning "Certificado ya en seguimiento, deteniendo el seguimiento primero..."
  getcert stop-tracking -f "${CERT_FILE}"
fi

echo

# Solicitar certificado autofirmado
print_info "Solicitando certificado autofirmado..."

getcert request \
  -f "${CERT_FILE}" \
  -k "${KEY_FILE}" \
  -c local \
  -N CN=self-signed.example.com \
  -D self-signed.example.com \
  -D localhost \
  -U id-kp-serverAuth

print_success "Solicitud de certificado enviada"
echo

# Esperar la emisión del certificado
print_info "Esperando la emisión del certificado..."
sleep 3

# Comprobar estado
REQUEST_ID="$(getcert list -f "${CERT_FILE}" 2>/dev/null | grep "Request ID" | awk '{print $3}' | tr -d "':")"

if [[ -n "${REQUEST_ID}" ]]; then
  echo "ID de solicitud: ${REQUEST_ID}"

  # Obtener estado
  STATUS="$(getcert list -i "${REQUEST_ID}" 2>/dev/null | grep "status:" | awk '{print $2}')"
  echo "Estado: ${STATUS}"

  if [[ "${STATUS}" == "MONITORING" ]]; then
    print_success "Certificado emitido y monitoreado correctamente"
  else
    print_warning "Estado: ${STATUS}"
  fi
fi

echo

# Mostrar detalles del certificado
if [[ -f "${CERT_FILE}" ]]; then
  print_success "Archivo de certificado creado"
  echo
  echo "Detalles del certificado:"
  openssl x509 -in "${CERT_FILE}" -noout -subject -dates -ext subjectAltName 2>/dev/null || openssl x509 -in "${CERT_FILE}" -noout -subject -dates

  echo
  echo "Ubicaciones de archivos:"
  echo "  Certificado: ${CERT_FILE}"
  echo "  Clave privada: ${KEY_FILE}"
else
  print_warning "Archivo de certificado aún no creado"
fi

echo
print_success "Solicitud de certificado autofirmado completada"
echo
echo "Comprobar estado con:"
echo "  getcert list"
echo "  getcert list -i ${REQUEST_ID}"
