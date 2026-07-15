#!/usr/bin/env bash
#=============================================================================
# Lab 08: Probar STARTTLS
# Prueba la capacidad STARTTLS
#
# Uso: ./test-starttls.sh
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

print_header "Lab 08: Probando STARTTLS (Puerto 25)"

# Probar conexión SMTP básica
print_info "Probando conexión SMTP en el puerto 25..."
if timeout 5 bash -c "echo QUIT | nc localhost 25" 2>/dev/null | grep -q "220"; then
  print_success "Puerto SMTP 25 respondiendo"
else
  print_error "No se puede conectar al puerto 25"
  exit 1
fi

echo

# Probar capacidad STARTTLS
print_info "Probando capacidad STARTTLS..."
EHLO_RESPONSE="$(timeout 5 bash -c "echo -e 'EHLO localhost\nQUIT' | nc localhost 25" 2>/dev/null)"

if echo "${EHLO_RESPONSE}" | grep -q "STARTTLS"; then
  print_success "STARTTLS anunciado"
else
  print_error "STARTTLS no anunciado"
  echo "Respuesta EHLO:"
  echo "${EHLO_RESPONSE}"
  exit 1
fi

echo

# Probar handshake STARTTLS
print_info "Probando handshake STARTTLS..."
STARTTLS_TEST="$(echo "QUIT" | openssl s_client -connect localhost:25 -starttls smtp -brief 2>&1)"

if echo "${STARTTLS_TEST}" | grep -q "Cipher\|Protocol"; then
  print_success "Handshake STARTTLS exitoso"

  # Extraer protocolo y cifrado
  PROTOCOL="$(echo "${STARTTLS_TEST}" | grep "Protocol" | head -1)"
  CIPHER="$(echo "${STARTTLS_TEST}" | grep "Cipher" | head -1)"

  if [[ -n "${PROTOCOL}" ]]; then
    echo "  ${PROTOCOL}"
  fi
  if [[ -n "${CIPHER}" ]]; then
    echo "  ${CIPHER}"
  fi
else
  print_warning "No se pudieron extraer detalles TLS, pero la conexión puede funcionar"
fi

echo

# Probar certificado
print_info "Probando certificado..."
CERT_INFO="$(echo "QUIT" | openssl s_client -connect localhost:25 -starttls smtp 2>&1)"

if echo "${CERT_INFO}" | grep -q "Server certificate"; then
  print_success "Certificado presentado"

  # Extraer subject
  SUBJECT="$(echo "${CERT_INFO}" | grep "subject=" | head -1)"
  if [[ -n "${SUBJECT}" ]]; then
    echo "  ${SUBJECT}"
  fi

  # Extraer validez
  echo "${CERT_INFO}" | grep -E "Not Before|Not After" | head -2 | sed 's/^/  /'
else
  print_warning "No se pudieron extraer detalles del certificado"
fi

echo
print_success "Pruebas STARTTLS completadas"
echo
echo "Comando de prueba manual:"
echo "  openssl s_client -connect localhost:25 -starttls smtp"
