#!/usr/bin/env bash
#=============================================================================
# Lab 13: Configurar renovação automática
# Configura a renovação automática de certificados
#
# Uso: ./setup-autorenewal.sh
# Pré-requisitos: RHEL 8, 9, 10, privilégios de root
#=============================================================================

set -e  # Sair em caso de erro
set -u  # Sair em variável indefinida

#=============================================================================
# CONFIGURAÇÃO
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
# FUNÇÕES AUXILIARES
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

trap 'error_exit "Erro na linha ${LINENO}"' ERR

#=============================================================================
# VERIFICAÇÃO DA VERSÃO RHEL
#=============================================================================

if ! grep -q '^ID="rhel"$' /etc/os-release 2>/dev/null; then
  error_exit "Este script requer Red Hat Enterprise Linux (RHEL)."
fi
readonly RHEL_VERSION="$(grep -oP '^VERSION_ID="\K[0-9]+' /etc/os-release 2>/dev/null)"
if [[ ${RHEL_VERSION} -lt 8 || ${RHEL_VERSION} -gt 10 ]]; then
  error_exit "Versão do RHEL não suportada. Este script requer RHEL 8, 9 ou 10."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

print_header "Lab 13: Configurar Renovação Automática"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

# Detectar versão do RHEL
echo "Versão RHEL: ${RHEL_VERSION}"
echo

print_info "Verificando timer systemd do certbot..."

if systemctl list-unit-files | grep -q "certbot-renew.timer"; then
  print_success "Timer do Certbot já existe"

  # Habilitar se não estiver habilitado
  if ! systemctl is-enabled certbot-renew.timer &>/dev/null; then
    systemctl enable certbot-renew.timer
    print_success "Timer habilitado"
  fi

  # Iniciar se não estiver em execução
  if ! systemctl is-active certbot-renew.timer &>/dev/null; then
    systemctl start certbot-renew.timer
    print_success "Timer iniciado"
  fi

  echo
  echo "Status do timer:"
  systemctl status certbot-renew.timer --no-pager | head -10

  echo
  echo "Próxima execução:"
  systemctl list-timers certbot-renew.timer --no-pager
else
  print_warning "Timer do Certbot não encontrado"
  echo "Criando timer personalizado..."

  # Criar unit de timer
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

  # Criar unit de serviço
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

  print_success "Timer personalizado criado e iniciado"
fi

echo
print_success "Renovação automática configurada"
echo
echo "Detalhes da renovação:"
echo "  - Verifica duas vezes ao dia"
echo "  - Renova quando restam <30 dias"
echo "  - Registra em /var/log/letsencrypt/"
echo
echo "Monitorar renovações:"
echo "  systemctl status certbot-renew.service"
echo "  journalctl -u certbot-renew"
