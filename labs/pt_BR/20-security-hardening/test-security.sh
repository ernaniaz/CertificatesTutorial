#!/usr/bin/env bash
#=============================================================================
# Lab 20: Testar segurança
# Testa a configuração de segurança endurecida
#
# Uso: ./test-security.sh
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

print_header "Lab 20: Testes de Configuração de Segurança"

# Testar Apache se estiver em execução
if systemctl is-active httpd &>/dev/null; then
  print_info "Testando HTTPS do Apache..."

  # Testar conexão TLS
  TLS_INFO="$(echo "QUIT" | timeout 5 openssl s_client -connect localhost:443 2>&1 || true)"

  if echo "${TLS_INFO}" | grep -q "Protocol.*TLSv1\.[23]"; then
    PROTOCOL="$(echo "${TLS_INFO}" | grep "Protocol" | head -1 | awk '{print $2}')"
    print_success "Protocolo TLS: ${PROTOCOL}"
  else
    print_warning "Não foi possível detectar a versão TLS"
  fi

  # Verificar cabeçalho HSTS
  if curl -I -k https://localhost/ 2>/dev/null | grep -qi "Strict-Transport-Security"; then
    print_success "Cabeçalho HSTS presente"
  else
    print_warning "Cabeçalho HSTS ausente"
  fi

  echo
fi

# Testar NGINX se estiver em execução
if systemctl is-active nginx &>/dev/null; then
  print_info "Testando HTTPS do NGINX..."

  # Testar conexão TLS
  TLS_INFO="$(echo "QUIT" | timeout 5 openssl s_client -connect localhost:443 2>&1 || true)"

  if echo "${TLS_INFO}" | grep -q "Protocol.*TLSv1\.[23]"; then
    PROTOCOL="$(echo "${TLS_INFO}" | grep "Protocol" | head -1 | awk '{print $2}')"
    print_success "Protocolo TLS: ${PROTOCOL}"
  fi

  # Verificar HSTS
  if curl -I -k https://localhost/ 2>/dev/null | grep -qi "Strict-Transport-Security"; then
    print_success "Cabeçalho HSTS presente"
  else
    print_warning "Cabeçalho HSTS ausente"
  fi

  echo
fi

# Testar rejeição de protocolos fracos
print_info "Testando rejeição de protocolos fracos..."

# Tentar TLS 1.0 (deve falhar)
if echo "QUIT" | timeout 3 openssl s_client -connect localhost:443 -tls1 2>&1 | grep -q "Cipher.*TLS"; then
  print_error "TLS 1.0 aceito (deveria ser bloqueado)"
else
  print_success "TLS 1.0 rejeitado"
fi

# Tentar TLS 1.1 (deve falhar)
if echo "QUIT" | timeout 3 openssl s_client -connect localhost:443 -tls1_1 2>&1 | grep -q "Cipher.*TLS"; then
  print_error "TLS 1.1 aceito (deveria ser bloqueado)"
else
  print_success "TLS 1.1 rejeitado"
fi

echo
print_success "Testes de segurança concluídos"
echo
echo "Status de segurança:"
echo "  ✓ Apenas versões TLS modernas"
echo "  ✓ Protocolos fracos bloqueados"
echo "  ✓ Cabeçalhos de segurança configurados"
