#!/usr/bin/env bash
#=============================================================================
# Lab 13: Configurar renovación automática
# Configura la renovación automática de certificados
#
# Uso: ./setup-autorenewal.sh
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

print_header "Lab 13: Configurar renovación automática"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

# Detectar versión de RHEL
echo "Versión de RHEL: ${RHEL_VERSION}"
echo

print_info "Comprobando temporizador systemd de certbot..."

if systemctl list-unit-files | grep -q "certbot-renew.timer"; then
  print_success "El temporizador de certbot ya existe"

  # Habilitar si no está habilitado
  if ! systemctl is-enabled certbot-renew.timer &>/dev/null; then
    systemctl enable certbot-renew.timer
    print_success "Temporizador habilitado"
  fi

  # Iniciar si no está iniciado
  if ! systemctl is-active certbot-renew.timer &>/dev/null; then
    systemctl start certbot-renew.timer
    print_success "Temporizador iniciado"
  fi

  echo
  echo "Estado del temporizador:"
  systemctl status certbot-renew.timer --no-pager | head -10

  echo
  echo "Próxima ejecución:"
  systemctl list-timers certbot-renew.timer --no-pager
else
  print_warning "Temporizador de certbot no encontrado"
  echo "Creando temporizador personalizado..."

  # Crear unidad de temporizador
  cat > /etc/systemd/system/certbot-renew.timer << 'EOF'
[Unit]
Description=Certbot Renewal Timer

[Timer]
OnCalendar=daily
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF

  # Crear unidad de servicio
  cat > /etc/systemd/system/certbot-renew.service << 'EOF'
[Unit]
Description=Certbot Renewal

[Service]
Type=oneshot
ExecStart=/usr/bin/certbot renew --quiet
EOF

  systemctl daemon-reload
  systemctl enable certbot-renew.timer
  systemctl start certbot-renew.timer

  print_success "Temporizador personalizado creado e iniciado"
fi

echo
print_success "Renovación automática configurada"
echo
echo "Detalles de renovación:"
echo "  - Comprueba dos veces al día"
echo "  - Renueva cuando quedan <30 días"
echo "  - Registra en /var/log/letsencrypt/"
echo
echo "Monitorear renovaciones:"
echo "  systemctl status certbot-renew.service"
echo "  journalctl -u certbot-renew"
