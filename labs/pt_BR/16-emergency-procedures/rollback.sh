#!/usr/bin/env bash
#=============================================================================
# Lab 16: Reverter
# Reverte rapidamente para certificados anteriores
#
# Uso: ./rollback.sh
# Pré-requisitos: RHEL 7, 8, 9, 10, privilégios de root
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

CERT_DIR="/etc/pki/tls/certs"
KEY_DIR="/etc/pki/tls/private"

print_header "Lab 16: Reverter Alterações de Certificado"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

print_info "Procurando arquivos de backup..."
echo

# Encontrar arquivos .backup e .old
echo "Backups de certificado:"
if ! find "${CERT_DIR}" -name "*.backup" -o -name "*.old" 2>/dev/null; then
  echo "None found"
fi
echo

echo "Backups de chave privada:"
if ! find "${KEY_DIR}" -name "*.backup" -o -name "*.old" 2>/dev/null; then
  echo "None found"
fi
echo

read -p "Informe o arquivo de certificado para reverter (sem .backup/.old): " CERT_BASE

if [[ -z "${CERT_BASE}" ]]; then
  echo "Nenhum arquivo especificado"
  exit 1
fi

# Tentar encontrar backup
BACKUP_FILE=""
if [[ -f "${CERT_DIR}/${CERT_BASE}.backup" ]]; then
  BACKUP_FILE="${CERT_DIR}/${CERT_BASE}.backup"
elif [[ -f "${CERT_DIR}/${CERT_BASE}.old" ]]; then
  BACKUP_FILE="${CERT_DIR}/${CERT_BASE}.old"
else
  print_error "Nenhum backup encontrado para ${CERT_BASE}"
  exit 1
fi

echo
echo "Backup encontrado: ${BACKUP_FILE}"
echo
echo "Info do certificado de backup:"
if ! openssl x509 -in "${BACKUP_FILE}" -noout -subject -dates 2>/dev/null; then
  echo "Não foi possível ler o certificado"
fi
echo

read -p "Rollback para este certificado? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Rollback cancelado"
  exit 0
fi

echo
print_info "Executando rollback..."

# Salvar atual como .rollback
if [[ -f "${CERT_DIR}/${CERT_BASE}" ]]; then
  cp "${CERT_DIR}/${CERT_BASE}" "${CERT_DIR}/${CERT_BASE}.rollback"
  print_success "Atual salvo como ${CERT_BASE}.rollback"
fi

# Restaurar backup
cp "${BACKUP_FILE}" "${CERT_DIR}/${CERT_BASE}"
print_success "Certificado revertido"

# Tentar reverter chave também
KEY_BASE="${CERT_BASE%.crt}.key"
if [[ -f "${KEY_DIR}/${KEY_BASE}.backup" ]]; then
  cp "${KEY_DIR}/${KEY_BASE}" "${KEY_DIR}/${KEY_BASE}.rollback" 2>/dev/null || true
  cp "${KEY_DIR}/${KEY_BASE}.backup" "${KEY_DIR}/${KEY_BASE}"
  chmod 600 "${KEY_DIR}/${KEY_BASE}"
  print_success "Chave privada revertida"
elif [[ -f "${KEY_DIR}/${KEY_BASE}.old" ]]; then
  cp "${KEY_DIR}/${KEY_BASE}" "${KEY_DIR}/${KEY_BASE}.rollback" 2>/dev/null || true
  cp "${KEY_DIR}/${KEY_BASE}.old" "${KEY_DIR}/${KEY_BASE}"
  chmod 600 "${KEY_DIR}/${KEY_BASE}"
  print_success "Chave privada revertida"
fi

echo
print_success "Rollback concluído"
echo
echo "Reiniciar serviços para aplicar alterações"
echo
echo "Se a reversão não funcionou, restaure a partir dos arquivos .rollback:"
echo "  cp ${CERT_DIR}/${CERT_BASE}.rollback ${CERT_DIR}/${CERT_BASE}"
