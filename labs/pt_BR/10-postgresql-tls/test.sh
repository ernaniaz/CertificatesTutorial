#!/usr/bin/env bash
#=============================================================================
# Lab 10: Teste
# Validação automatizada para PostgreSQL TLS
#
# Uso: ./test.sh
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

PASS=0
FAIL=0
PG_DATA="/var/lib/pgsql/data"

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

print_header "Lab 10: Testes Automatizados"

test_check "Serviço PostgreSQL em execução" "systemctl is-active postgresql"
test_check "Porta 5432 escutando" "ss -tlnp | grep -q ':5432'"
test_check "Arquivo de certificado existe" "[ -f ${PG_DATA}/server.crt ]"
test_check "Chave privada existe" "[ -f ${PG_DATA}/server.key ]"
test_check "Chave privada possui permissões corretas" "[ \$(stat -c%a ${PG_DATA}/server.key) == '600' ]"
test_check "Chave privada pertence a postgres" "[ \$(stat -c%U ${PG_DATA}/server.key) == 'postgres' ]"
test_check "SSL habilitado em postgresql.conf" "grep -q '^ssl = on' ${PG_DATA}/postgresql.conf"
test_check "SSL habilitado no banco de dados" "[[ \$(sudo -u postgres psql -t -c 'SHOW ssl;' | tr -d '[:space:]') == 'on' ]]"
test_check "Conexão com banco de dados funciona" "sudo -u postgres psql -c 'SELECT 1;'"
test_check "Regra hostssl existe" "grep -q '^hostssl' ${PG_DATA}/pg_hba.conf"

echo
echo "======================================="
echo "Aprovados: ${PASS}"
echo "Falhou: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "Lab 10 concluído com sucesso"
  exit 0
else
  print_error "Alguns testes falharam"
  exit 1
fi
