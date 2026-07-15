#!/usr/bin/env bash
#=============================================================================
# Lab 12: Verificar
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

print_header "Lab 12: Verificação Crypto-Policy"

# Verificar versão do RHEL
echo "Versão RHEL: ${RHEL_VERSION}"

if [[ ${RHEL_VERSION} -lt 8 ]]; then
  echo "Nota: Crypto-policies requer RHEL 8+"
  exit 0
fi

echo

print_info "1. Política atual:"
POLICY="$(update-crypto-policies --show 2>/dev/null)"
echo " ${POLICY}"

echo

print_info "2. Arquivo de configuração:"
if [[ -f /etc/crypto-policies/config ]]; then
  echo "  Conteúdo: $(cat /etc/crypto-policies/config)"
else
  echo "  Não encontrado"
fi

echo

print_info "3. Políticas disponíveis:"
if ! ls -1 /usr/share/crypto-policies/policies/*.pol 2>/dev/null | sed 's|.*/||;s|\.pol$||' | sed 's/^/  /'; then
  echo "  None found"
fi

echo

print_info "4. Configurações backend:"
if ! ls -1 /etc/crypto-policies/back-ends/ 2>/dev/null | sed 's/^/  /'; then
  echo "  None found"
fi

echo

print_info "5. Contagem de cifras OpenSSL:"
CIPHER_COUNT="$(openssl ciphers -v 2>/dev/null | wc -l)"
echo " ${CIPHER_COUNT} cifras"

echo

print_info "6. Cifras SSH disponíveis:"
if command -v ssh &>/dev/null; then
  SSH_COUNT="$(ssh -Q cipher 2>/dev/null | wc -l)"
  echo " ${SSH_COUNT} cifras SSH"
else
  echo "  SSH não instalado"
fi

echo
print_success "Verificação concluída"
