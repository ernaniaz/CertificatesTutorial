#!/usr/bin/env bash
#=============================================================================
# Lab 12: Verificar política
# Exibe a política criptográfica atual do sistema
#
# Uso: ./check-policy.sh
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

print_header "Lab 12: Verificar Crypto-Policy"

# Verificar versão do RHEL
if [[ ${RHEL_VERSION} -lt 8 ]]; then
  print_error "Erro: Crypto-policies requer RHEL 8 ou mais recente"
  echo "Versão atual: RHEL ${RHEL_VERSION}"
  exit 1
fi

echo "Versão RHEL: ${RHEL_VERSION}"
echo

# Verificar política atual
print_info "Crypto-policy atual:"
CURRENT_POLICY="$(update-crypto-policies --show 2>/dev/null || cat /etc/crypto-policies/config 2>/dev/null || echo "UNKNOWN")"
print_success " ${CURRENT_POLICY}"

echo

# Mostrar arquivo de configuração da política
print_info "Arquivo de configuração de política:"
if [[ -f /etc/crypto-policies/config ]]; then
  echo "  Localização: /etc/crypto-policies/config"
  echo "  Conteúdo: $(cat /etc/crypto-policies/config)"
else
  echo "  Arquivo de configuração não encontrado"
fi

echo

# Listar políticas disponíveis
print_info "Políticas disponíveis:"
if [[ -d /usr/share/crypto-policies/policies/ ]]; then
  ls -1 /usr/share/crypto-policies/policies/*.pol 2>/dev/null | sed 's|.*/||;s|\.pol$||' | while read policy; do
    if [[ ${policy} == ${CURRENT_POLICY} ]]; then
      echo -e " ${GREEN}*${policy} (current)${NC}"
    else
      echo "   ${policy}"
    fi
  done
else
  echo "  Diretório de políticas não encontrado"
fi

echo

# Mostrar configurações de backend
print_info "Configurações backend:"
if [[ -d /etc/crypto-policies/back-ends/ ]]; then
  echo "  Diretório de config backend: /etc/crypto-policies/back-ends/"
  ls -1 /etc/crypto-policies/back-ends/ 2>/dev/null | head -10
else
  echo "  Diretório backend não encontrado"
fi

echo

# Mostrar detalhes da política (amostra)
print_info "Detalhes da política atual:"
if [[ -f "/usr/share/crypto-policies/policies/${CURRENT_POLICY}.pol" ]]; then
  echo "  Arquivo de política: /usr/share/crypto-policies/policies/${CURRENT_POLICY}.pol"
  echo
  echo "  Configuração de exemplo (primeiras 20 linhas):"
  head -20 "/usr/share/crypto-policies/policies/${CURRENT_POLICY}.pol" 2>/dev/null | sed 's/^/    /'
else
  echo "  Arquivo de política não encontrado"
fi

echo
print_success "Verificação de política concluída"
echo
echo "Para alterar a política:"
echo "  sudo update-crypto-policies --set LEGACY"
echo "  sudo update-crypto-policies --set DEFAULT"
echo "  sudo update-crypto-policies --set FUTURE"
