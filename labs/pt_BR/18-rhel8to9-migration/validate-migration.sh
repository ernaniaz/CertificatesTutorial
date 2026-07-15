#!/usr/bin/env bash
#=============================================================================
# Lab 18: Validar migração
# Validação no RHEL 9 já atualizado
#
# Uso: ./validate-migration.sh
# Pré-requisitos: RHEL 9
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
if [[ ${RHEL_VERSION} -ne 9 ]]; then
  error_exit "Versão do RHEL não suportada. Este script requer apenas RHEL 9."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

print_header "Lab 18: Validação pós-upgrade do RHEL 9"

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
test_check "Executando RHEL 9" "grep -q 'release 9' /etc/redhat-release"
test_check "OpenSSL 3.x ativo" "openssl version | grep -q 'OpenSSL 3'"
test_check "Crypto-policies configuradas" "update-crypto-policies --show"

echo
print_info "Validação de certificado:"
test_check "Certificados legíveis" "ls /etc/pki/tls/certs/*.crt | head -1 | xargs -I {} openssl x509 -in {} -noout"
test_check "Trust store intacto" "[ -d /etc/pki/ca-trust ]"

echo
print_info "Funcionalidade OpenSSL 3.x:"
test_check "Pode gerar chaves" "openssl genrsa -out /tmp/test.key 2048"
test_check "Pode criar certificados" "openssl req -new -x509 -key /tmp/test.key -out /tmp/test.crt -days 1 -subj '/CN=test' -addext 'subjectAltName=DNS:test'"

# Limpar arquivos de teste
rm -f /tmp/test.key /tmp/test.crt

echo
echo "======================================="
echo "Aprovados: ${PASS}"
echo "Falhou: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "Validação pós-upgrade do RHEL 8→9 bem-sucedida"
  echo
  echo "Migração concluída! OpenSSL 3.x operacional."
  exit 0
else
  print_error "Algumas verificações de validação falharam"
  echo "Revisar e corrigir problemas"
  exit 1
fi
