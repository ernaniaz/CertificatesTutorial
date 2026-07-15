#!/usr/bin/env bash
#=============================================================================
# Lab 15: Diagnosticar
# Escenario 01: Diagnosticar certificado vencido
#
# Uso: ./diagnose.sh
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
  error_exit "Versión de RHEL no soportada. Este script requiere RHEL 7, 8, 9, 10."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

CERT_FILE="/etc/pki/tls/certs/expired.crt"

print_header "Escenario 01: Diagnosticar problema de certificado"

if [[ ! -f "${CERT_FILE}" ]]; then
  print_error "Certificado no encontrado. Ejecute ./create-problem.sh primero"
  exit 1
fi

print_info "Paso 1: Comprobar fechas de validez del certificado"
openssl x509 -in "${CERT_FILE}" -noout -dates
echo

print_info "Paso 2: Comprobar si el certificado está vencido"
if openssl x509 -in "${CERT_FILE}" -noout -checkend 0 2>/dev/null; then
  print_success "El certificado aún es válido"
else
  print_error "¡El certificado ha vencido!"
fi
echo

print_info "Paso 3: Mostrar detalles completos del certificado"
openssl x509 -in "${CERT_FILE}" -noout -subject -issuer -dates
echo

print_info "Paso 4: Calcular días hasta/desde el vencimiento"
NOT_AFTER="$(openssl x509 -in "${CERT_FILE}" -noout -enddate | cut -d= -f2)"
EXPIRE_EPOCH="$(date -d "${NOT_AFTER}" +%s 2>/dev/null || echo "0")"
NOW_EPOCH="$(date +%s)"
DAYS_DIFF="$(( (${EXPIRE_EPOCH} - ${NOW_EPOCH}) / 86400 ))"

if [[ ${DAYS_DIFF} -lt 0 ]]; then
  print_error "El certificado venció hace ${DAYS_DIFF#-} días"
else
  print_success "El certificado vence en ${DAYS_DIFF} días"
fi

echo
echo "======================================="
if openssl x509 -in "${CERT_FILE}" -noout -checkend 0 2>/dev/null; then
  print_success "DIAGNÓSTICO: El certificado aún es válido"
  echo
  echo "Nota: Este escenario espera un certificado vencido."
  echo "Si ve resultados contradictorios arriba, revise notBefore/notAfter con detalle."
else
  print_warning "DIAGNÓSTICO: El certificado ha vencido"
  echo
  echo "Impacto:"
  echo "  - Las conexiones SSL/TLS fallarán cuando se use este certificado"
  echo "  - Los servicios no pueden usar este certificado"
  echo "  - Los clientes mostrarán advertencias de seguridad"
  echo
  echo "Solución: Generar nuevo certificado con vencimiento futuro"
  echo "Ejecute ./fix.sh para resolver este problema"
fi
