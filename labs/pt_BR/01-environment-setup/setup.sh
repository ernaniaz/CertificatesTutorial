#!/usr/bin/env bash
#=============================================================================
# Lab 01: Configuração
# Instala ferramentas de gerenciamento de certificados
#
# Uso: ./setup.sh
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

print_header "Lab 01: Configuração do Ambiente (RHEL ${RHEL_VERSION})"

print_success "RHEL ${RHEL_VERSION} detectado: $(cat /etc/redhat-release)"
echo

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Este script deve ser executado como root (use sudo)"
fi

# Instalar pacotes
print_info "Instalando ferramentas de gerenciamento de certificados..."
echo

if [[ ${RHEL_VERSION} -eq 7 ]]; then
  yum install -y \
    openssl \
    nss-tools \
    certmonger \
    ca-certificates \
    mod_ssl
else
  dnf install -y \
    openssl \
    nss-tools \
    certmonger \
    ca-certificates \
    mod_ssl
fi

echo
print_success "Instalação de pacotes concluída"
echo

# Verificar instalações
print_info "Verificando instalações..."

if command -v openssl &> /dev/null; then
  print_success "OpenSSL: $(openssl version)"
else
  error_exit "Falha na instalação do OpenSSL"
fi

if command -v certutil &> /dev/null; then
  print_success "certutil (ferramentas NSS) instalado"
else
  error_exit "Falha na instalação das ferramentas NSS"
fi

if command -v getcert &> /dev/null; then
  print_success "certmonger instalado"
else
  print_error "certmonger não disponível (opcional, pode precisar de EPEL)"
fi

# Verificar estrutura de /etc/pki/
if [[ -d "/etc/pki" ]]; then
  print_success "/etc/pki/ diretório existe"
else
  error_exit "/etc/pki/ não encontrado"
fi

echo
print_success "=== Configuração concluída ==="
echo
echo "Próximo passo: Execute './verify-environment.sh' para validar a instalação"
echo
