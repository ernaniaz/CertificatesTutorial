#!/usr/bin/env bash
#=============================================================================
# Lab 09: Limpieza
# Elimina OpenLDAP y restaura el estado del sistema
#
# Uso: ./cleanup.sh
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

print_header "Lab 09: Limpieza"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

# Confirmación
print_warning "Esto eliminará OpenLDAP y todas las configuraciones del lab."
read -p "¿Continuar? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Limpieza cancelada"
  exit 0
fi

echo

# Detener slapd
if systemctl is-active slapd &>/dev/null; then
  print_info "Deteniendo slapd..."
  systemctl stop slapd
  systemctl disable slapd
  print_success "slapd detenido"
fi

echo

# Restaurar configuraciones originales
if [[ -f /etc/sysconfig/slapd.lab-backup ]]; then
  print_info "Restaurando configuración de slapd..."
  mv /etc/sysconfig/slapd.lab-backup /etc/sysconfig/slapd
  print_success "Configuración de slapd restaurada"
fi

if [[ -f /etc/openldap/ldap.conf.lab-backup ]]; then
  print_info "Restaurando configuración del cliente..."
  mv /etc/openldap/ldap.conf.lab-backup /etc/openldap/ldap.conf
  print_success "Configuración del cliente restaurada"
fi

echo

# Eliminar paquetes OpenLDAP
print_info "Eliminando paquetes OpenLDAP..."
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum remove -y openldap-servers openldap-clients
else
  dnf remove -y openldap-servers openldap-clients
fi

print_success "OpenLDAP eliminado"
echo

# Eliminar certificados del lab
print_info "Eliminando certificados del lab..."
rm -rf /etc/openldap/certs/ldap.crt
rm -rf /etc/openldap/certs/ldap.key
print_success "Certificados eliminados"
echo

# Eliminar datos de OpenLDAP (opcional - comentado por seguridad)
# echo -e "${BLUE}Eliminando datos de OpenLDAP...${NC}"
# rm -rf /var/lib/ldap/*
# rm -rf /etc/openldap/slapd.d/*
# echo -e "${GREEN}✓ Datos eliminados${NC}"

# Eliminar reglas del firewall
print_info "Limpiando reglas del firewall..."
if command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null; then
  firewall-cmd --permanent --remove-service=ldap 2>/dev/null || true
  firewall-cmd --permanent --remove-service=ldaps 2>/dev/null || true
  firewall-cmd --reload
  print_success "Reglas del firewall eliminadas"
fi

echo
print_success "Limpieza completada"
echo
echo "Sistema restaurado al estado previo al lab."
