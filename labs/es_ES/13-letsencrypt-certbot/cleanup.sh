#!/usr/bin/env bash
#=============================================================================
# Lab 13: Limpieza
# Elimina certbot y los certificados
#
# Uso: ./cleanup.sh
# Requisitos previos: RHEL 8, 9, 10, privilegios de root
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

print_header "Lab 13: Limpieza"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

# Confirmación
print_warning "Esto eliminará certbot y todos los certificados."
read -p "¿Continuar? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Limpieza cancelada"
  exit 0
fi

echo

# Eliminar todos los certificados
if command -v certbot &>/dev/null && [[ -d /etc/letsencrypt/live ]]; then
  print_info "Eliminando certificados..."
  for cert_dir in /etc/letsencrypt/live/*/; do
    if [[ -d "${cert_dir}" ]]; then
      cert_name="$(basename "${cert_dir}")"
      echo "Eliminando certificado: ${cert_name}"
      certbot delete --cert-name "${cert_name}" --non-interactive 2>/dev/null || true
    fi
  done
  print_success "Certificados eliminados"
fi

echo

# Detener y deshabilitar temporizador
print_info "Deshabilitando temporizador de certbot..."
systemctl stop certbot-renew.timer 2>/dev/null || true
systemctl disable certbot-renew.timer 2>/dev/null || true
print_success "Temporizador deshabilitado"

echo

# Eliminar paquete certbot
print_info "Eliminando paquete certbot..."

dnf remove -y certbot python3-certbot-apache python3-certbot-nginx 2>/dev/null || true

print_success "Certbot eliminado"
echo

# Eliminar directorio de Let's Encrypt
print_info "Eliminando directorio de Let's Encrypt..."
rm -rf /etc/letsencrypt
rm -rf /var/log/letsencrypt
print_success "Directorios eliminados"

echo
print_success "Limpieza completada"
echo
echo "Sistema restaurado al estado previo al lab."
