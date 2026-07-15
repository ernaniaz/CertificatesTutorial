#!/usr/bin/env bash
#=============================================================================
# Lab 19: Configurar serviços FIPS
# Garante que os serviços atendam aos requisitos FIPS
#
# Uso: ./configure-services-fips.sh
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

print_header "Lab 19: Configurar Serviços para FIPS"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

# Verificar se o FIPS está habilitado
if [[ -f /proc/sys/crypto/fips_enabled && "$(cat /proc/sys/crypto/fips_enabled)" != "1" ]]; then
  print_warning "Modo FIPS não habilitado"
  echo "Habilite o FIPS primeiro com ./enable-fips.sh"
  echo
fi

print_info "Verificando configurações de serviço..."
echo

# Apache
if [[ -d /etc/httpd/conf.d ]]; then
  print_info "Apache (httpd):"
  echo "  Em modo FIPS, crypto-policy restringe cifras automaticamente"
  echo "  Remova diretivas manuais SSLProtocol/SSLCipherSuite"
  echo

  if grep -r "^[^#]*SSLCipherSuite" /etc/httpd/conf.d/ 2>/dev/null | grep -q .; then
    echo -e " ${YELLOW}⚠ Configuração manual de cifras encontrada${NC}"
    echo "    Considere remover para usar crypto-policy FIPS"
  else
    echo -e " ${GREEN}✓ Usando padrões da crypto-policy${NC}"
  fi
  echo
fi

# NGINX
if [[ -d /etc/nginx ]]; then
  print_info "NGINX:"
  echo "  NGINX requer configuração explícita de cifras"
  echo "  Use apenas cifras aprovadas FIPS"
  echo

  echo "  Cifras FIPS recomendadas para NGINX:"
  echo "    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';"
  echo
fi

# OpenSSH
if [[ -f /etc/ssh/sshd_config ]]; then
  print_info "OpenSSH:"
  echo "  Crypto-policy configura automaticamente algoritmos compatíveis com FIPS"
  echo -e " ${GREEN}✓ Nenhuma configuração manual necessária${NC}"
  echo
fi

# Postfix
if [[ -f /etc/postfix/main.cf ]]; then
  print_info "Postfix:"
  echo "  Crypto-policy configura TLS compatível com FIPS"
  if grep -q "^smtpd_tls_ciphers = high" /etc/postfix/main.cf; then
    echo -e " ${GREEN}✓ Grau alto de cifras configurado${NC}"
  else
    echo "  Configurar: smtpd_tls_ciphers = high"
  fi
  echo
fi

print_success "Revisão da configuração do serviço concluída"
echo
echo "Após habilitação FIPS:"
echo "  1. Reinicie todos os serviços"
echo "  2. Teste conectividade"
echo "  3. Monitore erros"
echo "  4. Atualize configurações não conformes"
