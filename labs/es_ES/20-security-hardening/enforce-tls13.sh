#!/usr/bin/env bash
#=============================================================================
# Lab 20: Imponer TLS 1.3
# Configura TLS 1.3 como versión mínima
#
# Uso: ./enforce-tls13.sh
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

print_header "Lab 20: Imponer TLS 1.3"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: este script debe ejecutarse como root (use sudo)"
  exit 1
fi

print_warning "Modo solo TLS 1.3"
echo "  Máxima seguridad pero puede afectar la compatibilidad"
echo "  No todos los clientes soportan TLS 1.3"
echo

read -p "¿Imponer TLS 1.3 como mínimo? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Operación cancelada"
  exit 0
fi

echo

# Verificar versión de OpenSSL (requiere 1.1.1+)
OPENSSL_VERSION="$(openssl version | awk '{print $2}')"
echo "Versión de OpenSSL: ${OPENSSL_VERSION}"

if ! openssl version | grep -qE "1\.1\.1|3\."; then
  print_error "TLS 1.3 requiere OpenSSL 1.1.1+"
  echo "OpenSSL actual no soporta TLS 1.3"
  exit 1
fi

print_success "OpenSSL soporta TLS 1.3"
echo

# Apache
if [[ -d /etc/httpd/conf.d ]]; then
  print_info "Configurando Apache para TLS 1.3..."

  cat > /etc/httpd/conf.d/tls13-only.conf << 'EOF'
# Lab 20: TLS 1.3 solo
SSLProtocol -all +TLSv1.3
EOF

  if apachectl configtest 2>&1 | grep -q "Syntax OK"; then
    print_success "Apache configurado"
    systemctl reload httpd 2>/dev/null || true
  fi
fi

# NGINX
if [[ -d /etc/nginx ]]; then
  print_info "Configurando NGINX para TLS 1.3..."

  cat > /etc/nginx/conf.d/tls13-only.conf << 'EOF'
# Lab 20: TLS 1.3 solo
ssl_protocols TLSv1.3;
EOF

  if nginx -t 2>&1 | grep -q "successful"; then
    print_success "NGINX configurado"
    systemctl reload nginx 2>/dev/null || true
  fi
fi

echo
print_success "Imposición de TLS 1.3 configurada"
echo
print_warning "Advertencia: esto afecta clientes solo TLS 1.2"
echo
echo "Para volver a TLS 1.2+:"
echo "  Elimine /etc/httpd/conf.d/tls13-only.conf"
echo "  Elimine /etc/nginx/conf.d/tls13-only.conf"
echo "  Reinicie los servicios"
