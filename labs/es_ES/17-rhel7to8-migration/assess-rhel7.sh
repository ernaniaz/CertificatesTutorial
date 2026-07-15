#!/usr/bin/env bash
#=============================================================================
# Lab 17: Evaluar RHEL 7
# Evaluación previa a la migración
#
# Uso: ./assess-rhel7.sh
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

print_header "Lab 17: Evaluación de certificados en RHEL 7"

print_info "1. Versión del sistema:"
cat /etc/redhat-release
echo

print_info "2. Certificados instalados:"
echo "Certificados del sistema en /etc/pki/tls/certs:"
ls -lh /etc/pki/tls/certs/*.crt /etc/pki/tls/certs/*.pem 2>/dev/null | wc -l | xargs echo "  Archivos de certificados:"

echo
echo "Buscando certificados SHA-1..."
SHA1_COUNT=0
for cert in /etc/pki/tls/certs/*.crt /etc/pki/tls/certs/*.pem; do
  if [[ -f "${cert}" ]]; then
    if openssl x509 -in "${cert}" -noout -text 2>/dev/null | grep -q "sha1WithRSAEncryption"; then
      echo -e "  ${YELLOW}⚠ SHA-1: $(basename "${cert}")${NC}"
      ((SHA1_COUNT+=1))
    fi
  fi
done

if [[ ${SHA1_COUNT} -eq 0 ]]; then
  echo -e "  ${GREEN}✓ No se encontraron certificados SHA-1${NC}"
else
  echo -e "  ${RED}✗ Se encontraron ${SHA1_COUNT} certificados SHA-1 (deberán reemplazarse en RHEL 8)${NC}"
fi

echo

print_info "3. Servicios que usan certificados:"
SERVICES=("httpd" "nginx" "postfix" "slapd" "postgresql")
for svc in "${SERVICES[@]}"; do
  if systemctl list-unit-files | grep -q "^${svc}.service"; then
    STATUS="$(systemctl is-active ${svc} 2>/dev/null || echo "inactive")"
    if [[ ${STATUS} == active ]]; then
      echo -e "  ${GREEN}✓ ${svc} (activo)${NC}"
    else
      echo "    ${svc} (inactivo)"
    fi
  fi
done

echo

print_info "4. Configuraciones TLS:"
echo "Configuraciones de Apache con SSL:"
grep -r "SSLProtocol\|SSLCipherSuite" /etc/httpd/conf* 2>/dev/null | wc -l | xargs echo "  Configuraciones TLS manuales:"

echo

print_info "5. Almacén de confianza:"
CA_COUNT="$(ls /etc/pki/ca-trust/source/anchors/*.crt 2>/dev/null | wc -l)"
echo "  Certificados CA personalizados: ${CA_COUNT}"

echo

print_info "Resumen de la evaluación:"
echo "  Sistema RHEL 7 listo para la evaluación de migración"
echo
print_warning "Acciones previas a la migración necesarias:"
echo "  1. Respaldar todos los certificados"
if [[ ${SHA1_COUNT} -gt 0 ]]; then
  echo "  2. Reemplazar certificados SHA-1 antes de la migración"
fi
echo "  3. Documentar las configuraciones de los servicios"
echo "  4. Probar la funcionalidad actual"
echo
echo "Siguiente paso: ejecutar ./backup-certificates.sh"
