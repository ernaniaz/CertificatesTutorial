#!/usr/bin/env bash
#=============================================================================
# Lab 13: Probar renovación
# Prueba el proceso de renovación de certbot
#
# Uso: ./test-renewal.sh
# Requisitos previos: RHEL 8, 9, 10, privilegios de root
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
if [[ ${RHEL_VERSION} -lt 8 || ${RHEL_VERSION} -gt 10 ]]; then
  error_exit "Versión de RHEL no soportada. Este script requiere RHEL 8, 9 o 10."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

print_header "Lab 13: Probar renovación de certificado"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

# Listar certificados existentes
print_info "Certificados existentes:"
if certbot certificates 2>/dev/null | grep -q "Certificate Name:"; then
  certbot certificates
else
  print_warning "No se encontraron certificados"
  echo "Ejecute obtain-standalone.sh u obtain-webserver.sh primero"
  exit 0
fi

echo

# Probar renovación (dry-run)
print_info "Probando renovación (dry-run, no renovará realmente)..."
echo

if certbot renew --dry-run 2>&1 | tee /tmp/certbot-renewal-test.log; then
  echo
  print_success "Prueba de renovación exitosa"
  echo
  echo "Dry-run completado correctamente"
  echo "Los certificados se renovarían sin errores"
else
  echo
  print_warning "La prueba de renovación encontró problemas"
  echo
  echo "Esto es normal en un entorno de lab"
  echo "Consulte /tmp/certbot-renewal-test.log para más detalles"
fi

echo
print_info "Configuración de renovación:"
if [[ -d /etc/letsencrypt/renewal ]]; then
  echo "Configuraciones de renovación:"
  ls -1 /etc/letsencrypt/renewal/*.conf 2>/dev/null | while read conf; do
    echo "  ${conf}"
    grep -E "authenticator|installer|renewalparams" "${conf}" 2>/dev/null | head -5 | sed 's/^/    /'
  done
else
  echo "No se encontraron configuraciones de renovación"
fi

echo
print_success "Pruebas de renovación completadas"
echo
echo "Conceptos clave:"
echo "  - Los certificados se renuevan cuando quedan <30 días"
echo "  - --dry-run prueba sin renovar realmente"
echo "  - La renovación usa el mismo método que la solicitud original"
echo
echo "Renovación manual:"
echo "  certbot renew"
echo "  certbot renew --force-renewal"
