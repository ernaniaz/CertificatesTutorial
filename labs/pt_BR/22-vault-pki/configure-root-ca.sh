#!/usr/bin/env bash
#=============================================================================
# Lab 22: Configurar CA raiz
# Gera e configura a CA raiz
#
# Uso: ./configure-root-ca.sh
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

print_header "Lab 22: Configurar CA Raiz"

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

# --- Passo 2: Verificar se engine PKI está habilitado ---
print_step "Verificando pré-requisitos"

if ! vault secrets list | grep -q "^pki/"; then
  error_exit "PKI secrets engine não habilitado. Execute ./enable-pki.sh primeiro"
fi

print_success "PKI secrets engine encontrado"
echo

# --- Passo 3: Gerar CA raiz interna ---
print_step "Gerando certificado CA raiz"

# A geração interna mantém a chave privada dentro do Vault — nunca exportada para disco
if ! vault write -field=certificate pki/root/generate/internal \
  common_name="Lab Root CA" \
  issuer_name="root-2025" \
  ttl=87600h \
  > "${SCRIPT_DIR}/root-ca.crt"; then
  error_exit "Falha ao gerar CA raiz"
fi

print_success "CA raiz gerada"
print_info "CA raiz salva em: root-ca.crt"
echo

# --- Passo 4: Configurar URLs de distribuição CA e CRL ---
print_step "Configurando URLs da CA"

# Clientes precisam dessas URLs para construir cadeias de confiança e verificar revogação
if ! vault write pki/config/urls \
  issuing_certificates="http://127.0.0.1:8200/v1/pki/ca" \
  crl_distribution_points="http://127.0.0.1:8200/v1/pki/crl"; then
  error_exit "Falha ao configurar URLs da CA"
fi

print_success "URLs da CA configuradas"
echo

print_success "Configuração da CA raiz concluída"
echo

# --- Passo 5: Exibir informações da CA raiz ---
print_step "Informações da CA raiz"

print_info "Detalhes do certificado:"
openssl x509 -in "${SCRIPT_DIR}/root-ca.crt" -noout -text | grep -A2 "Subject:\|Issuer:\|Validity"
echo
print_info "Configuração de URL da CA:"
vault read pki/config/urls
echo
print_info "CA raiz do Vault:"
vault read pki/cert/ca

echo
echo "Próximos passos:"
echo "  - Execute './configure-intermediate-ca.sh' para criar CA intermediária"
echo "  - Visualize CA: vault read pki/cert/ca"
