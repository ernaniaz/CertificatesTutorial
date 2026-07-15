#!/usr/bin/env bash
#=============================================================================
# Lab 11: Instalar certmonger
# Instala e configura o serviço certmonger
#
# Uso: ./install-certmonger.sh
# Pré-requisitos: RHEL 7, 8, 9, 10, privilégios de root
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
if [[ ${RHEL_VERSION} -lt 7 || ${RHEL_VERSION} -gt 10 ]]; then
  error_exit "Versão do RHEL não suportada. Este script requer RHEL 7, 8, 9 ou 10."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

print_header "Lab 11: Instalando certmonger"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

# Detectar versão do RHEL
echo "Versão RHEL: ${RHEL_VERSION}"
echo

# Instalar certmonger
print_info "Instalando certmonger..."

if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum install -y certmonger
else
  dnf install -y certmonger
fi

print_success "certmonger instalado"
echo

# Habilitar e iniciar certmonger
print_info "Habilitando e iniciando serviço certmonger..."
systemctl enable certmonger
systemctl start certmonger

print_success "Serviço certmonger iniciado"
echo

# Verificar instalação
if systemctl is-active certmonger &>/dev/null; then
  print_success "certmonger está em execução"
else
  print_error "certmonger falhou ao iniciar"
  exit 1
fi

# Exibir versão do certmonger
echo
echo "Versão do pacote certmonger:"
rpm -q certmonger

# Listar CAs disponíveis
echo
echo "CAs disponíveis:"
if ! getcert list-cas 2>/dev/null; then
  echo "No CAs configured yet"
fi

echo
print_success "Instalação certmonger concluída"
echo
echo "Status certmonger:"
systemctl status certmonger --no-pager | head -5

echo
echo "Tente estes comandos:"
echo "  getcert list"
echo "  getcert list-cas"
echo "  journalctl -u certmonger -f"
