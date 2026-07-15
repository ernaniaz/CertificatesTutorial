#!/usr/bin/env bash
#=============================================================================
# Lab 22: Instalar Vault
# Baixa e instala o HashiCorp Vault
#
# Uso: ./install-vault.sh
# Pré-requisitos: RHEL 8, 9, 10
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

# Configuração do Vault
readonly VAULT_VERSION="1.15.4"
readonly VAULT_URL="https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip"

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

print_header "Lab 22: Instalar Vault"

print_success "RHEL ${RHEL_VERSION} detectado"
echo

# --- Passo 1: Verificar instalação existente ---
print_step "Verificando instalação existente do Vault"

if command -v vault &> /dev/null; then
  existing_version="$(vault version | head -n1)"
  print_warning "Vault já instalado: ${existing_version}"
  read -p "Reinstalar? (s/N): " -n 1 -r
  echo
  if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
    print_info "Usando instalação existente"
    echo
    print_info "Vault está pronto para uso"
    echo
    echo "Comandos rápidos:"
    echo "  vault version         - Exibir versão do Vault"
    echo "  vault --help          - Exibir ajuda"
    echo
    echo "Próximos passos:"
    echo "  - Execute './start-vault-dev.sh' para iniciar Vault em modo dev"
    echo "  - Execute 'vault server --help' para opções do servidor"
    exit 0
  fi
fi

print_success "Prosseguindo com a instalação do Vault"
echo

# --- Passo 2: Instalar dependências ---
print_step "Instalando dependências"

# unzip e jq são necessários para extrair o binário e analisar JSON em laboratórios posteriores
if ! command -v unzip &> /dev/null; then
  sudo dnf install -y unzip
fi

if ! command -v curl &> /dev/null; then
  sudo dnf install -y curl
fi

if ! command -v jq &> /dev/null; then
  sudo dnf install -y jq
fi

print_success "Dependências instaladas"
echo

# --- Passo 3: Detectar arquitetura e baixar Vault ---
print_step "Baixando Vault ${VAULT_VERSION}"

vault_arch="amd64"
if [[ "$(uname -m)" == "aarch64" ]] || [[ "$(uname -m)" == "arm64" ]]; then
  vault_arch="arm64"
fi

vault_download_url="https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${vault_arch}.zip"
print_info "Arquitetura: ${vault_arch}"
print_info "URL de download: ${vault_download_url}"

temp_dir="$(mktemp -d)"
if ! curl -sSL -o "${temp_dir}/vault.zip" "${vault_download_url}"; then
  rm -rf "${temp_dir}"
  error_exit "Falha ao baixar Vault de releases.hashicorp.com"
fi

print_success "Vault baixado"
echo

# --- Passo 4: Instalar binário Vault ---
print_step "Instalando Vault em /usr/local/bin"

if ! unzip -q "${temp_dir}/vault.zip" -d "${temp_dir}"; then
  rm -rf "${temp_dir}"
  error_exit "Falha ao extrair arquivo do Vault"
fi

chmod +x "${temp_dir}/vault"
if ! sudo mv "${temp_dir}/vault" /usr/local/bin/vault; then
  rm -rf "${temp_dir}"
  error_exit "Falha ao instalar binário do Vault"
fi

rm -rf "${temp_dir}"
print_success "Vault instalado em /usr/local/bin/vault"
echo

# --- Passo 5: Verificar instalação ---
print_step "Verificando instalação"

if ! command -v vault &> /dev/null; then
  error_exit "Instalação Vault falhou — binário não encontrado no PATH"
fi

installed_version="$(vault version)"
print_success "Versão Vault: ${installed_version}"
echo

# --- Passo 6: Exibir instruções de uso ---
print_step "Instalação concluída"

print_info "Vault está pronto para uso"
echo
echo "Comandos rápidos:"
echo "  vault version         - Exibir versão do Vault"
echo "  vault --help          - Exibir ajuda"
echo
echo "Próximos passos:"
echo "  - Execute './start-vault-dev.sh' para iniciar Vault em modo dev"
echo "  - Execute 'vault server --help' para opções do servidor"
