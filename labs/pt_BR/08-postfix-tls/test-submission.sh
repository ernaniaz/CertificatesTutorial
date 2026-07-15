#!/usr/bin/env bash
#=============================================================================
# Lab 08: Testar Submission
# Testa a porta submission com TLS obrigatório
#
# Uso: ./test-submission.sh
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

print_header "Lab 08: Testando Porta de Submissão (587)"

# Testar porta de submission escutando
print_info "Testando porta de submission 587..."
if ss -tlnp | grep -q ':587'; then
  print_success "Porta 587 escutando"
else
  print_error "Porta 587 não está escutando"
  echo "Verificar configuração de master.cf"
  exit 1
fi

echo

# Testar EHLO na porta de submission
print_info "Testando EHLO na porta de submission..."
EHLO_RESPONSE="$(timeout 5 bash -c "echo -e 'EHLO localhost\nQUIT' | nc localhost 587" 2>/dev/null)"

if echo "${EHLO_RESPONSE}" | grep -q "220"; then
  print_success "Porta de submission respondendo"
else
  print_error "Porta de submission não respondendo corretamente"
  exit 1
fi

# Verificar STARTTLS
if echo "${EHLO_RESPONSE}" | grep -q "STARTTLS"; then
  print_success "STARTTLS disponível"
fi

# Verificar AUTH
if echo "${EHLO_RESPONSE}" | grep -q "AUTH"; then
  print_success "Métodos AUTH anunciados"
fi

echo

# Testar conexão TLS na porta de submission
print_info "Testando TLS na porta de submission..."
TLS_TEST="$(echo "QUIT" | openssl s_client -connect localhost:587 -starttls smtp -brief 2>&1)"

if echo "${TLS_TEST}" | grep -q "Cipher\|Protocol"; then
  print_success "Conexão TLS bem-sucedida"

  # Extrair protocolo
  PROTOCOL="$(echo "${TLS_TEST}" | grep "Protocol" | head -1)"
  if [[ -n "${PROTOCOL}" ]]; then
    echo " ${PROTOCOL}"
  fi

  # Extrair cipher
  CIPHER="$(echo "${TLS_TEST}" | grep "Cipher" | head -1)"
  if [[ -n "${CIPHER}" ]]; then
    echo " ${CIPHER}"
  fi
else
  print_warning "Teste TLS inconclusivo"
fi

echo

# Verificar nível de segurança TLS
print_info "Verificando nível de segurança TLS..."
TLS_LEVEL="$(postconf -h smtpd_tls_security_level 2>/dev/null || echo "not set")"
echo "  smtpd_tls_security_level: ${TLS_LEVEL}"

# Verificar se submission tem requisito de encrypt
if grep -q "smtpd_tls_security_level=encrypt" /etc/postfix/master.cf; then
  print_success "Porta de submission exige criptografia"
else
  print_warning "Porta de submission pode não exigir criptografia"
fi

echo
print_success "Testes da porta de submission concluídos"
echo
echo "Comandos de teste manual:"
echo "  openssl s_client -connect localhost:587 -starttls smtp"
echo "  telnet localhost 587"
