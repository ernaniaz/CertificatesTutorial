#!/usr/bin/env bash
#=============================================================================
# Lab 03: Prueba de manipulación
# Demuestra que la firma falla cuando el archivo es modificado
#
# Uso: ./tamper-test.sh
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

KEY_DIR="../02-key-generation/output"
SAMPLE_FILE="sample-data.txt"
SIGNATURE_FILE="sample-data.sig"
TAMPERED_FILE="tampered-data.txt"

print_header "Lab 03: Prueba de detección de manipulación"

# Verificar requisitos previos
if [[ ! -f "${SIGNATURE_FILE}" ]]; then
  print_error "Error: ejecute primero ./sign-file.sh"
  exit 1
fi

# Crear versión manipulada
print_warning "Creando versión manipulada del archivo..."
cp "${SAMPLE_FILE}" "${TAMPERED_FILE}"
echo "CONTENIDO MANIPULADO - ¡Este texto se agregó después de firmar!" >> "${TAMPERED_FILE}"
print_warning "✓ Archivo modificado"
echo

# Intentar verificar firma en archivo manipulado
echo "Intentando verificar firma en archivo manipulado..."
echo "(Esto debería FALLAR, demostrando la detección de manipulación)"
echo

if openssl dgst -sha256 \
  -verify "${KEY_DIR}/rsa-2048.pub" \
  -signature "${SIGNATURE_FILE}" \
  "${TAMPERED_FILE}" 2>/dev/null; then
  print_error "======================================="
  print_error "ERROR: ¡El archivo manipulado se verificó!"
  print_error "¡Esto no debería ocurrir!"
  print_error "======================================="
  rm -f "${TAMPERED_FILE}"
  exit 1
else
  print_success "ÉXITO: ¡Manipulación detectada!"
  echo
  echo "Como se esperaba, la firma NO se verifica para el archivo modificado."
  echo "Esto demuestra que las firmas digitales detectan cualquier cambio en los datos firmados."
fi

# Limpieza
rm -f "${TAMPERED_FILE}"
echo
print_success "Prueba de detección de manipulación superada"
