#!/usr/bin/env bash
#=============================================================================
# Lab 16: Restaurar backup
# Restaura certificados conhecidos como bons
#
# Uso: ./restore-backup.sh
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

print_header "Lab 16: Restaurar Certificados do Backup"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

# Encontrar backups disponíveis
print_info "Backups disponíveis:"
if ls -d /root/cert-backup-* 2>/dev/null; then
  echo
else
  echo "Nenhum backup encontrado em /root/cert-backup-*"
  echo
  echo "Verificando arquivos .backup..."
  if ! find /etc/pki/tls -name "*.backup" -o -name "*.old" 2>/dev/null; then
    echo "No backup files found"
  fi
  exit 1
fi

echo
read -p "Informe o caminho do diretório de backup: " BACKUP_DIR

if [[ ! -d "${BACKUP_DIR}" ]]; then
  print_error "Diretório de backup não encontrado"
  exit 1
fi

echo
echo "Diretório de backup: ${BACKUP_DIR}"
echo "Conteúdo:"
ls -lh "${BACKUP_DIR}"
echo

read -p "Restaurar deste backup? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Restauração cancelada"
  exit 0
fi

echo
print_info "Restaurando certificados..."

# Criar backup de segurança do estado atual
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p /root/cert-before-restore-${TIMESTAMP}
cp -r /etc/pki/tls/certs/* /root/cert-before-restore-${TIMESTAMP}/ 2>/dev/null || true
cp -r /etc/pki/tls/private/* /root/cert-before-restore-${TIMESTAMP}/ 2>/dev/null || true
print_success "Estado atual salvo em backup em /root/cert-before-restore-${TIMESTAMP}/"

# Restaurar certificados
for file in "${BACKUP_DIR}"/*.crt; do
  if [[ -f "${file}" ]]; then
    filename="$(basename "${file}")"
    cp "${file}" "${CERT_DIR}/${filename}"
    print_success "Restaurado ${filename}"
  fi
done

# Restaurar chaves privadas
for file in "${BACKUP_DIR}"/*.key; do
  if [[ -f "${file}" ]]; then
    filename="$(basename "${file}")"
    cp "${file}" "${KEY_DIR}/${filename}"
    chmod 600 "${KEY_DIR}/${filename}"
    print_success "Restaurado ${filename}"
  fi
done

echo
print_success "Restauração concluída"
echo
echo "Reiniciar serviços afetados:"
echo "  systemctl restart httpd"
echo "  systemctl restart nginx"
echo
echo "Se a restauração não funcionou, reverta com:"
echo "  cp /root/cert-before-restore-${TIMESTAMP}/* /etc/pki/tls/certs/"
