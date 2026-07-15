#!/usr/bin/env bash
#=============================================================================
# Lab 15: Diagnosticar
# Cenário 01: Diagnosticar certificado vencido
#
# Uso: ./diagnose.sh
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
  error_exit "Versão do RHEL não suportada. Este script requer RHEL 7, 8, 9, 10."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

CERT_FILE="/etc/pki/tls/certs/expired.crt"

print_header "Cenário 01: Diagnosticando problema de certificado"

if [[ ! -f "${CERT_FILE}" ]]; then
  print_error "Certificado não encontrado. Execute ./create-problem.sh primeiro"
  exit 1
fi

print_info "Passo 1: Verificar datas de validade do certificado"
openssl x509 -in "${CERT_FILE}" -noout -dates
echo

print_info "Passo 2: Verificar se o certificado está expirado"
if openssl x509 -in "${CERT_FILE}" -noout -checkend 0 2>/dev/null; then
  print_success "Certificado ainda é válido"
else
  print_error "Certificado expirou!"
fi
echo

print_info "Passo 3: Mostrar detalhes completos do certificado"
openssl x509 -in "${CERT_FILE}" -noout -subject -issuer -dates
echo

print_info "Passo 4: Calcular dias até/desde a expiração"
NOT_AFTER="$(openssl x509 -in "${CERT_FILE}" -noout -enddate | cut -d= -f2)"
EXPIRE_EPOCH="$(date -d "${NOT_AFTER}" +%s 2>/dev/null || echo "0")"
NOW_EPOCH="$(date +%s)"
DAYS_DIFF="$(( (${EXPIRE_EPOCH} - ${NOW_EPOCH}) / 86400 ))"

if [[ ${DAYS_DIFF} -lt 0 ]]; then
  print_error "Certificado expirou há ${DAYS_DIFF#-} dias"
else
  print_success "Certificado expira em ${DAYS_DIFF} dias"
fi

echo
echo "======================================="
if openssl x509 -in "${CERT_FILE}" -noout -checkend 0 2>/dev/null; then
  print_success "DIAGNÓSTICO: Certificado ainda é válido"
  echo
  echo "Nota: Este cenário espera um certificado expirado."
  echo "Se vir resultados conflitantes acima, revise notBefore/notAfter com atenção."
else
  print_warning "DIAGNÓSTICO: Certificado expirou"
  echo
  echo "Impacto:"
  echo "  - Conexões SSL/TLS falharão quando este certificado estiver em uso"
  echo "  - Serviços não podem usar este certificado"
  echo "  - Clientes exibirão avisos de segurança"
  echo
  echo "Solução: Gerar novo certificado com expiração futura"
  echo "Execute ./fix.sh para resolver este problema"
fi
