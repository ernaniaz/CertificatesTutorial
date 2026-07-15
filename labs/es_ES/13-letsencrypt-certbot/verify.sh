#!/usr/bin/env bash
#=============================================================================
# Lab 13: Verificar
# Pasos de verificación
#
# Uso: ./verify.sh
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

print_header "Lab 13: Verificación de Certbot"

print_info "1. Versión de certbot:"
certbot --version

echo

print_info "2. Certificados existentes:"
if certbot certificates 2>/dev/null | grep -q "Certificate Name:"; then
  certbot certificates
else
  print_warning "No se encontraron certificados"
fi

echo

print_info "3. Archivos de certificados:"
if [[ -d /etc/letsencrypt/live ]]; then
  echo "Directorios de certificados:"
  ls -1d /etc/letsencrypt/live/*/ 2>/dev/null | while read dir; do
    echo "  ${dir}"
    ls -l "${dir}" 2>/dev/null | grep -E "\.pem$" | sed 's/^/    /'
  done
else
  echo "No hay directorios de certificados"
fi

echo

print_info "4. Configuración de renovación:"
if [[ -d /etc/letsencrypt/renewal ]]; then
  echo "Configuraciones de renovación:"
  if ! ls -1 /etc/letsencrypt/renewal/*.conf 2>/dev/null | sed 's/^/  /'; then
    echo "  Ninguno"
  fi
else
  echo "No hay configuraciones de renovación"
fi

echo

print_info "5. Renovación automática:"

if [[ ${RHEL_VERSION} -ge 8 ]]; then
  if systemctl is-active certbot-renew.timer &>/dev/null; then
    print_success "Temporizador systemd activo"
    systemctl list-timers certbot-renew.timer --no-pager 2>/dev/null || true
  else
    echo "El temporizador no está activo"
  fi
else
  if crontab -l 2>/dev/null | grep -q "certbot renew"; then
    print_success "Trabajo cron configurado"
    crontab -l 2>/dev/null | grep "certbot renew"
  else
    echo "No se encontró trabajo cron"
  fi
fi

echo

print_info "6. Archivos de registro:"
if [[ -d /var/log/letsencrypt ]]; then
  echo "Archivos de registro recientes:"
  if ! ls -lt /var/log/letsencrypt/*.log 2>/dev/null | head -3 | sed 's/^/  /'; then
    echo "  Sin registros"
  fi
else
  echo "Directorio de registros no encontrado"
fi

echo
print_success "Verificación completada"
