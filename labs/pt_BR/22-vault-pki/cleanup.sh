#!/usr/bin/env bash
#=============================================================================
# Lab 22: Limpeza
# Para o Vault e remove todos os arquivos do lab
#
# Uso: ./cleanup.sh
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

# Diretório do script
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Keep Vault flag
KEEP_VAULT=false
if [[ "${1:-}" == "--keep-vault" ]]; then
  KEEP_VAULT=true
fi

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

print_header "Lab 22: Limpeza"

# --- Passo 1: Confirmar limpeza com o usuário ---
print_step "Confirmando limpeza"

print_warning "Isso parará Vault e removerá todos os arquivos do laboratório"
read -p "Continuar? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  print_info "Limpeza cancelada"
  exit 0
fi
echo

# --- Passo 2: Parar processo Vault ---
print_step "Parando Vault"

if [[ -f "${SCRIPT_DIR}/vault-env.sh" ]]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/vault-env.sh"
fi

if [[ -n "${VAULT_PID:-}" ]] && kill -0 "${VAULT_PID}" 2>/dev/null; then
  kill "${VAULT_PID}" || true
  sleep 2
  print_success "Vault parado (PID ${VAULT_PID})"
elif pgrep -x vault > /dev/null; then
  pkill vault || true
  sleep 2
  if pgrep -x vault > /dev/null; then
    pkill -9 vault || true
  fi
  print_success "Vault parado"
else
  print_info "Vault não em execução"
fi
echo

# --- Passo 3: Remover arquivos de certificado ---
print_step "Removendo arquivos de certificado"

if [[ -d "${SCRIPT_DIR}/certs" ]]; then
  rm -rf "${SCRIPT_DIR}/certs"
  print_success "Diretório de certificados removido"
fi

rm -f "${SCRIPT_DIR}/root-ca.crt"
rm -f "${SCRIPT_DIR}/intermediate.csr"
rm -f "${SCRIPT_DIR}/intermediate.crt"
rm -f "${SCRIPT_DIR}/crl.pem"
print_success "Arquivos CA e CRL removidos"
echo

# --- Passo 4: Remover arquivos de configuração Vault ---
print_step "Removendo arquivos de configuração Vault"

rm -f "${SCRIPT_DIR}/vault-env.sh"
rm -f "${SCRIPT_DIR}/vault.log"
print_success "Arquivos de configuração removidos"
echo

# --- Passo 5: Remover binário Vault opcionalmente ---
if [[ ${KEEP_VAULT} == false ]]; then
  print_step "Removendo binário Vault"

  if command -v vault &> /dev/null; then
    read -p "Remover Vault de /usr/local/bin/vault? (s/N): " -n 1 -r
    echo
    if [[ ${REPLY} =~ ^[Ss]$ ]]; then
      sudo rm -f /usr/local/bin/vault
      print_success "Binário Vault removido"
    else
      print_info "Binário Vault mantido"
    fi
  else
    print_info "Binário Vault não encontrado"
  fi
  echo
else
  print_info "Mantendo binário do Vault (--keep-vault)"
  echo
fi

# --- Passo 6: Exibir resumo de limpeza ---
print_step "Resumo da limpeza"

print_success "Limpeza concluída"
echo "  - Vault parado"
echo "  - Certificados removidos"
echo "  - Arquivos de configuração removidos"
if [[ ${KEEP_VAULT} == false ]]; then
  echo "  - Remoção do binário Vault oferecida"
else
  echo "  - Binário Vault mantido"
fi
echo
print_warning "Nota: No modo dev, todos os dados do Vault foram armazenados em memória"
print_info "Todos os dados PKI foram perdidos (comportamento esperado)"

echo
echo "Para executar o laboratório novamente:"
echo "  1. ./start-vault-dev.sh"
echo "  2. ./enable-pki.sh"
echo "  3. Continue com os scripts restantes"
echo
echo "Ou para começar do zero:"
echo "  ./install-vault.sh"
