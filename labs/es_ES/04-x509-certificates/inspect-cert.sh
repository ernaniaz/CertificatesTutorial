#!/usr/bin/env bash
#=============================================================================
# Lab 04: Inspección de certificado
# Muestra información detallada del certificado
#
# Uso: ./inspect-cert.sh
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
CERT_FILE="${OUTPUT_DIR}/server.crt"

print_header "Lab 04: Inspección de certificado"

# Verificar si existe el certificado
if [[ ! -f "${CERT_FILE}" ]]; then
  print_error "Error: certificado no encontrado. Ejecute primero ./create-self-signed.sh"
  exit 1
fi

# Subject
print_info "Subject (a quién identifica el certificado):"
openssl x509 -in "${CERT_FILE}" -noout -subject
echo

# Issuer
print_info "Issuer (quién firmó el certificado):"
openssl x509 -in "${CERT_FILE}" -noout -issuer
echo

# Fechas de validez
print_info "Período de validez:"
openssl x509 -in "${CERT_FILE}" -noout -dates
echo

# Verificar si expiró
if openssl x509 -in "${CERT_FILE}" -noout -checkend 0 &>/dev/null; then
  print_success "El certificado es válido actualmente"
else
  print_error "El certificado ha expirado"
fi
echo

# Subject Alternative Names
print_info "Subject Alternative Names (SANs):"
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  if ! openssl x509 -in "${CERT_FILE}" -noout -text | grep -A2 "Subject Alternative Name" 2>/dev/null; then
    echo "  Sin SANs (no recomendado para RHEL 9+)"
  fi
else
  if ! openssl x509 -in "${CERT_FILE}" -noout -ext subjectAltName 2>/dev/null; then
    echo "  Sin SANs (no recomendado para RHEL 9+)"
  fi
fi
echo

# Información de clave pública
print_info "Clave pública:"
openssl x509 -in "${CERT_FILE}" -noout -text | grep -A 2 "Public Key Algorithm"
echo

# Algoritmo de firma
print_info "Algoritmo de firma:"
openssl x509 -in "${CERT_FILE}" -noout -text | grep "Signature Algorithm" | head -1
echo

# Fingerprints
print_info "Fingerprints del certificado:"
echo -n "  SHA-256: "
openssl x509 -in "${CERT_FILE}" -noout -fingerprint -sha256 | cut -d= -f2
echo -n "  SHA-1:   "
openssl x509 -in "${CERT_FILE}" -noout -fingerprint -sha1 | cut -d= -f2
echo

# Verificación de versión RHEL
if [[ ${RHEL_VERSION} -ge 9 ]]; then
  if openssl x509 -in "${CERT_FILE}" -noout -ext subjectAltName 2>/dev/null | grep -q "DNS"; then
    print_success "Requisito RHEL 9+: SANs presentes"
  else
    print_warning "Advertencia RHEL 9+: SANs ausentes (requeridos para validación)"
  fi
fi

echo
print_success "Inspección de certificado completada"
