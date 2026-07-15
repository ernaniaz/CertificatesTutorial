#!/usr/bin/env bash
#=============================================================================
# Lab 15: Corregir
# Escenario 01: Corregir certificado vencido
#
# Uso: ./fix.sh
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
  error_exit "Versión de RHEL no soportada. Este script requiere RHEL 7, 8, 9, 10."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

CERT_FILE="/etc/pki/tls/certs/expired.crt"
KEY_FILE="/etc/pki/tls/private/expired.key"

print_header "Escenario 01: Corregir certificado vencido"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

print_info "Paso 1: Respaldar certificado anterior"
cp "${CERT_FILE}" "${CERT_FILE}.old"
print_success "Respaldado en ${CERT_FILE}.old"
echo

print_info "Paso 2: Generar nuevo certificado (validez de 365 días)"
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "${KEY_FILE}" \
  -out "${CERT_FILE}" \
  -days 365 \
  -subj "/CN=expired.example.com" 2>/dev/null

chmod 644 "${CERT_FILE}"
chmod 600 "${KEY_FILE}"

print_success "Nuevo certificado generado"
echo

print_info "Paso 3: Verificar nuevo certificado"
openssl x509 -in "${CERT_FILE}" -noout -dates
echo

if openssl x509 -in "${CERT_FILE}" -noout -checkend 0 2>/dev/null; then
  print_success "El nuevo certificado es válido"
else
  print_error "Algo salió mal"
  exit 1
fi

echo
print_success "Certificado renovado correctamente"
echo
echo "Próximos pasos:"
echo "  1. Reiniciar servicios que usan este certificado"
echo "  2. Probar conexiones"
echo "  3. Ejecutar ./verify-fix.sh para confirmar"
echo
echo "Prevención:"
echo "  - Usar certmonger/certbot para renovación automática"
echo "  - Monitorear fechas de vencimiento"
echo "  - Renovar 30 días antes del vencimiento"
