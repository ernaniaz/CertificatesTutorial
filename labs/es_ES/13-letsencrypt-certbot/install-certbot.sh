#!/usr/bin/env bash
#=============================================================================
# Lab 13: Instalar Certbot
# Instala certbot para Let's Encrypt
#
# Uso: ./install-certbot.sh
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

print_header "Lab 13: Instalación de Certbot"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

# Detectar versión de RHEL
echo "Versión de RHEL: ${RHEL_VERSION}"
echo

# Instalar Certbot
print_info "Habilitando repositorio EPEL..."
dnf install -y epel-release || dnf install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${RHEL_VERSION}.noarch.rpm"
print_success "EPEL habilitado"
echo

print_info "Instalando certbot..."

dnf install -y certbot python3-certbot-apache python3-certbot-nginx

print_success "Certbot instalado"
echo

# Mostrar versión de certbot
certbot --version

echo
print_success "Instalación de Certbot completada"
echo
print_warning "Nota: Let's Encrypt requiere:"
echo "  - Conectividad a Internet"
echo "  - Puerto 80 accesible (para desafío HTTP-01)"
echo "  - Nombre de dominio válido apuntando a este servidor"
echo
print_warning "Para pruebas sin un dominio real, use:"
echo "  - Modo standalone (servidor integrado temporal)"
echo "  - Entorno staging: certbot --staging"
echo
echo "Comandos disponibles:"
echo "  certbot --help"
echo "  certbot certificates"
echo "  certbot renew --dry-run"
