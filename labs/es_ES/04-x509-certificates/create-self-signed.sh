#!/usr/bin/env bash
#=============================================================================
# Lab 04: Certificado autofirmado
# Genera un certificado X.509 autofirmado con SANs
#
# Uso: ./create-self-signed.sh
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
OUTPUT_DIR="output"
mkdir -p "${OUTPUT_DIR}"

print_header "Lab 04: Creación de certificado autofirmado"

# Verificar requisitos previos
if [[ ! -f "${KEY_DIR}/rsa-2048.key" ]]; then
  print_error "Error: clave RSA no encontrada. Ejecute primero el Lab 02."
  exit 1
fi

# Crear configuración OpenSSL para SANs
cat > "${OUTPUT_DIR}/san.cnf" << 'EOF'
[req]
default_bits = 2048
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = Lab Organization
OU = Certificate Lab
CN = server.example.com

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = server.example.com
DNS.2 = www.example.com
DNS.3 = *.example.com
IP.1 = 192.168.1.100
EOF

print_info "Generando certificado autofirmado..."
echo

# Generar certificado autofirmado con SANs
openssl req -new -x509 -sha256 \
  -key "${KEY_DIR}/rsa-2048.key" \
  -out "${OUTPUT_DIR}/server.crt" \
  -days 365 \
  -config "${OUTPUT_DIR}/san.cnf" \
  -extensions v3_req

print_success "Certificado autofirmado creado: output/server.crt"
echo

# Mostrar información del certificado
echo "Detalles del certificado:"
openssl x509 -in "${OUTPUT_DIR}/server.crt" -noout -subject -issuer -dates
echo
echo "Subject Alternative Names:"
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  openssl x509 -in "${OUTPUT_DIR}/server.crt" -noout -text | grep -A2 "Subject Alternative Name"
else
  openssl x509 -in "${OUTPUT_DIR}/server.crt" -noout -ext subjectAltName
fi
echo

# Notas específicas por versión de RHEL
if [[ ${RHEL_VERSION} -ge 9 ]]; then
  print_success "RHEL 9+ detectado: el certificado incluye los SANs requeridos"
fi

echo
print_success "Creación de certificado autofirmado completada"
echo
echo "Validez: 365 días desde hoy"
echo "Algoritmo: SHA-256 con RSA (2048 bits)"
