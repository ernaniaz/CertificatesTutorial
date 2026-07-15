#!/usr/bin/env bash
#=============================================================================
# Lab 20: Testar endurecimento
# Testa as medidas de segurança aplicadas
#
# Uso: ./test-hardening.sh
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

print_header "Lab 20: Testes de Endurecimento de Segurança"

# Testar Apache se estiver em execução
if systemctl is-active httpd &>/dev/null; then
  print_info "Testando HTTPS do Apache..."

  # Verificar cabeçalho HSTS
  if curl -k -I https://localhost/ 2>/dev/null | grep -qi "strict-transport-security"; then
    echo -e " ${GREEN}✓ Cabeçalho HSTS presente${NC}"
  else
    echo -e " ${YELLOW}⚠ Cabeçalho HSTS não encontrado${NC}"
  fi

  # Verificar X-Frame-Options
  if curl -k -I https://localhost/ 2>/dev/null | grep -qi "x-frame-options"; then
    echo -e " ${GREEN}✓ X-Frame-Options presente${NC}"
  else
    echo -e " ${YELLOW}⚠ X-Frame-Options não encontrado${NC}"
  fi

  # Testar TLS 1.0 (deve falhar)
  if echo | openssl s_client -connect localhost:443 -tls1 2>&1 | grep -q "Cipher.*is.*none"; then
    echo -e " ${GREEN}✓ TLS 1.0 bloqueado${NC}"
  else
    echo -e " ${YELLOW}⚠ TLS 1.0 pode estar permitido${NC}"
  fi

  echo
fi

# Testar NGINX se estiver em execução
if systemctl is-active nginx &>/dev/null; then
  print_info "Testando HTTPS do NGINX..."

  # Verificar cabeçalhos
  if curl -k -I https://localhost/ 2>/dev/null | grep -qi "strict-transport-security"; then
    echo -e " ${GREEN}✓ Cabeçalho HSTS presente${NC}"
  else
    echo -e " ${YELLOW}⚠ Cabeçalho HSTS não encontrado${NC}"
  fi

  echo
fi

# Testar cifras disponíveis
print_info "Testando força das cifras..."
CIPHER_COUNT="$(openssl ciphers -v 2>/dev/null | wc -l)"
echo "  Cifras disponíveis: ${CIPHER_COUNT}"

# Verificar ciphers fracos
WEAK="$(openssl ciphers -v 2>/dev/null | grep -iE "DES|RC4|MD5|NULL|EXPORT" | wc -l)"
if [[ ${WEAK} -eq 0 ]]; then
  echo -e " ${GREEN}✓ Nenhuma cifra fraca detectada${NC}"
else
  echo -e " ${YELLOW}⚠ ${WEAK} cifras fracas disponíveis${NC}"
fi

echo
print_success "Testes de segurança concluídos"
echo
echo "Para teste abrangente, use:"
echo "  https://www.ssllabs.com/ssltest/ (para sites públicos)"
echo "  testssl.sh localhost:443 (ferramenta de linha de comando)"
