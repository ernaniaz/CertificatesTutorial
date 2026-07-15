#!/usr/bin/env bash
#=============================================================================
# Lab 22: Iniciar Vault em modo dev
# Inicia o servidor Vault em modo de desenvolvimento
#
# Uso: ./start-vault-dev.sh
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

# Diretório do script
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuração do Vault
readonly VAULT_ADDR="http://127.0.0.1:8200"

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

print_header "Lab 22: Iniciar Vault (Modo Dev)"

# --- Passo 1: Verificar se o Vault está instalado ---
print_step "Verificando pré-requisitos"

if ! command -v vault &> /dev/null; then
  error_exit "Vault não encontrado. Execute ./install-vault.sh primeiro"
fi

print_success "Vault encontrado: $(vault version | head -n1)"
echo

# --- Passo 2: Verificar processo Vault existente ---
print_step "Verificando processo existente do Vault"

if pgrep -x vault > /dev/null; then
  print_warning "Vault já está em execução"
  print_info "Para parar o Vault existente: pkill vault"
  read -p "Parar o Vault existente e iniciar um novo? (s/N): " -n 1 -r
  echo
  if [[ ${REPLY} =~ ^[Ss]$ ]]; then
    pkill vault || true
    sleep 2
  else
    exit 0
  fi
fi

print_success "Nenhum processo Vault conflitante"
echo

# --- Passo 3: Iniciar Vault em modo dev ---
print_step "Iniciando Vault em modo dev"

print_warning "Modo dev NÃO é para produção!"
print_info "Modo dev armazena todos os dados em memória e desbloqueia automaticamente com um root token conhecido"
echo

# Processo em background mantém o terminal do lab livre enquanto Vault atende requisições
nohup vault server -dev \
  -dev-root-token-id="root" \
  -dev-listen-address="127.0.0.1:8200" \
  > "${SCRIPT_DIR}/vault.log" 2>&1 &

vault_pid="${!}"
print_success "Vault iniciado com PID: ${vault_pid}"
echo

# --- Passo 4: Aguardar Vault ficar pronto ---
print_step "Aguardando Vault ficar pronto"

max_attempts=30
attempt=0
while [[ ${attempt} -lt ${max_attempts} ]]; do
  if VAULT_ADDR="${VAULT_ADDR}" vault status &> /dev/null; then
    print_success "Vault está pronto"
    break
  fi
  sleep 1
  attempt=$((attempt + 1))
done

if [[ ${attempt} -ge ${max_attempts} ]]; then
  error_exit "Vault falhou ao iniciar — verifique vault.log para detalhes"
fi
echo

# --- Passo 5: Salvar detalhes de conexão para outros scripts de lab ---
print_step "Salvando configuração em vault-env.sh"

cat > "${SCRIPT_DIR}/vault-env.sh" <<EOF
#!/usr/bin/env bash
# Variáveis de ambiente Vault para Lab 22
# Carregue este arquivo: source vault-env.sh

export VAULT_ADDR='${VAULT_ADDR}'
export VAULT_TOKEN='root'
export VAULT_PID='${vault_pid}'
EOF

chmod +x "${SCRIPT_DIR}/vault-env.sh"
print_success "Configuração salva em vault-env.sh"
echo

# --- Passo 6: Exportar ambiente e verificar status ---
print_step "Verificando status Vault"

export VAULT_ADDR="${VAULT_ADDR}"
export VAULT_TOKEN="root"

if ! vault status; then
  error_exit "Verificação de status Vault falhou"
fi

print_success "Vault está em execução e desbloqueado"
echo

# --- Passo 7: Exibir informações de acesso ---
print_step "Informações de acesso Vault"

print_warning "IMPORTANTE: Salve estas credenciais!"
echo
print_info "Endereço Vault: ${VAULT_ADDR}"
print_info "Root Token: root"
print_info "PID do processo: ${vault_pid}"
echo
print_warning "Avisos do modo Dev:"
echo "  - Todos os dados armazenados em memória (perdidos ao reiniciar)"
echo "  - Vault executa desbloqueado"
echo "  - Token raiz é 'root' (inseguro)"
echo "  - NÃO use em produção!"
echo
print_info "Para configurar seu shell:"
echo "  source vault-env.sh"
echo
echo "Próximos passos:"
echo "  1. Carregue ambiente: source vault-env.sh"
echo "  2. Execute './enable-pki.sh' para habilitar secrets engine PKI"
echo
print_info "Logs do Vault: tail -f vault.log"
