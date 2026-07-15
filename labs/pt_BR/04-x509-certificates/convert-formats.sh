#!/usr/bin/env bash
#=============================================================================
# Lab 04: Conversão de formatos
# Converte entre formatos PEM e DER
#
# Uso: ./convert-formats.sh
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
CERT_PEM="${OUTPUT_DIR}/server.crt"
CERT_DER="${OUTPUT_DIR}/server.der"
CERT_BACK="${OUTPUT_DIR}/server-from-der.pem"

print_header "Lab 04: Conversão de Formato de Certificado"

# Verificar se o certificado existe
if [[ ! -f "${CERT_PEM}" ]]; then
  print_error "Erro: Certificado não encontrado. Execute ./create-self-signed.sh primeiro"
  exit 1
fi

# Converter PEM para DER
print_info "Convertendo PEM para DER (formato binário)..."
openssl x509 -in "${CERT_PEM}" -outform DER -out "${CERT_DER}"
print_success "Criado: ${CERT_DER}"
echo

# Converter DER de volta para PEM
print_info "Convertendo DER de volta para PEM..."
openssl x509 -in "${CERT_DER}" -inform DER -out "${CERT_BACK}"
print_success "Criado: ${CERT_BACK}"
echo

# Comparar tamanhos de arquivo
echo "Comparação de tamanho de arquivo:"
PEM_SIZE=$(stat -f%z "${CERT_PEM}" 2>/dev/null || stat -c%s "${CERT_PEM}")
DER_SIZE=$(stat -f%z "${CERT_DER}" 2>/dev/null || stat -c%s "${CERT_DER}")
echo "  PEM (Base64): ${PEM_SIZE} bytes"
echo "  DER (binário): ${DER_SIZE} bytes"
echo

# Verificar se contêm o mesmo certificado
echo "Verificando conteúdo do certificado..."
PEM_HASH=$(openssl x509 -in "${CERT_PEM}" -noout -fingerprint -sha256 | cut -d= -f2)
DER_HASH=$(openssl x509 -in "${CERT_DER}" -inform DER -noout -fingerprint -sha256 | cut -d= -f2)

if [[ "${PEM_HASH}" == "${DER_HASH}" ]]; then
  print_success "Certificados correspondem (mesmo conteúdo, codificação diferente)"
else
  print_error "Certificados não correspondem"
  exit 1
fi
echo

# Exibir características do formato
echo "Características do formato:"
echo
echo "PEM (Privacy Enhanced Mail):"
echo "  - Texto codificado em Base64"
echo "  - Possui cabeçalhos -----BEGIN/END-----"
echo "  - Legível por humanos (pode visualizar em editor de texto)"
echo "  - Mais comum em RHEL/Linux"
echo "  - Usado por: Apache, NGINX, maioria das ferramentas Linux"
echo
echo "DER (Distinguished Encoding Rules):"
echo "  - Formato binário"
echo "  - Tamanho de arquivo menor"
echo "  - Não legível por humanos"
echo "  - Usado por: Java, Windows, alguns dispositivos embarcados"
echo

print_success "Conversão de formato concluída"
