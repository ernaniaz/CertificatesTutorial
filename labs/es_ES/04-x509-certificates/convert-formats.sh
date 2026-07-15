#!/usr/bin/env bash
#=============================================================================
# Lab 04: Conversión de formatos
# Convierte entre formatos PEM y DER
#
# Uso: ./convert-formats.sh
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

OUTPUT_DIR="output"
CERT_PEM="${OUTPUT_DIR}/server.crt"
CERT_DER="${OUTPUT_DIR}/server.der"
CERT_BACK="${OUTPUT_DIR}/server-from-der.pem"

print_header "Lab 04: Conversión de formatos de certificado"

# Verificar si existe el certificado
if [[ ! -f "${CERT_PEM}" ]]; then
  print_error "Error: certificado no encontrado. Ejecute primero ./create-self-signed.sh"
  exit 1
fi

# Convertir PEM a DER
print_info "Convirtiendo PEM a DER (formato binario)..."
openssl x509 -in "${CERT_PEM}" -outform DER -out "${CERT_DER}"
print_success "Creado: ${CERT_DER}"
echo

# Convertir DER de vuelta a PEM
print_info "Convirtiendo DER de vuelta a PEM..."
openssl x509 -in "${CERT_DER}" -inform DER -out "${CERT_BACK}"
print_success "Creado: ${CERT_BACK}"
echo

# Comparar tamaños de archivos
echo "Comparación de tamaños de archivo:"
PEM_SIZE=$(stat -f%z "${CERT_PEM}" 2>/dev/null || stat -c%s "${CERT_PEM}")
DER_SIZE=$(stat -f%z "${CERT_DER}" 2>/dev/null || stat -c%s "${CERT_DER}")
echo "  PEM (Base64):  ${PEM_SIZE} bytes"
echo "  DER (Binary):  ${DER_SIZE} bytes"
echo

# Verificar que contienen el mismo certificado
echo "Verificando contenido del certificado..."
PEM_HASH=$(openssl x509 -in "${CERT_PEM}" -noout -fingerprint -sha256 | cut -d= -f2)
DER_HASH=$(openssl x509 -in "${CERT_DER}" -inform DER -noout -fingerprint -sha256 | cut -d= -f2)

if [[ "${PEM_HASH}" == "${DER_HASH}" ]]; then
  print_success "Los certificados coinciden (mismo contenido, codificación diferente)"
else
  print_error "Los certificados no coinciden"
  exit 1
fi
echo

# Mostrar características de formatos
echo "Características de los formatos:"
echo
echo "PEM (Privacy Enhanced Mail):"
echo "  - Texto codificado en Base64"
echo "  - Tiene encabezados -----BEGIN/END-----"
echo "  - Legible por humanos (se puede ver en un editor de texto)"
echo "  - Más común en RHEL/Linux"
echo "  - Usado por: Apache, NGINX, la mayoría de herramientas Linux"
echo
echo "DER (Distinguished Encoding Rules):"
echo "  - Formato binario"
echo "  - Tamaño de archivo menor"
echo "  - No legible por humanos"
echo "  - Usado por: Java, Windows, algunos dispositivos embebidos"
echo

print_success "Conversión de formatos completada"
