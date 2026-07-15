#!/usr/bin/env bash
#=============================================================================
# Lab 22: Emitir certificado
# Emite certificados usando o role configurado
#
# Uso: ./issue-certificate.sh
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

# Default values
ROLE_NAME="web-server"
COMMON_NAME="${1:-}"
TTL="${2:-24h}"

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

print_header "Lab 22: Emitir Certificados"

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

# --- Passo 2: Verificar se role e CA intermediária existem ---
print_step "Verificando pré-requisitos"

if ! vault read "pki_int/roles/${ROLE_NAME}" &> /dev/null; then
  error_exit "Role '${ROLE_NAME}' não encontrada. Execute ./create-role.sh primeiro"
fi

if ! vault read pki_int/cert/ca &> /dev/null; then
  error_exit "CA intermediária não encontrada. Execute ./configure-intermediate-ca.sh primeiro"
fi

mkdir -p "${CERTS_DIR}"
print_success "Role PKI e CA intermediária encontradas"
echo

# --- Passo 3: Emitir certificado(s) ---
print_step "Emitindo certificados"

if [[ -n "${COMMON_NAME}" ]]; then
  cert_names=("${COMMON_NAME}")
  cert_ttls=("${TTL}")
else
  cert_names=("server01.lab.local" "server02.lab.local" "temp.lab.local")
  cert_ttls=("24h" "24h" "1h")
fi

for i in "${!cert_names[@]}"; do
  cn="${cert_names[${i}]}"
  ttl="${cert_ttls[${i}]}"
  cert_base="${CERTS_DIR}/${cn}"

  print_info "Emitindo certificado: ${cn} (TTL: ${ttl})..."

  if ! response="$(vault write -format=json "pki_int/issue/${ROLE_NAME}" \
    common_name="${cn}" \
    ttl="${ttl}")"; then
    error_exit "Falha ao emitir certificado para ${cn}"
  fi

  echo "${response}" | jq -r '.data.certificate' > "${cert_base}.crt"
  echo "${response}" | jq -r '.data.private_key' > "${cert_base}.key"
  echo "${response}" | jq -r '.data.ca_chain[]' > "${cert_base}-chain.crt"
  echo "${response}" | jq -r '.data.issuing_ca' > "${cert_base}-ca.crt"
  cat "${cert_base}.crt" "${cert_base}.key" > "${cert_base}.pem"
  echo "${response}" | jq -r '.data.serial_number' > "${cert_base}.serial"

  chmod 644 "${cert_base}.crt" "${cert_base}.pem" "${cert_base}-chain.crt" "${cert_base}-ca.crt"
  chmod 600 "${cert_base}.key"

  print_success "Certificado emitido: ${cn}"
  print_info "  Certificado: ${cert_base}.crt"
  print_info "  Chave privada: ${cert_base}.key"
  print_info "  Serial: $(cat "${cert_base}.serial")"
  echo
done

if [[ -z "${COMMON_NAME}" ]]; then
  print_success "Todos os certificados de teste emitidos"
fi
echo

# --- Passo 4: Exibir resumo de certificados ---
print_step "Resumo do certificado"

print_info "Certificados emitidos:"
if ! ls -lh "${CERTS_DIR}"/*.crt 2>/dev/null | grep -v -- '-chain.crt' | grep -v -- '-ca.crt'; then
  print_warning "Nenhum certificado encontrado"
fi
echo
print_info "Total de certificados: $(find "${CERTS_DIR}" -maxdepth 1 -name '*.crt' ! -name '*-chain.crt' ! -name '*-ca.crt' 2>/dev/null | wc -l)"
echo

# --- Passo 5: Verificar certificados com OpenSSL ---
print_step "Verificando certificados com OpenSSL"

for cert_file in "${CERTS_DIR}"/*.crt; do
  if [[ ! (-f "${cert_file}") ]]; then
    continue
  fi
  if [[ "${cert_file}" =~ -chain\.crt$ ]]; then
    continue
  fi
  if [[ "${cert_file}" =~ -ca\.crt$ ]]; then
    continue
  fi

  cert_base="${cert_file%.crt}"
  print_info "Verificando: $(basename "${cert_file}")"

  if [[ -f "${cert_base}-ca.crt" ]] && openssl verify -CAfile "${cert_base}-ca.crt" "${cert_file}" &> /dev/null; then
    print_success "Certificado é válido"
  else
    print_warning "A verificação do certificado apresentou problemas"
  fi

  print_info "Subject e validade:"
  openssl x509 -in "${cert_file}" -noout -subject -dates
done

echo
print_success "Emissão de certificado concluída!"
echo
echo "Arquivos de certificado:"
echo "  *.crt       - Certificado"
echo "  *.key       - Chave privada"
echo "  *.pem       - Pacote certificado + chave"
echo "  *-chain.crt - cadeia CA"
echo "  *.serial    - Número de série (para revogação)"
echo
echo "Próximos passos:"
echo "  - Inspecione o certificado: openssl x509 -in certs/server01.lab.local.crt -noout -text"
echo "  - Use certificado: cp certs/server01.lab.local.* /etc/pki/tls/"
echo "  - Execute './revoke-certificate.sh' para testar revogação"
