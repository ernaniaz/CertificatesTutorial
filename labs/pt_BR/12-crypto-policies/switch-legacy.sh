#!/usr/bin/env bash
#=============================================================================
# Lab 12: Alternar para LEGACY
# Habilita a crypto-policy LEGACY para máxima compatibilidade
#
# Uso: ./switch-legacy.sh
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

print_header "Lab 12: Alternar para Política LEGACY"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

# Verificar versão do RHEL
if [[ ${RHEL_VERSION} -lt 8 ]]; then
  print_error "Erro: Crypto-policies requer RHEL 8 ou mais recente"
  exit 1
fi

# Mostrar política atual
CURRENT_POLICY="$(update-crypto-policies --show 2>/dev/null)"
echo "Política atual: ${CURRENT_POLICY}"

echo
print_warning "Política LEGACY permite criptografia fraca para compatibilidade"
print_warning "  - TLS 1.0 e 1.1 permitidos"
print_warning "  - Cifras fracas habilitadas"
print_warning "  - Use apenas para testes ou compatibilidade com sistemas legados"
echo

read -p "Continuar com política LEGACY? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Operação cancelada"
  exit 0
fi

echo

# Alternar para LEGACY
print_info "Alternando para política LEGACY..."
if update-crypto-policies --set LEGACY; then
  print_success "Política definida como LEGACY"
else
  print_error "Falha ao definir política LEGACY"
  exit 1
fi

echo

# Verificar
NEW_POLICY="$(update-crypto-policies --show 2>/dev/null)"
echo "Nova política: ${NEW_POLICY}"

echo
print_info "Reiniciando serviços afetados..."
print_warning "Nota: Alguns serviços podem precisar de reinicialização manual"

# Serviços que podem precisar de reinicialização
SERVICES="sshd httpd nginx postfix"
for service in ${SERVICES}; do
  if systemctl is-active ${service} &>/dev/null; then
    echo "  Reiniciando ${service}..."
    if ! systemctl restart ${service} 2>/dev/null; then
      echo "    (reinício falhou ou não instalado)"
    fi
  fi
done

echo
print_success "Alternado para política LEGACY"
echo
echo "Testar com:"
echo "  openssl ciphers -v"
echo "  ssh -Q cipher"
echo
print_warning "Lembre-se de restaurar a política DEFAULT quando os testes forem concluídos:"
echo "  sudo update-crypto-policies --set DEFAULT"
