#!/usr/bin/env bash
#=============================================================================
# Lab 13: Obtener certificado (webserver)
# Obtiene certificado con integración Apache/NGINX
#
# Uso: ./obtain-webserver.sh
# Requisitos previos: RHEL 8, 9, 10, privilegios de root
#=============================================================================

set -e  # Salir en caso de error
set -u  # Salir en variable no definida
set -o pipefail  # El pipeline retorna el primer código de salida no-cero

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

print_header "Lab 13: Obtener certificado (modo servidor web)"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

print_warning "Este script demuestra la integración con servidor web"
print_warning "  - Requiere Apache o NGINX en ejecución"
print_warning "  - Requiere un dominio real para producción"
print_warning "  - Esta demo usa modo staging"
echo

# Nombre de dominio para pruebas (el usuario debe reemplazarlo por el suyo)
DOMAIN="example.com"

echo "Dominio a usar: ${DOMAIN}"
echo

# Detectar servidor web en ejecución
WEB_SERVER=""
if systemctl is-active httpd &>/dev/null; then
  WEB_SERVER="apache"
  echo "Detectado: Apache (httpd)"
elif systemctl is-active nginx &>/dev/null; then
  WEB_SERVER="nginx"
  echo "Detectado: NGINX"
else
  print_warning "No hay servidor web en ejecución"
  echo "Instale e inicie Apache o NGINX primero"
  echo "  Lab 06 (Apache) o Lab 07 (NGINX)"
  exit 1
fi

echo
echo "Usando plugin: ${WEB_SERVER}"
echo

read -p "¿Continuar con la integración ${WEB_SERVER}? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Operación cancelada"
  exit 0
fi

echo

# Obtener certificado con plugin de servidor web
print_info "Obteniendo certificado con el plugin ${WEB_SERVER}..."
echo

if [[ ${WEB_SERVER} == apache ]]; then
  # Plugin Apache
  if certbot --apache \
    --staging \
    --agree-tos \
    --register-unsafely-without-email \
    --domain "${DOMAIN}" \
    --non-interactive 2>&1 | tee /tmp/certbot-apache.log; then
    echo
    print_success "Certificado obtenido y Apache configurado"
  else
    echo
    print_warning "La solicitud de certificado falló (esperado en el lab)"
  fi
elif [[ ${WEB_SERVER} == nginx ]]; then
  # Plugin NGINX
  if certbot --nginx \
    --staging \
    --agree-tos \
    --register-unsafely-without-email \
    --domain "${DOMAIN}" \
    --non-interactive 2>&1 | tee /tmp/certbot-nginx.log; then
    echo
    print_success "Certificado obtenido y NGINX configurado"
  else
    echo
    print_warning "La solicitud de certificado falló (esperado en el lab)"
  fi
fi

echo
print_success "Demostración de integración con servidor web completada"
echo
echo "Lo que hizo certbot:"
echo "  1. Obtuvo el certificado"
echo "  2. Modificó la configuración del servidor web"
echo "  3. Habilitó HTTPS"
echo "  4. Configuró redirección HTTP->HTTPS"
echo
echo "Ejemplo de producción:"
echo "  certbot --${WEB_SERVER} -d example.com --email admin@example.com"
