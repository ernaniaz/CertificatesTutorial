#!/usr/bin/env bash
#=============================================================================
# Lab 14: Testar idempotência
# Testa se os playbooks são idempotentes
#
# Uso: ./test-idempotency.sh
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

print_header "Lab 14: Testar Idempotência"

# Verificar pré-requisitos
if ! command -v ansible-playbook &>/dev/null; then
  print_error "Erro: ansible-playbook não encontrado"
  exit 1
fi

if [[ ! -f "${SCRIPT_DIR}/playbook-apache.yml" ]]; then
  print_error "Erro: playbook-apache.yml não encontrado"
  exit 1
fi

print_info "Executando playbook pela primeira vez..."
echo

ansible-playbook -i "${SCRIPT_DIR}/inventory.ini" "${SCRIPT_DIR}/playbook-apache.yml" | tee /tmp/ansible-run1.log

echo
print_info "Executando playbook pela segunda vez (não deve mostrar alterações)..."
echo

ansible-playbook -i "${SCRIPT_DIR}/inventory.ini" "${SCRIPT_DIR}/playbook-apache.yml" | tee /tmp/ansible-run2.log

echo
print_info "Analisando idempotência..."
echo

# Verificar tarefas alteradas na segunda execução
CHANGED_COUNT="$(grep -c "changed=" /tmp/ansible-run2.log | tail -1 || true)"

if grep -q "changed=0" /tmp/ansible-run2.log; then
  print_success "Playbook é idempotente"
  echo "  Segunda execução não fez alterações"
else
  print_warning "Algumas tarefas reportaram alterações na segunda execução"
  echo "  Verifique /tmp/ansible-run2.log para detalhes"
  echo
  echo "Causas comuns:"
  echo "  - Usando 'command' ou 'shell' sem 'creates' ou 'changed_when'"
  echo "  - Templates com conteúdo dinâmico"
  echo "  - Módulos não idempotentes"
fi

echo
print_success "Teste de idempotência concluído"
echo
echo "Logs:"
echo "  Primeira execução:  /tmp/ansible-run1.log"
echo "  Segunda execução: /tmp/ansible-run2.log"
