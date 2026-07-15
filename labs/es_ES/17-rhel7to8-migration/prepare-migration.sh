#!/usr/bin/env bash
#=============================================================================
# Lab 17: Preparar migración
# Verificación de preparación para la migración
#
# Uso: ./prepare-migration.sh
# Requisitos previos: RHEL 7
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
if [[ ${RHEL_VERSION} -ne 7 ]]; then
  error_exit "Versión de RHEL no soportada. Este script requiere solo RHEL 7."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

print_header "Lab 17: Preparación para la migración"

ISSUES=0

print_info "Lista de verificación de preparación para la migración:"
echo

# Verificación 1: existe respaldo
echo -n "1. Respaldo de certificados creado: "
if ls /root/rhel7-cert-backup-*.tar.gz 2>/dev/null | grep -q .; then
  print_success ""
else
  print_error "(ejecute ./backup-certificates.sh)"
  ((ISSUES+=1))
fi

# Verificación 2: certificados SHA-1
echo -n "2. Sin certificados SHA-1: "
SHA1_FOUND=0
for cert in /etc/pki/tls/certs/*.crt; do
  if [[ -f "${cert}" ]] && openssl x509 -in "${cert}" -noout -text 2>/dev/null | grep -q "sha1WithRSAEncryption"; then
    SHA1_FOUND=1
    break
  fi
done

if [[ ${SHA1_FOUND} -eq 0 ]]; then
  print_success ""
else
  print_warning "(los certificados SHA-1 deben reemplazarse)"
fi

# Verificación 3: certificados no vencidos
echo -n "3. Todos los certificados válidos: "
EXPIRED=0
for cert in /etc/pki/tls/certs/*.crt; do
  if [[ -f "${cert}" ]] && ! openssl x509 -in "${cert}" -noout -checkend 0 2>/dev/null; then
    EXPIRED=1
    break
  fi
done

if [[ ${EXPIRED} -eq 0 ]]; then
  print_success ""
else
  print_error "(se encontraron certificados vencidos)"
  ((ISSUES+=1))
fi

# Verificación 4: servicios documentados
echo -n "4. Configuraciones de servicios respaldadas: "
if ls /root/rhel7-cert-backup-*/configs/ 2>/dev/null | grep -q .; then
  print_success ""
else
  print_warning "(recomendado)"
fi

echo
print_info "Problemas de compatibilidad conocidos:"
echo
echo "TLS 1.0/1.1:"
echo "  - RHEL 8 los deshabilita por defecto"
echo "  - Use la política LEGACY si necesita clientes antiguos"
echo
echo "Firmas SHA-1:"
echo "  - Bloqueadas en la política DEFAULT"
echo "  - Reemplácelas o use la política LEGACY"
echo
echo "Configuraciones TLS manuales:"
echo "  - Elimine las directivas SSLProtocol"
echo "  - Elimine las directivas SSLCipherSuite"
echo "  - Deje que crypto-policies las gestione"
echo

if [[ ${ISSUES} -eq 0 ]]; then
  print_success "Sistema listo para migrar a RHEL 8"
else
  print_error "Resuelva ${ISSUES} problemas críticos antes de la migración"
fi

echo
echo "Después de actualizar a RHEL 8, ejecute: ./configure-rhel8.sh"
