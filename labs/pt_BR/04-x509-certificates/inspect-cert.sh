#!/usr/bin/env bash
#=============================================================================
# Lab 04: Inspeção de certificado
# Exibe informações detalhadas do certificado
#
# Uso: ./inspect-cert.sh
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
CERT_FILE="${OUTPUT_DIR}/server.crt"

print_header "Lab 04: Inspeção de Certificado"

# Verificar se o certificado existe
if [[ ! -f "${CERT_FILE}" ]]; then
  print_error "Erro: Certificado não encontrado. Execute ./create-self-signed.sh primeiro"
  exit 1
fi

# Subject
print_info "Subject (Quem o certificado identifica):"
openssl x509 -in "${CERT_FILE}" -noout -subject
echo

# Emissor
print_info "Emissor (quem assinou o certificado):"
openssl x509 -in "${CERT_FILE}" -noout -issuer
echo

# Datas de validade
print_info "Período de validade:"
openssl x509 -in "${CERT_FILE}" -noout -dates
echo

# Verificar se expirou
if openssl x509 -in "${CERT_FILE}" -noout -checkend 0 &>/dev/null; then
  print_success "Certificado está atualmente válido"
else
  print_error "Certificado expirou"
fi
echo

# Subject Alternative Names
print_info "Subject Alternative Names (SANs):"
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  if ! openssl x509 -in "${CERT_FILE}" -noout -text | grep -A2 "Subject Alternative Name" 2>/dev/null; then
    echo "  Sem SANs (não recomendado para RHEL 9+)"
  fi
else
  if ! openssl x509 -in "${CERT_FILE}" -noout -ext subjectAltName 2>/dev/null; then
    echo "  Sem SANs (não recomendado para RHEL 9+)"
  fi
fi
echo

# Informações da chave pública
print_info "Chave Pública:"
openssl x509 -in "${CERT_FILE}" -noout -text | grep -A 2 "Public Key Algorithm"
echo

# Algoritmo de assinatura
print_info "Algoritmo de assinatura:"
openssl x509 -in "${CERT_FILE}" -noout -text | grep "Signature Algorithm" | head -1
echo

# Impressões digitais
print_info "Impressões digitais do certificado:"
echo -n "  SHA-256: "
openssl x509 -in "${CERT_FILE}" -noout -fingerprint -sha256 | cut -d= -f2
echo -n "  SHA-1:   "
openssl x509 -in "${CERT_FILE}" -noout -fingerprint -sha1 | cut -d= -f2
echo

# Verificação de versão RHEL
if [[ ${RHEL_VERSION} -ge 9 ]]; then
  if openssl x509 -in "${CERT_FILE}" -noout -ext subjectAltName 2>/dev/null | grep -q "DNS"; then
    print_success "Requisito RHEL 9+: SANs presentes"
  else
    print_warning "Aviso RHEL 9+: SANs ausentes (obrigatórios para validação)"
  fi
fi

echo
print_success "Inspeção de certificado concluída"
