#!/usr/bin/env bash
#=============================================================================
# Lab 10: Verificar
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

PG_DATA="/var/lib/pgsql/data"

print_header "Lab 10: Verificação PostgreSQL TLS"

print_info "1. Verificando serviço PostgreSQL..."
systemctl status postgresql --no-pager | head -5
echo

print_info "2. Verificando porta em escuta..."
ss -tlnp | grep 5432
echo

print_info "3. Verificando configuração SSL..."
echo "Configuração SSL em postgresql.conf:"
if ! grep "^ssl = " "${PG_DATA}/postgresql.conf"; then
  echo "Não configurado"
fi
echo
echo "Arquivo de certificado SSL:"
if ! grep "^ssl_cert_file = " "${PG_DATA}/postgresql.conf"; then
  echo "Não configurado"
fi
echo
echo "Arquivo de chave SSL:"
if ! grep "^ssl_key_file = " "${PG_DATA}/postgresql.conf"; then
  echo "Não configurado"
fi
echo

print_info "4. Verificando arquivos de certificado..."
if [[ -f "${PG_DATA}/server.crt" ]]; then
  print_success "Certificado existe"
  openssl x509 -in "${PG_DATA}/server.crt" -noout -subject -dates
else
  echo "Certificado não encontrado"
fi
echo

print_info "5. Verificando chave privada..."
if [[ -f "${PG_DATA}/server.key" ]]; then
  print_success "Chave privada existe"
  ls -l "${PG_DATA}/server.key"
  PERMS="$(stat -c%a "${PG_DATA}/server.key")"
  if [[ "${PERMS}" == "600" ]]; then
    print_success "Permissões corretas (600)"
  else
    print_warning "Permissões: ${PERMS} (devem ser 600)"
  fi

  OWNER="$(stat -c%U "${PG_DATA}/server.key")"
  if [[ "${OWNER}" == "postgres" ]]; then
    print_success "Proprietário correto (postgres)"
  else
    print_warning "Proprietário: ${OWNER} (deve ser postgres)"
  fi
else
  echo "Chave privada não encontrada"
fi
echo

print_info "6. Verificando status SSL no banco de dados..."
SSL_STATUS="$(sudo -u postgres psql -t -c "SHOW ssl;" 2>/dev/null | tr -d '[:space:]')"
if [[ ${SSL_STATUS} == on ]]; then
  print_success "SSL habilitado no banco de dados (ssl=${SSL_STATUS})"
else
  echo "Status SSL: ${SSL_STATUS}"
fi
echo

print_info "7. Verificando pg_hba.conf para regras SSL..."
echo "Regras de conexão SSL:"
if ! grep "^hostssl" "${PG_DATA}/pg_hba.conf"; then
  echo "No hostssl rules configured"
fi
echo

print_info "8. Testando conexão com banco de dados..."
if sudo -u postgres psql -c "SELECT 'Connection OK';" &>/dev/null; then
  print_success "Conexão com banco de dados funciona"
fi

print_info "9. Consultando informações SSL do servidor..."
if sudo -u postgres psql -t -c "SELECT 1 FROM pg_stat_ssl LIMIT 0;" &>/dev/null; then
  SSL_CONNS="$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_stat_ssl WHERE ssl = true;" 2>/dev/null | tr -d '[:space:]')"
  echo "  Conexões SSL ativas: ${SSL_CONNS:-0}"
  sudo -u postgres psql -c "SHOW ssl; SHOW ssl_cert_file; SHOW ssl_key_file;" 2>/dev/null
else
  echo "  pg_stat_ssl não disponível (requer PostgreSQL 9.5+)"
  sudo -u postgres psql -c "SHOW ssl;" 2>/dev/null || echo "  Informação SSL não disponível"
fi

echo
print_success "Verificação concluída"
