#!/usr/bin/env bash
#=============================================================================
# Lab 17: Avaliar RHEL 7
# Avaliação prévia à migração
#
# Uso: ./assess-rhel7.sh
# Pré-requisitos: RHEL 7
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
if [[ ${RHEL_VERSION} -ne 7 ]]; then
  error_exit "Versão do RHEL não suportada. Este script requer apenas RHEL 7."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

print_header "Lab 17: Avaliação de Certificados RHEL 7"

print_info "1. Versão do sistema:"
cat /etc/redhat-release
echo

print_info "2. Certificados instalados:"
echo "Certificados do sistema em /etc/pki/tls/certs:"
ls -lh /etc/pki/tls/certs/*.crt /etc/pki/tls/certs/*.pem 2>/dev/null | wc -l | xargs echo "  Arquivos de certificado:"

echo
echo "Verificando certificados SHA-1..."
SHA1_COUNT=0
for cert in /etc/pki/tls/certs/*.crt /etc/pki/tls/certs/*.pem; do
  if [[ -f "${cert}" ]]; then
    if openssl x509 -in "${cert}" -noout -text 2>/dev/null | grep -q "sha1WithRSAEncryption"; then
      echo -e " ${YELLOW}⚠ SHA-1: $(basename "${cert}")${NC}"
      ((SHA1_COUNT+=1))
    fi
  fi
done

if [[ ${SHA1_COUNT} -eq 0 ]]; then
  echo -e " ${GREEN}✓ Nenhum certificado SHA-1 encontrado${NC}"
else
  echo -e " ${RED}✗ Encontrados ${SHA1_COUNT} certificados SHA-1 (precisarão ser substituídos no RHEL 8)${NC}"
fi

echo

print_info "3. Serviços usando certificados:"
SERVICES=("httpd" "nginx" "postfix" "slapd" "postgresql")
for svc in "${SERVICES[@]}"; do
  if systemctl list-unit-files | grep -q "^${svc}.service"; then
    STATUS="$(systemctl is-active ${svc} 2>/dev/null || echo "inactive")"
    if [[ ${STATUS} == active ]]; then
      echo -e " ${GREEN}✓ ${svc} (ativo)${NC}"
    else
      echo "   ${svc} (inativo)"
    fi
  fi
done

echo

print_info "4. Configurações TLS:"
echo "Configurações Apache com SSL:"
grep -r "SSLProtocol\|SSLCipherSuite" /etc/httpd/conf* 2>/dev/null | wc -l | xargs echo "  Configurações TLS manuais:"

echo

print_info "5. Repositório de confiança:"
CA_COUNT="$(ls /etc/pki/ca-trust/source/anchors/*.crt 2>/dev/null | wc -l)"
echo "  Certificados CA personalizados: ${CA_COUNT}"

echo

print_info "Resumo da avaliação:"
echo "  Sistema RHEL 7 pronto para avaliação de migração"
echo
print_warning "Ações Pré-Migração Necessárias:"
echo "  1. Faça backup de todos os certificados"
if [[ ${SHA1_COUNT} -gt 0 ]]; then
  echo "  2. Substitua certificados SHA-1 antes da migração"
fi
echo "  3. Documente configurações de serviços"
echo "  4. Teste funcionalidade atual"
echo
echo "Próximo passo: Execute ./backup-certificates.sh"
