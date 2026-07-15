#!/usr/bin/env bash
#=============================================================================
# Lab 08: Verificar
# Passos de verificação manual
#
# Uso: ./verify.sh
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

print_header "Lab 08: Verificação Postfix TLS"

print_info "1. Verificando serviço Postfix..."
systemctl status postfix --no-pager | head -5
echo

print_info "2. Verificando portas em escuta..."
ss -tlnp | grep master
echo

print_info "3. Verificando configuração TLS..."
echo "Certificado e chave TLS:"
postconf -n | grep -E "smtpd_tls_cert_file|smtpd_tls_key_file" || print_warning "Ainda não configurado"
echo
echo "Níveis de segurança TLS:"
postconf -n | grep -E "smtpd_tls_security_level|smtp_tls_security_level" || print_warning "Ainda não configurado"
echo
echo "Protocolos TLS:"
postconf -n | grep -E "smtpd_tls_protocols" || print_warning "Ainda não configurado"
echo

print_info "4. Verificando arquivos de certificado..."
if [[ -f /etc/pki/tls/certs/postfix.crt ]]; then
  print_success "Certificado existe"
  openssl x509 -in /etc/pki/tls/certs/postfix.crt -noout -subject -dates
else
  echo "Certificado não encontrado"
fi
echo

print_info "5. Verificando chave privada..."
if [[ -f /etc/pki/tls/private/postfix.key ]]; then
  print_success "Chave privada existe"
  ls -l /etc/pki/tls/private/postfix.key
  PERMS="$(stat -c%a /etc/pki/tls/private/postfix.key)"
  if [[ "${PERMS}" == "600" ]]; then
    print_success "Permissões corretas (600)"
  else
    print_warning "Permissões: ${PERMS} (devem ser 600)"
  fi
else
  echo "Chave privada não encontrada"
fi
echo

print_info "6. Verificando capacidade STARTTLS..."
EHLO_TEST="$(echo -e "EHLO localhost\nQUIT" | nc localhost 25 2>/dev/null || true)"
if echo "${EHLO_TEST}" | grep -q "STARTTLS"; then
  print_success "STARTTLS anunciado na porta 25"
else
  if ! command -v nc &>/dev/null; then
    print_warning "nc (netcat) não instalado, pulando verificação STARTTLS"
  else
    print_warning "STARTTLS não anunciado na porta 25"
  fi
fi
echo

print_info "7. Verificando porta de submissão..."
if ss -tlnp | grep -q ':587'; then
  print_success "Porta 587 ativa"
  if grep -q "smtpd_tls_security_level=encrypt" /etc/postfix/master.cf; then
    print_success "Criptografia obrigatória configurada"
  fi
else
  echo "Porta 587 não está escutando"
fi
echo

print_info "8. Verificando logs recentes..."
echo "Entradas recentes de log Postfix TLS:"
if [[ -f /var/log/maillog ]]; then
  if ! grep -i "tls\|starttls" /var/log/maillog 2>/dev/null | tail -5; then
    echo "No TLS logs yet"
  fi
elif [[ -f /var/log/messages ]]; then
  if ! grep -i "postfix.*tls" /var/log/messages 2>/dev/null | tail -5; then
    echo "No TLS logs yet"
  fi
else
  if ! journalctl -u postfix --no-pager | grep -i tls | tail -5; then
    echo "No TLS logs yet"
  fi
fi

echo
print_success "Verificação concluída"
