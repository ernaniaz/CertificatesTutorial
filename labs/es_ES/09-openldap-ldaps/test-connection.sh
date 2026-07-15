#!/usr/bin/env bash
#=============================================================================
# Lab 09: Probar conexión
# Prueba LDAP, STARTTLS y LDAPS
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

print_header "Lab 09: Probando conexiones LDAP"

# Probar LDAP sin cifrado (puerto 389)
print_info "1. Probando LDAP sin cifrado (puerto 389)..."
if ldapsearch -x -H ldap://localhost -b "" -s base supportedSASLMechanisms &>/dev/null; then
  print_success "Conexión LDAP sin cifrado exitosa"
else
  print_error "Conexión LDAP sin cifrado fallida"
  exit 1
fi

echo

# Probar STARTTLS (puerto 389)
print_info "2. Probando STARTTLS (puerto 389 con -ZZ)..."
if ldapsearch -x -H ldap://localhost -b "" -s base -ZZ supportedSASLMechanisms &>/dev/null; then
  print_success "Conexión STARTTLS exitosa"
else
  print_warning "STARTTLS falló (puede necesitar TLS_REQCERT allow en ldap.conf)"
fi

echo

# Probar LDAPS (puerto 636)
print_info "3. Probando LDAPS (puerto 636)..."
if ldapsearch -x -H ldaps://localhost -b "" -s base supportedSASLMechanisms &>/dev/null; then
  print_success "Conexión LDAPS exitosa"
else
  print_warning "LDAPS falló (verifique si el puerto 636 está habilitado)"
fi

echo

# Probar con openssl s_client
print_info "4. Probando handshake TLS con openssl..."
if ss -tlnp | grep -q ':636'; then
  TLS_INFO="$(echo "QUIT" | timeout 5 openssl s_client -connect localhost:636 2>&1 || true)"

  if echo "${TLS_INFO}" | grep -q "Server certificate"; then
    print_success "Handshake TLS exitoso"

    # Extraer información del certificado
    SUBJECT="$(echo "${TLS_INFO}" | grep "subject=" | head -1)"
    if [[ -n "${SUBJECT}" ]]; then
      echo "  ${SUBJECT}"
    fi

    # Extraer protocolo
    PROTOCOL="$(echo "${TLS_INFO}" | grep "Protocol" | head -1)"
    if [[ -n "${PROTOCOL}" ]]; then
      echo "  ${PROTOCOL}"
    fi

    # Extraer cifrado
    CIPHER="$(echo "${TLS_INFO}" | grep "Cipher" | head -1)"
    if [[ -n "${CIPHER}" ]]; then
      echo "  ${CIPHER}"
    fi
  else
    print_warning "No se pudieron verificar los detalles TLS"
  fi
else
  print_warning "Puerto 636 no escuchando"
fi

echo

# Consultar mecanismos soportados
print_info "5. Consultando mecanismos SASL soportados..."
MECHANISMS="$(ldapsearch -x -H ldap://localhost -b "" -s base supportedSASLMechanisms 2>/dev/null | grep "supportedSASLMechanisms" | awk '{print $2}' | tr '\n' ' ')"
if [[ -n "${MECHANISMS}" ]]; then
  print_success "Mecanismos SASL soportados: ${MECHANISMS}"
else
  echo "No se reportaron mecanismos SASL"
fi

echo
print_success "Pruebas de conexión completadas"
echo
echo "Comandos de prueba manual:"
echo "  ldapsearch -x -H ldap://localhost -b \"\" -s base"
echo "  ldapsearch -x -H ldaps://localhost -b \"\" -s base"
echo "  ldapsearch -x -H ldap://localhost -b \"\" -s base -ZZ"
echo "  openssl s_client -connect localhost:636"
