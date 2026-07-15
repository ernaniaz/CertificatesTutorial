#!/usr/bin/env bash
#=============================================================================
# Lab 14: Verificar
# Passos de verificação
#
# Uso: ./verify.sh
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

print_header "Lab 14: Verificação Ansible"

print_info "1. Versão do Ansible:"
if command -v ansible &>/dev/null; then
  ansible --version | head -3
else
  echo "Ansible não instalado"
fi

echo

print_info "2. Arquivo de inventário:"
if [[ -f "${SCRIPT_DIR}/inventory.ini" ]]; then
  print_success "Inventário existe"
  echo "Arquivo: ${SCRIPT_DIR}/inventory.ini"
else
  echo "Inventário não encontrado"
fi

echo

print_info "3. Arquivos de playbook:"
for playbook in "${SCRIPT_DIR}"/playbook-*.yml; do
  if [[ -f "${playbook}" ]]; then
    echo "  $(basename "${playbook}")"
  fi
done

echo

print_info "4. Testando conexão do inventário:"
if command -v ansible &>/dev/null && [ -f "${SCRIPT_DIR}/inventory.ini" ]; then
  ansible all -i "${SCRIPT_DIR}/inventory.ini" -m ping 2>&1 | head -10
else
  echo "Não foi possível testar (ansible ou inventory ausente)"
fi

echo

print_info "5. Verificando certificados implantados:"
if [[ -f /etc/pki/tls/certs/lab-ansible.crt ]]; then
  print_success "Certificado implantado"
  openssl x509 -in /etc/pki/tls/certs/lab-ansible.crt -noout -subject -dates
else
  echo "Certificado ainda não implantado"
fi

echo

print_info "6. Verificando configuração Apache:"
if [[ -f /etc/httpd/conf.d/ansible-ssl.conf ]]; then
  print_success "Config SSL Apache existe"
else
  echo "Config SSL Apache não encontrada"
fi

echo
print_success "Verificação concluída"
