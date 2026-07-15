#!/usr/bin/env bash
#=============================================================================
# Lab 05: Creación de CA de prueba
# Genera una Certificate Authority personalizada para pruebas
#
# Uso: ./create-test-ca.sh
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
mkdir -p "${OUTPUT_DIR}"

print_header "Lab 05: Creación de certificado CA de prueba"

# Generar clave privada de CA
print_info "Generando clave privada de CA..."
openssl genpkey -algorithm RSA \
  -out "${OUTPUT_DIR}/test-ca.key" \
  -pkeyopt rsa_keygen_bits:4096

chmod 600 "${OUTPUT_DIR}/test-ca.key"
print_success "Clave privada de CA creada"
echo

# Generar certificado CA autofirmado
print_info "Generando certificado CA autofirmado..."

# Crear configuración de CA
cat > "${OUTPUT_DIR}/ca.cnf" << 'EOF'
[req]
default_bits = 4096
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = Lab Test CA
OU = Certificate Lab
CN = Lab Test Root CA

[v3_ca]
basicConstraints = critical,CA:TRUE
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
EOF

openssl req -new -x509 -sha256 \
  -key "${OUTPUT_DIR}/test-ca.key" \
  -out "${OUTPUT_DIR}/test-ca.crt" \
  -days 3650 \
  -config "${OUTPUT_DIR}/ca.cnf" \
  -extensions v3_ca

print_success "Certificado CA creado (válido por 10 años)"
echo

# Mostrar información de CA
echo "Detalles del certificado CA:"
openssl x509 -in "${OUTPUT_DIR}/test-ca.crt" -noout -subject -issuer
echo
echo "Basic Constraints:"
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  openssl x509 -in "${OUTPUT_DIR}/test-ca.crt" -noout -text | grep -A2 "Basic Constraints"
else
  openssl x509 -in "${OUTPUT_DIR}/test-ca.crt" -noout -ext basicConstraints
fi
echo

print_success "Creación de CA de prueba completada"
echo
echo "Archivos creados:"
echo "  ${OUTPUT_DIR}/test-ca.key (clave privada de CA - ¡manténgala segura!)"
echo "  ${OUTPUT_DIR}/test-ca.crt (certificado CA - para confiar)"
