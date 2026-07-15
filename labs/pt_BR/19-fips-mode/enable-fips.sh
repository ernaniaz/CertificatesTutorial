#!/usr/bin/env bash
#=============================================================================
# Lab 19: Habilitar FIPS
# Script para habilitar FIPS do Lab 19
#
# Uso: ./enable-fips.sh
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

print_header "Lab 19: Habilitar Modo FIPS"

if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root"
  exit 1
fi

if [[ ${RHEL_VERSION} -ge 10 ]]; then
  print_error "RHEL 10+ não suporta habilitar FIPS após a instalação."
  echo
  echo "No RHEL 10, o modo FIPS deve ser habilitado durante a instalação do SO."
  echo "Para reinstalar com FIPS habilitado, adicione o seguinte parâmetro de kernel"
  echo "na linha de comando de boot do instalador:"
  echo "  fips=1"
  echo
  echo "Ou selecione a opção FIPS na política de segurança do instalador Anaconda."
  echo
  echo "Para verificar o status atual do FIPS:"
  echo "  fips-mode-setup --check"
  exit 1
fi

print_warning "AVISO: Habilitar modo FIPS irá:"
echo "  - Requer reinicialização do sistema"
echo "  - Bloqueia algoritmos não FIPS"
echo "  - Pode quebrar algumas aplicações"
echo

read -p "Continuar? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Cancelado"
  exit 0
fi

echo
print_info "Habilitando modo FIPS..."

if command -v fips-mode-setup &>/dev/null; then
  fips-mode-setup --enable
  echo
  print_success "Modo FIPS será habilitado após reinicialização"
  echo
  read -p "Reinicializar agora? (s/N): " -n 1 -r
  echo
  if [[ ${REPLY} =~ ^[Ss]$ ]]; then
    reboot
  fi
else
  print_error "fips-mode-setup não disponível"
  exit 1
fi
