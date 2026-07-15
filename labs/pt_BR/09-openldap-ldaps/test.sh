#!/usr/bin/env bash
#=============================================================================
# Lab 09: Teste
# Validação automatizada para OpenLDAP LDAPS
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

print_header "Lab 09: Testes Automatizados"

test_check "Serviço slapd em execução" "systemctl is-active slapd"
test_check "Porta 389 escutando" "ss -tlnp | grep -q ':389'"
test_check "Arquivo de certificado existe" "[ -f /etc/openldap/certs/ldap.crt ]"
test_check "Chave privada existe" "[ -f /etc/openldap/certs/ldap.key ]"
test_check "Chave privada possui permissões corretas" "[ \$(stat -c%a /etc/openldap/certs/ldap.key) == '600' ]"
test_check "Chave privada pertence a ldap" "[ \$(stat -c%U /etc/openldap/certs/ldap.key) == 'ldap' ]"
test_check "Certificado TLS configurado em cn=config" "ldapsearch -Y EXTERNAL -H ldapi:/// -b cn=config '(objectClass=olcGlobal)' olcTLSCertificateFile 2>&1 | grep -q olcTLSCertificateFile"
test_check "Conexão LDAP funciona" "ldapsearch -x -H ldap://localhost -b '' -s base"
test_check "Config do cliente existe" "[ -f /etc/openldap/ldap.conf ]"

# Opcional: Porta 636 (pode não estar habilitada por padrão)
if ss -tlnp | grep -q ':636'; then
  test_check "Conexão LDAPS funciona" "timeout 5 ldapsearch -x -H ldaps://localhost -b '' -s base"
fi

echo
echo "======================================="
echo "Aprovados: ${PASS}"
echo "Falhou: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "Lab 09 concluído com sucesso"
  exit 0
else
  print_error "Alguns testes falharam"
  exit 1
fi
