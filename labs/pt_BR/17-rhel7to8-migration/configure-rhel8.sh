#!/usr/bin/env bash
#=============================================================================
# Lab 17: Configurar RHEL 8
# Configuração de certificados no RHEL 8 já atualizado
#
# Uso: ./configure-rhel8.sh
# Pré-requisitos: RHEL 8, privilégios de root
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
if [[ ${RHEL_VERSION} -ne 8 ]]; then
  error_exit "Versão do RHEL não suportada. Este script requer apenas RHEL 8."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

print_header "Lab 17: Configuração pós-upgrade do RHEL 8"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

# Verificar crypto-policy atual
print_info "1. Verificando crypto-policy..."
POLICY="$(update-crypto-policies --show 2>/dev/null || echo "UNKNOWN")"
echo "  Política atual: ${POLICY}"

if [[ ${POLICY} == DEFAULT ]]; then
  echo -e " ${GREEN}✓ Usando política DEFAULT${NC}"
elif [[ ${POLICY} == LEGACY ]]; then
  echo -e " ${YELLOW}⚠ Usando política LEGACY (para compatibilidade)${NC}"
fi

echo

# Atualizar configurações de serviço
print_info "2. Atualizando configurações de serviços..."

# Apache
if [[ -d /etc/httpd/conf.d ]]; then
  echo "  Verificando configurações Apache..."
  if grep -r "^[^#]*SSLProtocol" /etc/httpd/conf* 2>/dev/null | grep -q .; then
    echo -e "   ${YELLOW}⚠ Directivas SSLProtocol manuais encontradas${NC}"
    echo "      Considere remover para usar crypto-policies"
  else
    echo -e "   ${GREEN}✓ Sem configurações manuais de protocolo TLS${NC}"
  fi
fi

# NGINX
if [[ -d /etc/nginx ]]; then
  echo "  Verificando configurações NGINX..."
  if grep -r "ssl_protocols" /etc/nginx/ 2>/dev/null | grep -v "^#" | grep -q .; then
    echo -e "   ${YELLOW}⚠ Directivas ssl_protocols manuais encontradas${NC}"
    echo "      NGINX ainda requer configurações explícitas de protocolo"
  fi
fi

echo

# Verificar certificados
print_info "3. Verificando certificados..."
CERT_COUNT=0
VALID_COUNT=0

for cert in /etc/pki/tls/certs/*.crt; do
  if [[ -f "${cert}" ]]; then
    ((CERT_COUNT+=1))
    if openssl x509 -in "${cert}" -noout -checkend 0 2>/dev/null; then
      ((VALID_COUNT+=1))
    fi
  fi
done

echo "  Total de certificados: ${CERT_COUNT}"
echo "  Certificados válidos: ${VALID_COUNT}"

if [[ ${CERT_COUNT} -eq ${VALID_COUNT} ]]; then
  echo -e " ${GREEN}✓ Todos os certificados válidos${NC}"
else
  echo -e " ${RED}✗ Alguns certificados expirados ou inválidos${NC}"
fi

echo

# Testar serviços
print_info "4. Testando serviços..."
SERVICES=("httpd" "nginx" "postfix")
for svc in "${SERVICES[@]}"; do
  if systemctl is-active ${svc} &>/dev/null; then
    echo -e " ${GREEN}✓ ${svc} em execução${NC}"
  elif systemctl list-unit-files | grep -q "^${svc}.service"; then
    echo -e " ${YELLOW}⚠ ${svc} instalado mas não em execução${NC}"
  fi
done

echo

print_success "Configuração pós-upgrade do RHEL 8 concluída"
echo
echo "Próximos passos:"
echo "  1. Teste todos os serviços minuciosamente"
echo "  2. Execute ./validate-migration.sh"
echo "  3. Monitore logs em busca de problemas"
echo
echo "Se surgirem problemas de compatibilidade:"
echo "  sudo update-crypto-policies --set LEGACY"
