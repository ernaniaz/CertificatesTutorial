#!/usr/bin/env bash
#=============================================================================
# Lab 01: Verificação do ambiente
# Valida que todas as ferramentas de certificados estejam instaladas corretamente
#
# Uso: ./verify-environment.sh
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

print_header "Lab 01: Verificação do Ambiente"

# Verificar versão do RHEL
echo "Versão RHEL: ${RHEL_VERSION}"
echo

# Verificar OpenSSL
if command -v openssl &> /dev/null; then
  print_success "OpenSSL: $(openssl version)"
else
  print_error "OpenSSL não encontrado"
  exit 1
fi

# Verificar certutil
if command -v certutil &> /dev/null; then
  print_success "certutil disponível"
else
  print_error "certutil não encontrado"
  exit 1
fi

# Verificar certmonger
if command -v getcert &> /dev/null; then
  print_success "certmonger disponível"
else
  print_warning "certmonger não encontrado (opcional para RHEL 7)"
fi

# Verificar crypto-policies (RHEL 8+)
if command -v update-crypto-policies &> /dev/null; then
  POLICY="$(update-crypto-policies --show 2>/dev/null || echo "DEFAULT")"
  print_success "Crypto-policies: ${POLICY}"
fi

echo
echo "Diretórios de certificado:"

# Verificar diretórios
for dir in /etc/pki/tls/certs /etc/pki/tls/private /etc/pki/ca-trust; do
  if [[ -d "${dir}" ]]; then
    print_success "${dir}"
  else
    print_error "${dir} não encontrado"
    exit 1
  fi
done

# Verificar pacote CA
if [[ -f "/etc/pki/tls/certs/ca-bundle.crt" ]]; then
  BUNDLE_SIZE=$(wc -l < /etc/pki/tls/certs/ca-bundle.crt)
  print_success "Pacote CA: ${BUNDLE_SIZE} linhas"
else
  print_error "Pacote CA não encontrado"
  exit 1
fi

echo
print_success "Todas as validações aprovadas!"
print_success "Lab 01 concluído com sucesso."
echo
echo "Próximo: Prossiga para Lab 02: Geração de Chaves"
echo
