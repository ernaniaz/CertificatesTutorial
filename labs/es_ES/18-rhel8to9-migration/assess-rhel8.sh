#!/usr/bin/env bash
#=============================================================================
# Lab 18: Evaluar RHEL 8
# Evaluación previa a la migración para RHEL 9
#
# Uso: ./assess-rhel8.sh
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

print_header "Lab 18: Evaluación de certificados en RHEL 8"

print_info "1. Versión del sistema:"
cat /etc/redhat-release
openssl version
echo

print_info "2. Análisis de certificados:"

SANS_MISSING=0
WEAK_KEYS=0

for cert in /etc/pki/tls/certs/*.crt; do
  if [[ -f "${cert}" ]] && openssl x509 -in "${cert}" -noout -text >/dev/null 2>&1; then
    # Verificar SANs
    if ! openssl x509 -in "${cert}" -noout -ext subjectAltName 2>/dev/null | grep -q "DNS:"; then
      echo -e "  ${YELLOW}⚠ Sin SAN: $(basename "${cert}")${NC}"
      ((SANS_MISSING+=1))
    fi

    # Verificar tamaño de clave
    KEY_SIZE="$(openssl x509 -in "${cert}" -noout -text | grep "Public-Key:" | grep -oP '\d+' | head -1)"
    if [[ -n "${KEY_SIZE}" && ${KEY_SIZE} -lt 2048 ]]; then
      echo -e "  ${RED}✗ Clave débil (${KEY_SIZE} bits): $(basename "${cert}")${NC}"
      ((WEAK_KEYS+=1))
    fi
  fi
done

if [[ ${SANS_MISSING} -eq 0 ]]; then
  echo -e "  ${GREEN}✓ Todos los certificados tienen SANs${NC}"
else
  echo -e "  ${YELLOW}⚠ ${SANS_MISSING} certificados sin SANs${NC}"
  echo "    (RHEL 9 prefiere certificados con SANs)"
fi

if [[ ${WEAK_KEYS} -eq 0 ]]; then
  echo -e "  ${GREEN}✓ Todas las claves cumplen el tamaño mínimo${NC}"
else
  echo -e "  ${RED}✗ ${WEAK_KEYS} claves débiles encontradas${NC}"
  echo "    (RHEL 9 requiere RSA de 2048+ bits)"
fi

echo

print_info "3. Crypto-Policy actual:"
POLICY="$(update-crypto-policies --show 2>/dev/null)"
echo "  ${POLICY}"

echo

print_info "4. Configuración de OpenSSL:"
if [[ -f /etc/pki/tls/openssl.cnf ]]; then
  if grep -qP '^[^#]*legacy\s*=' /etc/pki/tls/openssl.cnf; then
    echo -e "  ${YELLOW}⚠ Proveedor legacy habilitado${NC}"
  else
    echo -e "  ${GREEN}✓ Configuración estándar${NC}"
  fi
fi

echo

print_info "Resumen de la evaluación:"
echo "  Listo para la evaluación de migración a RHEL 9"
echo

if [[ ${SANS_MISSING} -gt 0 || ${WEAK_KEYS} -gt 0 ]]; then
  print_warning "Recomendaciones antes de la migración:"
  if [ ${SANS_MISSING} -gt 0 ]; then
    echo "  - Regenerar certificados con SANs"
  fi
  if [ ${WEAK_KEYS} -gt 0 ]; then
    echo "  - Regenerar con claves más fuertes (2048+ bits)"
  fi
fi

echo
echo "Siguiente: haga copia de seguridad con ./backup-certificates.sh"
