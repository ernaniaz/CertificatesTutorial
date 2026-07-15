#!/usr/bin/env bash
#=============================================================================
# Lab 03: Teste de manipulação
# Demonstra que a assinatura falha quando o arquivo é modificado
#
# Uso: ./tamper-test.sh
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
SAMPLE_FILE="sample-data.txt"
SIGNATURE_FILE="sample-data.sig"
TAMPERED_FILE="tampered-data.txt"

print_header "Lab 03: Teste de Detecção de Adulteração"

# Verificar pré-requisitos
if [[ ! -f "${SIGNATURE_FILE}" ]]; then
  print_error "Erro: Execute ./sign-file.sh primeiro"
  exit 1
fi

# Criar versão adulterada
print_warning "Criando versão adulterada do arquivo..."
cp "${SAMPLE_FILE}" "${TAMPERED_FILE}"
echo "TAMPERED CONTENT - This text was added after signing!" >> "${TAMPERED_FILE}"
print_warning "✓ Arquivo modificado"
echo

# Tentativa de verificar assinatura em arquivo adulterado
echo "Tentando verificar assinatura em arquivo adulterado..."
echo "(Isso deve FALHAR - comprovando detecção de adulteração)"
echo

if openssl dgst -sha256 \
  -verify "${KEY_DIR}/rsa-2048.pub" \
  -signature "${SIGNATURE_FILE}" \
  "${TAMPERED_FILE}" 2>/dev/null; then
  print_error "======================================="
  print_error "ERRO: Arquivo adulterado verificado!"
  print_error "Isso não deveria acontecer!"
  print_error "======================================="
  rm -f "${TAMPERED_FILE}"
  exit 1
else
  print_success "SUCESSO: Adulteração detectada!"
  echo
  echo "Como esperado, a assinatura NÃO verifica para o arquivo modificado."
  echo "Isso prova que assinaturas digitais detectam quaisquer alterações nos dados assinados."
fi

# Limpeza
rm -f "${TAMPERED_FILE}"
echo
print_success "Teste de detecção de adulteração aprovado"
