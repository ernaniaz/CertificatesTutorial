#!/usr/bin/env bash
#=============================================================================
# Lab 22: Configurar CA intermediária
# Cria e configura uma CA intermediária
#
# Uso: ./configure-intermediate-ca.sh
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

print_header "Lab 22: Configurar CA Intermediária"

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

# --- Passo 2: Verificar se CA raiz existe ---
print_step "Verificando pré-requisitos"

if ! vault read pki/cert/ca &> /dev/null; then
  error_exit "CA raiz não encontrada. Execute ./configure-root-ca.sh primeiro"
fi

print_success "CA raiz encontrada"
echo

# --- Passo 3: Habilitar engine PKI intermediário ---
print_step "Habilitando PKI secrets engine intermediário"

if vault secrets list | grep -q "^pki_int/"; then
  print_warning "PKI intermediário já habilitado"
else
  if ! vault secrets enable -path=pki_int pki; then
    error_exit "Falha ao habilitar PKI secrets engine intermediário"
  fi
  print_success "PKI intermediário habilitado em: pki_int/"
fi
echo

# --- Passo 4: Ajustar TTL de lease PKI intermediário ---
print_step "Configurando lease TTL do PKI intermediário"

# CAs intermediárias normalmente têm validade mais curta que a raiz
if ! vault secrets tune -max-lease-ttl=43800h pki_int; then
  error_exit "Falha ao ajustar lease TTL máximo do PKI intermediário"
fi

print_success "TTL máximo de lease definido para: 43800h (5 anos)"
echo

# --- Passo 5: Gerar CSR intermediário ---
print_step "Gerando CSR da CA intermediária"

if ! vault write -field=csr pki_int/intermediate/generate/internal \
  common_name="Lab Intermediate CA" \
  issuer_name="intermediate-2025" \
  > "${SCRIPT_DIR}/intermediate.csr"; then
  error_exit "Falha ao gerar CSR intermediário"
fi

print_success "CSR intermediário gerado"
print_info "CSR salvo em: intermediate.csr"
echo

# --- Passo 6: Assinar CSR com CA raiz ---
print_step "Assinando CSR intermediário com CA raiz"

# Raiz assina a intermediária — hierarquia PKI padrão de dois níveis
if ! vault write -field=certificate pki/root/sign-intermediate \
  issuer_ref="root-2025" \
  csr=@"${SCRIPT_DIR}/intermediate.csr" \
  format=pem_bundle \
  ttl=43800h \
  > "${SCRIPT_DIR}/intermediate.crt"; then
  error_exit "Falha ao assinar CSR intermediário"
fi

print_success "Certificado intermediário assinado"
print_info "Certificado salvo em: intermediate.crt"
echo

# --- Passo 7: Importar certificado assinado no engine intermediário ---
print_step "Definindo certificado intermediário"

if ! vault write pki_int/intermediate/set-signed \
  certificate=@"${SCRIPT_DIR}/intermediate.crt"; then
  error_exit "Falha ao definir certificado intermediário"
fi

print_success "Certificado intermediário definido"
echo

# --- Passo 8: Configurar URLs da CA intermediária ---
print_step "Configurando URLs da CA intermediária"

if ! vault write pki_int/config/urls \
  issuing_certificates="http://127.0.0.1:8200/v1/pki_int/ca" \
  crl_distribution_points="http://127.0.0.1:8200/v1/pki_int/crl"; then
  error_exit "Falha ao configurar URLs da CA intermediária"
fi

print_success "URLs intermediárias configuradas"
echo

print_success "Configuração da CA intermediária concluída"
echo

# --- Passo 9: Exibir info da CA intermediária e verificar cadeia ---
print_step "Informações da CA intermediária"

print_info "Detalhes do certificado:"
openssl x509 -in "${SCRIPT_DIR}/intermediate.crt" -noout -text | grep -A2 "Subject:\|Issuer:\|Validity"
echo
print_info "Configuração de URL da CA:"
vault read pki_int/config/urls
echo
print_info "CA intermediária do Vault:"
vault read pki_int/cert/ca
echo

print_step "Verificando cadeia de certificados"

if openssl verify -CAfile "${SCRIPT_DIR}/root-ca.crt" "${SCRIPT_DIR}/intermediate.crt" &> /dev/null; then
  print_success "Cadeia de certificados é válida"
else
  print_warning "A verificação da cadeia de certificados apresentou problemas (pode ser normal em modo dev)"
fi

echo
echo "Próximos passos:"
echo "  - Execute './create-role.sh' para criar uma role PKI"
echo "  - Visualize CA intermediária: vault read pki_int/cert/ca"
