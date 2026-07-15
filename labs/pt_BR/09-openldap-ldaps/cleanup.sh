#!/usr/bin/env bash
#=============================================================================
# Lab 09: Limpeza
# Remove o OpenLDAP e restaura o estado do sistema
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

print_header "Lab 09: Limpeza"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

# Confirmação
print_warning "Isso removerá OpenLDAP e todas as configurações do laboratório."
read -p "Continuar? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Limpeza cancelada"
  exit 0
fi

echo

# Parar slapd
if systemctl is-active slapd &>/dev/null; then
  print_info "Parando slapd..."
  systemctl stop slapd
  systemctl disable slapd
  print_success "slapd parado"
fi

echo

# Restaurar configurações originais
if [[ -f /etc/sysconfig/slapd.lab-backup ]]; then
  print_info "Restaurando configuração slapd..."
  mv /etc/sysconfig/slapd.lab-backup /etc/sysconfig/slapd
  print_success "Configuração slapd restaurada"
fi

if [[ -f /etc/openldap/ldap.conf.lab-backup ]]; then
  print_info "Restaurando configuração do cliente..."
  mv /etc/openldap/ldap.conf.lab-backup /etc/openldap/ldap.conf
  print_success "Configuração do cliente restaurada"
fi

echo

# Remover pacotes OpenLDAP
print_info "Removendo pacotes OpenLDAP..."
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum remove -y openldap-servers openldap-clients
else
  dnf remove -y openldap-servers openldap-clients
fi

print_success "OpenLDAP removido"
echo

# Remover certificados do lab
print_info "Removendo certificados do laboratório..."
rm -rf /etc/openldap/certs/ldap.crt
rm -rf /etc/openldap/certs/ldap.key
print_success "Certificados removidos"
echo

# Remover dados OpenLDAP (opcional - comentado por segurança)
# echo -e "${BLUE}Removing OpenLDAP data...${NC}"
# rm -rf /var/lib/ldap/*
# rm -rf /etc/openldap/slapd.d/*
# echo -e "${GREEN}✓ Data removed${NC}"

# Remover regras de firewall
print_info "Limpando regras de firewall..."
if command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null; then
  firewall-cmd --permanent --remove-service=ldap 2>/dev/null || true
  firewall-cmd --permanent --remove-service=ldaps 2>/dev/null || true
  firewall-cmd --reload
  print_success "Regras de firewall removidas"
fi

echo
print_success "Limpeza concluída"
echo
echo "Sistema restaurado ao estado anterior ao laboratório."
