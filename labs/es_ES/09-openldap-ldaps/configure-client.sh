#!/usr/bin/env bash
#=============================================================================
# Lab 09: Configurar cliente
# Configura el cliente LDAP para conexiones TLS
#
# Uso: ./configure-client.sh
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

print_header "Lab 09: Configurando cliente LDAP"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

# Crear respaldo de la configuración original del cliente
print_info "Creando respaldo de la configuración del cliente..."
if [[ -f /etc/openldap/ldap.conf ]]; then
  if [[ ! -f /etc/openldap/ldap.conf.lab-backup ]]; then
    cp /etc/openldap/ldap.conf /etc/openldap/ldap.conf.lab-backup
    print_success "Configuración respaldada"
  else
    echo "El respaldo ya existe"
  fi
else
  echo "No existe ldap.conf, creando uno nuevo"
fi

echo

# Configurar ajustes TLS del cliente
print_info "Configurando ajustes TLS del cliente..."

cat >> /etc/openldap/ldap.conf << 'EOF'

# Lab 09: Configuración TLS del cliente
TLS_CACERTDIR /etc/openldap/certs
TLS_REQCERT allow

# URI predeterminada
URI ldap://localhost

# Base DN (ajustar según sea necesario)
BASE dc=example,dc=com
EOF

print_success "Ajustes TLS del cliente configurados"
echo

# Mostrar configuración
echo "Configuración del cliente:"
grep -v "^#" /etc/openldap/ldap.conf | grep -v "^$" | tail -6

echo
print_success "Configuración del cliente LDAP completada"
echo
echo "Probar con:"
echo "  ldapsearch -x -H ldap://localhost -b \"\" -s base"
echo "  ldapsearch -x -H ldaps://localhost -b \"\" -s base"
echo "  ldapsearch -x -H ldap://localhost -b \"\" -s base -ZZ"
