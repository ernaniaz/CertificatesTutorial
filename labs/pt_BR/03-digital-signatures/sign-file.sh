#!/usr/bin/env bash
#=============================================================================
# Lab 03: Assinatura de arquivo
# Cria a assinatura digital de um arquivo de exemplo
#
# Uso: ./sign-file.sh
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

KEY_DIR="../02-key-generation/output"
SAMPLE_FILE="sample-data.txt"
SIGNATURE_FILE="sample-data.sig"

print_header "Lab 03: Criando Assinatura Digital"

# Verificar pré-requisitos
if [[ ! -f "${KEY_DIR}/rsa-2048.key" ]]; then
  print_error "Erro: Chave RSA não encontrada. Execute o Lab 02 primeiro."
  exit 1
fi

if [[ ! -f "${SAMPLE_FILE}" ]]; then
  print_error "Erro: Arquivo de exemplo não encontrado."
  exit 1
fi

# Assinar o arquivo com chave privada RSA usando SHA-256
print_info "Assinando ${SAMPLE_FILE} com chave RSA-2048..."
openssl dgst -sha256 \
  -sign "${KEY_DIR}/rsa-2048.key" \
  -out "${SIGNATURE_FILE}" \
  "${SAMPLE_FILE}"

print_success "Arquivo assinado: ${SIGNATURE_FILE}"
echo
echo "Detalhes da assinatura:"
echo "  Algoritmo: SHA-256 com RSA"
echo "  Tamanho: $(stat -f%z "${SIGNATURE_FILE}" 2>/dev/null || stat -c%s "${SIGNATURE_FILE}") bytes"
echo
echo "Assinatura (primeiros 80 bytes em hex):"
hexdump -C "${SIGNATURE_FILE}" | head -n 5
echo
print_success "Criação de assinatura concluída"
echo
echo "Próximo: Execute ./verify-signature.sh para verificar"
