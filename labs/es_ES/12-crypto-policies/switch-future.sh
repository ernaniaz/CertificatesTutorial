#!/usr/bin/env bash
#=============================================================================
# Lab 12: Cambiar a FUTURE
# Habilita la crypto-policy FUTURE para máxima seguridad
#
# Uso: ./switch-future.sh
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

print_header "Lab 12: Cambiar a política FUTURE"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

# Comprobar versión de RHEL
if [[ ${RHEL_VERSION} -lt 8 ]]; then
  print_error "Error: crypto-policies requiere RHEL 8 o superior"
  exit 1
fi

# Mostrar política actual
CURRENT_POLICY="$(update-crypto-policies --show 2>/dev/null)"
echo "Política actual: ${CURRENT_POLICY}"

echo
print_warning "La política FUTURE impone criptografía fuerte"
print_warning "  - TLS 1.2+ con preferencia por 1.3"
print_warning "  - Solo cifrados fuertes"
print_warning "  - Se requieren tamaños de clave mayores"
print_warning "  - Puede romper la compatibilidad con sistemas antiguos"
echo

read -p "¿Continuar con la política FUTURE? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Operación cancelada"
  exit 0
fi

echo

# Cambiar a FUTURE
print_info "Cambiando a la política FUTURE..."
if update-crypto-policies --set FUTURE; then
  print_success "Política establecida en FUTURE"
else
  print_error "No se pudo establecer la política FUTURE"
  exit 1
fi

echo

# Verificar
NEW_POLICY="$(update-crypto-policies --show 2>/dev/null)"
echo "Nueva política: ${NEW_POLICY}"

echo
print_info "Reiniciando servicios afectados..."
print_warning "Nota: Algunos servicios pueden requerir reinicio manual"

# Servicios que pueden necesitar reinicio
SERVICES="sshd httpd nginx postfix"
for service in ${SERVICES}; do
  if systemctl is-active ${service} &>/dev/null; then
    echo "  Reiniciando ${service}..."
    if ! systemctl restart ${service} 2>/dev/null; then
      echo "    (no instalado o falló el reinicio)"
    fi
  fi
done

echo
print_success "Cambiado a la política FUTURE"
echo
echo "Probar con:"
echo "  openssl ciphers -v"
echo "  ssh -Q cipher"
echo
print_warning "Si encuentra problemas de compatibilidad, restaure DEFAULT:"
echo "  sudo update-crypto-policies --set DEFAULT"
