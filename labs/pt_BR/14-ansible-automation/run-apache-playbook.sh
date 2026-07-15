#!/usr/bin/env bash
#=============================================================================
# Lab 14: Executar playbook do Apache
# Executa o playbook do Ansible para Apache SSL
#
# Uso: ./run-apache-playbook.sh
# Pré-requisitos: RHEL 8, 9, 10
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_header "Lab 14: Executar Playbook Apache"

# Verificar pré-requisitos
if ! command -v ansible-playbook &>/dev/null; then
  print_error "Erro: ansible-playbook não encontrado"
  echo "Execute ./install-ansible.sh primeiro"
  exit 1
fi

if [[ ! -f "${SCRIPT_DIR}/inventory.ini" ]]; then
  print_error "Erro: inventory.ini não encontrado"
  echo "Execute ./create-inventory.sh primeiro"
  exit 1
fi

if [[ ! -f "${SCRIPT_DIR}/playbook-apache.yml" ]]; then
  print_error "Erro: playbook-apache.yml não encontrado"
  exit 1
fi

# Executar playbook
print_info "Executando playbook SSL do Apache..."
echo

if ansible-playbook -i "${SCRIPT_DIR}/inventory.ini" "${SCRIPT_DIR}/playbook-apache.yml"; then
  echo
  print_success "Playbook executado com sucesso"
else
  echo
  print_error "Falha na execução do playbook"
  exit 1
fi

echo
print_success "Implantação SSL Apache concluída"
echo
echo "Verificar com:"
echo "  curl -k https://localhost/"
echo "  openssl s_client -connect localhost:443"
echo "  systemctl status httpd"
