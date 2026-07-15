#!/usr/bin/env bash
#=============================================================================
# Lab 15: Verificar correção
# Cenário 01: Verificar correção
#
# Uso: ./verify-fix.sh
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
  error_exit "Versão do RHEL não suportada. Este script requer RHEL 7, 8, 9, 10."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

CERT_FILE="/etc/pki/tls/certs/expired.crt"

print_header "Cenário 01: Verificando correção"

PASS=0
FAIL=0

test_check ()
{
  local description="${1}"
  local command="${2}"

  if eval "${command}" &>/dev/null; then
    echo -e "${GREEN}✓ PASS: ${NC} ${description}"
    ((PASS+=1))
  else
    echo -e "${RED}✗ FAIL: ${NC} ${description}"
    ((FAIL+=1))
  fi
}

test_check "Arquivo de certificado existe" "[ -f ${CERT_FILE} ]"
test_check "Certificado é válido (não expirado)" "openssl x509 -in ${CERT_FILE} -noout -checkend 0"
test_check "Certificado é válido por 30+ dias" "openssl x509 -in ${CERT_FILE} -noout -checkend 2592000"
test_check "Certificado possui subject correto" "openssl x509 -in ${CERT_FILE} -noout -subject | grep -q expired.example.com"

echo
echo "Validade do certificado:"
openssl x509 -in "${CERT_FILE}" -noout -dates

echo
echo "======================================="
echo "Aprovados: ${PASS}"
echo "Falhou: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "Cenário 01 concluído com sucesso"
  echo
  echo "Principais aprendizados:"
  echo "  - Sempre verifique as datas de expiração dos certificados"
  echo "  - Implemente monitoramento antes da expiração"
  echo "  - Use automação para renovação"
  echo "  - Teste o processo de renovação regularmente"
  exit 0
else
  print_error "Algumas verificações falharam"
  exit 1
fi
