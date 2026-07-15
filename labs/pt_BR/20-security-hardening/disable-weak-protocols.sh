#!/usr/bin/env bash
#=============================================================================
# Lab 20: Desabilitar protocolos fracos
# Remove o suporte a protocolos SSL/TLS fracos
#
# Uso: ./disable-weak-protocols.sh
# Pré-requisitos: RHEL 8, 9, 10, privilégios de root
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

print_header "Lab 20: Desabilitar Protocolos Fracos"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

print_info "Desabilitando protocolos fracos em todo o sistema..."
echo

# RHEL 8+: Use crypto-policies
if [[ ${RHEL_VERSION} -ge 8 ]]; then
  echo "Usando crypto-policies para desabilitar protocolos fracos..."

  CURRENT_POLICY="$(update-crypto-policies --show)"
  echo "Política atual: ${CURRENT_POLICY}"

  if [[ ${CURRENT_POLICY} == LEGACY ]]; then
    print_warning "Política LEGACY permite protocolos fracos"
    echo "Alternando para política DEFAULT..."
    update-crypto-policies --set DEFAULT
    print_success "Alternado para DEFAULT (bloqueia TLS 1.0/1.1)"
  elif [[ ${CURRENT_POLICY} == DEFAULT ]]; then
    print_success "Política DEFAULT já ativa (TLS 1.2+)"
  elif [[ ${CURRENT_POLICY} == FUTURE ]]; then
    print_success "Política FUTURE ativa (segurança mais forte)"
  fi

  echo
  echo "Reiniciando serviços..."
  for svc in httpd nginx postfix sshd; do
    if systemctl is-active ${svc} &>/dev/null; then
      if systemctl restart ${svc} 2>/dev/null; then
        echo "  ✓ ${svc} restarted"
      fi
    fi
  done
else
  # RHEL 7: Configuração manual
  echo "RHEL 7 detectado - configuração manual necessária"
  echo "Certifique-se de que suas configurações de serviço tenham:"
  echo "  SSLProtocol -all +TLSv1.2 +TLSv1.3"
fi

echo
print_success "Protocolos fracos desabilitados"
echo
echo "Protocolos bloqueados:"
echo "  - SSLv2, SSLv3"
echo "  - TLS 1.0, TLS 1.1"
echo
echo "Protocolos permitidos:"
echo "  - TLS 1.2"
echo "  - TLS 1.3"
