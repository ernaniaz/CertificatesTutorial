#!/usr/bin/env bash
#=============================================================================
# Lab 16: Reemplazo de emergencia
# Reemplazo rápido de certificados para emergencias en producción
#
# Uso: ./emergency-replacement.sh
# Requisitos previos: RHEL 7, 8, 9, 10, privilegios de root
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

CERT_DIR="/etc/pki/tls/certs"
KEY_DIR="/etc/pki/tls/private"
CERT_NAME="emergency"

print_header "Lab 16: Reemplazo de certificado de emergencia"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

print_warning "PROCEDIMIENTO DE EMERGENCIA"
echo "Esto crea y despliega un nuevo certificado de inmediato"
echo

read -p "¿Continuar con el reemplazo de emergencia? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Operación cancelada"
  exit 0
fi

echo

# Paso 1: Respaldar certificados existentes
print_info "Paso 1: Respaldando certificados existentes..."
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p "/root/cert-backup-${TIMESTAMP}"

if [[ -f "${CERT_DIR}/${CERT_NAME}.crt" ]]; then
  cp "${CERT_DIR}/${CERT_NAME}.crt" "/root/cert-backup-${TIMESTAMP}/"
  print_success "Certificado respaldado"
fi

if [[ -f "${KEY_DIR}/${CERT_NAME}.key" ]]; then
  cp "${KEY_DIR}/${CERT_NAME}.key" "/root/cert-backup-${TIMESTAMP}/"
  print_success "Clave privada respaldada"
fi

echo "  Ubicación del respaldo: /root/cert-backup-${TIMESTAMP}/"
echo

# Paso 2: Generar nuevo certificado
print_info "Paso 2: Generando nuevo certificado..."
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "${KEY_DIR}/${CERT_NAME}.key" \
  -out "${CERT_DIR}/${CERT_NAME}.crt" \
  -days 90 \
  -subj "/CN=$(hostname)" \
  -extensions v3_req \
  -config <(cat /etc/pki/tls/openssl.cnf <(printf "[v3_req]\nsubjectAltName=DNS:$(hostname),DNS:localhost")) 2>/dev/null

chmod 644 "${CERT_DIR}/${CERT_NAME}.crt"
chmod 600 "${KEY_DIR}/${CERT_NAME}.key"

print_success "Nuevo certificado generado"
echo

# Paso 3: Verificar nuevo certificado
print_info "Paso 3: Verificando nuevo certificado..."
if openssl x509 -in "${CERT_DIR}/${CERT_NAME}.crt" -noout -checkend 0 2>/dev/null; then
  print_success "El certificado es válido"
  openssl x509 -in "${CERT_DIR}/${CERT_NAME}.crt" -noout -subject -dates
else
  print_error "Falló la validación del certificado"
  exit 1
fi

echo

# Paso 4: Instrucciones para reiniciar servicios
print_info "Paso 4: Reiniciar servicios afectados"
echo
echo "Servicios que pueden necesitar reinicio:"
echo "  systemctl restart httpd"
echo "  systemctl restart nginx"
echo "  systemctl restart postfix"
echo

print_success "Reemplazo de emergencia completado"
echo
echo "Certificado: ${CERT_DIR}/${CERT_NAME}.crt"
echo "Clave privada: ${KEY_DIR}/${CERT_NAME}.key"
echo "Respaldo: /root/cert-backup-${TIMESTAMP}/"
echo
print_warning "IMPORTANTE: Este es un certificado temporal de 90 días"
echo "Obtenga un certificado adecuado de la CA lo antes posible"
