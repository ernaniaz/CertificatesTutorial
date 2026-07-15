#!/usr/bin/env bash
#=============================================================================
# Lab 17: Configurar RHEL 8
# Configuración de certificados en RHEL 8 ya actualizado
#
# Uso: ./configure-rhel8.sh
# Requisitos previos: RHEL 8, privilegios de root
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
if [[ ${RHEL_VERSION} -ne 8 ]]; then
  error_exit "Versión de RHEL no soportada. Este script requiere solo RHEL 8."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

print_header "Lab 17: Configuración posterior a la actualización a RHEL 8"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: este script debe ejecutarse como root (use sudo)"
  exit 1
fi

# Verificar crypto-policy actual
print_info "1. Verificando crypto-policy..."
POLICY="$(update-crypto-policies --show 2>/dev/null || echo "UNKNOWN")"
echo "  Política actual: ${POLICY}"

if [[ ${POLICY} == DEFAULT ]]; then
  echo -e "  ${GREEN}✓ Usando política DEFAULT${NC}"
elif [[ ${POLICY} == LEGACY ]]; then
  echo -e "  ${YELLOW}⚠ Usando política LEGACY (por compatibilidad)${NC}"
fi

echo

# Actualizar configuraciones de servicios
print_info "2. Actualizando configuraciones de servicios..."

# Apache
if [[ -d /etc/httpd/conf.d ]]; then
  echo "  Verificando configuraciones de Apache..."
  if grep -r "^[^#]*SSLProtocol" /etc/httpd/conf* 2>/dev/null | grep -q .; then
    echo -e "    ${YELLOW}⚠ Se encontraron directivas SSLProtocol manuales${NC}"
    echo "      Considere eliminarlas para usar crypto-policies"
  else
    echo -e "    ${GREEN}✓ Sin configuraciones manuales de protocolos TLS${NC}"
  fi
fi

# NGINX
if [[ -d /etc/nginx ]]; then
  echo "  Verificando configuraciones de NGINX..."
  if grep -r "ssl_protocols" /etc/nginx/ 2>/dev/null | grep -v "^#" | grep -q .; then
    echo -e "    ${YELLOW}⚠ Se encontraron directivas ssl_protocols manuales${NC}"
    echo "      NGINX aún requiere configuraciones explícitas de protocolos"
  fi
fi

echo

# Verificar certificados
print_info "3. Verificando certificados..."
CERT_COUNT=0
VALID_COUNT=0

for cert in /etc/pki/tls/certs/*.crt; do
  if [[ -f "${cert}" ]]; then
    ((CERT_COUNT+=1))
    if openssl x509 -in "${cert}" -noout -checkend 0 2>/dev/null; then
      ((VALID_COUNT+=1))
    fi
  fi
done

echo "  Total de certificados: ${CERT_COUNT}"
echo "  Certificados válidos: ${VALID_COUNT}"

if [[ ${CERT_COUNT} -eq ${VALID_COUNT} ]]; then
  echo -e "  ${GREEN}✓ Todos los certificados son válidos${NC}"
else
  echo -e "  ${RED}✗ Algunos certificados están vencidos o son inválidos${NC}"
fi

echo

# Probar servicios
print_info "4. Probando servicios..."
SERVICES=("httpd" "nginx" "postfix")
for svc in "${SERVICES[@]}"; do
  if systemctl is-active ${svc} &>/dev/null; then
    echo -e "  ${GREEN}✓ ${svc} en ejecución${NC}"
  elif systemctl list-unit-files | grep -q "^${svc}.service"; then
    echo -e "  ${YELLOW}⚠ ${svc} instalado pero no en ejecución${NC}"
  fi
done

echo

print_success "Configuración posterior a la actualización de RHEL 8 completada"
echo
echo "Próximos pasos:"
echo "  1. Probar todos los servicios a fondo"
echo "  2. Ejecutar ./validate-migration.sh"
echo "  3. Supervisar los registros en busca de problemas"
echo
echo "Si surgen problemas de compatibilidad:"
echo "  sudo update-crypto-policies --set LEGACY"
