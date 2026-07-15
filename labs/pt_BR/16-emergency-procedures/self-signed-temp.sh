#!/usr/bin/env bash
#=============================================================================
# Lab 16: Autoassinado temporário
# Certificado autoassinado rápido para emergências
#
# Uso: ./self-signed-temp.sh
# Pré-requisitos: RHEL 7, 8, 9, 10, privilégios de root
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

CERT_DIR="/etc/pki/tls/certs"
KEY_DIR="/etc/pki/tls/private"

print_header "Lab 16: Certificado Autoassinado Temporário"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

print_warning "Criando certificado autoassinado temporário"
echo "Use isso quando CA estiver inacessível e você precisar de certificado imediato"
echo

# Obter nome de domínio
read -p "Nome do domínio (ou Enter para o hostname): " DOMAIN
if [[ -z "${DOMAIN}" ]]; then
  DOMAIN="$(hostname)"
fi

echo
echo "Criando certificado para: ${DOMAIN}"
echo

# Gerar certificado temporário
print_info "Gerando certificado..."

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "${KEY_DIR}/temp-${DOMAIN}.key" \
  -out "${CERT_DIR}/temp-${DOMAIN}.crt" \
  -days 30 \
  -subj "/CN=${DOMAIN}/O=Temporary/OU=Emergency" \
  -addext "subjectAltName=DNS:${DOMAIN},DNS:localhost" 2>/dev/null || \
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "${KEY_DIR}/temp-${DOMAIN}.key" \
  -out "${CERT_DIR}/temp-${DOMAIN}.crt" \
  -days 30 \
  -subj "/CN=${DOMAIN}/O=Temporary/OU=Emergency" 2>/dev/null

chmod 644 "${CERT_DIR}/temp-${DOMAIN}.crt"
chmod 600 "${KEY_DIR}/temp-${DOMAIN}.key"

print_success "Certificado temporário criado"
echo

# Exibir informações do certificado
echo "Detalhes do certificado:"
openssl x509 -in "${CERT_DIR}/temp-${DOMAIN}.crt" -noout -subject -dates
echo

print_success "Arquivos de certificado criados"
echo
echo "Certificado: ${CERT_DIR}/temp-${DOMAIN}.crt"
echo "Chave privada: ${KEY_DIR}/temp-${DOMAIN}.key"
echo
print_warning "CERTIFICADO TEMPORÁRIO DE 30 DIAS"
echo "Substitua por certificado assinado por CA adequada o quanto antes"
echo
echo "Implantar no serviço:"
echo "  # Para Apache"
echo "  SSLCertificateFile ${CERT_DIR}/temp-${DOMAIN}.crt"
echo "  SSLCertificateKeyFile ${KEY_DIR}/temp-${DOMAIN}.key"
echo
echo "  # Para NGINX"
echo "  ssl_certificate ${CERT_DIR}/temp-${DOMAIN}.crt;"
echo "  ssl_certificate_key ${KEY_DIR}/temp-${DOMAIN}.key;"
