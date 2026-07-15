#!/usr/bin/env bash
#=============================================================================
# Lab 19: Verificar preparação FIPS
# Verifica a preparação para FIPS
#
# Uso: ./check-fips-readiness.sh
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

print_header "Lab 19: Verificação de Prontidão FIPS"

print_info "1. Status FIPS atual:"
if command -v fips-mode-setup &>/dev/null; then
  fips-mode-setup --check
else
  echo "  Comando fips-mode-setup não encontrado"
fi
echo

print_info "2. Flag FIPS do kernel:"
if [[ -f /proc/sys/crypto/fips_enabled ]]; then
  FIPS="$(cat /proc/sys/crypto/fips_enabled)"
  if [[ ${FIPS} -eq 1 ]]; then
    echo -e " ${GREEN}✓ FIPS habilitado${NC}"
  else
    echo "  FIPS desabilitado"
  fi
else
  echo "  Não disponível"
fi
echo

print_info "3. Compatibilidade de certificados:"
WEAK_KEYS=0
for cert in /etc/pki/tls/certs/*.crt; do
  if [[ ! (-f "${cert}") ]]; then
    continue
  fi
  KEY_SIZE="$(openssl x509 -in "${cert}" -noout -text 2>/dev/null | grep "Public-Key:" | grep -oP '\d+' | head -1)"
  if [[ -n "${KEY_SIZE}" ]] && [[ "${KEY_SIZE}" -lt 2048 ]]; then
    ((WEAK_KEYS+=1))
  fi
done

if [[ ${WEAK_KEYS} -eq 0 ]]; then
  echo -e " ${GREEN}✓ Todas as chaves atendem aos requisitos FIPS${NC}"
else
  echo -e " ${RED}✗ ${WEAK_KEYS} chaves fracas demais para FIPS${NC}"
fi

echo
if [[ ${RHEL_VERSION} -ge 10 ]]; then
  echo "RHEL 10: FIPS só pode ser habilitado na instalação (parâmetro de kernel fips=1)."
else
  echo "Para habilitar FIPS: sudo ./enable-fips.sh"
fi
