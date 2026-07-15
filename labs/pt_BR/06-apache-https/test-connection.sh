#!/usr/bin/env bash
#=============================================================================
# Lab 06: Testar conexão
# Testa a funcionalidade HTTPS do Apache
#
# Uso: ./test-connection.sh
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

print_header "Lab 06: Testando Apache HTTPS"

# Teste 1: Verificar se Apache está em execução
print_info "Teste 1: Status do serviço Apache"
if systemctl is-active httpd &>/dev/null; then
  print_success "Apache está em execução"
else
  print_error "Apache não está em execução"
  exit 1
fi
echo

# Teste 2: Verificar porta 443
print_info "Teste 2: Porta 443 escutando"
if ss -tlnp | grep -q ':443'; then
  print_success "Porta 443 está escutando"
  ss -tlnp | grep ':443'
else
  print_error "Porta 443 não está escutando"
  exit 1
fi
echo

# Teste 3: Conexão HTTP
print_info "Teste 3: Conexão HTTP (porta 80)"
if curl -s http://localhost/ &>/dev/null; then
  print_success "Conexão HTTP bem-sucedida"
else
  print_warning "Conexão HTTP falhou (pode ser normal se HTTP estiver desabilitado)"
fi
echo

# Teste 4: Conexão HTTPS
print_info "Teste 4: Conexão HTTPS (porta 443)"
if curl -k -s https://localhost/ &>/dev/null; then
  print_success "Conexão HTTPS bem-sucedida"
  echo
  echo "Resposta:"
  curl -k -s https://localhost/ | head -5
else
  print_error "Conexão HTTPS falhou"
  exit 1
fi
echo

# Teste 5: Detalhes do certificado
print_info "Teste 5: Certificado servido pelo Apache"
CERT_INFO=$(echo | openssl s_client -connect localhost:443 -servername localhost 2>/dev/null | openssl x509 -noout -subject -dates 2>/dev/null || echo)

if [[ -n "${CERT_INFO}" ]]; then
  print_success "Certificado recuperado"
  echo "${CERT_INFO}"
else
  print_error "Não foi possível recuperar o certificado"
fi
echo

# Teste 6: Versão TLS
print_info "Teste 6: Versão do protocolo TLS"
TLS_VERSION=$(echo | openssl s_client -connect localhost:443 -servername localhost 2>&1 | grep -E "Protocol|New, TLS" | head -1)
if [[ -n "${TLS_VERSION}" ]]; then
  print_success "${TLS_VERSION}"
else
  print_warning "Não foi possível determinar a versão TLS"
fi
echo

# Teste 7: Cifra
print_info "Teste 7: Suite de cifras"
CIPHER=$(echo | openssl s_client -connect localhost:443 -servername localhost 2>&1 | grep "Cipher" | head -1)
if [[ -n "${CIPHER}" ]]; then
  print_success "${CIPHER}"
else
  print_warning "Não foi possível determinar o cipher"
fi

echo
print_success "Teste HTTPS Apache concluído"
