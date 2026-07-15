#!/usr/bin/env bash
#=============================================================================
# Lab 05: Criação de CA de teste
# Gera uma Certificate Authority personalizada para testes
#
# Uso: ./create-test-ca.sh
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

OUTPUT_DIR="output"
mkdir -p "${OUTPUT_DIR}"

print_header "Lab 05: Criando Certificado de CA de Teste"

# Gerar chave privada CA
print_info "Gerando chave privada CA..."
openssl genpkey -algorithm RSA \
  -out "${OUTPUT_DIR}/test-ca.key" \
  -pkeyopt rsa_keygen_bits:4096

chmod 600 "${OUTPUT_DIR}/test-ca.key"
print_success "Chave privada CA criada"
echo

# Gerar certificado CA autoassinado
print_info "Gerando certificado CA autoassinado..."

# Criar configuração CA
cat > "${OUTPUT_DIR}/ca.cnf" << 'EOF'
[req]
default_bits = 4096
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = Lab Test CA
OU = Certificate Lab
CN = Lab Test Root CA

[v3_ca]
basicConstraints = critical,CA:TRUE
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
EOF

openssl req -new -x509 -sha256 \
  -key "${OUTPUT_DIR}/test-ca.key" \
  -out "${OUTPUT_DIR}/test-ca.crt" \
  -days 3650 \
  -config "${OUTPUT_DIR}/ca.cnf" \
  -extensions v3_ca

print_success "Certificado CA criado (válido por 10 anos)"
echo

# Exibir informações da CA
echo "Detalhes do certificado CA:"
openssl x509 -in "${OUTPUT_DIR}/test-ca.crt" -noout -subject -issuer
echo
echo "Basic Constraints:"
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  openssl x509 -in "${OUTPUT_DIR}/test-ca.crt" -noout -text | grep -A2 "Basic Constraints"
else
  openssl x509 -in "${OUTPUT_DIR}/test-ca.crt" -noout -ext basicConstraints
fi
echo

print_success "Criação de CA de teste concluída"
echo
echo "Arquivos criados:"
echo " ${OUTPUT_DIR}/test-ca.key (chave privada CA - mantenha segura!)"
echo " ${OUTPUT_DIR}/test-ca.crt (certificado CA - a ser confiável)"
