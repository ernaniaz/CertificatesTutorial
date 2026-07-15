#!/usr/bin/env bash
#=============================================================================
# Lab 20: Deshabilitar protocolos débiles
# Elimina el soporte de protocolos SSL/TLS débiles
#
# Uso: ./disable-weak-protocols.sh
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

print_header "Lab 20: Deshabilitar protocolos débiles"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: este script debe ejecutarse como root (use sudo)"
  exit 1
fi

print_info "Deshabilitando protocolos débiles en todo el sistema..."
echo

# RHEL 8+: usar crypto-policies
if [[ ${RHEL_VERSION} -ge 8 ]]; then
  echo "Usando crypto-policies para deshabilitar protocolos débiles..."

  CURRENT_POLICY="$(update-crypto-policies --show)"
  echo "Política actual: ${CURRENT_POLICY}"

  if [[ ${CURRENT_POLICY} == LEGACY ]]; then
    print_warning "La política LEGACY permite protocolos débiles"
    echo "Cambiando a política DEFAULT..."
    update-crypto-policies --set DEFAULT
    print_success "Cambiado a DEFAULT (bloquea TLS 1.0/1.1)"
  elif [[ ${CURRENT_POLICY} == DEFAULT ]]; then
    print_success "Política DEFAULT ya activa (TLS 1.2+)"
  elif [[ ${CURRENT_POLICY} == FUTURE ]]; then
    print_success "Política FUTURE activa (máxima seguridad)"
  fi

  echo
  echo "Reiniciando servicios..."
  for svc in httpd nginx postfix sshd; do
    if systemctl is-active ${svc} &>/dev/null; then
      if systemctl restart ${svc} 2>/dev/null; then
        echo "  ✓ ${svc} reiniciado"
      fi
    fi
  done
else
  # RHEL 7: configuración manual
  echo "RHEL 7 detectado - se requiere configuración manual"
  echo "Asegúrese de que las configuraciones de servicio tengan:"
  echo "  SSLProtocol -all +TLSv1.2 +TLSv1.3"
fi

echo
print_success "Protocolos débiles deshabilitados"
echo
echo "Protocolos bloqueados:"
echo "  - SSLv2, SSLv3"
echo "  - TLS 1.0, TLS 1.1"
echo
echo "Protocolos permitidos:"
echo "  - TLS 1.2"
echo "  - TLS 1.3"
