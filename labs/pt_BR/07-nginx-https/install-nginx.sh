#!/usr/bin/env bash
#=============================================================================
# Lab 07: Instalar NGINX
# Instala o servidor web nginx
#
# Uso: ./install-nginx.sh
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

print_header "Lab 07: Instalando NGINX"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

# Detectar versão do RHEL
echo "Versão RHEL: ${RHEL_VERSION}"
echo

# Instalar NGINX
print_info "Instalando nginx..."

if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum install -y epel-release || yum install -y https://archives.fedoraproject.org/pub/archive/epel/7/x86_64/Packages/e/epel-release-7-14.noarch.rpm
  yum install -y nginx
else
  dnf install -y nginx
fi

print_success "NGINX instalado"
echo

# Habilitar e iniciar NGINX
print_info "Habilitando e iniciando serviço nginx..."
systemctl enable nginx
systemctl start nginx

print_success "Serviço NGINX iniciado"
echo

# Configurar firewall
print_info "Configurando firewall..."
if command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null; then
  firewall-cmd --permanent --add-service=http
  firewall-cmd --permanent --add-service=https
  firewall-cmd --reload
  print_success "Firewall configurado (portas 80, 443)"
else
  echo "firewalld não em execução, ignorando configuração de firewall"
fi

echo

# Verificar instalação
if systemctl is-active nginx &>/dev/null; then
  print_success "NGINX está em execução"
else
  print_error "NGINX falhou ao iniciar"
  exit 1
fi

# Verificar se está escutando
if ss -tlnp | grep -q ':80\|:443'; then
  print_success "NGINX escutando nas portas"
fi

# Exibir versão do NGINX
nginx -v 2>&1 | head -1

echo
print_success "Instalação do NGINX concluída"
echo
echo "Status do NGINX:"
systemctl status nginx --no-pager | head -5
