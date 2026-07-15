#!/usr/bin/env bash
#=============================================================================
# Lab 05: Verificación de confianza
# Verifica que la CA personalizada sea confiable para el sistema
#
# Uso: ./verify-trust.sh
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
CA_CERT="${OUTPUT_DIR}/test-ca.crt"
CA_KEY="${OUTPUT_DIR}/test-ca.key"
TEST_KEY="${OUTPUT_DIR}/test-server.key"
TEST_CERT="${OUTPUT_DIR}/test-server.crt"

print_header "Lab 05: Verificación de confianza de CA"

# Verificar requisitos previos
if [[ ! -f "${CA_CERT}" || ! -f "${CA_KEY}" ]]; then
  print_error "Error: archivos CA no encontrados"
  exit 1
fi

# Generar clave de servidor de prueba
print_info "Creando certificado de servidor de prueba firmado por la CA personalizada..."
openssl genpkey -algorithm RSA -out "${TEST_KEY}" -pkeyopt rsa_keygen_bits:2048 2>/dev/null

# Generar certificado de prueba firmado por la CA personalizada
openssl req -new -key "${TEST_KEY}" \
  -subj "/C=US/ST=State/O=Lab/CN=test.example.com" | \
openssl x509 -req -sha256 -days 365 \
  -CA "${CA_CERT}" -CAkey "${CA_KEY}" -CAcreateserial \
  -out "${TEST_CERT}" 2>/dev/null

print_success "Certificado de prueba creado"
echo

# Prueba 1: verificar con confianza del sistema (debería tener éxito si la CA es confiable)
print_info "Prueba 1: verificando con almacén de confianza del sistema..."
if openssl verify "${TEST_CERT}" &>/dev/null; then
  print_success "ÉXITO: certificado verificado con confianza del sistema"
  echo "  ¡Su CA personalizada es confiable para el sistema!"
else
  print_warning "FALLÓ: certificado no confiable para el sistema"
  echo "  ¿Ejecutó ./update-trust.sh?"
fi
echo

# Prueba 2: verificar con CA explícita (siempre debería tener éxito)
print_info "Prueba 2: verificando con CA explícita..."
if openssl verify -CAfile "${CA_CERT}" "${TEST_CERT}" &>/dev/null; then
  print_success "ÉXITO: certificado verificado con CA explícita"
else
  print_error "FALLÓ: esto no debería ocurrir"
  exit 1
fi
echo

# Prueba 3: verificar si la CA está en el bundle
print_info "Prueba 3: verificando si la CA está en el bundle del sistema..."
if grep -q "Lab Test Root CA" /etc/pki/tls/certs/ca-bundle.crt 2>/dev/null; then
  print_success "ÉXITO: CA encontrada en el bundle del sistema"
else
  print_warning "ADVERTENCIA: CA no encontrada en el bundle del sistema"
  echo "  Ejecute: sudo ./update-trust.sh"
fi
echo

print_success "Verificación de confianza completada"
