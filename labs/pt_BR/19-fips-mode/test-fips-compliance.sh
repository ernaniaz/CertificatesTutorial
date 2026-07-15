#!/usr/bin/env bash
#=============================================================================
# Lab 19: Testar conformidade FIPS
# Testa operações com certificados em modo FIPS
#
# Uso: ./test-fips-compliance.sh
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

OUTPUT_DIR="/tmp/fips-test-$(date +%s)"

print_header "Lab 19: Testes de Conformidade FIPS"

# Criar diretório de saída
mkdir -p "${OUTPUT_DIR}"
cd "${OUTPUT_DIR}"

print_info "1. Testando geração de chaves compatível com FIPS..."

# RSA 2048 (deve funcionar)
if openssl genrsa -out rsa2048.key 2048 2>/dev/null; then
  echo -e " ${GREEN}✓ Chave RSA de 2048 bits gerada${NC}"
else
  echo -e " ${RED}✗ Falha na geração RSA 2048${NC}"
fi

# RSA 1024 (deve falhar em FIPS)
if openssl genrsa -out rsa1024.key 1024 2>/dev/null; then
  echo -e " ${YELLOW}⚠ RSA 1024 bits bem-sucedido (FIPS pode não estar ativo)${NC}"
else
  echo -e " ${GREEN}✓ RSA 1024 bloqueado corretamente${NC}"
fi

echo

print_info "2. Testando geração de certificado compatível com FIPS..."

# SHA-256 (deve funcionar)
if openssl req -x509 -newkey rsa:2048 -sha256 -nodes \
  -keyout sha256.key -out sha256.crt -days 30 \
  -subj "/CN=fips-test" 2>/dev/null; then
  echo -e " ${GREEN}✓ Certificado SHA-256 criado${NC}"
else
  echo -e " ${RED}✗ Falha no certificado SHA-256${NC}"
fi

echo

print_info "3. Testando algoritmos bloqueados..."

# MD5 (deve falhar)
if echo "test" | openssl dgst -md5 >/dev/null 2>&1; then
  echo -e " ${YELLOW}⚠ MD5 funciona (FIPS pode não estar aplicando)${NC}"
else
  echo -e " ${GREEN}✓ MD5 bloqueado corretamente${NC}"
fi

# SHA-1 (deve falhar para assinaturas em FIPS)
if echo "test" | openssl dgst -sha1 >/dev/null 2>&1; then
  echo -e " ${YELLOW}⚠ Hash SHA-1 funciona (permitido para hash, não para assinaturas)${NC}"
else
  echo -e " ${GREEN}✓ SHA-1 bloqueado${NC}"
fi

echo

print_info "4. Testando conformidade TLS..."

# Verificar ciphers disponíveis
CIPHER_COUNT="$(openssl ciphers -v 2>/dev/null | wc -l)"
echo "  Cifras disponíveis: ${CIPHER_COUNT}"
echo "  (Modo FIPS restringe apenas a cifras aprovadas)"

echo

# Exibir ciphers aprovados pelo FIPS (amostra)
echo "  Cifras FIPS de exemplo:"
if ! openssl ciphers -v 'FIPS' 2>/dev/null | head -5 | sed 's/^/    /'; then
  echo "    Não foi possível listar cifras FIPS"
fi

echo

# Limpeza
cd /
rm -rf "${OUTPUT_DIR}"

print_success "Teste de conformidade FIPS concluído"
echo

if [[ -f /proc/sys/crypto/fips_enabled && "$(cat /proc/sys/crypto/fips_enabled)" == "1" ]]; then
  print_success "Sistema está em conformidade com FIPS"
else
  print_warning "Sistema NÃO está em modo FIPS"
fi
