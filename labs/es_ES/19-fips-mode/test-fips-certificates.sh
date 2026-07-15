#!/usr/bin/env bash
#=============================================================================
# Lab 19: Probar certificados FIPS
# Prueba operaciones con certificados bajo FIPS
#
# Uso: ./test-fips-certificates.sh
# Requisitos previos: RHEL 8, 9, 10
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

TEST_DIR="/tmp/fips-cert-test"

print_header "Lab 19: Probar operaciones con certificados FIPS"

# Verificar si FIPS está habilitado
if [[ -f /proc/sys/crypto/fips_enabled ]]; then
  FIPS_STATUS="$(cat /proc/sys/crypto/fips_enabled)"
  if [[ ${FIPS_STATUS} -ne 1 ]]; then
    print_warning "Modo FIPS no habilitado"
    echo "Esta prueba funciona mejor con FIPS habilitado"
    echo
  fi
fi

# Crear directorio de prueba
mkdir -p "${TEST_DIR}"
cd "${TEST_DIR}"

print_info "1. Probando generación de clave RSA 2048..."
if openssl genrsa -out rsa-2048.key 2048 2>/dev/null; then
  print_success "Generación RSA 2048 exitosa"
else
  print_error "Generación RSA 2048 falló"
fi

echo

print_info "2. Probando generación de clave ECDSA P-256..."
if openssl ecparam -genkey -name prime256v1 -out ec-p256.key 2>/dev/null; then
  print_success "Generación ECDSA P-256 exitosa"
else
  print_error "Generación ECDSA P-256 falló"
fi

echo

print_info "3. Probando certificado con SHA-256..."
if openssl req -x509 -new -key rsa-2048.key -sha256 \
  -out cert-sha256.pem -days 365 \
  -subj "/CN=fips-test.example.com" \
  -addext "subjectAltName=DNS:fips-test.example.com" 2>/dev/null; then
  print_success "Certificado SHA-256 creado"
  openssl x509 -in cert-sha256.pem -noout -subject -dates | sed 's/^/  /'
else
  print_error "Creación de certificado SHA-256 falló"
fi

echo

print_info "4. Probando MD5 (debería fallar en FIPS)..."
if echo "test" | openssl md5 2>&1 | grep -qi "fips"; then
  print_success "MD5 bloqueado correctamente por FIPS"
elif ! echo "test" | openssl md5 &>/dev/null; then
  print_success "MD5 bloqueado"
else
  print_warning "MD5 no bloqueado (¿FIPS inactivo?)"
fi

echo

print_info "5. Probando verificación de certificados..."
if openssl x509 -in cert-sha256.pem -noout -text >/dev/null 2>&1; then
  print_success "Validación de certificados funciona"
else
  print_error "Validación de certificados falló"
fi

echo

# Limpiar
cd /
rm -rf "${TEST_DIR}"

print_success "Pruebas de certificados FIPS completadas"
echo
echo "Operaciones de certificados aprobadas por FIPS:"
echo "  ✓ Claves RSA de 2048/3072/4096 bits"
echo "  ✓ Claves ECDSA P-256/384/521"
echo "  ✓ Firmas SHA-256/384/512"
echo "  ✓ Cifras AES-128/256-GCM"
echo
echo "Operaciones bloqueadas:"
echo "  ✗ MD5 (cualquier uso)"
echo "  ✗ Firmas SHA-1"
echo "  ✗ RSA < 2048 bits"
echo "  ✗ RC4, DES, 3DES"
