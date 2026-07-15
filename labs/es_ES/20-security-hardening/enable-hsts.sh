#!/usr/bin/env bash
#=============================================================================
# Lab 20: Habilitar HSTS
# Configura HTTP Strict Transport Security
#
# Uso: ./enable-hsts.sh
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

print_header "Lab 20: Habilitar HSTS"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: este script debe ejecutarse como root (use sudo)"
  exit 1
fi

echo "HSTS obliga a los navegadores a usar solo HTTPS"
echo "Duración: 2 años (63072000 segundos)"
echo

# Apache
if [[ -d /etc/httpd/conf.d ]]; then
  print_info "Configurando HSTS para Apache..."

  cat > /etc/httpd/conf.d/hsts.conf << 'EOF'
# Lab 20: HTTP Strict Transport Security
<IfModule mod_headers.c>
    Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
</IfModule>
EOF

  if apachectl configtest 2>&1 | grep -q "Syntax OK"; then
    print_success "HSTS de Apache configurado"
    systemctl reload httpd 2>/dev/null || true
  fi
fi

# NGINX
if [[ -d /etc/nginx/conf.d ]]; then
  print_info "Configurando HSTS para NGINX..."

  cat > /etc/nginx/conf.d/hsts.conf << 'EOF'
# Lab 20: HTTP Strict Transport Security
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
EOF

  if nginx -t 2>&1 | grep -q "successful"; then
    print_success "HSTS de NGINX configurado"
    systemctl reload nginx 2>/dev/null || true
  fi
fi

echo
print_success "HSTS habilitado"
echo
echo "Probar con:"
echo "  curl -I https://localhost/ | grep Strict-Transport-Security"
