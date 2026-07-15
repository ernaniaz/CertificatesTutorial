#!/usr/bin/env bash
#=============================================================================
# Lab 18: Comprobar compatibilidad
# Identifica posibles problemas
#
# Uso: ./check-compatibility.sh
# Requisitos previos: RHEL 8
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
if [[ ${RHEL_VERSION} -ne 8 ]]; then
  error_exit "Versión de RHEL no soportada. Este script requiere solo RHEL 8."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

print_header "Lab 18: Verificación de compatibilidad con RHEL 9"

ISSUES=0
WARNINGS=0

print_info "Análisis de compatibilidad:"
echo

# Verificación 1: versión de OpenSSL
echo -n "1. OpenSSL 1.1.1 detectado: "
if openssl version | grep -q "1.1.1"; then
  print_success ""
else
  print_warning "(versión inesperada)"
fi

# Verificación 2: certificados con SANs
echo -n "2. Los certificados tienen SANs: "
SANS_OK=0
SANS_TOTAL=0
for cert in /etc/pki/tls/certs/*.crt; do
  if [[ -f "${cert}" ]] && openssl x509 -in "${cert}" -noout -text >/dev/null 2>&1; then
    ((SANS_TOTAL+=1))
    if openssl x509 -in "${cert}" -noout -ext subjectAltName 2>/dev/null | grep -q "DNS:"; then
      ((SANS_OK+=1))
    fi
  fi
done

if [[ ${SANS_TOTAL} -eq 0 ]]; then
  print_warning "N/A"
elif [[ ${SANS_OK} -eq ${SANS_TOTAL} ]]; then
  print_success ""
else
  print_warning "(${SANS_OK}/${SANS_TOTAL})"
  ((WARNINGS+=1))
fi

# Verificación 3: tamaños de clave
echo -n "3. Tamaños de clave fuertes (2048+): "
WEAK_COUNT=0
for cert in /etc/pki/tls/certs/*.crt; do
  if [[ -f "${cert}" ]]; then
    KEY_SIZE="$(openssl x509 -in "${cert}" -noout -text 2>/dev/null | grep "Public-Key:" | grep -oP '\d+' | head -1)"
    if [[ -n "${KEY_SIZE}" && ${KEY_SIZE} -lt 2048 ]]; then
      ((WEAK_COUNT+=1))
    fi
  fi
done

if [[ ${WEAK_COUNT} -eq 0 ]]; then
  print_success ""
else
  print_error "(${WEAK_COUNT} claves débiles)"
  ((ISSUES+=1))
fi

# Verificación 4: sin SHA-1
echo -n "4. Sin firmas SHA-1: "
SHA1_COUNT=0
for cert in /etc/pki/tls/certs/*.crt; do
  if [[ -f "${cert}" ]] && openssl x509 -in "${cert}" -noout -text 2>/dev/null | grep -q "sha1WithRSAEncryption"; then
    ((SHA1_COUNT+=1))
  fi
done

if [[ ${SHA1_COUNT} -eq 0 ]]; then
  print_success ""
else
  print_error "(${SHA1_COUNT} certificados SHA-1)"
  ((ISSUES+=1))
fi

echo

print_info "Cambios a esperar en RHEL 9:"
echo "  - OpenSSL 3.x (arquitectura de proveedores)"
echo "  - Validación de certificados más estricta"
echo "  - SANs requeridos (solo CN obsoleto)"
echo "  - Los algoritmos legacy requieren habilitación explícita"
echo

if [[ ${ISSUES} -eq 0 && ${WARNINGS} -eq 0 ]]; then
  print_success "El sistema parece listo para RHEL 9"
elif [[ ${ISSUES} -eq 0 ]]; then
  print_warning "Problemas menores: ${WARNINGS} advertencias"
  echo "  Revise las advertencias antes de la migración"
else
  print_error "Problemas críticos: ${ISSUES}"
  echo "  Resuélvalos antes de migrar a RHEL 9"
fi
