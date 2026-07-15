#!/usr/bin/env bash
#=============================================================================
# Lab 09: Verificar
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

print_header "Lab 09: Verificação OpenLDAP LDAPS"

print_info "1. Verificando serviço slapd..."
systemctl status slapd --no-pager | head -5
echo

print_info "2. Verificando portas em escuta..."
ss -tlnp | grep slapd
echo

print_info "3. Verificando configuração TLS em cn=config..."
echo "Arquivo de certificado TLS:"
if ! ldapsearch -Y EXTERNAL -H ldapi:/// -b cn=config "(objectClass=olcGlobal)" olcTLSCertificateFile 2>/dev/null | grep "olcTLSCertificateFile"; then
  echo "Não configurado"
fi
echo
echo "Arquivo de chave TLS:"
if ! ldapsearch -Y EXTERNAL -H ldapi:/// -b cn=config "(objectClass=olcGlobal)" olcTLSCertificateKeyFile 2>/dev/null | grep "olcTLSCertificateKeyFile"; then
  echo "Não configurado"
fi
echo

print_info "4. Verificando arquivos de certificado..."
if [[ -f /etc/openldap/certs/ldap.crt ]]; then
  print_success "Certificado existe"
  openssl x509 -in /etc/openldap/certs/ldap.crt -noout -subject -dates
else
  echo "Certificado não encontrado"
fi
echo

print_info "5. Verificando chave privada..."
if [[ -f /etc/openldap/certs/ldap.key ]]; then
  print_success "Chave privada existe"
  ls -l /etc/openldap/certs/ldap.key
  PERMS="$(stat -c%a /etc/openldap/certs/ldap.key)"
  if [[ "${PERMS}" == "600" ]]; then
    print_success "Permissões corretas (600)"
  else
    print_warning "Permissões: ${PERMS} (devem ser 600)"
  fi

  OWNER="$(stat -c%U:%G /etc/openldap/certs/ldap.key)"
  if [[ "${OWNER}" == "ldap:ldap" ]]; then
    print_success "Proprietário correto (ldap:ldap)"
  else
    print_warning "Proprietário: ${OWNER} (deve ser ldap:ldap)"
  fi
else
  echo "Chave privada não encontrada"
fi
echo

print_info "6. Verificando configuração SLAPD_URLS..."
if [[ -f /etc/sysconfig/slapd ]]; then
  if ! grep "SLAPD_URLS" /etc/sysconfig/slapd; then
    echo "Não configurado"
  fi
else
  echo "Arquivo sysconfig não encontrado"
fi
echo

print_info "7. Verificando configuração do cliente..."
if [[ -f /etc/openldap/ldap.conf ]]; then
  echo "Configurações TLS do cliente:"
  grep -E "^TLS_|^URI" /etc/openldap/ldap.conf | grep -v "^#"
else
  echo "Configuração do cliente não encontrada"
fi
echo

print_info "8. Testando conexão LDAP..."
if ldapsearch -x -H ldap://localhost -b "" -s base &>/dev/null; then
  print_success "Conexão LDAP funciona"
else
  echo "Conexão LDAP falhou"
fi

print_info "9. Testando conexão LDAPS..."
if ldapsearch -x -H ldaps://localhost -b "" -s base &>/dev/null; then
  print_success "Conexão LDAPS funciona"
else
  echo "Conexão LDAPS falhou (pode ser necessário habilitar a porta 636)"
fi

echo
print_success "Verificação concluída"
