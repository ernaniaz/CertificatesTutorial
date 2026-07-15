#!/usr/bin/env bash
#=============================================================================
# Lab 11: Instalar certmonger
# Instala y configura el servicio certmonger
#
# Uso: ./install-certmonger.sh
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

print_header "Lab 11: Instalación de certmonger"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

# Detectar versión de RHEL
echo "Versión de RHEL: ${RHEL_VERSION}"
echo

# Instalar certmonger
print_info "Instalando certmonger..."

if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum install -y certmonger
else
  dnf install -y certmonger
fi

print_success "certmonger instalado"
echo

# Habilitar e iniciar certmonger
print_info "Habilitando e iniciando el servicio certmonger..."
systemctl enable certmonger
systemctl start certmonger

print_success "servicio certmonger iniciado"
echo

# Verificar instalación
if systemctl is-active certmonger &>/dev/null; then
  print_success "certmonger está en ejecución"
else
  print_error "certmonger no pudo iniciarse"
  exit 1
fi

# Mostrar versión de certmonger
echo
echo "Versión del paquete certmonger:"
rpm -q certmonger

# Listar CAs disponibles
echo
echo "CAs disponibles:"
if ! getcert list-cas 2>/dev/null; then
  echo "Aún no hay CAs configuradas"
fi

echo
print_success "instalación de certmonger completada"
echo
echo "Estado de certmonger:"
systemctl status certmonger --no-pager | head -5

echo
echo "Pruebe estos comandos:"
echo "  getcert list"
echo "  getcert list-cas"
echo "  journalctl -u certmonger -f"
