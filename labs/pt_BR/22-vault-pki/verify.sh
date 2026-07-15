#!/usr/bin/env bash
#=============================================================================
# Lab 22: Verificar
# Valida que todos os componentes do lab estejam configurados corretamente
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

# Diretório do script
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Counters
PASS=0
FAIL=0

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

print_header "Lab 22: Verificação"

# --- Passo 1: Carregar detalhes de conexão do Vault ---
print_step "Carregando ambiente Vault"

if [[ -f "${SCRIPT_DIR}/vault-env.sh" ]]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/vault-env.sh"
  print_success "Ambiente carregado de vault-env.sh"
else
  export VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
  export VAULT_TOKEN="${VAULT_TOKEN:-root}"
  print_warning "vault-env.sh não encontrado — usando padrões"
fi
echo

# --- Passo 2: Executar testes de verificação ---
print_step "Executando testes de verificação"

if pgrep -x vault &> /dev/null; then
  print_success "PASS: Vault está em execução"
  PASS=$((PASS + 1))
else
  print_error "FALHA: Vault está em execução"
  FAIL=$((FAIL + 1))
fi

if vault status &> /dev/null; then
  print_success "PASS: Vault está acessível e desbloqueado"
  PASS=$((PASS + 1))
else
  print_error "FALHA: Vault está acessível e desbloqueado"
  FAIL=$((FAIL + 1))
fi

if vault secrets list | grep -q '^pki/'; then
  print_success "PASS: PKI secrets engine está habilitado"
  PASS=$((PASS + 1))
else
  print_error "FALHA: PKI secrets engine está habilitado"
  FAIL=$((FAIL + 1))
fi

if vault read pki/cert/ca &> /dev/null; then
  print_success "PASS: CA raiz existe"
  PASS=$((PASS + 1))
else
  print_error "FALHA: CA raiz existe"
  FAIL=$((FAIL + 1))
fi

if vault read pki_int/cert/ca &> /dev/null; then
  print_success "PASS: CA intermediária existe"
  PASS=$((PASS + 1))
else
  print_error "FALHA: CA intermediária existe"
  FAIL=$((FAIL + 1))
fi

if vault read pki_int/roles/web-server &> /dev/null; then
  print_success "PASS: Role PKI 'web-server' existe"
  PASS=$((PASS + 1))
else
  print_error "FALHA: Role PKI 'web-server' existe"
  FAIL=$((FAIL + 1))
fi

if [[ -n "$(find "${SCRIPT_DIR}/certs" -maxdepth 1 -name '*.crt' ! -name '*-chain.crt' ! -name '*-ca.crt' 2>/dev/null)" ]]; then
  print_success "PASS: Certificados foram emitidos"
  PASS=$((PASS + 1))
else
  print_error "FALHA: Certificados foram emitidos"
  FAIL=$((FAIL + 1))
fi

echo

# --- Passo 3: Exibir resumo aprovado/reprovado ---
print_step "Resumo da verificação"

echo
echo "Aprovados: ${PASS}"
echo "Falhou: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "Todas as validações aprovadas!"
  print_success "Lab 22 concluído com sucesso."
  echo
  echo "Você concluiu com sucesso:"
  echo "  - HashiCorp Vault instalado"
  echo "  - Secrets engine PKI configurado"
  echo "  - Hierarquia de CA raiz e intermediária criada"
  echo "  - Roles PKI criadas e certificados dinâmicos emitidos"
  echo "  - Revogação de certificados compreendida"
  exit 0
else
  print_error "Algumas validações falharam."
  echo
  echo "Solução de problemas:"
  echo "  - Verifique se o Vault está em execução: vault status"
  echo "  - Verifique os logs do Vault: cat vault.log"
  echo "  - Verifique ambiente: source vault-env.sh"
  echo "  - Execute novamente scripts de lab com falha"
  exit 1
fi
