#!/usr/bin/env bash
#=============================================================================
# Lab 09: Instalar OpenLDAP
# Instala o servidor e clientes OpenLDAP
#
# Uso: ./install-openldap.sh
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

print_header "Lab 09: Instalando OpenLDAP"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

# Detectar versão do RHEL
echo "Versão RHEL: ${RHEL_VERSION}"
echo

# Instalar OpenLDAP
print_info "Instalando pacotes OpenLDAP..."

if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum install -y openldap openldap-servers openldap-clients
elif [[ ${RHEL_VERSION} -eq 8 ]]; then
  dnf install -y openldap openldap-servers openldap-clients
else
  # RHEL 9+: openldap-servers removido dos repos base, instalar do EPEL
  dnf install -y epel-release || dnf install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${RHEL_VERSION}.noarch.rpm"
  dnf install -y openldap openldap-servers openldap-clients
fi

print_success "OpenLDAP instalado"
echo

# Habilitar e iniciar slapd
print_info "Habilitando e iniciando serviço slapd..."
systemctl enable slapd
systemctl start slapd

print_success "Serviço slapd iniciado"
echo

# Configurar firewall
print_info "Configurando firewall..."
if command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null; then
  firewall-cmd --permanent --add-service=ldap
  firewall-cmd --permanent --add-service=ldaps
  firewall-cmd --reload
  print_success "Firewall configurado (portas 389, 636)"
else
  echo "firewalld não em execução, ignorando configuração de firewall"
fi

echo

# Verificar instalação
if systemctl is-active slapd &>/dev/null; then
  print_success "slapd está em execução"
else
  print_error "slapd falhou ao iniciar"
  exit 1
fi

# Verificar se está escutando na porta 389
if ss -tlnp | grep -q ':389'; then
  print_success "LDAP escutando na porta 389"
fi

# Exibir versão do OpenLDAP
echo
echo "Versão do OpenLDAP:"
slapd -VV 2>&1 | head -1

echo
print_success "Instalação do OpenLDAP concluída"
echo
echo "Status slapd:"
systemctl status slapd --no-pager | head -5
