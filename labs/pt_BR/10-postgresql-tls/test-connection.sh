#!/usr/bin/env bash
#=============================================================================
# Lab 10: Testar conexão
# Testa conexões ao banco de dados com e sem SSL
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

print_header "Lab 10: Testando PostgreSQL SSL"

# Testar conexão básica
print_info "1. Testando conexão básica..."
if sudo -u postgres psql -c "SELECT version();" &>/dev/null; then
  print_success "Conexão básica bem-sucedida"
else
  print_error "Conexão básica falhou"
  exit 1
fi

echo

# Testar status SSL
print_info "2. Verificando status SSL..."
SSL_STATUS="$(sudo -u postgres psql -t -c "SHOW ssl;" | tr -d '[:space:]')"

if [[ ${SSL_STATUS} == on ]]; then
  print_success "SSL está habilitado (ssl=${SSL_STATUS})"
else
  print_error "SSL não está habilitado"
  exit 1
fi

echo

# Testar conexão com sslmode=require
print_info "3. Testando conexão com sslmode=require..."
if sudo -u postgres psql "sslmode=require" -c "SELECT 1;" &>/dev/null; then
  print_success "Conexão SSL bem-sucedida"
else
  print_warning "Conexão SSL com sslmode=require falhou"
fi

echo

# Consultar configuração SSL do servidor
print_info "4. Consultando configuração SSL do servidor..."
if sudo -u postgres psql -t -c "SELECT 1 FROM pg_stat_ssl LIMIT 0;" &>/dev/null; then
  SSL_STATUS="$(sudo -u postgres psql -t -c "SHOW ssl;" 2>/dev/null | tr -d '[:space:]')"
  SSL_CERT="$(sudo -u postgres psql -t -c "SHOW ssl_cert_file;" 2>/dev/null | tr -d '[:space:]')"
  SSL_KEY="$(sudo -u postgres psql -t -c "SHOW ssl_key_file;" 2>/dev/null | tr -d '[:space:]')"
  if [[ "${SSL_STATUS}" == "on" ]]; then
    print_success "Configuração SSL do servidor:"
    echo "  ssl = ${SSL_STATUS}"
    echo "  ssl_cert_file = ${SSL_CERT}"
    echo "  ssl_key_file = ${SSL_KEY}"
  else
    print_warning "SSL não está habilitado no servidor"
  fi
else
  print_warning "pg_stat_ssl não disponível (requer PostgreSQL 9.5+)"
  SSL_STATUS="$(sudo -u postgres psql -t -c "SHOW ssl;" 2>/dev/null | tr -d '[:space:]')"
  if [[ "${SSL_STATUS}" == "on" ]]; then
    print_success "SSL está habilitado (verificado via SHOW ssl)"
  fi
fi

echo

# Testar SSL com variável de ambiente psql
print_info "5. Testando com variável de ambiente PGSSLMODE..."
if PGSSLMODE=require sudo -u postgres psql -c "SELECT 'SSL test';" &>/dev/null; then
  print_success "Conexão com PGSSLMODE=require bem-sucedida"
else
  print_warning "Conexão com PGSSLMODE=require falhou"
fi

echo

# Exibir todas as conexões SSL atuais
print_info "6. Exibindo estatísticas de conexão SSL..."
echo "Conexões SSL ativas:"
if ! sudo -u postgres psql -c "SELECT datname, usename, ssl, version, cipher FROM pg_stat_ssl JOIN pg_stat_activity USING (pid) WHERE ssl = true;" 2>/dev/null; then
  echo "Sem conexões SSL ou pg_stat_ssl não disponível"
fi

echo
print_success "Testes SSL concluídos"
echo
echo "Comandos de teste manual:"
echo "  sudo -u postgres psql \"sslmode=require\""
echo "  sudo -u postgres psql -c \"SHOW ssl;\""
echo "  sudo -u postgres psql -c \"SELECT * FROM pg_stat_ssl WHERE pid = pg_backend_pid();\""
