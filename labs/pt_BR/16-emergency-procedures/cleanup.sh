#!/usr/bin/env bash
#=============================================================================
# Lab 16: Limpeza
# Remove certificados de emergência
#
# Uso: ./cleanup.sh
# Pré-requisitos: RHEL 7, 8, 9, 10, privilégios de root
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

print_header "Lab 16: Limpeza"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

print_info "Removendo certificados de emergência..."

# Remover certificados de emergência
rm -f /etc/pki/tls/certs/emergency.crt
rm -f /etc/pki/tls/private/emergency.key
rm -f /etc/pki/tls/certs/temp-*.crt
rm -f /etc/pki/tls/private/temp-*.key

# Remover arquivos de backup e reversão
rm -f /etc/pki/tls/certs/*.backup
rm -f /etc/pki/tls/certs/*.old
rm -f /etc/pki/tls/certs/*.rollback
rm -f /etc/pki/tls/private/*.backup
rm -f /etc/pki/tls/private/*.old
rm -f /etc/pki/tls/private/*.rollback

print_success "Certificados de emergência removidos"
echo

# Nota sobre diretórios de backup
if ls -d /root/cert-backup-* /root/cert-before-restore-* 2>/dev/null; then
  print_info "Diretórios de backup encontrados:"
  ls -d /root/cert-backup-* /root/cert-before-restore-* 2>/dev/null
  echo
  echo "Esses backups são preservados"
  echo "Remova manualmente se não for necessário:"
  echo "  rm -rf /root/cert-backup-*"
  echo "  rm -rf /root/cert-before-restore-*"
fi

echo
print_success "Limpeza concluída"
