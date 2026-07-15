#!/usr/bin/env bash
#=============================================================================
# Lab 09: Testar conexão
# Testa LDAP, STARTTLS e LDAPS
#
# Uso: ./test-connection.sh
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

print_header "Lab 09: Testando Conexões LDAP"

# Testar LDAP simples (porta 389)
print_info "1. Testando LDAP simples (porta 389)..."
if ldapsearch -x -H ldap://localhost -b "" -s base supportedSASLMechanisms &>/dev/null; then
  print_success "Conexão LDAP simples bem-sucedida"
else
  print_error "Conexão LDAP simples falhou"
  exit 1
fi

echo

# Testar STARTTLS (porta 389)
print_info "2. Testando STARTTLS (porta 389 com -ZZ)..."
if ldapsearch -x -H ldap://localhost -b "" -s base -ZZ supportedSASLMechanisms &>/dev/null; then
  print_success "Conexão STARTTLS bem-sucedida"
else
  print_warning "STARTTLS falhou (pode ser necessário TLS_REQCERT allow em ldap.conf)"
fi

echo

# Testar LDAPS (porta 636)
print_info "3. Testando LDAPS (porta 636)..."
if ldapsearch -x -H ldaps://localhost -b "" -s base supportedSASLMechanisms &>/dev/null; then
  print_success "Conexão LDAPS bem-sucedida"
else
  print_warning "LDAPS falhou (verifique se a porta 636 está habilitada)"
fi

echo

# Testar com openssl s_client
print_info "4. Testando handshake TLS com openssl..."
if ss -tlnp | grep -q ':636'; then
  TLS_INFO="$(echo "QUIT" | timeout 5 openssl s_client -connect localhost:636 2>&1 || true)"

  if echo "${TLS_INFO}" | grep -q "Server certificate"; then
    print_success "Handshake TLS bem-sucedido"

    # Extrair informações do certificado
    SUBJECT="$(echo "${TLS_INFO}" | grep "subject=" | head -1)"
    if [[ -n "${SUBJECT}" ]]; then
      echo " ${SUBJECT}"
    fi

    # Extrair protocolo
    PROTOCOL="$(echo "${TLS_INFO}" | grep "Protocol" | head -1)"
    if [[ -n "${PROTOCOL}" ]]; then
      echo " ${PROTOCOL}"
    fi

    # Extrair cipher
    CIPHER="$(echo "${TLS_INFO}" | grep "Cipher" | head -1)"
    if [[ -n "${CIPHER}" ]]; then
      echo " ${CIPHER}"
    fi
  else
    print_warning "Não foi possível verificar detalhes TLS"
  fi
else
  print_warning "Porta 636 não está escutando"
fi

echo

# Consultar mecanismos suportados
print_info "5. Consultando mecanismos SASL suportados..."
MECHANISMS="$(ldapsearch -x -H ldap://localhost -b "" -s base supportedSASLMechanisms 2>/dev/null | grep "supportedSASLMechanisms" | awk '{print $2}' | tr '\n' ' ')"
if [[ -n "${MECHANISMS}" ]]; then
  print_success "Mecanismos SASL suportados: ${MECHANISMS}"
else
  echo "Nenhum mecanismo SASL reportado"
fi

echo
print_success "Teste de conexão concluído"
echo
echo "Comandos de teste manual:"
echo "  ldapsearch -x -H ldap://localhost -b \"\" -s base"
echo "  ldapsearch -x -H ldaps://localhost -b \"\" -s base"
echo "  ldapsearch -x -H ldap://localhost -b \"\" -s base -ZZ"
echo "  openssl s_client -connect localhost:636"
