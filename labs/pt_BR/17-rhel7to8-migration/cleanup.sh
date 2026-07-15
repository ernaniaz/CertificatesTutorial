#!/usr/bin/env bash
#=============================================================================
# Lab 17: Limpeza
# Remove arquivos temporários
#
# Uso: ./cleanup.sh
# Pré-requisitos: RHEL 7
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
if [[ ${RHEL_VERSION} -ne 7 ]]; then
  error_exit "Versão do RHEL não suportada. Este script requer apenas RHEL 7."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

print_header "Lab 17: Limpeza da Migração"

print_warning "Isso removerá arquivos de teste de migração"
print_warning "Arquivos de backup serão preservados"
echo

read -p "Continuar? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Limpeza cancelada"
  exit 0
fi

echo
print_info "Limpando..."

# Remover quaisquer arquivos de teste criados durante a migração
rm -f /tmp/migration-test-*

print_success "Limpeza concluída"
echo
echo "Arquivos de backup preservados em:"
if ! ls -lh /root/rhel7-cert-backup-*.tar.gz 2>/dev/null; then
  echo "  Nenhum encontrado"
fi
echo
echo "Para remover backups (se não forem mais necessários):"
echo "  rm /root/rhel7-cert-backup-*.tar.gz"
