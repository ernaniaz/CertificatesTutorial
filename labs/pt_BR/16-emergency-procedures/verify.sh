#!/usr/bin/env bash
#=============================================================================
# Lab 16: Verificar
# Passos de verificação
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

print_header "Lab 16: Verificação de Procedimentos de Emergência"

print_info "1. Verificando scripts de emergência..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS=(
  "emergency-replacement.sh"
  "self-signed-temp.sh"
  "restore-backup.sh"
  "rollback.sh"
)

for script in "${SCRIPTS[@]}"; do
  if [[ -f "${SCRIPT_DIR}/${script}" && -x "${SCRIPT_DIR}/${script}" ]]; then
    print_success "${script}"
  else
    echo " ${script} (não encontrado ou não executável)"
  fi
done

echo

print_info "2. Verificando diretórios de certificados..."
for dir in /etc/pki/tls/certs /etc/pki/tls/private; do
  if [[ -d "${dir}" ]]; then
    print_success "${dir}"
  else
    echo " ${dir} (não encontrado)"
  fi
done

echo

print_info "3. Verificando backups..."
BACKUP_COUNT="$(ls -d /root/cert-backup-* 2>/dev/null | wc -l)"
echo "  Encontrados ${BACKUP_COUNT} diretórios de backup"

echo

print_info "4. Verificando certificados de emergência..."
for cert in /etc/pki/tls/certs/emergency.crt /etc/pki/tls/certs/temp-*.crt; do
  if [[ -f "${cert}" ]]; then
    echo "  $(basename "${cert}")"
    openssl x509 -in "${cert}" -noout -subject -dates 2>/dev/null | sed 's/^/    /'
  fi
done

echo
print_success "Verificação concluída"
echo
echo "Procedimentos de emergência prontos"
