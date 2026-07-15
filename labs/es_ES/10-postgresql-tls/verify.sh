#!/usr/bin/env bash
#=============================================================================
# Lab 10: Verificar
# Pasos de verificación manual
#
# Uso: ./verify.sh
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

PG_DATA="/var/lib/pgsql/data"

print_header "Lab 10: Verificación TLS de PostgreSQL"

print_info "1. Verificando servicio PostgreSQL..."
systemctl status postgresql --no-pager | head -5
echo

print_info "2. Verificando puerto escuchando..."
ss -tlnp | grep 5432
echo

print_info "3. Verificando configuración SSL..."
echo "Ajuste SSL en postgresql.conf:"
if ! grep "^ssl = " "${PG_DATA}/postgresql.conf"; then
  echo "No configurado"
fi
echo
echo "Archivo de certificado SSL:"
if ! grep "^ssl_cert_file = " "${PG_DATA}/postgresql.conf"; then
  echo "No configurado"
fi
echo
echo "Archivo de clave SSL:"
if ! grep "^ssl_key_file = " "${PG_DATA}/postgresql.conf"; then
  echo "No configurado"
fi
echo

print_info "4. Verificando archivos de certificado..."
if [[ -f "${PG_DATA}/server.crt" ]]; then
  print_success "El certificado existe"
  openssl x509 -in "${PG_DATA}/server.crt" -noout -subject -dates
else
  echo "Certificado no encontrado"
fi
echo

print_info "5. Verificando clave privada..."
if [[ -f "${PG_DATA}/server.key" ]]; then
  print_success "La clave privada existe"
  ls -l "${PG_DATA}/server.key"
  PERMS="$(stat -c%a "${PG_DATA}/server.key")"
  if [[ "${PERMS}" == "600" ]]; then
    print_success "Permisos correctos (600)"
  else
    print_warning "Permisos: ${PERMS} (deberían ser 600)"
  fi

  OWNER="$(stat -c%U "${PG_DATA}/server.key")"
  if [[ "${OWNER}" == "postgres" ]]; then
    print_success "Propietario correcto (postgres)"
  else
    print_warning "Propietario: ${OWNER} (debería ser postgres)"
  fi
else
  echo "Clave privada no encontrada"
fi
echo

print_info "6. Verificando estado SSL en la base de datos..."
SSL_STATUS="$(sudo -u postgres psql -t -c "SHOW ssl;" 2>/dev/null | tr -d '[:space:]')"
if [[ ${SSL_STATUS} == on ]]; then
  print_success "SSL habilitado en la base de datos (ssl=${SSL_STATUS})"
else
  echo "Estado SSL: ${SSL_STATUS}"
fi
echo

print_info "7. Verificando pg_hba.conf para reglas SSL..."
echo "Reglas de conexión SSL:"
if ! grep "^hostssl" "${PG_DATA}/pg_hba.conf"; then
  echo "No hay reglas hostssl configuradas"
fi
echo

print_info "8. Probando conexión a la base de datos..."
if sudo -u postgres psql -c "SELECT 'Connection OK';" &>/dev/null; then
  print_success "Conexión a la base de datos funciona"
fi

print_info "9. Consultando información SSL del servidor..."
if sudo -u postgres psql -t -c "SELECT 1 FROM pg_stat_ssl LIMIT 0;" &>/dev/null; then
  SSL_CONNS="$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_stat_ssl WHERE ssl = true;" 2>/dev/null | tr -d '[:space:]')"
  echo "  Conexiones SSL activas: ${SSL_CONNS:-0}"
  sudo -u postgres psql -c "SHOW ssl; SHOW ssl_cert_file; SHOW ssl_key_file;" 2>/dev/null
else
  echo "  pg_stat_ssl no disponible (requiere PostgreSQL 9.5+)"
  sudo -u postgres psql -c "SHOW ssl;" 2>/dev/null || echo "  Información SSL no disponible"
fi

echo
print_success "Verificación completada"
