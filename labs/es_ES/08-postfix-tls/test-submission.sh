#!/usr/bin/env bash
#=============================================================================
# Lab 08: Probar Submission
# Prueba el puerto submission con TLS obligatorio
#
# Uso: ./test-submission.sh
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

print_header "Lab 08: Probando puerto Submission (587)"

# Probar si el puerto submission está escuchando
print_info "Probando puerto submission 587..."
if ss -tlnp | grep -q ':587'; then
  print_success "Puerto 587 escuchando"
else
  print_error "Puerto 587 no escuchando"
  echo "Verifique la configuración de master.cf"
  exit 1
fi

echo

# Probar EHLO en el puerto submission
print_info "Probando EHLO en el puerto submission..."
EHLO_RESPONSE="$(timeout 5 bash -c "echo -e 'EHLO localhost\nQUIT' | nc localhost 587" 2>/dev/null)"

if echo "${EHLO_RESPONSE}" | grep -q "220"; then
  print_success "Puerto submission respondiendo"
else
  print_error "El puerto submission no responde correctamente"
  exit 1
fi

# Verificar STARTTLS
if echo "${EHLO_RESPONSE}" | grep -q "STARTTLS"; then
  print_success "STARTTLS disponible"
fi

# Verificar AUTH
if echo "${EHLO_RESPONSE}" | grep -q "AUTH"; then
  print_success "Métodos AUTH anunciados"
fi

echo

# Probar conexión TLS en el puerto submission
print_info "Probando TLS en el puerto submission..."
TLS_TEST="$(echo "QUIT" | openssl s_client -connect localhost:587 -starttls smtp -brief 2>&1)"

if echo "${TLS_TEST}" | grep -q "Cipher\|Protocol"; then
  print_success "Conexión TLS exitosa"

  # Extraer protocolo
  PROTOCOL="$(echo "${TLS_TEST}" | grep "Protocol" | head -1)"
  if [[ -n "${PROTOCOL}" ]]; then
    echo "  ${PROTOCOL}"
  fi

  # Extraer cifrado
  CIPHER="$(echo "${TLS_TEST}" | grep "Cipher" | head -1)"
  if [[ -n "${CIPHER}" ]]; then
    echo "  ${CIPHER}"
  fi
else
  print_warning "Prueba TLS no concluyente"
fi

echo

# Verificar nivel de seguridad TLS
print_info "Verificando nivel de seguridad TLS..."
TLS_LEVEL="$(postconf -h smtpd_tls_security_level 2>/dev/null || echo "no configurado")"
echo "  smtpd_tls_security_level: ${TLS_LEVEL}"

# Verificar si submission requiere cifrado
if grep -q "smtpd_tls_security_level=encrypt" /etc/postfix/master.cf; then
  print_success "El puerto submission requiere cifrado"
else
  print_warning "El puerto submission puede no requerir cifrado"
fi

echo
print_success "Pruebas del puerto submission completadas"
echo
echo "Comandos de prueba manual:"
echo "  openssl s_client -connect localhost:587 -starttls smtp"
echo "  telnet localhost 587"
