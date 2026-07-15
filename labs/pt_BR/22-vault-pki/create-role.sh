#!/usr/bin/env bash
#=============================================================================
# Lab 22: Criar role
# Cria um role para a emissão de certificados
#
# Uso: ./create-role.sh
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

# Configuração do role
ROLE_NAME="${1:-web-server}"

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

print_header "Lab 22: Criar Role PKI"

# --- Passo 1: Carregar detalhes de conexão do Vault ---
print_step "Carregando ambiente Vault"

if [[ -f "${SCRIPT_DIR}/vault-env.sh" ]]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/vault-env.sh"
  print_success "Ambiente carregado de vault-env.sh"
else
  export VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
  export VAULT_TOKEN="${VAULT_TOKEN:-root}"
fi
echo

# --- Passo 2: Verificar se CA intermediária está pronta ---
print_step "Verificando pré-requisitos"

if ! vault read pki_int/cert/ca &> /dev/null; then
  error_exit "CA intermediária não encontrada. Execute ./configure-intermediate-ca.sh primeiro"
fi

print_success "CA intermediária encontrada"
echo

# --- Passo 3: Criar role PKI ---
print_step "Criando role PKI: ${ROLE_NAME}"

# Roles restringem quais certificados o Vault pode emitir — domínios, TTL, tipo de chave, etc.
if ! vault write "pki_int/roles/${ROLE_NAME}" \
  allowed_domains="example.com,lab.local" \
  allow_subdomains=true \
  max_ttl="72h" \
  ttl="24h" \
  key_type="rsa" \
  key_bits=2048 \
  allow_ip_sans=true \
  server_flag=true \
  client_flag=true \
  code_signing_flag=false \
  email_protection_flag=false; then
  error_exit "Falha ao criar role PKI '${ROLE_NAME}'"
fi

print_success "Role PKI '${ROLE_NAME}' criada"
echo

print_success "Configuração da role PKI concluída"
echo

# --- Passo 4: Exibir informações da role ---
print_step "Informações da role PKI"

print_info "Role: ${ROLE_NAME}"
echo
vault read "pki_int/roles/${ROLE_NAME}"
echo

# --- Passo 5: Exibir exemplos de uso ---
print_step "Exemplos de uso"

print_info "Emitir um certificado:"
echo "  vault write pki_int/issue/${ROLE_NAME} \\"
echo "    common_name=\"server01.lab.local\" \\"
echo "    ttl=\"24h\""
echo
print_info "Emitir com IP SAN:"
echo "  vault write pki_int/issue/${ROLE_NAME} \\"
echo "    common_name=\"server02.lab.local\" \\"
echo "    ip_sans=\"192.168.1.100\" \\"
echo "    ttl=\"24h\""
echo
print_info "Emitir certificado de curta validade:"
echo "  vault write pki_int/issue/${ROLE_NAME} \\"
echo "    common_name=\"temp.lab.local\" \\"
echo "    ttl=\"1h\""

echo
echo "Próximos passos:"
echo "  - Execute './issue-certificate.sh' para emitir certificados"
echo "  - Liste roles: vault list pki_int/roles"
echo "  - Leia role: vault read pki_int/roles/${ROLE_NAME}"
