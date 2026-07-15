#!/usr/bin/env bash
#=============================================================================
# Lab 13: Obter em modo standalone
# Obtém certificado do Let's Encrypt em modo standalone
#
# Uso: ./obtain-standalone.sh
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

print_header "Lab 13: Obter Certificado (Standalone)"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

print_warning "IMPORTANTE: Este laboratório usa modo standalone"
print_warning "  - Requer porta 80 livre"
print_warning "  - Usará domínio de teste (não Let's Encrypt real)"
print_warning "  - Para produção, use um nome de domínio real"
echo

# Nome de domínio para teste (o usuário deve substituir pelo próprio)
DOMAIN="example.com"

echo "Domínio a usar: ${DOMAIN}"
echo
print_warning "Para este laboratório, usaremos --staging e --register-unsafely-without-email"
print_warning "Em produção, use domínio real e endereço --email"
echo

read -p "Continuar com teste standalone? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Operação cancelada"
  exit 0
fi

echo

# Parar quaisquer servidores web usando a porta 80
print_info "Verificando serviços na porta 80..."
SERVICES="httpd nginx apache2"
STOPPED_SERVICES=""

for service in ${SERVICES}; do
  if systemctl is-active ${service} &>/dev/null; then
    echo "Parando ${service}..."
    systemctl stop ${service}
    STOPPED_SERVICES="${STOPPED_SERVICES} ${service}"
  fi
done

if [[ -n "${STOPPED_SERVICES}" ]]; then
  print_success "Serviços parados: ${STOPPED_SERVICES}"
fi

echo

# Obter certificado usando modo standalone
print_info "Obtendo certificado usando modo standalone..."
echo

# Usar ambiente de staging e aceitar TOS
if certbot certonly \
  --standalone \
  --staging \
  --agree-tos \
  --register-unsafely-without-email \
  --domain "${DOMAIN}" \
  --non-interactive 2>&1 | tee /tmp/certbot-standalone.log; then
  echo
  print_success "Certificado obtido (staging)"
else
  echo
  print_warning "Solicitação de certificado falhou (esperado se não houver domínio real)"
  echo "Isso é normal em ambiente de laboratório sem domínio público"
  echo
  echo "Para uso em produção:"
  echo "  certbot certonly --standalone -d your-domain.com --email your@email.com"
fi

echo

# Reiniciar serviços parados
if [[ -n "${STOPPED_SERVICES}" ]]; then
  print_info "Reiniciando serviços parados..."
  for service in ${STOPPED_SERVICES}; do
    echo "Iniciando ${service}..."
    systemctl start ${service}
  done
fi

echo
print_success "Demonstração do modo standalone concluída"
echo
echo "Locais do certificado (se bem-sucedido):"
echo "  /etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
echo "  /etc/letsencrypt/live/${DOMAIN}/privkey.pem"
echo
echo "Listar certificados:"
echo "  certbot certificates"
echo
echo "Exemplo de produção:"
echo "  certbot certonly --standalone -d example.com --email admin@example.com"
