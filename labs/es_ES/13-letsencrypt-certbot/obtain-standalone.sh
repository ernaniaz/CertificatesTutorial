#!/usr/bin/env bash
#=============================================================================
# Lab 13: Obtener certificado (standalone)
# Obtiene certificado de Let's Encrypt en modo standalone
#
# Uso: ./obtain-standalone.sh
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

print_header "Lab 13: Obtener certificado (standalone)"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

print_warning "IMPORTANTE: Este lab usa modo standalone"
print_warning "  - Requiere que el puerto 80 esté libre"
print_warning "  - Usará dominio de prueba (no Let's Encrypt real)"
print_warning "  - Para producción, use un nombre de dominio real"
echo

# Nombre de dominio para pruebas (el usuario debe reemplazarlo por el suyo)
DOMAIN="example.com"

echo "Dominio a usar: ${DOMAIN}"
echo
print_warning "En este lab usaremos --staging y --register-unsafely-without-email"
print_warning "En producción, use un dominio real y la dirección --email"
echo

read -p "¿Continuar con la prueba standalone? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Operación cancelada"
  exit 0
fi

echo

# Detener servidores web que usen el puerto 80
print_info "Comprobando servicios en el puerto 80..."
SERVICES="httpd nginx apache2"
STOPPED_SERVICES=""

for service in ${SERVICES}; do
  if systemctl is-active ${service} &>/dev/null; then
    echo "Deteniendo ${service}..."
    systemctl stop ${service}
    STOPPED_SERVICES="${STOPPED_SERVICES} ${service}"
  fi
done

if [[ -n "${STOPPED_SERVICES}" ]]; then
  print_success "Servicios detenidos: ${STOPPED_SERVICES}"
fi

echo

# Obtener certificado en modo standalone
print_info "Obteniendo certificado en modo standalone..."
echo

# Usar entorno staging y aceptar TOS
if certbot certonly \
  --standalone \
  --staging \
  --agree-tos \
  --register-unsafely-without-email \
  --domain "${DOMAIN}" \
  --non-interactive 2>&1 | tee /tmp/certbot-standalone.log; then
  echo
  print_success "Certificado obtenido (staging)"
else
  echo
  print_warning "La solicitud de certificado falló (esperado si no hay dominio real)"
  echo "Esto es normal en un entorno de lab sin un dominio público"
  echo
  echo "Para uso en producción:"
  echo "  certbot certonly --standalone -d your-domain.com --email your@email.com"
fi

echo

# Reiniciar servicios detenidos
if [[ -n "${STOPPED_SERVICES}" ]]; then
  print_info "Reiniciando servicios detenidos..."
  for service in ${STOPPED_SERVICES}; do
    echo "Iniciando ${service}..."
    systemctl start ${service}
  done
fi

echo
print_success "Demostración en modo standalone completada"
echo
echo "Ubicaciones del certificado (si tuvo éxito):"
echo "  /etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
echo "  /etc/letsencrypt/live/${DOMAIN}/privkey.pem"
echo
echo "Listar certificados:"
echo "  certbot certificates"
echo
echo "Ejemplo de producción:"
echo "  certbot certonly --standalone -d example.com --email admin@example.com"
