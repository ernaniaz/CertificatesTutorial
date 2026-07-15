#!/usr/bin/env bash
#=============================================================================
# Lab 11: Limpeza
# Remove o certmonger e os certificados em monitoramento
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

print_header "Lab 11: Limpeza"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

# Confirmação
print_warning "Isso removerá certmonger e todos os certificados rastreados."
read -p "Continuar? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Limpeza cancelada"
  exit 0
fi

echo

# Parar rastreamento de todos os certificados
print_info "Parando rastreamento de todos os certificados..."
REQUEST_IDS="$(getcert list 2>/dev/null | grep "Request ID" | awk '{print $3}' | tr -d "':" || echo)"

if [[ -n "${REQUEST_IDS}" ]]; then
  for REQ_ID in ${REQUEST_IDS}; do
    echo "Parando rastreamento: ${REQ_ID}"
    getcert stop-tracking -i "${REQ_ID}" 2>/dev/null || true
  done
  print_success "Rastreamento de certificados parado"
else
  echo "Nenhum certificado sendo monitorado"
fi

echo

# Parar certmonger
if systemctl is-active certmonger &>/dev/null; then
  print_info "Parando certmonger..."
  systemctl stop certmonger
  systemctl disable certmonger
  print_success "certmonger parado"
fi

echo

# Remover pacote certmonger
print_info "Removendo pacote certmonger..."

if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum remove -y certmonger
else
  dnf remove -y certmonger
fi

print_success "certmonger removido"
echo

# Remover arquivos de certificado
print_info "Removendo arquivos de certificado..."
if [[ -d /etc/pki/certmonger ]]; then
  rm -rf /etc/pki/certmonger
  print_success "Arquivos de certificado removidos"
fi

echo
print_success "Limpeza concluída"
echo
echo "Sistema restaurado ao estado anterior ao laboratório."
