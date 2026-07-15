#!/usr/bin/env bash
#=============================================================================
# Lab 19: Testar certificados FIPS
# Testa operações com certificados sob FIPS
#
# Uso: ./test-fips-certificates.sh
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

TEST_DIR="/tmp/fips-cert-test"

print_header "Lab 19: Testar Operações de Certificado FIPS"

# Verificar se o FIPS está habilitado
if [[ -f /proc/sys/crypto/fips_enabled ]]; then
  FIPS_STATUS="$(cat /proc/sys/crypto/fips_enabled)"
  if [[ ${FIPS_STATUS} -ne 1 ]]; then
    print_warning "Modo FIPS não habilitado"
    echo "Este teste funciona melhor com FIPS habilitado"
    echo
  fi
fi

# Criar diretório de teste
mkdir -p "${TEST_DIR}"
cd "${TEST_DIR}"

print_info "1. Testando geração de chave RSA 2048..."
if openssl genrsa -out rsa-2048.key 2048 2>/dev/null; then
  print_success "Geração RSA 2048 bem-sucedida"
else
  print_error "Geração RSA 2048 falhou"
fi

echo

print_info "2. Testando geração de chave ECDSA P-256..."
if openssl ecparam -genkey -name prime256v1 -out ec-p256.key 2>/dev/null; then
  print_success "Geração ECDSA P-256 bem-sucedida"
else
  print_error "Geração ECDSA P-256 falhou"
fi

echo

print_info "3. Testando certificado com SHA-256..."
if openssl req -x509 -new -key rsa-2048.key -sha256 \
  -out cert-sha256.pem -days 365 \
  -subj "/CN=fips-test.example.com" \
  -addext "subjectAltName=DNS:fips-test.example.com" 2>/dev/null; then
  print_success "Certificado SHA-256 criado"
  openssl x509 -in cert-sha256.pem -noout -subject -dates | sed 's/^/  /'
else
  print_error "Falha na criação do certificado SHA-256"
fi

echo

print_info "4. Testando MD5 (deve falhar em FIPS)..."
if echo "test" | openssl md5 2>&1 | grep -qi "fips"; then
  print_success "MD5 bloqueado corretamente pelo FIPS"
elif ! echo "test" | openssl md5 &>/dev/null; then
  print_success "MD5 bloqueado"
else
  print_warning "MD5 não bloqueado (FIPS inativo?)"
fi

echo

print_info "5. Testando verificação de certificado..."
if openssl x509 -in cert-sha256.pem -noout -text >/dev/null 2>&1; then
  print_success "Validação de certificado funciona"
else
  print_error "Validação de certificado falhou"
fi

echo

# Limpeza
cd /
rm -rf "${TEST_DIR}"

print_success "Teste de certificado FIPS concluído"
echo
echo "Operações de certificado aprovadas pelo FIPS:"
echo "  ✓ Chaves RSA de 2048/3072/4096 bits"
echo "  ✓ Chaves ECDSA P-256/384/521"
echo "  ✓ Assinaturas SHA-256/384/512"
echo "  ✓ Cifras AES-128/256-GCM"
echo
echo "Operações bloqueadas:"
echo "  ✗ MD5 (qualquer uso)"
echo "  ✗ Assinaturas SHA-1"
echo "  ✗ RSA < 2048 bits"
echo "  ✗ RC4, DES, 3DES"
