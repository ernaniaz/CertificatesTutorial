#!/usr/bin/env bash
#=============================================================================
# Lab 04: Criação de CSR
# Gera um CSR para enviá-lo a uma Certificate Authority
#
# Uso: ./create-csr.sh
# Pré-requisitos: RHEL 7, 8, 9, 10
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

KEY_DIR="../02-key-generation/output"
OUTPUT_DIR="output"
mkdir -p "${OUTPUT_DIR}"

print_header "Lab 04: Criando Certificate Signing Request"

# Verificar pré-requisitos
if [[ ! -f "${KEY_DIR}/rsa-2048.key" ]]; then
  print_error "Erro: Chave RSA não encontrada. Execute o Lab 02 primeiro."
  exit 1
fi

# Criar configuração OpenSSL para CSR com SANs
cat > "${OUTPUT_DIR}/csr.cnf" << 'EOF'
[req]
default_bits = 2048
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = Lab Organization
OU = Certificate Lab
CN = server.example.com
emailAddress = admin@example.com

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = server.example.com
DNS.2 = www.example.com
DNS.3 = mail.example.com
IP.1 = 192.168.1.100
EOF

print_info "Gerando Certificate Signing Request..."
echo

# Gerar CSR
openssl req -new -sha256 \
  -key "${KEY_DIR}/rsa-2048.key" \
  -out "${OUTPUT_DIR}/server.csr" \
  -config "${OUTPUT_DIR}/csr.cnf"

print_success "CSR criado: output/server.csr"
echo

# Exibir informações do CSR
echo "Detalhes do CSR:"
openssl req -in "${OUTPUT_DIR}/server.csr" -noout -subject
echo
echo "Subject Alternative Names no CSR:"
if ! openssl req -in "${OUTPUT_DIR}/server.csr" -noout -text | grep -A 3 "Subject Alternative Name"; then
  echo "  (SANs included in request)"
fi
echo

print_success "Criação do CSR concluída"
echo
echo "Próximos passos (em produção):"
echo "  1. Envie server.csr para sua Autoridade Certificadora"
echo "  2. CA valida sua identidade"
echo "  3. CA assina e retorna server.crt"
echo "  4. Instale server.crt no seu servidor"
