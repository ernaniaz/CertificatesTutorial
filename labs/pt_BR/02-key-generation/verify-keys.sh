#!/usr/bin/env bash
#=============================================================================
# Lab 02: Verificação de chaves
# Valida as chaves geradas
#
# Uso: ./verify-keys.sh
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

OUTPUT_DIR="output"

print_header "Lab 02: Verificando Chaves Geradas"

# Verificar se o diretório de saída existe
if [[ ! -d "${OUTPUT_DIR}" ]]; then
  print_error "Diretório de saída não encontrado. Execute os scripts de geração primeiro."
  exit 1
fi

# Verificar RSA 2048
echo "Chave RSA de 2048 bits:"
if [[ -f "${OUTPUT_DIR}/rsa-2048.key" ]]; then
  openssl pkey -in "${OUTPUT_DIR}/rsa-2048.key" -text -noout | grep -E "Private-Key|RSA" | head -2
  print_success "Válido"
else
  print_error "Não encontrado"
fi
echo

# Verificar RSA 4096
echo "Chave RSA de 4096 bits:"
if [[ -f "${OUTPUT_DIR}/rsa-4096.key" ]]; then
  openssl pkey -in "${OUTPUT_DIR}/rsa-4096.key" -text -noout | grep -E "Private-Key|RSA" | head -2
  print_success "Válido"
else
  print_error "Não encontrado"
fi
echo

# Verificar ECC P-256
echo "Chave ECC P-256:"
if [[ -f "${OUTPUT_DIR}/ecc-p256.key" ]]; then
  openssl pkey -in "${OUTPUT_DIR}/ecc-p256.key" -text -noout | grep -E "Private-Key|ASN1 OID" | head -2
  print_success "Válido"
else
  print_error "Não encontrado"
fi
echo

# Verificar ECC P-384
echo "Chave ECC P-384:"
if [[ -f "${OUTPUT_DIR}/ecc-p384.key" ]]; then
  openssl pkey -in "${OUTPUT_DIR}/ecc-p384.key" -text -noout | grep -E "Private-Key|ASN1 OID" | head -2
  print_success "Válido"
else
  print_error "Não encontrado"
fi
echo

# Verificar permissões de arquivo
echo "Permissões de arquivo:"
ls -l "${OUTPUT_DIR}"/ | grep -E '\.key$|\.pub$'
echo

print_success "Todas as chaves verificadas com sucesso"
