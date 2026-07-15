#!/usr/bin/env bash
#=============================================================================
# Lab 15: Criar problema
# Cenário 01: Criar problema de certificado vencido
#
# Uso: ./create-problem.sh
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
  error_exit "Versão do RHEL não suportada. Este script requer RHEL 7, 8, 9, 10."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_FILE="/etc/pki/tls/certs/expired.crt"
KEY_FILE="/etc/pki/tls/private/expired.key"

print_header "Cenário 01: Criando certificado expirado"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

print_info "Criando certificado expirado..."

# OpenSSL 1.1.1+ (RHEL 8+) rejeita -days 0, então usamos openssl ca com
# datas passadas explícitas para criar um certificado já expirado de forma portável.
WORK_DIR=$(mktemp -d)
mkdir -p "${WORK_DIR}/newcerts"
touch "${WORK_DIR}/index.txt"
echo "01" > "${WORK_DIR}/serial"

openssl genrsa -out "${KEY_FILE}" 2048 2>/dev/null

openssl req -new -key "${KEY_FILE}" \
  -out "${WORK_DIR}/expired.csr" \
  -subj "/CN=expired.example.com" 2>/dev/null

openssl req -x509 -new -key "${KEY_FILE}" \
  -out "${WORK_DIR}/ca.crt" -days 3650 \
  -subj "/CN=Lab 15 CA" 2>/dev/null

cat > "${WORK_DIR}/ca.cnf" << CONF
[ca]
default_ca = mini

[mini]
dir              = ${WORK_DIR}
database         = \$dir/index.txt
serial           = \$dir/serial
new_certs_dir    = \$dir/newcerts
certificate      = \$dir/ca.crt
private_key      = ${KEY_FILE}
default_md       = sha256
policy           = pol

[pol]
commonName = supplied
CONF

openssl ca -batch -notext \
  -config "${WORK_DIR}/ca.cnf" \
  -startdate 230101000000Z \
  -enddate 230102000000Z \
  -in "${WORK_DIR}/expired.csr" \
  -out "${CERT_FILE}" 2>/dev/null

rm -rf "${WORK_DIR}"

chmod 644 "${CERT_FILE}"
chmod 600 "${KEY_FILE}"

print_success "Certificado expirado criado"
echo
echo "Local do certificado: ${CERT_FILE}"
echo "Localização da chave privada: ${KEY_FILE}"
echo

# Mostrar que está expirado
print_info "Detalhes do certificado:"
openssl x509 -in "${CERT_FILE}" -noout -dates

echo
print_error "⚠ Problema criado: Certificado expirado!"
echo
echo "Próximos passos:"
echo "  1. Execute ./diagnose.sh para investigar"
echo "  2. Execute ./fix.sh para resolver"
echo "  3. Execute ./verify-fix.sh para confirmar"
