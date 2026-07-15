#!/usr/bin/env bash
#=============================================================================
# Lab 17: Preparar migração
# Verificação de preparação para a migração
#
# Uso: ./prepare-migration.sh
# Pré-requisitos: RHEL 7
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
if [[ ${RHEL_VERSION} -ne 7 ]]; then
  error_exit "Versão do RHEL não suportada. Este script requer apenas RHEL 7."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

print_header "Lab 17: Preparação da Migração"

ISSUES=0

print_info "Checklist de Prontidão para Migração:"
echo

# Verificação 1: Backup existe
echo -n "1. Backup de certificados criado: "
if ls /root/rhel7-cert-backup-*.tar.gz 2>/dev/null | grep -q .; then
  print_success ""
else
  print_error "(execute ./backup-certificates.sh)"
  ((ISSUES+=1))
fi

# Verificação 2: Certificados SHA-1
echo -n "2. Sem certificados SHA-1: "
SHA1_FOUND=0
for cert in /etc/pki/tls/certs/*.crt; do
  if [[ -f "${cert}" ]] && openssl x509 -in "${cert}" -noout -text 2>/dev/null | grep -q "sha1WithRSAEncryption"; then
    SHA1_FOUND=1
    break
  fi
done

if [[ ${SHA1_FOUND} -eq 0 ]]; then
  print_success ""
else
  print_warning "(Certificados SHA-1 devem ser substituídos)"
fi

# Verificação 3: Certificados não expirados
echo -n "3. Todos os certificados válidos: "
EXPIRED=0
for cert in /etc/pki/tls/certs/*.crt; do
  if [[ -f "${cert}" ]] && ! openssl x509 -in "${cert}" -noout -checkend 0 2>/dev/null; then
    EXPIRED=1
    break
  fi
done

if [[ ${EXPIRED} -eq 0 ]]; then
  print_success ""
else
  print_error "(certificados expirados encontrados)"
  ((ISSUES+=1))
fi

# Verificação 4: Serviços documentados
echo -n "4. Configurações de serviços em backup: "
if ls /root/rhel7-cert-backup-*/configs/ 2>/dev/null | grep -q .; then
  print_success ""
else
  print_warning "(recomendado)"
fi

echo
print_info "Problemas de compatibilidade conhecidos:"
echo
echo "TLS 1.0/1.1:"
echo "  - RHEL 8 desabilita por padrão"
echo "  - Use política LEGACY se clientes antigos forem necessários"
echo
echo "Assinaturas SHA-1:"
echo "  - Bloqueado na política DEFAULT"
echo "  - Substitua ou use política LEGACY"
echo
echo "Configs TLS Manuais:"
echo "  - Remova diretivas SSLProtocol"
echo "  - Remova diretivas SSLCipherSuite"
echo "  - Deixe crypto-policies gerenciar isso"
echo

if [[ ${ISSUES} -eq 0 ]]; then
  print_success "Sistema pronto para migração para RHEL 8"
else
  print_error "Resolva ${ISSUES} problemas críticos antes da migração"
fi

echo
echo "Após upgrade RHEL 8, execute: ./configure-rhel8.sh"
