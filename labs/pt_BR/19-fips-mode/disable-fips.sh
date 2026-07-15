#!/usr/bin/env bash
#=============================================================================
# Lab 19: Desabilitar FIPS
# Desabilita o modo FIPS (se necessário)
#
# Uso: ./disable-fips.sh
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

print_header "Lab 19: Desabilitar Modo FIPS"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

if [[ ${RHEL_VERSION} -ge 10 ]]; then
  print_error "RHEL 10+ não suporta desabilitar FIPS após a instalação."
  echo
  echo "No RHEL 10, o modo FIPS é definido na instalação e não pode ser"
  echo "alterado depois. Uma reinstalação sem o parâmetro de kernel fips=1"
  echo "é necessária para executar sem FIPS."
  echo
  echo "Status atual do FIPS:"
  fips-mode-setup --check 2>/dev/null || cat /proc/sys/crypto/fips_enabled
  exit 1
fi

print_warning "AVISO: Desabilitando modo FIPS"
echo
echo "Isso só deve ser feito se:"
echo "  - Conformidade FIPS não é obrigatória"
echo "  - Ambiente de teste/lab"
echo "  - Solução de problemas FIPS"
echo

read -p "Desabilitar modo FIPS? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Operação cancelada"
  exit 0
fi

echo

# Verificar se o FIPS está habilitado
if [[ ! -f /proc/sys/crypto/fips_enabled || "$(cat /proc/sys/crypto/fips_enabled)" != "1" ]]; then
  print_success "Modo FIPS já desabilitado"
  exit 0
fi

# Desabilitar FIPS
print_info "Desabilitando modo FIPS..."

if command -v fips-mode-setup &>/dev/null; then
  fips-mode-setup --disable
  print_success "Modo FIPS desabilitado"
else
  print_error "Comando fips-mode-setup não encontrado"
  exit 1
fi

echo
print_error "⚠ REINICIALIZAÇÃO NECESSÁRIA"
echo
echo "Após reinicialização, modo FIPS será desabilitado"
echo
echo "Para reinicializar agora:"
echo "  sudo reboot"
