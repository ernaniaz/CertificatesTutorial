#!/usr/bin/env bash
#=============================================================================
# Lab 19: Configurar servicios en FIPS
# Garantiza que los servicios cumplan los requisitos FIPS
#
# Uso: ./configure-services-fips.sh
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

print_header "Lab 19: Configurar servicios para FIPS"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: este script debe ejecutarse como root (use sudo)"
  exit 1
fi

# Verificar si FIPS está habilitado
if [[ -f /proc/sys/crypto/fips_enabled && "$(cat /proc/sys/crypto/fips_enabled)" != "1" ]]; then
  print_warning "Modo FIPS no habilitado"
  echo "Habilite FIPS primero con ./enable-fips.sh"
  echo
fi

print_info "Verificando configuraciones de servicios..."
echo

# Apache
if [[ -d /etc/httpd/conf.d ]]; then
  print_info "Apache (httpd):"
  echo "  En modo FIPS, crypto-policy restringe cifras automáticamente"
  echo "  Elimine directivas SSLProtocol/SSLCipherSuite manuales"
  echo

  if grep -r "^[^#]*SSLCipherSuite" /etc/httpd/conf.d/ 2>/dev/null | grep -q .; then
    echo -e "  ${YELLOW}⚠ Configuración manual de cifras encontrada${NC}"
    echo "    Considere eliminarla para usar crypto-policy FIPS"
  else
    echo -e "  ${GREEN}✓ Usando valores predeterminados de crypto-policy${NC}"
  fi
  echo
fi

# NGINX
if [[ -d /etc/nginx ]]; then
  print_info "NGINX:"
  echo "  NGINX requiere configuración explícita de cifras"
  echo "  Use solo cifras aprobadas por FIPS"
  echo

  echo "  Cifras FIPS recomendadas para NGINX:"
  echo "    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';"
  echo
fi

# OpenSSH
if [[ -f /etc/ssh/sshd_config ]]; then
  print_info "OpenSSH:"
  echo "  Crypto-policy configura algoritmos compatibles con FIPS automáticamente"
  echo -e "  ${GREEN}✓ No se necesita configuración manual${NC}"
  echo
fi

# Postfix
if [[ -f /etc/postfix/main.cf ]]; then
  print_info "Postfix:"
  echo "  Crypto-policy configura TLS compatible con FIPS"
  if grep -q "^smtpd_tls_ciphers = high" /etc/postfix/main.cf; then
    echo -e "  ${GREEN}✓ Grado alto de cifras configurado${NC}"
  else
    echo "  Configure: smtpd_tls_ciphers = high"
  fi
  echo
fi

print_success "Revisión de configuración de servicios completada"
echo
echo "Después de habilitar FIPS:"
echo "  1. Reinicie todos los servicios"
echo "  2. Pruebe la conectividad"
echo "  3. Supervise errores"
echo "  4. Actualice configuraciones no compatibles"
