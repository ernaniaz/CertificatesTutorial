#!/usr/bin/env bash
#=============================================================================
# Lab 05: Verificação de confiança
# Verifica que a CA personalizada seja confiável para o sistema
#
# Uso: ./verify-trust.sh
# Pré-requisitos: RHEL 7, 8, 9, 10
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
if [[ ${RHEL_VERSION} -lt 7 || ${RHEL_VERSION} -gt 10 ]]; then
  error_exit "Versão do RHEL não suportada. Este script requer RHEL 7, 8, 9 ou 10."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

OUTPUT_DIR="output"
CA_CERT="${OUTPUT_DIR}/test-ca.crt"
CA_KEY="${OUTPUT_DIR}/test-ca.key"
TEST_KEY="${OUTPUT_DIR}/test-server.key"
TEST_CERT="${OUTPUT_DIR}/test-server.crt"

print_header "Lab 05: Verificando Confiança da CA"

# Verificar pré-requisitos
if [[ ! -f "${CA_CERT}" || ! -f "${CA_KEY}" ]]; then
  print_error "Erro: Arquivos CA não encontrados"
  exit 1
fi

# Gerar chave de servidor de teste
print_info "Criando certificado de servidor de teste assinado por CA personalizada..."
openssl genpkey -algorithm RSA -out "${TEST_KEY}" -pkeyopt rsa_keygen_bits:2048 2>/dev/null

# Gerar certificado de teste assinado por CA personalizada
openssl req -new -key "${TEST_KEY}" \
  -subj "/C=US/ST=State/O=Lab/CN=test.example.com" | \
openssl x509 -req -sha256 -days 365 \
  -CA "${CA_CERT}" -CAkey "${CA_KEY}" -CAcreateserial \
  -out "${TEST_CERT}" 2>/dev/null

print_success "Certificado de teste criado"
echo

# Teste 1: Verificar com confiança do sistema (deve ter sucesso se CA for confiável)
print_info "Teste 1: Verificando com repositório de confiança do sistema..."
if openssl verify "${TEST_CERT}" &>/dev/null; then
  print_success "SUCESSO: Certificado verificado com confiança do sistema"
  echo "  Sua CA personalizada é confiável pelo sistema!"
else
  print_warning "FALHOU: Certificado não confiável pelo sistema"
  echo "  Você executou ./update-trust.sh?"
fi
echo

# Teste 2: Verificar com CA explícita (deve sempre ter sucesso)
print_info "Teste 2: Verificando com CA explícita..."
if openssl verify -CAfile "${CA_CERT}" "${TEST_CERT}" &>/dev/null; then
  print_success "SUCESSO: Certificado verificado com CA explícita"
else
  print_error "FALHOU: Isso não deveria acontecer"
  exit 1
fi
echo

# Teste 3: Verificar se CA está no pacote
print_info "Teste 3: Verificando se CA está no pacote do sistema..."
if grep -q "Lab Test Root CA" /etc/pki/tls/certs/ca-bundle.crt 2>/dev/null; then
  print_success "SUCESSO: CA encontrada no pacote do sistema"
else
  print_warning "AVISO: CA não encontrada no pacote do sistema"
  echo "  Execute: sudo ./update-trust.sh"
fi
echo

print_success "Verificação de confiança concluída"
