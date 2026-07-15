#!/usr/bin/env bash
#=============================================================================
# Lab 11: Testar renovação
# Força a renovação de um certificado em monitoramento
#
# Uso: ./test-renewal.sh
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

CERT_FILE="/etc/pki/certmonger/self-signed.crt"

print_header "Lab 11: Testar Renovação de Certificado"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

# Verificar se o certificado está monitorado
if ! getcert list -f "${CERT_FILE}" &>/dev/null; then
  print_error "Erro: Certificado ${CERT_FILE} não está monitorado"
  echo "Execute ./request-self-signed.sh primeiro"
  exit 1
fi

# Obter ID da solicitação
REQUEST_ID="$(getcert list -f "${CERT_FILE}" 2>/dev/null | grep "Request ID" | awk '{print $3}' | tr -d "':")"

echo "ID da solicitação: ${REQUEST_ID}"
echo "Certificado: ${CERT_FILE}"
echo

# Mostrar datas atuais do certificado
if [[ -f "${CERT_FILE}" ]]; then
  print_info "Certificado atual:"
  openssl x509 -in "${CERT_FILE}" -noout -dates
  SERIAL_BEFORE="$(openssl x509 -in "${CERT_FILE}" -noout -serial)"
  echo "${SERIAL_BEFORE}"
  echo
fi

# Forçar renovação
print_info "Forçando renovação de certificado..."
getcert resubmit -i "${REQUEST_ID}"

print_success "Solicitação de renovação enviada"
echo

# Aguardar renovação
print_info "Aguardando conclusão da renovação..."
sleep 5

# Verificar novo status
echo "Novo status:"
STATUS="$(getcert list -i "${REQUEST_ID}" 2>/dev/null | grep "status:" | awk '{print $2}')"
echo " ${STATUS}"

# Verificar se o certificado foi renovado
if [[ -f "${CERT_FILE}" ]]; then
  echo
  print_info "Certificado renovado:"
  openssl x509 -in "${CERT_FILE}" -noout -dates
  SERIAL_AFTER="$(openssl x509 -in "${CERT_FILE}" -noout -serial)"
  echo "${SERIAL_AFTER}"

  echo
  if [[ "${SERIAL_BEFORE}" != "${SERIAL_AFTER}" ]]; then
    print_success "Certificado foi renovado (número de série alterado)"
  else
    print_warning "Número de série inalterado (renovação pode não ter sido concluída)"
  fi
fi

echo
print_success "Teste de renovação concluído"
echo
echo "Monitorar renovação com:"
echo "  journalctl -u certmonger -f"
echo "  getcert list -i ${REQUEST_ID}"
