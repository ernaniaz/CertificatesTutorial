#!/usr/bin/env bash
#=============================================================================
# Lab 10: Configurar TLS
# Configura SSL/TLS para PostgreSQL
#
# Uso: ./configure-tls.sh
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

CERT_DIR="../04-x509-certificates/output"
KEY_DIR="../02-key-generation/output"
PG_DATA="/var/lib/pgsql/data"

print_header "Lab 10: Configurando TLS de PostgreSQL"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

# Verificar requisitos previos
if [[ ! -f "${CERT_DIR}/server.crt" || ! -f "${KEY_DIR}/rsa-2048.key" ]]; then
  print_error "Error: No se encontraron certificados. Complete primero los Labs 02 y 04."
  exit 1
fi

# Crear respaldo de la configuración original
print_info "Creando respaldo de la configuración original..."
if [[ ! -f "${PG_DATA}/postgresql.conf.lab-backup" ]]; then
  cp "${PG_DATA}/postgresql.conf" "${PG_DATA}/postgresql.conf.lab-backup"
  print_success "postgresql.conf respaldado"
fi

if [[ ! -f "${PG_DATA}/pg_hba.conf.lab-backup" ]]; then
  cp "${PG_DATA}/pg_hba.conf" "${PG_DATA}/pg_hba.conf.lab-backup"
  print_success "pg_hba.conf respaldado"
fi

echo

# Copiar certificados al directorio de datos de PostgreSQL
print_info "Copiando certificados..."
cp "${CERT_DIR}/server.crt" "${PG_DATA}/server.crt"
cp "${KEY_DIR}/rsa-2048.key" "${PG_DATA}/server.key"
chmod 644 "${PG_DATA}/server.crt"
chmod 600 "${PG_DATA}/server.key"
chown postgres:postgres "${PG_DATA}/server.crt"
chown postgres:postgres "${PG_DATA}/server.key"

print_success "Certificados copiados"
echo

# Habilitar SSL en postgresql.conf
print_info "Habilitando SSL en postgresql.conf..."

# Eliminar ajustes ssl existentes para evitar duplicados
sed -i '/^ssl = /d' "${PG_DATA}/postgresql.conf"
sed -i '/^ssl_cert_file = /d' "${PG_DATA}/postgresql.conf"
sed -i '/^ssl_key_file = /d' "${PG_DATA}/postgresql.conf"
sed -i '/^ssl_ciphers = /d' "${PG_DATA}/postgresql.conf"
sed -i '/^ssl_prefer_server_ciphers = /d' "${PG_DATA}/postgresql.conf"
sed -i '/^ssl_min_protocol_version = /d' "${PG_DATA}/postgresql.conf"

# Detectar número de versión de PostgreSQL (ej. 90209, 100019, 120015)
PG_VERSION_NUM="$(sudo -u postgres psql -t -c "SHOW server_version_num;" 2>/dev/null | tr -d '[:space:]')"
PG_VERSION_NUM="${PG_VERSION_NUM:-0}"

# Agregar configuración SSL
cat >> "${PG_DATA}/postgresql.conf" << 'EOF'

# Lab 10: Configuración SSL/TLS
ssl = on
ssl_cert_file = 'server.crt'
ssl_key_file = 'server.key'
ssl_ciphers = 'HIGH:MEDIUM:+3DES:!aNULL'
EOF

# ssl_prefer_server_ciphers requiere PostgreSQL 9.4+ (90400)
if [[ ${PG_VERSION_NUM} -ge 90400 ]]; then
  echo "ssl_prefer_server_ciphers = on" >> "${PG_DATA}/postgresql.conf"
fi

# ssl_min_protocol_version requiere PostgreSQL 12+ (120000)
if [[ ${PG_VERSION_NUM} -ge 120000 ]]; then
  echo "ssl_min_protocol_version = 'TLSv1.2'" >> "${PG_DATA}/postgresql.conf"
fi

print_success "SSL habilitado en postgresql.conf"
echo

# Configurar pg_hba.conf para soportar conexiones SSL
print_info "Configurando pg_hba.conf para SSL..."

# Agregar reglas hostssl (permitir SSL y no-SSL para flexibilidad del lab)
cat >> "${PG_DATA}/pg_hba.conf" << 'EOF'

# Lab 10: Conexiones SSL
hostssl    all    all    127.0.0.1/32    md5
hostssl    all    all    ::1/128         md5
EOF

print_success "pg_hba.conf configurado"
echo

# Reiniciar PostgreSQL
print_info "Reiniciando PostgreSQL..."
systemctl restart postgresql

if systemctl is-active postgresql &>/dev/null; then
  print_success "PostgreSQL reiniciado correctamente"
else
  print_error "Error al reiniciar PostgreSQL"
  journalctl -xeu postgresql | tail -20
  exit 1
fi

echo

# Verificar que SSL esté habilitado
print_info "Verificando configuración SSL..."
SSL_STATUS="$(sudo -u postgres psql -t -c "SHOW ssl;" 2>/dev/null | tr -d '[:space:]')"

if [[ ${SSL_STATUS} == on ]]; then
  print_success "SSL está habilitado"
else
  print_error "SSL no está habilitado"
  exit 1
fi

echo
print_success "Configuración TLS de PostgreSQL completada"
echo
echo "Probar conexión SSL:"
echo "  psql \"host=localhost sslmode=require user=postgres\""
echo "  sudo -u postgres psql -c \"SELECT * FROM pg_stat_ssl WHERE pid = pg_backend_pid();\""
