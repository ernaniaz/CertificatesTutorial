#!/usr/bin/env bash
#=============================================================================
# Lab 13: Obter com webserver
# Obtém certificado com integração Apache/NGINX
#
# Uso: ./obtain-webserver.sh
# Pré-requisitos: RHEL 8, 9, 10, privilégios de root
#=============================================================================

set -e  # Sair em caso de erro
set -u  # Sair em variável indefinida
set -o pipefail  # Pipeline retorna o primeiro código de saída não-zero

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

print_header "Lab 13: Obter Certificado (Modo Servidor Web)"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

print_warning "Este script demonstra integração com servidor web"
print_warning "  - Requer Apache ou NGINX em execução"
print_warning "  - Requer domínio real para produção"
print_warning "  - Esta demonstração usa modo staging"
echo

# Nome de domínio para testes (o usuário deve substituir pelo próprio)
DOMAIN="example.com"

echo "Domínio a usar: ${DOMAIN}"
echo

# Detectar servidor web em execução
WEB_SERVER=""
if systemctl is-active httpd &>/dev/null; then
  WEB_SERVER="apache"
  echo "Detectado: Apache (httpd)"
elif systemctl is-active nginx &>/dev/null; then
  WEB_SERVER="nginx"
  echo "Detectado: NGINX"
else
  print_warning "Nenhum servidor web em execução"
  echo "Instale e inicie o Apache ou NGINX primeiro"
  echo "  Lab 06 (Apache) ou Lab 07 (NGINX)"
  exit 1
fi

echo
echo "Usando plugin: ${WEB_SERVER}"
echo

read -p "Continuar com integração do ${WEB_SERVER}? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Operação cancelada"
  exit 0
fi

echo

# Obter certificado com plugin de servidor web
print_info "Obtendo certificado com plugin ${WEB_SERVER}..."
echo

if [[ ${WEB_SERVER} == apache ]]; then
  # Plugin Apache
  if certbot --apache \
    --staging \
    --agree-tos \
    --register-unsafely-without-email \
    --domain "${DOMAIN}" \
    --non-interactive 2>&1 | tee /tmp/certbot-apache.log; then
    echo
    print_success "Certificado obtido e Apache configurado"
  else
    echo
    print_warning "Solicitação de certificado falhou (esperado no laboratório)"
  fi
elif [[ ${WEB_SERVER} == nginx ]]; then
  # Plugin NGINX
  if certbot --nginx \
    --staging \
    --agree-tos \
    --register-unsafely-without-email \
    --domain "${DOMAIN}" \
    --non-interactive 2>&1 | tee /tmp/certbot-nginx.log; then
    echo
    print_success "Certificado obtido e NGINX configurado"
  else
    echo
    print_warning "Solicitação de certificado falhou (esperado no laboratório)"
  fi
fi

echo
print_success "Demonstração de integração com servidor web concluída"
echo
echo "O que certbot fez:"
echo "  1. Certificado obtido"
echo "  2. Configuração do servidor web modificada"
echo "  3. HTTPS habilitado"
echo "  4. Configure redirecionamento HTTP->HTTPS"
echo
echo "Exemplo de produção:"
echo "  certbot --${WEB_SERVER} -d example.com --email admin@example.com"
