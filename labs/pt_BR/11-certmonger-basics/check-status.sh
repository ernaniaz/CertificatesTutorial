#!/usr/bin/env bash
#=============================================================================
# Lab 11: Verificar status
# Exibe o status de todos os certificados em monitoramento
#
# Uso: ./check-status.sh
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

print_header "Lab 11: Status do Certificado"

# Verificar serviço certmonger
print_info "Status do serviço certmonger:"
if systemctl is-active certmonger &>/dev/null; then
  print_success "certmonger está em execução"
else
  echo "certmonger não está em execução"
  exit 1
fi

echo

# Listar todos os certificados monitorados
print_info "Certificados rastreados:"
echo

CERT_LIST="$(getcert list 2>/dev/null)"

if [[ -z "${CERT_LIST}" ]]; then
  echo "Nenhum certificado está sendo monitorado"
else
  echo "${CERT_LIST}"
fi

echo
echo "======================================="

# Contar certificados
CERT_COUNT="$(getcert list 2>/dev/null | grep -c "Request ID:" || true)"
echo "Total de certificados rastreados: ${CERT_COUNT}"

echo

# Mostrar resumo de cada certificado
if [[ ${CERT_COUNT} -gt 0 ]]; then
  print_info "Resumo do certificado:"
  echo

  # Obter todos os IDs de solicitação
  REQUEST_IDS="$(getcert list 2>/dev/null | grep "Request ID" | awk '{print $3}' | tr -d "':")"

  for REQ_ID in ${REQUEST_IDS}; do
    echo "ID da solicitação: ${REQ_ID}"

    # Obter detalhes da chave
    STATUS="$(getcert list -i "${REQ_ID}" 2>/dev/null | grep "status:" | awk '{print $2}')"
    CERT="$(getcert list -i "${REQ_ID}" 2>/dev/null | grep "certificate:" | cut -d: -f2- | xargs)"
    EXPIRES="$(getcert list -i "${REQ_ID}" 2>/dev/null | grep "expires:" | cut -d: -f2-)"
    CA="$(getcert list -i "${REQ_ID}" 2>/dev/null | grep "ca-name:" | awk '{print $2}')"

    echo "  Status: ${STATUS}"
    echo "  CA: ${CA}"
    echo "  Certificado: ${CERT}"
    echo "  Expira: ${EXPIRES}"
    echo
  done
fi

echo
print_success "Verificação de status concluída"
echo
echo "Comandos úteis:"
echo "  getcert list"
echo "  getcert list -i <REQUEST_ID>"
echo "  journalctl -u certmonger -f"
