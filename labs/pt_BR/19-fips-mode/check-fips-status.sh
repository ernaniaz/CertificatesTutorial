#!/usr/bin/env bash
#=============================================================================
# Lab 19: Verificar status FIPS
# Verifica se o modo FIPS está habilitado
#
# Uso: ./check-fips-status.sh
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

print_header "Lab 19: Status do Modo FIPS"

# Verificar modo FIPS
print_info "1. Status do modo FIPS:"
if [[ -f /proc/sys/crypto/fips_enabled ]]; then
  FIPS_ENABLED="$(cat /proc/sys/crypto/fips_enabled)"
  if [[ ${FIPS_ENABLED} -eq 1 ]]; then
    echo -e " ${GREEN}✓ Modo FIPS está HABILITADO${NC}"
  else
    echo -e " ${YELLOW}⚠ Modo FIPS está DESABILITADO${NC}"
  fi
else
  echo "  Arquivo de status FIPS não encontrado"
fi

echo

# Verificar comando fips-mode-setup
print_info "2. Status do fips-mode-setup:"
if command -v fips-mode-setup &>/dev/null; then
  fips-mode-setup --check
  else
  echo "  comando fips-mode-setup não encontrado"
fi

echo

# Verificar linha de comando do kernel
print_info "3. Linha de comando do kernel:"
if grep -q "fips=1" /proc/cmdline; then
  echo -e " ${GREEN}✓ fips=1 nos parâmetros do kernel${NC}"
  else
  echo "  fips=1 não está nos parâmetros do kernel"
fi

echo

# Verificar crypto-policy
print_info "4. Crypto-Policy:"
POLICY="$(update-crypto-policies --show 2>/dev/null)"
echo "  Atual: ${POLICY}"

if [[ ${POLICY} == FIPS ]]; then
  echo -e " ${GREEN}✓ Usando política FIPS${NC}"
elif [[ ${FIPS_ENABLED} -eq 1 ]]; then
  echo -e " ${YELLOW}⚠ FIPS habilitado, mas não usa política FIPS${NC}"
fi

echo

# Status FIPS do OpenSSL
print_info "5. Status FIPS do OpenSSL:"
if openssl list -providers 2>/dev/null | grep -q "fips"; then
  echo -e " ${GREEN}✓ Provider FIPS disponível${NC}"
else
  echo "  Provider FIPS não detectado"
fi

echo
echo "======================================="

if [[ ${FIPS_ENABLED:-0} -eq 1 ]]; then
  print_success "Sistema está em execução em modo FIPS"
else
  print_warning "Sistema NÃO está em modo FIPS"
  echo
  echo "Para habilitar modo FIPS:"
  echo "  sudo ./enable-fips.sh"
fi
