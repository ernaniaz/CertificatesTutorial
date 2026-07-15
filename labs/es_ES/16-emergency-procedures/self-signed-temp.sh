#!/usr/bin/env bash
#=============================================================================
# Lab 16: Certificado autofirmado temporal
# Certificado autofirmado rápido para emergencias
#
# Uso: ./self-signed-temp.sh
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

CERT_DIR="/etc/pki/tls/certs"
KEY_DIR="/etc/pki/tls/private"

print_header "Lab 16: Certificado autofirmado temporal"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

print_warning "Creando certificado autofirmado temporal"
echo "Use esto cuando la CA no esté disponible y necesite un certificado de inmediato"
echo

# Obtener nombre de dominio
read -p "Nombre de dominio (o Enter para el hostname): " DOMAIN
if [[ -z "${DOMAIN}" ]]; then
  DOMAIN="$(hostname)"
fi

echo
echo "Creando certificado para: ${DOMAIN}"
echo

# Generar certificado temporal
print_info "Generando certificado..."

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "${KEY_DIR}/temp-${DOMAIN}.key" \
  -out "${CERT_DIR}/temp-${DOMAIN}.crt" \
  -days 30 \
  -subj "/CN=${DOMAIN}/O=Temporary/OU=Emergency" \
  -addext "subjectAltName=DNS:${DOMAIN},DNS:localhost" 2>/dev/null || \
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "${KEY_DIR}/temp-${DOMAIN}.key" \
  -out "${CERT_DIR}/temp-${DOMAIN}.crt" \
  -days 30 \
  -subj "/CN=${DOMAIN}/O=Temporary/OU=Emergency" 2>/dev/null

chmod 644 "${CERT_DIR}/temp-${DOMAIN}.crt"
chmod 600 "${KEY_DIR}/temp-${DOMAIN}.key"

print_success "Certificado temporal creado"
echo

# Mostrar información del certificado
echo "Detalles del certificado:"
openssl x509 -in "${CERT_DIR}/temp-${DOMAIN}.crt" -noout -subject -dates
echo

print_success "Archivos de certificado creados"
echo
echo "Certificado: ${CERT_DIR}/temp-${DOMAIN}.crt"
echo "Clave privada: ${KEY_DIR}/temp-${DOMAIN}.key"
echo
print_warning "CERTIFICADO TEMPORAL DE 30 DÍAS"
echo "Reemplace con un certificado firmado por CA lo antes posible"
echo
echo "Desplegar en el servicio:"
echo "  # Para Apache"
echo "  SSLCertificateFile ${CERT_DIR}/temp-${DOMAIN}.crt"
echo "  SSLCertificateKeyFile ${KEY_DIR}/temp-${DOMAIN}.key"
echo
echo "  # Para NGINX"
echo "  ssl_certificate ${CERT_DIR}/temp-${DOMAIN}.crt;"
echo "  ssl_certificate_key ${KEY_DIR}/temp-${DOMAIN}.key;"
