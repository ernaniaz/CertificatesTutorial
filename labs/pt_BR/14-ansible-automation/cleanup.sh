#!/usr/bin/env bash
#=============================================================================
# Lab 14: Limpeza
# Remove o Ansible e as configurações do lab
#
# Uso: ./cleanup.sh
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

print_header "Lab 14: Limpeza"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Confirmação
print_warning "Isso desfará todas as tarefas do lab: remover Apache, Ansible, certificados e configurações."
read -p "Continuar? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Limpeza cancelada"
  exit 0
fi

echo

# Parar e desabilitar Apache
print_info "Parando e desabilitando Apache..."
if systemctl is-active httpd &>/dev/null; then
  systemctl stop httpd
fi
systemctl disable httpd 2>/dev/null || true
print_success "Apache parado e desabilitado"

echo

# Remover configuração SSL do Apache
print_info "Removendo configuração SSL do Apache..."
rm -f /etc/httpd/conf.d/ansible-ssl.conf
print_success "Configuração SSL do Apache removida"

echo

# Remover página de teste criada pelo playbook
print_info "Removendo página de teste..."
rm -f /var/www/html/index.html
print_success "Página de teste removida"

echo

# Remover certificados implantados
print_info "Removendo certificados implantados..."
rm -f /etc/pki/tls/certs/lab-ansible.crt
rm -f /etc/pki/tls/private/lab-ansible.key
print_success "Certificados removidos"

echo

# Remover pacotes Apache instalados pelo playbook
print_info "Removendo pacotes Apache (httpd, mod_ssl)..."
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum remove -y httpd mod_ssl 2>/dev/null || true
else
  dnf remove -y httpd mod_ssl 2>/dev/null || true
fi
print_success "Pacotes Apache removidos"

echo

# Remover diretório de configuração do Ansible
print_info "Removendo configuração do Ansible..."
rm -rf /etc/ansible
print_success "Configuração do Ansible removida"

echo

# Remover arquivo de inventário
print_info "Removendo arquivo de inventário..."
rm -f "${SCRIPT_DIR}/inventory.ini"
print_success "Arquivo de inventário removido"

echo

# Remover pacote Ansible
print_info "Removendo pacote Ansible..."
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum remove -y ansible 2>/dev/null || true
elif [[ ${RHEL_VERSION} -eq 8 ]]; then
  dnf remove -y ansible 2>/dev/null || true
else
  dnf remove -y ansible-core 2>/dev/null || true
fi
print_success "Ansible removido"

echo
print_success "Limpeza concluída"
echo
echo "Todas as tarefas do lab foram desfeitas:"
echo "  - Apache (httpd, mod_ssl) removido"
echo "  - Configuração SSL e página de teste removidas"
echo "  - Certificados removidos"
echo "  - Configuração do Ansible removida"
echo "  - Pacote Ansible removido"
