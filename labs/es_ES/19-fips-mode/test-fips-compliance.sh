#!/usr/bin/env bash
#=============================================================================
# Lab 19: Probar cumplimiento FIPS
# Prueba operaciones con certificados en modo FIPS
#
# Uso: ./test-fips-compliance.sh
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

OUTPUT_DIR="/tmp/fips-test-$(date +%s)"

print_header "Lab 19: Pruebas de cumplimiento FIPS"

# Create output directory
mkdir -p "${OUTPUT_DIR}"
cd "${OUTPUT_DIR}"

print_info "1. Probando generación de claves compatible con FIPS..."

# RSA 2048 (should work)
if openssl genrsa -out rsa2048.key 2048 2>/dev/null; then
  echo -e "  ${GREEN}✓ Clave RSA de 2048 bits generada${NC}"
else
  echo -e "  ${RED}✗ RSA 2048 falló${NC}"
fi

# RSA 1024 (should fail in FIPS)
if openssl genrsa -out rsa1024.key 1024 2>/dev/null; then
  echo -e "  ${YELLOW}⚠ RSA de 1024 bits exitosa (FIPS puede no estar activo)${NC}"
else
  echo -e "  ${GREEN}✓ RSA 1024 bloqueada correctamente${NC}"
fi

echo

print_info "2. Probando generación de certificados compatible con FIPS..."

# SHA-256 (should work)
if openssl req -x509 -newkey rsa:2048 -sha256 -nodes \
  -keyout sha256.key -out sha256.crt -days 30 \
  -subj "/CN=fips-test" 2>/dev/null; then
  echo -e "  ${GREEN}✓ Certificado SHA-256 creado${NC}"
else
  echo -e "  ${RED}✗ Certificado SHA-256 falló${NC}"
fi

echo

print_info "3. Probando algoritmos bloqueados..."

# MD5 (should fail)
if echo "test" | openssl dgst -md5 >/dev/null 2>&1; then
  echo -e "  ${YELLOW}⚠ MD5 funciona (FIPS puede no estar aplicando)${NC}"
else
  echo -e "  ${GREEN}✓ MD5 bloqueado correctamente${NC}"
fi

# SHA-1 (should fail for signatures in FIPS)
if echo "test" | openssl dgst -sha1 >/dev/null 2>&1; then
  echo -e "  ${YELLOW}⚠ Hash SHA-1 funciona (permitido para hash, no firmas)${NC}"
else
  echo -e "  ${GREEN}✓ SHA-1 bloqueado${NC}"
fi

echo

print_info "4. Probando cumplimiento TLS..."

# Check available ciphers
CIPHER_COUNT="$(openssl ciphers -v 2>/dev/null | wc -l)"
echo "  Cifras disponibles: ${CIPHER_COUNT}"
echo "  (El modo FIPS restringe solo a cifras aprobadas)"

echo

# Display FIPS-approved ciphers (sample)
echo "  Muestra de cifras FIPS:"
if ! openssl ciphers -v 'FIPS' 2>/dev/null | head -5 | sed 's/^/    /'; then
  echo "    No se pudieron listar cifras FIPS"
fi

echo

# Limpiar
cd /
rm -rf "${OUTPUT_DIR}"

print_success "Pruebas de cumplimiento FIPS completadas"
echo

if [[ -f /proc/sys/crypto/fips_enabled && "$(cat /proc/sys/crypto/fips_enabled)" == "1" ]]; then
  print_success "El sistema cumple con FIPS"
else
  print_warning "El sistema NO está en modo FIPS"
fi
