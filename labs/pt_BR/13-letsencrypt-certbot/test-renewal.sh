#!/usr/bin/env bash
#=============================================================================
# Lab 13: Testar renovação
# Testa o processo de renovação do certbot
#
# Uso: ./test-renewal.sh
# Pré-requisitos: RHEL 8, 9, 10, privilégios de root
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

print_header "Lab 13: Testar Renovação de Certificado"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

# Listar certificados existentes
print_info "Certificados existentes:"
if certbot certificates 2>/dev/null | grep -q "Certificate Name:"; then
  certbot certificates
else
  print_warning "Nenhum certificado encontrado"
  echo "Execute obtain-standalone.sh ou obtain-webserver.sh primeiro"
  exit 0
fi

echo

# Testar renovação (dry-run)
print_info "Testando renovação (dry-run, não renovará de fato)..."
echo

if certbot renew --dry-run 2>&1 | tee /tmp/certbot-renewal-test.log; then
  echo
  print_success "Teste de renovação bem-sucedido"
  echo
  echo "Dry-run concluído com sucesso"
  echo "Certificados seriam renovados sem erros"
else
  echo
  print_warning "Teste de renovação encontrou problemas"
  echo
  echo "Isso é normal em ambiente de laboratório"
  echo "Verifique /tmp/certbot-renewal-test.log para detalhes"
fi

echo
print_info "Configuração de renovação:"
if [[ -d /etc/letsencrypt/renewal ]]; then
  echo "Configurações de renovação:"
  ls -1 /etc/letsencrypt/renewal/*.conf 2>/dev/null | while read conf; do
    echo " ${conf}"
    grep -E "authenticator|installer|renewalparams" "${conf}" 2>/dev/null | head -5 | sed 's/^/    /'
  done
else
  echo "Nenhuma configuração de renovação encontrada"
fi

echo
print_success "Testes de renovação concluídos"
echo
echo "Conceitos-chave:"
echo "  - Certificados renovam quando restam <30 dias"
echo "  - --dry-run testa sem renovar de fato"
echo "  - Renovação usa o mesmo método da solicitação original"
echo
echo "Renovação manual:"
echo "  certbot renew"
echo "  certbot renew --force-renewal"
