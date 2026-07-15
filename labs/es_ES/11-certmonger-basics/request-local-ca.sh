#!/usr/bin/env bash
#=============================================================================
# Lab 11: Solicitar CA local
# Usa certmonger con el helper de CA local
#
# Uso: ./request-local-ca.sh
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
CA_CERT_FILE="${CERT_DIR}/local-ca.crt"
CA_KEY_FILE="${CERT_DIR}/local-ca.key"
CERT_FILE="${CERT_DIR}/local-ca-signed.crt"
KEY_FILE="${CERT_DIR}/local-ca-signed.key"

print_header "Lab 11: Solicitud desde CA local"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

# Crear directorio
mkdir -p "${CERT_DIR}"

# Comprobar si existe CA del Lab 05
PREV_CA_DIR="../05-trust-store/output"
if [[ -f "${PREV_CA_DIR}/ca.crt" && -f "${PREV_CA_DIR}/ca.key" ]]; then
  print_info "Usando CA del Lab 05..."
  cp "${PREV_CA_DIR}/ca.crt" "${CA_CERT_FILE}"
  cp "${PREV_CA_DIR}/ca.key" "${CA_KEY_FILE}"
  chmod 600 "${CA_KEY_FILE}"
  print_success "Archivos de CA copiados"
else
  # Crear CA local simple si es necesario
  print_info "Creando CA local..."
  openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "${CA_KEY_FILE}" \
    -out "${CA_CERT_FILE}" \
    -days 365 \
    -subj "/CN=Lab11 Local CA"
  chmod 600 "${CA_KEY_FILE}"
  print_success "CA local creada"
fi

echo

# Comprobar si ya se solicitó
if getcert list -f "${CERT_FILE}" &>/dev/null; then
  print_warning "Certificado ya en seguimiento, deteniendo el seguimiento primero..."
  getcert stop-tracking -f "${CERT_FILE}"
fi

# Solicitar certificado usando CA local (autofirmado para el lab)
print_info "Solicitando certificado de la CA local..."

# Nota: Se usa la CA local, que en realidad es autofirmada
# En producción, usaría IPA o una CA externa
getcert request \
  -f "${CERT_FILE}" \
  -k "${KEY_FILE}" \
  -c local \
  -N CN=local-ca-server.example.com \
  -D local-ca-server.example.com \
  -D localhost \
  -U id-kp-serverAuth \
  -T 90

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

  if [[ ${STATUS} == MONITORING ]]; then
    print_success "Certificado emitido y monitoreado correctamente"

    # Mostrar vencimiento
    EXPIRES="$(getcert list -i "${REQUEST_ID}" 2>/dev/null | grep "expires:" | cut -d: -f2-)"
    echo "Vence: ${EXPIRES}"
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
  openssl x509 -in "${CERT_FILE}" -noout -subject -issuer -dates 2>/dev/null

  echo
  echo "Ubicaciones de archivos:"
  echo "  Certificado: ${CERT_FILE}"
  echo "  Clave privada: ${KEY_FILE}"
  echo "  Certificado CA: ${CA_CERT_FILE}"
else
  print_warning "Archivo de certificado aún no creado"
fi

echo
print_success "Solicitud de certificado de CA local completada"
echo
echo "Comprobar estado con:"
echo "  getcert list"
echo "  getcert list -i ${REQUEST_ID}"
