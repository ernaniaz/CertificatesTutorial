#!/usr/bin/env bash
#=============================================================================
# Lab 18: Configurar RHEL 9
# Configuración de OpenSSL 3.x en RHEL 9 ya actualizado
#
# Uso: ./configure-rhel9.sh
# Requisitos previos: RHEL 9, privilegios de root
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
if [[ ${RHEL_VERSION} -ne 9 ]]; then
  error_exit "Versión de RHEL no soportada. Este script requiere solo RHEL 9."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

print_header "Lab 18: Configuración posterior a la actualización a RHEL 9"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: este script debe ejecutarse como root (use sudo)"
  exit 1
fi

# Verificar versión de OpenSSL
print_info "1. Verificando OpenSSL 3.x..."
OPENSSL_VERSION="$(openssl version)"
echo "  ${OPENSSL_VERSION}"

if echo "${OPENSSL_VERSION}" | grep -q "OpenSSL 3"; then
  echo -e "  ${GREEN}✓ OpenSSL 3.x detectado${NC}"
else
  echo -e "  ${YELLOW}⚠ Versión de OpenSSL inesperada${NC}"
fi

echo

# Verificar crypto-policy
print_info "2. Verificando crypto-policy..."
POLICY="$(update-crypto-policies --show 2>/dev/null)"
echo "  Actual: ${POLICY}"

echo

# Verificar certificados
print_info "3. Validando certificados con OpenSSL 3.x..."
CERT_ERRORS=0

for cert in /etc/pki/tls/certs/*.crt; do
  if [[ -f "${cert}" ]]; then
    if ! openssl x509 -in "${cert}" -noout 2>/dev/null; then
      echo -e "  ${RED}✗ $(basename "${cert}")${NC}"
      ((CERT_ERRORS+=1))
    fi
  fi
done

if [[ ${CERT_ERRORS} -eq 0 ]]; then
  echo -e "  ${GREEN}✓ Todos los certificados son válidos bajo OpenSSL 3.x${NC}"
else
  echo -e "  ${RED}✗ ${CERT_ERRORS} certificados tienen problemas${NC}"
fi

echo

# Verificar necesidad del proveedor legacy
print_info "4. Verificando uso de algoritmos legacy..."
if [[ -f /etc/pki/tls/openssl.cnf ]] && grep -qP '^[^#]*legacy\s*=' /etc/pki/tls/openssl.cnf; then
  echo -e "  ${YELLOW}⚠ Proveedor legacy habilitado${NC}"
  echo "    Revise si aún es necesario"
else
  echo -e "  ${GREEN}✓ Usando solo el proveedor predeterminado${NC}"
fi

echo

# Probar servicios
print_info "5. Probando servicios..."
for svc in httpd nginx postfix; do
  if systemctl is-active ${svc} &>/dev/null; then
    echo -e "  ${GREEN}✓ ${svc} en ejecución${NC}"
  elif systemctl list-unit-files | grep -q "^${svc}.service"; then
    echo -e "  ${YELLOW}⚠ ${svc} instalado pero no en ejecución${NC}"
  fi
done

echo

print_success "Revisión de configuración posterior a la actualización de RHEL 9 completada"
echo
echo "Próximos pasos:"
echo "  1. Probar todas las conexiones TLS"
echo "  2. Ejecutar ./validate-migration.sh"
echo "  3. Supervisar advertencias de obsolescencia"
echo

if [[ ${CERT_ERRORS} -gt 0 ]]; then
  print_warning "Se detectaron problemas con certificados"
  echo "Considere regenerar los certificados afectados"
fi
