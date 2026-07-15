#!/usr/bin/env bash
#=============================================================================
# Lab 18: Copia de seguridad de certificados
# Respaldo integral de certificados antes de la migración RHEL 8 a 9
#
# Uso: ./backup-certificates.sh
# Requisitos previos: RHEL 8, privilegios de root
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
if [[ ${RHEL_VERSION} -ne 8 ]]; then
  error_exit "Versión de RHEL no soportada. Este script requiere solo RHEL 8."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

BACKUP_DIR="/root/rhel8-cert-backup-$(date +%Y%m%d-%H%M%S)"

print_header "Lab 18: Respaldo de certificados (RHEL 8)"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: este script debe ejecutarse como root (use sudo)"
  exit 1
fi

print_info "Creando directorio de respaldo..."
mkdir -p "${BACKUP_DIR}"/{pki,configs,crypto-policies}
echo "  ${BACKUP_DIR}"
echo

# Respaldar directorio PKI
print_info "Respaldando /etc/pki/..."
cp -a /etc/pki "${BACKUP_DIR}/pki/"
print_success "Directorio PKI respaldado"
echo

# Respaldar configuraciones de servicios
print_info "Respaldando configuraciones de servicios..."

if [[ -d /etc/httpd ]]; then
  cp -a /etc/httpd "${BACKUP_DIR}/configs/"
  echo "  ✓ Configuraciones de Apache"
fi

if [[ -d /etc/nginx ]]; then
  cp -a /etc/nginx "${BACKUP_DIR}/configs/"
  echo "  ✓ Configuraciones de NGINX"
fi

if [[ -d /etc/postfix ]]; then
  cp -a /etc/postfix "${BACKUP_DIR}/configs/"
  echo "  ✓ Configuraciones de Postfix"
fi

if [[ -d /etc/openldap ]]; then
  cp -a /etc/openldap "${BACKUP_DIR}/configs/"
  echo "  ✓ Configuraciones de OpenLDAP"
fi

echo

# Respaldar crypto-policies (específico de RHEL 8, relevante para migración a RHEL 9)
print_info "Respaldando crypto-policies..."
CURRENT_POLICY="$(update-crypto-policies --show 2>/dev/null || echo 'desconocido')"
echo "${CURRENT_POLICY}" > "${BACKUP_DIR}/crypto-policies/current-policy.txt"

if [[ -d /etc/crypto-policies ]]; then
  cp -a /etc/crypto-policies "${BACKUP_DIR}/crypto-policies/"
  print_success "Crypto-policies respaldadas (actual: ${CURRENT_POLICY})"
else
  print_warning "Directorio /etc/crypto-policies no encontrado"
fi
echo

# Crear inventario
print_info "Creando inventario de certificados..."
cat > "${BACKUP_DIR}/inventory.txt" << EOF
Respaldo de certificados RHEL 8
Fecha: $(date)
Nombre de host: $(hostname)
OpenSSL: $(openssl version)
Crypto-Policy: ${CURRENT_POLICY}

Archivos de certificado:
EOF

find /etc/pki/tls/certs -name "*.crt" -o -name "*.pem" 2>/dev/null | while read cert; do
  if [[ -f "${cert}" ]]; then
    echo "  ${cert}" >> "${BACKUP_DIR}/inventory.txt"
    if openssl x509 -in "${cert}" -noout -text 2>/dev/null >/dev/null; then
      openssl x509 -in "${cert}" -noout -subject -dates >> "${BACKUP_DIR}/inventory.txt" 2>/dev/null || true
    fi
    echo >> "${BACKUP_DIR}/inventory.txt"
  fi
done

print_success "Inventario creado"
echo

# Crear archivo comprimido
print_info "Creando archivo comprimido..."
tar czf "${BACKUP_DIR}.tar.gz" -C "$(dirname "${BACKUP_DIR}")" "$(basename "${BACKUP_DIR}")"
print_success "Archivo creado"
echo

print_success "Respaldo completado"
echo
echo "Ubicación del respaldo: ${BACKUP_DIR}"
echo "Archivo: ${BACKUP_DIR}.tar.gz"
echo
echo "Tamaño del respaldo:"
du -sh "${BACKUP_DIR}"
du -sh "${BACKUP_DIR}.tar.gz"
echo
print_info "¡Guarde el archivo de respaldo en un lugar seguro antes de la migración!"
