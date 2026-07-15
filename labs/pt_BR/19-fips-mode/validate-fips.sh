#!/usr/bin/env bash
#=============================================================================
# Lab 19: Validar FIPS
# Valida que o modo FIPS esteja ativo
#
# Uso: ./validate-fips.sh
# Pré-requisitos: RHEL 8, 9, 10
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

print_header "Lab 19: Validação do Modo FIPS"

PASS=0
FAIL=0

test_check ()
{
  local description="${1}"
  local command="${2}"

  if eval "${command}" &>/dev/null; then
    echo -e "${GREEN}✓ PASS: ${NC}${description}"
    ((PASS+=1))
  else
    echo -e "${RED}✗ FAIL: ${NC}${description}"
    ((FAIL+=1))
  fi
}

print_info "Verificações do modo FIPS:"
test_check "FIPS habilitado no kernel" "[[ -f /proc/sys/crypto/fips_enabled && \$(cat /proc/sys/crypto/fips_enabled) -eq 1 ]]"
test_check "Parâmetro de boot FIPS definido" "grep -q 'fips=1' /proc/cmdline"
test_check "crypto-policy FIPS ativa" "update-crypto-policies --show | grep -q FIPS"
test_check "fips-mode-setup reporta habilitado" "fips-mode-setup --check 2>&1 | grep -q 'enabled'"

echo
print_info "OpenSSL FIPS:"
if [[ ${RHEL_VERSION} -le 8 ]]; then
  test_check "Módulo FIPS do OpenSSL ativo" "openssl version 2>/dev/null | grep -qi fips"
else
  test_check "Provider FIPS do OpenSSL disponível" "openssl list -providers 2>/dev/null | grep -q fips"
fi
test_check "Pode gerar chave RSA 2048" "openssl genrsa -out /tmp/fips-test.key 2048"
test_check "Não é possível usar MD5" "! openssl dgst -md5 /tmp/fips-test.key"

rm -f /tmp/fips-test.key

echo
echo "======================================="
echo "Aprovados: ${PASS}"
echo "Falhou: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "Modo FIPS totalmente operacional"
  exit 0
else
  print_error "Validação FIPS falhou"
  echo "Sistema pode não estar em modo FIPS adequado"
  exit 1
fi
