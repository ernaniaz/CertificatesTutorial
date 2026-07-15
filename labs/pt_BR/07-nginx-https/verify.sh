#!/usr/bin/env bash
#=============================================================================
# Lab 07: Verificar
# Passos de verificação manual
#
# Uso: ./verify.sh
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

print_header "Lab 07: Verificação NGINX SSL"

print_info "1. Verificando serviço NGINX..."
systemctl status nginx --no-pager | head -5
echo

print_info "2. Verificando portas em escuta..."
ss -tlnp | grep nginx
echo

print_info "3. Verificando configuração NGINX..."
nginx -t
echo

print_info "4. Verificando arquivos de certificado..."
if [[ -f /etc/pki/nginx/server.crt ]]; then
  print_success "Certificado existe"
  openssl x509 -in /etc/pki/nginx/server.crt -noout -subject -dates
else
  echo "Certificado não encontrado"
fi
echo

print_info "5. Verificando chave privada..."
if [[ -f /etc/pki/nginx/private/server.key ]]; then
  print_success "Chave privada existe"
  ls -l /etc/pki/nginx/private/server.key
  PERMS=$(stat -c%a /etc/pki/nginx/private/server.key)
  if [[ "${PERMS}" == "600" ]]; then
    print_success "Permissões corretas (600)"
  else
    print_warning "Permissões: ${PERMS} (devem ser 600)"
  fi
else
  echo "Chave privada não encontrada"
fi
echo

print_info "6. Verificando configuração SSL..."
if [[ -f /etc/nginx/conf.d/lab-ssl.conf ]]; then
  print_success "Configuração SSL existe"
  echo
  echo "Diretivas SSL:"
  grep -E "ssl_|listen 443" /etc/nginx/conf.d/lab-ssl.conf | grep -v "^#"
else
  echo "Configuração SSL não encontrada"
fi
echo

print_info "7. Testando conexão HTTPS..."
if curl -k -s https://localhost/ | grep -q "Lab 07"; then
  print_success "HTTPS funcionando"
  curl -k -s https://localhost/ | head -3
else
  echo "Teste HTTPS falhou"
fi

echo
print_success "Verificação concluída"
