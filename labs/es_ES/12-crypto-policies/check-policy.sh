#!/usr/bin/env bash
#=============================================================================
# Lab 12: Comprobar política
# Muestra la política criptográfica actual del sistema
#
# Uso: ./check-policy.sh
# Requisitos previos: RHEL 8, 9, 10
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

print_header "Lab 12: Comprobar crypto-policy"

# Comprobar versión de RHEL
if [[ ${RHEL_VERSION} -lt 8 ]]; then
  print_error "Error: crypto-policies requiere RHEL 8 o superior"
  echo "Versión actual: RHEL ${RHEL_VERSION}"
  exit 1
fi

echo "Versión de RHEL: ${RHEL_VERSION}"
echo

# Comprobar política actual
print_info "Política crypto-policy actual:"
CURRENT_POLICY="$(update-crypto-policies --show 2>/dev/null || cat /etc/crypto-policies/config 2>/dev/null || echo "UNKNOWN")"
print_success "  ${CURRENT_POLICY}"

echo

# Mostrar archivo de configuración de política
print_info "Archivo de configuración de política:"
if [[ -f /etc/crypto-policies/config ]]; then
  echo "  Ubicación: /etc/crypto-policies/config"
  echo "  Contenido: $(cat /etc/crypto-policies/config)"
else
  echo "  Archivo de configuración no encontrado"
fi

echo

# Listar políticas disponibles
print_info "Políticas disponibles:"
if [[ -d /usr/share/crypto-policies/policies/ ]]; then
  ls -1 /usr/share/crypto-policies/policies/*.pol 2>/dev/null | sed 's|.*/||;s|\.pol$||' | while read policy; do
    if [[ ${policy} == ${CURRENT_POLICY} ]]; then
      echo -e "  ${GREEN}* ${policy} (actual)${NC}"
    else
      echo "    ${policy}"
    fi
  done
else
  echo "  Directorio de políticas no encontrado"
fi

echo

# Mostrar configuraciones de backend
print_info "Configuraciones de backend:"
if [[ -d /etc/crypto-policies/back-ends/ ]]; then
  echo "  Directorio de configuración de backend: /etc/crypto-policies/back-ends/"
  ls -1 /etc/crypto-policies/back-ends/ 2>/dev/null | head -10
else
  echo "  Directorio de backend no encontrado"
fi

echo

# Mostrar detalles de la política (muestra)
print_info "Detalles de la política actual:"
if [[ -f "/usr/share/crypto-policies/policies/${CURRENT_POLICY}.pol" ]]; then
  echo "  Archivo de política: /usr/share/crypto-policies/policies/${CURRENT_POLICY}.pol"
  echo
  echo "  Configuración de muestra (primeras 20 líneas):"
  head -20 "/usr/share/crypto-policies/policies/${CURRENT_POLICY}.pol" 2>/dev/null | sed 's/^/    /'
else
  echo "  Archivo de política no encontrado"
fi

echo
print_success "Comprobación de política completada"
echo
echo "Para cambiar la política:"
echo "  sudo update-crypto-policies --set LEGACY"
echo "  sudo update-crypto-policies --set DEFAULT"
echo "  sudo update-crypto-policies --set FUTURE"
