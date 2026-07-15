#!/usr/bin/env bash
#=============================================================================
# Lab 10: Probar conexión
# Prueba conexiones a la base de datos con y sin SSL
#
# Uso: ./test-connection.sh
# Requisitos previos: RHEL 7, 8, 9, 10
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

print_header "Lab 10: Probando SSL de PostgreSQL"

# Probar conexión básica
print_info "1. Probando conexión básica..."
if sudo -u postgres psql -c "SELECT version();" &>/dev/null; then
  print_success "Conexión básica exitosa"
else
  print_error "Conexión básica fallida"
  exit 1
fi

echo

# Probar estado SSL
print_info "2. Verificando estado SSL..."
SSL_STATUS="$(sudo -u postgres psql -t -c "SHOW ssl;" | tr -d '[:space:]')"

if [[ ${SSL_STATUS} == on ]]; then
  print_success "SSL está habilitado (ssl=${SSL_STATUS})"
else
  print_error "SSL no está habilitado"
  exit 1
fi

echo

# Probar conexión con sslmode=require
print_info "3. Probando conexión con sslmode=require..."
if sudo -u postgres psql "sslmode=require" -c "SELECT 1;" &>/dev/null; then
  print_success "Conexión SSL exitosa"
else
  print_warning "Conexión SSL con sslmode=require fallida"
fi

echo

# Consultar configuración SSL del servidor
print_info "4. Consultando configuración SSL del servidor..."
if sudo -u postgres psql -t -c "SELECT 1 FROM pg_stat_ssl LIMIT 0;" &>/dev/null; then
  SSL_STATUS="$(sudo -u postgres psql -t -c "SHOW ssl;" 2>/dev/null | tr -d '[:space:]')"
  SSL_CERT="$(sudo -u postgres psql -t -c "SHOW ssl_cert_file;" 2>/dev/null | tr -d '[:space:]')"
  SSL_KEY="$(sudo -u postgres psql -t -c "SHOW ssl_key_file;" 2>/dev/null | tr -d '[:space:]')"
  if [[ "${SSL_STATUS}" == "on" ]]; then
    print_success "Configuración SSL del servidor:"
    echo "  ssl = ${SSL_STATUS}"
    echo "  ssl_cert_file = ${SSL_CERT}"
    echo "  ssl_key_file = ${SSL_KEY}"
  else
    print_warning "SSL no está habilitado en el servidor"
  fi
else
  print_warning "pg_stat_ssl no disponible (requiere PostgreSQL 9.5+)"
  SSL_STATUS="$(sudo -u postgres psql -t -c "SHOW ssl;" 2>/dev/null | tr -d '[:space:]')"
  if [[ "${SSL_STATUS}" == "on" ]]; then
    print_success "SSL está habilitado (verificado mediante SHOW ssl)"
  fi
fi

echo

# Probar SSL con variable de entorno psql
print_info "5. Probando con variable de entorno PGSSLMODE..."
if PGSSLMODE=require sudo -u postgres psql -c "SELECT 'SSL test';" &>/dev/null; then
  print_success "Conexión con PGSSLMODE=require exitosa"
else
  print_warning "Conexión con PGSSLMODE=require fallida"
fi

echo

# Mostrar todas las conexiones SSL actuales
print_info "6. Mostrando estadísticas de conexión SSL..."
echo "Conexiones SSL activas:"
if ! sudo -u postgres psql -c "SELECT datname, usename, ssl, version, cipher FROM pg_stat_ssl JOIN pg_stat_activity USING (pid) WHERE ssl = true;" 2>/dev/null; then
  echo "No hay conexiones SSL o pg_stat_ssl no disponible"
fi

echo
print_success "Pruebas SSL completadas"
echo
echo "Comandos de prueba manual:"
echo "  sudo -u postgres psql \"sslmode=require\""
echo "  sudo -u postgres psql -c \"SHOW ssl;\""
echo "  sudo -u postgres psql -c \"SELECT * FROM pg_stat_ssl WHERE pid = pg_backend_pid();\""
