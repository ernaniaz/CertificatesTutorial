#!/usr/bin/env bash
#=============================================================================
# Lab 16: Revertir
# Revierte rápidamente a certificados anteriores
#
# Uso: ./rollback.sh
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

print_header "Lab 16: Revertir cambios de certificado"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

print_info "Buscando archivos de respaldo..."
echo

# Buscar archivos .backup y .old
echo "Respaldos de certificados:"
if ! find "${CERT_DIR}" -name "*.backup" -o -name "*.old" 2>/dev/null; then
  echo "Ninguno encontrado"
fi
echo

echo "Respaldos de claves privadas:"
if ! find "${KEY_DIR}" -name "*.backup" -o -name "*.old" 2>/dev/null; then
  echo "Ninguno encontrado"
fi
echo

read -p "Ingrese el archivo de certificado a revertir (sin .backup/.old): " CERT_BASE

if [[ -z "${CERT_BASE}" ]]; then
  echo "No se especificó ningún archivo"
  exit 1
fi

# Intentar encontrar respaldo
BACKUP_FILE=""
if [[ -f "${CERT_DIR}/${CERT_BASE}.backup" ]]; then
  BACKUP_FILE="${CERT_DIR}/${CERT_BASE}.backup"
elif [[ -f "${CERT_DIR}/${CERT_BASE}.old" ]]; then
  BACKUP_FILE="${CERT_DIR}/${CERT_BASE}.old"
else
  print_error "No se encontró respaldo para ${CERT_BASE}"
  exit 1
fi

echo
echo "Respaldo encontrado: ${BACKUP_FILE}"
echo
echo "Información del certificado de respaldo:"
if ! openssl x509 -in "${BACKUP_FILE}" -noout -subject -dates 2>/dev/null; then
  echo "No se pudo leer el certificado"
fi
echo

read -p "¿Revertir a este certificado? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Reversión cancelada"
  exit 0
fi

echo
print_info "Revirtiendo..."

# Guardar actual como .rollback
if [[ -f "${CERT_DIR}/${CERT_BASE}" ]]; then
  cp "${CERT_DIR}/${CERT_BASE}" "${CERT_DIR}/${CERT_BASE}.rollback"
  print_success "Actual guardado como ${CERT_BASE}.rollback"
fi

# Restaurar respaldo
cp "${BACKUP_FILE}" "${CERT_DIR}/${CERT_BASE}"
print_success "Certificado revertido"

# Intentar revertir clave también
KEY_BASE="${CERT_BASE%.crt}.key"
if [[ -f "${KEY_DIR}/${KEY_BASE}.backup" ]]; then
  cp "${KEY_DIR}/${KEY_BASE}" "${KEY_DIR}/${KEY_BASE}.rollback" 2>/dev/null || true
  cp "${KEY_DIR}/${KEY_BASE}.backup" "${KEY_DIR}/${KEY_BASE}"
  chmod 600 "${KEY_DIR}/${KEY_BASE}"
  print_success "Clave privada revertida"
elif [[ -f "${KEY_DIR}/${KEY_BASE}.old" ]]; then
  cp "${KEY_DIR}/${KEY_BASE}" "${KEY_DIR}/${KEY_BASE}.rollback" 2>/dev/null || true
  cp "${KEY_DIR}/${KEY_BASE}.old" "${KEY_DIR}/${KEY_BASE}"
  chmod 600 "${KEY_DIR}/${KEY_BASE}"
  print_success "Clave privada revertida"
fi

echo
print_success "Reversión completada"
echo
echo "Reiniciar servicios para aplicar cambios"
echo
echo "Si la reversión no funcionó, restaure desde archivos .rollback:"
echo "  cp ${CERT_DIR}/${CERT_BASE}.rollback ${CERT_DIR}/${CERT_BASE}"
