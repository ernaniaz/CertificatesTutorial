#!/usr/bin/env bash
#=============================================================================
# Lab 09: Instalar OpenLDAP
# Instala el servidor y clientes OpenLDAP
#
# Uso: ./install-openldap.sh
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

print_header "Lab 09: Instalando OpenLDAP"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

# Detectar versión de RHEL
echo "Versión de RHEL: ${RHEL_VERSION}"
echo

# Instalar OpenLDAP
print_info "Instalando paquetes OpenLDAP..."

if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum install -y openldap openldap-servers openldap-clients
elif [[ ${RHEL_VERSION} -eq 8 ]]; then
  dnf install -y openldap openldap-servers openldap-clients
else
  # RHEL 9+: openldap-servers eliminado de los repos base, instalar desde EPEL
  dnf install -y epel-release || dnf install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${RHEL_VERSION}.noarch.rpm"
  dnf install -y openldap openldap-servers openldap-clients
fi

print_success "OpenLDAP instalado"
echo

# Habilitar e iniciar slapd
print_info "Habilitando e iniciando el servicio slapd..."
systemctl enable slapd
systemctl start slapd

print_success "Servicio slapd iniciado"
echo

# Configurar firewall
print_info "Configurando firewall..."
if command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null; then
  firewall-cmd --permanent --add-service=ldap
  firewall-cmd --permanent --add-service=ldaps
  firewall-cmd --reload
  print_success "Firewall configurado (puertos 389, 636)"
else
  echo "firewalld no está en ejecución, omitiendo configuración del firewall"
fi

echo

# Verificar instalación
if systemctl is-active slapd &>/dev/null; then
  print_success "slapd está en ejecución"
else
  print_error "Error al iniciar slapd"
  exit 1
fi

# Verificar si escucha en el puerto 389
if ss -tlnp | grep -q ':389'; then
  print_success "LDAP escuchando en el puerto 389"
fi

# Mostrar versión de OpenLDAP
echo
echo "Versión de OpenLDAP:"
slapd -VV 2>&1 | head -1

echo
print_success "Instalación de OpenLDAP completada"
echo
echo "Estado de slapd:"
systemctl status slapd --no-pager | head -5
