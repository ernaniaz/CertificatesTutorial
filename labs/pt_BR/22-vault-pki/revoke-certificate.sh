#!/usr/bin/env bash
#=============================================================================
# Lab 22: Revogar certificado
# Demonstra a revogação de certificados
#
# Uso: ./revoke-certificate.sh
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
readonly CERTS_DIR="${SCRIPT_DIR}/certs"

# Serial number
SERIAL_NUMBER="${1:-}"

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

print_header "Lab 22: Revogar Certificado"

# --- Passo 1: Carregar detalhes de conexão do Vault ---
print_step "Carregando ambiente Vault"

if [[ -f "${SCRIPT_DIR}/vault-env.sh" ]]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/vault-env.sh"
  print_success "Ambiente carregado de vault-env.sh"
else
  export VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
  export VAULT_TOKEN="${VAULT_TOKEN:-root}"
fi
echo

# --- Passo 2: Verificar se Vault está em execução ---
print_step "Verificando status do Vault"

if ! vault status &> /dev/null; then
  error_exit "Vault não está em execução. Execute ./start-vault-dev.sh primeiro"
fi

print_success "Vault está em execução"
echo

# --- Passo 3: Encontrar número de série se não fornecido ---
if [[ -z "${SERIAL_NUMBER}" ]]; then
  print_step "Encontrando certificado para revogar"

  latest_serial_file="$(find "${CERTS_DIR}" -maxdepth 1 -name '*.serial' -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -n1 | awk '{print $2}')"

  if [[ -z "${latest_serial_file}" ]] || [[ ! -f "${latest_serial_file}" ]]; then
    error_exit "Nenhum certificado encontrado. Execute ./issue-certificate.sh primeiro"
  fi

  SERIAL_NUMBER="$(cat "${latest_serial_file}")"
  print_success "Usando certificado mais recente: $(basename "${latest_serial_file%.serial}")"
  echo
fi

print_info "Número de série: ${SERIAL_NUMBER}"
echo

# --- Passo 4: Confirmar revogação com o usuário ---
print_step "Confirmando revogação"

print_warning "Isso revogará o certificado!"
read -p "Continuar? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  print_info "Revogação cancelada"
  exit 0
fi
echo

# --- Passo 5: Revogar certificado ---
print_step "Revogando certificado"

if ! vault write pki_int/revoke serial_number="${SERIAL_NUMBER}"; then
  error_exit "Falha ao revogar certificado ${SERIAL_NUMBER}"
fi

print_success "Certificado revogado"
echo

# --- Passo 6: Ler e exibir CRL ---
print_step "Lendo Certificate Revocation List"

if ! vault read -field=certificate pki_int/cert/crl > "${SCRIPT_DIR}/crl.pem"; then
  error_exit "Falha ao ler CRL do Vault"
fi

print_success "CRL salva em: crl.pem"
echo
print_info "Conteúdo da CRL:"
openssl crl -in "${SCRIPT_DIR}/crl.pem" -noout -text | head -n 20
echo

# --- Passo 7: Verificar revogação na CRL ---
print_step "Verificando revogação"

print_info "Verificando se o serial ${SERIAL_NUMBER} aparece na CRL..."

if openssl crl -in "${SCRIPT_DIR}/crl.pem" -noout -text | grep -q "${SERIAL_NUMBER}"; then
  print_success "Certificado encontrado na CRL (revogado)"
else
  print_warning "Certificado não encontrado na CRL"
fi
echo

# --- Passo 8: Exibir informações de revogação ---
print_step "Informações de revogação"

print_info "Revogação de certificado:"
echo "  - Certificados revogados são adicionados à CRL"
echo "  - CRL URL: http://127.0.0.1:8200/v1/pki_int/crl"
echo "  - Aplicações devem verificar CRL ou usar OCSP"
echo
print_info "Baixar CRL:"
echo "  curl http://127.0.0.1:8200/v1/pki_int/crl > crl.pem"
echo
print_info "Visualizar CRL:"
echo "  openssl crl -in crl.pem -noout -text"

echo
print_success "Revogação de certificado demonstrada"
echo
echo "Próximos passos:"
echo "  - Execute './verify.sh' para validar todo o lab"
echo "  - Emita novos certificados: ./issue-certificate.sh"
