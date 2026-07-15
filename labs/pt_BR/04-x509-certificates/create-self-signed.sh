#!/usr/bin/env bash
#=============================================================================
# Lab 04: Certificado autoassinado
# Gera um certificado X.509 autoassinado com SANs
#
# Uso: ./create-self-signed.sh
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

print_header "Lab 04: Criando Certificado Autoassinado"

# Verificar pré-requisitos
if [[ ! -f "${KEY_DIR}/rsa-2048.key" ]]; then
  print_error "Erro: Chave RSA não encontrada. Execute o Lab 02 primeiro."
  exit 1
fi

# Criar configuração OpenSSL para SANs
cat > "${OUTPUT_DIR}/san.cnf" << 'EOF'
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

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = server.example.com
DNS.2 = www.example.com
DNS.3 = *.example.com
IP.1 = 192.168.1.100
EOF

print_info "Gerando certificado autoassinado..."
echo

# Gerar certificado autoassinado com SANs
openssl req -new -x509 -sha256 \
  -key "${KEY_DIR}/rsa-2048.key" \
  -out "${OUTPUT_DIR}/server.crt" \
  -days 365 \
  -config "${OUTPUT_DIR}/san.cnf" \
  -extensions v3_req

print_success "Certificado autoassinado criado: output/server.crt"
echo

# Exibir informações do certificado
echo "Detalhes do certificado:"
openssl x509 -in "${OUTPUT_DIR}/server.crt" -noout -subject -issuer -dates
echo
echo "Subject Alternative Names:"
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  openssl x509 -in "${OUTPUT_DIR}/server.crt" -noout -text | grep -A2 "Subject Alternative Name"
else
  openssl x509 -in "${OUTPUT_DIR}/server.crt" -noout -ext subjectAltName
fi
echo

# Notas específicas por versão RHEL
if [[ ${RHEL_VERSION} -ge 9 ]]; then
  print_success "RHEL 9+ detectado: Certificado inclui SANs obrigatórios"
fi

echo
print_success "Criação de certificado autoassinado concluída"
echo
echo "Validade: 365 dias a partir de hoje"
echo "Algoritmo: SHA-256 com RSA (2048-bit)"
