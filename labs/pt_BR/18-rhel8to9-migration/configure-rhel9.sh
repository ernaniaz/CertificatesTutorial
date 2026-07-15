#!/usr/bin/env bash
#=============================================================================
# Lab 18: Configurar RHEL 9
# Configuração do OpenSSL 3.x no RHEL 9 já atualizado
#
# Uso: ./configure-rhel9.sh
# Pré-requisitos: RHEL 9, privilégios de root
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
if [[ ${RHEL_VERSION} -ne 9 ]]; then
  error_exit "Versão do RHEL não suportada. Este script requer apenas RHEL 9."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

print_header "Lab 18: Configuração pós-upgrade do RHEL 9"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

# Verificar versão do OpenSSL
print_info "1. Verificando OpenSSL 3.x..."
OPENSSL_VERSION="$(openssl version)"
echo " ${OPENSSL_VERSION}"

if echo "${OPENSSL_VERSION}" | grep -q "OpenSSL 3"; then
  echo -e " ${GREEN}✓ OpenSSL 3.x detectado${NC}"
else
  echo -e " ${YELLOW}⚠ Versão inesperada do OpenSSL${NC}"
fi

echo

# Verificar crypto-policy
print_info "2. Verificando crypto-policy..."
POLICY="$(update-crypto-policies --show 2>/dev/null)"
echo "  Atual: ${POLICY}"

echo

# Verificar certificados
print_info "3. Validando certificados com OpenSSL 3.x..."
CERT_ERRORS=0

for cert in /etc/pki/tls/certs/*.crt; do
  if [[ -f "${cert}" ]]; then
    if ! openssl x509 -in "${cert}" -noout 2>/dev/null; then
      echo -e " ${RED}✗ $(basename "${cert}")${NC}"
      ((CERT_ERRORS+=1))
    fi
  fi
done

if [[ ${CERT_ERRORS} -eq 0 ]]; then
  echo -e " ${GREEN}✓ Todos os certificados válidos com OpenSSL 3.x${NC}"
else
  echo -e " ${RED}✗ ${CERT_ERRORS} certificados com problemas${NC}"
fi

echo

# Verificar necessidade de legacy provider
print_info "4. Verificando uso de algoritmos legados..."
if [[ -f /etc/pki/tls/openssl.cnf ]] && grep -qP '^[^#]*legacy\s*=' /etc/pki/tls/openssl.cnf; then
  echo -e " ${YELLOW}⚠ Provider legacy habilitado${NC}"
  echo "    Verifique se ainda é necessário"
else
  echo -e " ${GREEN}✓ Usando apenas o provider padrão${NC}"
fi

echo

# Testar serviços
print_info "5. Testando serviços..."
for svc in httpd nginx postfix; do
  if systemctl is-active ${svc} &>/dev/null; then
    echo -e " ${GREEN}✓ ${svc} em execução${NC}"
  elif systemctl list-unit-files | grep -q "^${svc}.service"; then
    echo -e " ${YELLOW}⚠ ${svc} instalado mas não em execução${NC}"
  fi
done

echo

print_success "Revisão de configuração pós-upgrade do RHEL 9 concluída"
echo
echo "Próximos passos:"
echo "  1. Teste todas as conexões TLS"
echo "  2. Execute ./validate-migration.sh"
echo "  3. Monitore avisos de depreciação"
echo

if [[ ${CERT_ERRORS} -gt 0 ]]; then
  print_warning "Problemas de certificado detectados"
  echo "Considere regenerar os certificados afetados"
fi
