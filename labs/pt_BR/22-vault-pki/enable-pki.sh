#!/usr/bin/env bash
#=============================================================================
# Lab 22: Habilitar PKI
# Habilita e configura o motor de segredos PKI
#
# Uso: ./enable-pki.sh
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

print_header "Lab 22: Habilitar PKI Secrets Engine"

# --- Passo 1: Carregar detalhes de conexão do Vault ---
print_step "Carregando ambiente Vault"

if [[ -f "${SCRIPT_DIR}/vault-env.sh" ]]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/vault-env.sh"
  print_success "Ambiente carregado de vault-env.sh"
else
  print_warning "vault-env.sh não encontrado — usando padrões"
  export VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
  export VAULT_TOKEN="${VAULT_TOKEN:-root}"
fi
echo

# --- Passo 2: Verificar se Vault está em execução e desbloqueado ---
print_step "Verificando status do Vault"

if ! command -v vault &> /dev/null; then
  error_exit "Vault não encontrado. Execute ./install-vault.sh primeiro"
fi

if ! vault status &> /dev/null; then
  error_exit "Vault não está em execução. Execute ./start-vault-dev.sh primeiro"
fi

print_success "Vault está em execução e acessível"
echo

# --- Passo 3: Habilitar secrets engine PKI ---
print_step "Habilitando PKI secrets engine"

if vault secrets list | grep -q "^pki/"; then
  print_warning "PKI secrets engine já habilitado"
else
  if ! vault secrets enable pki; then
    error_exit "Falha ao habilitar PKI secrets engine"
  fi
  print_success "PKI secrets engine habilitado em: pki/"
fi
echo

# --- Passo 4: Configurar TTL máximo de lease ---
print_step "Configurando lease TTL máximo"

# Certificados de CA raiz precisam de TTL longo para evitar reemissão frequente em laboratórios
if ! vault secrets tune -max-lease-ttl=87600h pki; then
  error_exit "Falha ao ajustar lease TTL máximo do PKI"
fi

print_success "TTL máximo de lease definido para: 87600h (10 anos)"
echo

print_success "PKI secrets engine pronto"
echo

# --- Passo 5: Exibir informações do engine PKI ---
print_step "Informações do PKI secrets engine"

print_info "Secrets engines habilitados:"
vault secrets list | grep -E "Path|pki"
echo
print_info "Configuração do mount PKI:"
vault read sys/mounts/pki

echo
echo "Próximos passos:"
echo "  - Execute './configure-root-ca.sh' para criar CA raiz"
echo "  - Execute 'vault read pki/config' para visualizar configuração"
