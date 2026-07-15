#!/usr/bin/env bash
#=============================================================================
# Lab 18: Avaliar RHEL 8
# Avaliação prévia à migração para RHEL 9
#
# Uso: ./assess-rhel8.sh
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

print_header "Lab 18: Avaliação de Certificados RHEL 8"

print_info "1. Versão do sistema:"
cat /etc/redhat-release
openssl version
echo

print_info "2. Análise de certificado:"

SANS_MISSING=0
WEAK_KEYS=0

for cert in /etc/pki/tls/certs/*.crt; do
  if [[ -f "${cert}" ]] && openssl x509 -in "${cert}" -noout -text >/dev/null 2>&1; then
    # Verificar SANs
    if ! openssl x509 -in "${cert}" -noout -ext subjectAltName 2>/dev/null | grep -q "DNS:"; then
      echo -e " ${YELLOW}⚠ Sem SAN: $(basename "${cert}")${NC}"
      ((SANS_MISSING+=1))
    fi

    # Verificar tamanho da chave
    KEY_SIZE="$(openssl x509 -in "${cert}" -noout -text | grep "Public-Key:" | grep -oP '\d+' | head -1)"
    if [[ -n "${KEY_SIZE}" && ${KEY_SIZE} -lt 2048 ]]; then
      echo -e " ${RED}✗ Chave fraca (${KEY_SIZE} bits): $(basename "${cert}")${NC}"
      ((WEAK_KEYS+=1))
    fi
  fi
done

if [[ ${SANS_MISSING} -eq 0 ]]; then
  echo -e " ${GREEN}✓ Todos os certificados têm SANs${NC}"
else
  echo -e " ${YELLOW}⚠ ${SANS_MISSING} certificados sem SANs${NC}"
  echo "    (RHEL 9 prefere certificados com SANs)"
fi

if [[ ${WEAK_KEYS} -eq 0 ]]; then
  echo -e " ${GREEN}✓ Todas as chaves atendem ao tamanho mínimo${NC}"
else
  echo -e " ${RED}✗ ${WEAK_KEYS} chaves fracas encontradas${NC}"
  echo "    (RHEL 9 requer RSA com 2048+ bits ou mais)"
fi

echo

print_info "3. Crypto-Policy atual:"
POLICY="$(update-crypto-policies --show 2>/dev/null)"
echo " ${POLICY}"

echo

print_info "4. Configuração OpenSSL:"
if [[ -f /etc/pki/tls/openssl.cnf ]]; then
  if grep -qP '^[^#]*legacy\s*=' /etc/pki/tls/openssl.cnf; then
    echo -e " ${YELLOW}⚠ Provider legacy habilitado${NC}"
  else
    echo -e " ${GREEN}✓ Configuração padrão${NC}"
  fi
fi

echo

print_info "Resumo da avaliação:"
echo "  Pronto para avaliação de migração RHEL 9"
echo

if [[ ${SANS_MISSING} -gt 0 || ${WEAK_KEYS} -gt 0 ]]; then
  print_warning "Recomendações antes da migração:"
  if [ ${SANS_MISSING} -gt 0 ]; then
    echo "  - Regenere os certificados com SANs"
  fi
  if [ ${WEAK_KEYS} -gt 0 ]; then
    echo "  - Regenere com chaves mais fortes (2048+ bits)"
  fi
fi

echo
echo "Próximo: faça backup dos certificados com ./backup-certificates.sh"
