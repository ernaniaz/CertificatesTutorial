#!/usr/bin/env bash
#=============================================================================
# Lab 12: Testar compatibilidade
# Testa o comportamento do sistema sob a política atual
#
# Uso: ./test-compatibility.sh
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

print_header "Lab 12: Testar Compatibilidade"

# Obter política atual
CURRENT_POLICY="$(update-crypto-policies --show 2>/dev/null || echo "UNKNOWN")"
echo "Testando sob política: ${CURRENT_POLICY}"
echo

# Testar cifras OpenSSL
print_info "1. Cifras OpenSSL:"
echo "Contagem de cifras disponíveis:"
CIPHER_COUNT="$(openssl ciphers -v 2>/dev/null | wc -l)"
echo " ${CIPHER_COUNT} cifras disponíveis"
echo
echo "Amostra de cifras (primeiras 10):"
openssl ciphers -v 2>/dev/null | head -10 | sed 's/^/  /'

echo

# Testar versões TLS
print_info "2. Versões TLS/SSL:"
echo "Testando quais versões TLS/SSL estão disponíveis..."

# Testar TLS 1.0
if echo | openssl s_client -connect www.google.com:443 -tls1 2>/dev/null | grep -q "Protocol.*TLSv1$"; then
  echo -e " ${GREEN}✓ TLS 1.0 available${NC}"
else
  echo "  ✗ TLS 1.0 não disponível"
fi

# Testar TLS 1.1
if echo | openssl s_client -connect www.google.com:443 -tls1_1 2>/dev/null | grep -q "Protocol.*TLSv1.1"; then
  echo -e " ${GREEN}✓ TLS 1.1 available${NC}"
else
  echo "  ✗ TLS 1.1 não disponível"
fi

# Testar TLS 1.2
if echo | openssl s_client -connect www.google.com:443 -tls1_2 2>&1 | grep -q "Protocol.*TLSv1.2"; then
  echo -e " ${GREEN}✓ TLS 1.2 available${NC}"
else
  echo "  ✗ TLS 1.2 não disponível"
fi

# Testar TLS 1.3
if echo | openssl s_client -connect www.google.com:443 -tls1_3 2>&1 | grep -q "Protocol.*TLSv1.3"; then
  echo -e " ${GREEN}✓ TLS 1.3 available${NC}"
else
  echo "  ✗ TLS 1.3 não disponível"
fi

echo

# Testar cifras SSH
print_info "3. Cifras SSH:"
if command -v ssh &>/dev/null; then
  SSH_CIPHER_COUNT="$(ssh -Q cipher 2>/dev/null | wc -l)"
  echo "Cifras SSH disponíveis: ${SSH_CIPHER_COUNT}"
  echo "Amostra de cifras SSH (primeiras 5):"
  ssh -Q cipher 2>/dev/null | head -5 | sed 's/^/  /'
else
  echo "SSH não disponível para teste"
fi

echo

# Mostrar configurações de backend
print_info "4. Configurações backend:"
echo "Config OpenSSL:"
if [[ -f /etc/crypto-policies/back-ends/opensslcnf.config ]]; then
  head -5 /etc/crypto-policies/back-ends/opensslcnf.config 2>/dev/null | sed 's/^/  /'
else
  echo "  Não encontrado"
fi

echo
echo "Config OpenSSH:"
if [[ -f /etc/crypto-policies/back-ends/openssh.config ]]; then
  cat /etc/crypto-policies/back-ends/openssh.config 2>/dev/null | sed 's/^/  /'
else
  echo "  Não encontrado"
fi

echo
print_success "Teste de compatibilidade concluído"
echo
echo "Política atual: ${CURRENT_POLICY}"
echo
echo "Comparação de políticas:"
echo "  LEGACY: Mais compatível, segurança mais fraca"
echo "  DEFAULT: Equilibrado"
echo "  FUTURE: Mais seguro, pode quebrar clientes antigos"
