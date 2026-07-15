#!/usr/bin/env bash
#=============================================================================
# Lab 17: Validar migração
# Validação no RHEL 8 já atualizado
#
# Uso: ./validate-migration.sh
# Pré-requisitos: RHEL 8
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
if [[ ${RHEL_VERSION} -ne 8 ]]; then
  error_exit "Versão do RHEL não suportada. Este script requer apenas RHEL 8."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

print_header "Lab 17: Validação pós-upgrade do RHEL 8"

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

print_info "Validação do sistema:"
test_check "Executando RHEL 8" "grep -q 'release 8' /etc/redhat-release"
test_check "Crypto-policies disponíveis" "command -v update-crypto-policies"
test_check "Crypto-policy definida" "update-crypto-policies --show"

echo
print_info "Validação de certificado:"
test_check "Diretório de certificado existe" "[ -d /etc/pki/tls/certs ]"
test_check "Certificados presentes" "ls /etc/pki/tls/certs/*.crt 2>/dev/null | grep -q ."
test_check "Trust store intacto" "[ -d /etc/pki/ca-trust ]"

echo
print_info "Validação de serviço:"
for svc in httpd nginx postfix; do
  if systemctl list-unit-files | grep -q "^${svc}.service"; then
    test_check "Arquivo de serviço ${svc} existe" "systemctl cat ${svc}"
  fi
done

echo
echo "======================================="
echo "Aprovados: ${PASS}"
echo "Falhou: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "Validação pós-upgrade do RHEL 7→8 bem-sucedida"
  echo
  echo "Migração RHEL 7→8 concluída!"
  exit 0
else
  print_error "Algumas verificações de validação falharam"
  echo "Revisar e corrigir problemas"
  exit 1
fi
