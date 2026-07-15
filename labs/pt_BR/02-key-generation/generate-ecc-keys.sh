#!/usr/bin/env bash
#=============================================================================
# Lab 02: Geração de chaves ECC
# Gera pares de chaves de curva elíptica
#
# Uso: ./generate-ecc-keys.sh
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
mkdir -p "${OUTPUT_DIR}"

print_header "Lab 02: Gerando Chaves ECC"

# Gerar chave P-256 (secp256r1)
print_info "Gerando chave ECC P-256 (secp256r1)..."
openssl ecparam -genkey -name prime256v1 \
    -out "${OUTPUT_DIR}/ecc-p256.key"

# Extrair chave pública
openssl pkey -in "${OUTPUT_DIR}/ecc-p256.key" \
    -pubout -out "${OUTPUT_DIR}/ecc-p256.pub"

print_success "Par de chaves ECC P-256 gerado"
echo

# Gerar chave P-384 (secp384r1)
print_info "Gerando chave ECC P-384 (secp384r1)..."
openssl ecparam -genkey -name secp384r1 \
    -out "${OUTPUT_DIR}/ecc-p384.key"

# Extrair chave pública
openssl pkey -in "${OUTPUT_DIR}/ecc-p384.key" \
    -pubout -out "${OUTPUT_DIR}/ecc-p384.pub"

print_success "Par de chaves ECC P-384 gerado"
echo

# Permissões seguras
chmod 600 "${OUTPUT_DIR}"/*.key 2>/dev/null || true
chmod 644 "${OUTPUT_DIR}"/*.pub 2>/dev/null || true

echo "Chaves geradas em ${OUTPUT_DIR}/"
echo "  Chaves privadas: ecc-p256.key, ecc-p384.key (modo 600)"
echo "  Chaves públicas:  ecc-p256.pub, ecc-p384.pub (modo 644)"
echo
print_success "Geração de chave ECC concluída"
