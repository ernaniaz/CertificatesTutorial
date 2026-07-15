#!/usr/bin/env bash
#=============================================================================
# Lab 16: Restaurar copia de seguridad
# Restaura certificados conocidos como buenos
#
# Uso: ./restore-backup.sh
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

print_header "Lab 16: Restaurar certificados desde respaldo"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

# Buscar respaldos disponibles
print_info "Respaldos disponibles:"
if ls -d /root/cert-backup-* 2>/dev/null; then
  echo
else
  echo "No se encontraron respaldos en /root/cert-backup-*"
  echo
  echo "Buscando archivos .backup..."
  if ! find /etc/pki/tls -name "*.backup" -o -name "*.old" 2>/dev/null; then
    echo "No se encontraron archivos de respaldo"
  fi
  exit 1
fi

echo
read -p "Ingrese la ruta del directorio de respaldo: " BACKUP_DIR

if [[ ! -d "${BACKUP_DIR}" ]]; then
  print_error "Directorio de respaldo no encontrado"
  exit 1
fi

echo
echo "Directorio de respaldo: ${BACKUP_DIR}"
echo "Contenido:"
ls -lh "${BACKUP_DIR}"
echo

read -p "¿Restaurar desde este respaldo? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Restauración cancelada"
  exit 0
fi

echo
print_info "Restaurando certificados..."

# Crear respaldo de seguridad del estado actual
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p /root/cert-before-restore-${TIMESTAMP}
cp -r /etc/pki/tls/certs/* /root/cert-before-restore-${TIMESTAMP}/ 2>/dev/null || true
cp -r /etc/pki/tls/private/* /root/cert-before-restore-${TIMESTAMP}/ 2>/dev/null || true
print_success "Estado actual respaldado en /root/cert-before-restore-${TIMESTAMP}/"

# Restaurar certificados
for file in "${BACKUP_DIR}"/*.crt; do
  if [[ -f "${file}" ]]; then
    filename="$(basename "${file}")"
    cp "${file}" "${CERT_DIR}/${filename}"
    print_success "Restaurado ${filename}"
  fi
done

# Restaurar claves privadas
for file in "${BACKUP_DIR}"/*.key; do
  if [[ -f "${file}" ]]; then
    filename="$(basename "${file}")"
    cp "${file}" "${KEY_DIR}/${filename}"
    chmod 600 "${KEY_DIR}/${filename}"
    print_success "Restaurado ${filename}"
  fi
done

echo
print_success "Restauración completada"
echo
echo "Reiniciar servicios afectados:"
echo "  systemctl restart httpd"
echo "  systemctl restart nginx"
echo
echo "Si la restauración no funcionó, revierta con:"
echo "  cp /root/cert-before-restore-${TIMESTAMP}/* /etc/pki/tls/certs/"
