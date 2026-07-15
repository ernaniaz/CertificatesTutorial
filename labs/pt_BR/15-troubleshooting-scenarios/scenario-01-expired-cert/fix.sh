#!/usr/bin/env bash
#=============================================================================
# Lab 15: Corrigir
# Cenário 01: Corrigir certificado vencido
#
# Uso: ./fix.sh
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
  error_exit "Versão do RHEL não suportada. Este script requer RHEL 7, 8, 9, 10."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

CERT_FILE="/etc/pki/tls/certs/expired.crt"
KEY_FILE="/etc/pki/tls/private/expired.key"

print_header "Cenário 01: Corrigindo certificado expirado"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

print_info "Passo 1: Fazer backup do certificado antigo"
cp "${CERT_FILE}" "${CERT_FILE}.old"
print_success "Backup em ${CERT_FILE}.old"
echo

print_info "Passo 2: Gerar novo certificado (validade de 365 dias)"
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "${KEY_FILE}" \
  -out "${CERT_FILE}" \
  -days 365 \
  -subj "/CN=expired.example.com" 2>/dev/null

chmod 644 "${CERT_FILE}"
chmod 600 "${KEY_FILE}"

print_success "Novo certificado gerado"
echo

print_info "Passo 3: Verificar novo certificado"
openssl x509 -in "${CERT_FILE}" -noout -dates
echo

if openssl x509 -in "${CERT_FILE}" -noout -checkend 0 2>/dev/null; then
  print_success "Novo certificado é válido"
else
  print_error "Algo deu errado"
  exit 1
fi

echo
print_success "Certificado renovado com sucesso"
echo
echo "Próximos passos:"
echo "  1. Reinicie serviços que usam este certificado"
echo "  2. Teste conexões"
echo "  3. Execute ./verify-fix.sh para confirmar"
echo
echo "Prevenção:"
echo "  - Use certmonger/certbot para renovação automática"
echo "  - Monitore datas de expiração"
echo "  - Renove 30 dias antes da expiração"
