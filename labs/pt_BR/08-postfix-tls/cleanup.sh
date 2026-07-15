#!/usr/bin/env bash
#=============================================================================
# Lab 08: Limpeza
# Remove o Postfix e restaura o estado do sistema
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

print_header "Lab 08: Limpeza"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

# Confirmação
print_warning "Isso removerá Postfix e todas as configurações do laboratório."
read -p "Continuar? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Limpeza cancelada"
  exit 0
fi

echo

# Parar Postfix
if systemctl is-active postfix &>/dev/null; then
  print_info "Parando Postfix..."
  systemctl stop postfix
  systemctl disable postfix
  print_success "Postfix parado"
fi

echo

# Restaurar configuração original se existir backup
if [[ -f /etc/postfix/main.cf.lab-backup ]]; then
  print_info "Restaurando configuração original..."
  mv /etc/postfix/main.cf.lab-backup /etc/postfix/main.cf
  print_success "Configuração restaurada"
fi

echo

# Remover pacote Postfix
print_info "Removendo pacote Postfix..."
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum remove -y postfix
else
  dnf remove -y postfix
fi

print_success "Postfix removido"
echo

# Remover certificados do lab
print_info "Removendo certificados do laboratório..."
rm -f /etc/pki/tls/certs/postfix.crt
rm -f /etc/pki/tls/private/postfix.key
print_success "Certificados removidos"
echo

# Remover bancos de dados de cache TLS
print_info "Limpando cache TLS..."
rm -f /var/lib/postfix/smtpd_tls_cache.db
rm -f /var/lib/postfix/smtp_tls_cache.db
print_success "Cache limpo"
echo

# Remover regras de firewall
print_info "Limpando regras de firewall..."
if command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null; then
  firewall-cmd --permanent --remove-service=smtp 2>/dev/null || true
  firewall-cmd --permanent --remove-service=smtp-submission 2>/dev/null || true
  firewall-cmd --reload
  print_success "Regras de firewall removidas"
fi

echo
print_success "Limpeza concluída"
echo
echo "Sistema restaurado ao estado anterior ao laboratório."
