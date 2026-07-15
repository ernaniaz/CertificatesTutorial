#!/usr/bin/env bash
#=============================================================================
# Lab 10: Instalar PostgreSQL
# Instala o servidor de banco de dados PostgreSQL
#
# Uso: ./install-postgresql.sh
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

print_header "Lab 10: Instalando PostgreSQL"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

# Detectar versão do RHEL
echo "Versão RHEL: ${RHEL_VERSION}"
echo

# Instalar PostgreSQL
print_info "Instalando pacotes PostgreSQL..."

if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum install -y postgresql-server postgresql-contrib
else
  dnf install -y postgresql-server postgresql-contrib
fi

print_success "PostgreSQL instalado"
echo

# Inicializar banco de dados (se ainda não inicializado)
if [[ ! -f /var/lib/pgsql/data/PG_VERSION ]]; then
  print_info "Inicializando banco de dados PostgreSQL..."
  if [[ ${RHEL_VERSION} -eq 7 ]]; then
    postgresql-setup initdb
  else
    postgresql-setup --initdb
  fi
  print_success "Banco de dados inicializado"
else
  echo "Banco de dados já inicializado"
fi

echo

# Habilitar e iniciar PostgreSQL
print_info "Habilitando e iniciando serviço postgresql..."
systemctl enable postgresql
systemctl start postgresql

print_success "Serviço PostgreSQL iniciado"
echo

# Configurar firewall
print_info "Configurando firewall..."
if command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null; then
  firewall-cmd --permanent --add-service=postgresql
  firewall-cmd --reload
  print_success "Firewall configurado (porta 5432)"
else
  echo "firewalld não em execução, ignorando configuração de firewall"
fi

echo

# Verificar instalação
if systemctl is-active postgresql &>/dev/null; then
  print_success "PostgreSQL está em execução"
else
  print_error "PostgreSQL falhou ao iniciar"
  exit 1
fi

# Verificar se está escutando
if ss -tlnp | grep -q ':5432'; then
  print_success "PostgreSQL escutando na porta 5432"
fi

# Exibir versão do PostgreSQL
echo
echo "Versão do PostgreSQL:"
sudo -u postgres psql --version

echo
print_success "Instalação do PostgreSQL concluída"
echo
echo "Status do PostgreSQL:"
systemctl status postgresql --no-pager | head -5
