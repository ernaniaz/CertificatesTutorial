#!/usr/bin/env bash
#=============================================================================
# Lab 18: Backup de certificados
# Backup integral de certificados antes da migração RHEL 8 para 9
#
# Uso: ./backup-certificates.sh
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

BACKUP_DIR="/root/rhel8-cert-backup-$(date +%Y%m%d-%H%M%S)"

print_header "Lab 18: Backup de Certificados (RHEL 8)"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

print_info "Criando diretório de backup..."
mkdir -p "${BACKUP_DIR}"/{pki,configs,crypto-policies}
echo " ${BACKUP_DIR}"
echo

# Fazer backup do diretório PKI
print_info "Fazendo backup de /etc/pki/..."
cp -a /etc/pki "${BACKUP_DIR}/pki/"
print_success "Diretório PKI com backup"
echo

# Backup das configurações de serviço
print_info "Fazendo backup das configurações de serviços..."

if [[ -d /etc/httpd ]]; then
  cp -a /etc/httpd "${BACKUP_DIR}/configs/"
  echo "  ✓ Configurações Apache"
fi

if [[ -d /etc/nginx ]]; then
  cp -a /etc/nginx "${BACKUP_DIR}/configs/"
  echo "  ✓ Configurações NGINX"
fi

if [[ -d /etc/postfix ]]; then
  cp -a /etc/postfix "${BACKUP_DIR}/configs/"
  echo "  ✓ Configurações Postfix"
fi

if [[ -d /etc/openldap ]]; then
  cp -a /etc/openldap "${BACKUP_DIR}/configs/"
  echo "  ✓ Configurações OpenLDAP"
fi

echo

# Backup das crypto-policies (específico do RHEL 8, relevante para migração ao RHEL 9)
print_info "Fazendo backup das crypto-policies..."
CURRENT_POLICY="$(update-crypto-policies --show 2>/dev/null || echo 'desconhecido')"
echo "${CURRENT_POLICY}" > "${BACKUP_DIR}/crypto-policies/current-policy.txt"

if [[ -d /etc/crypto-policies ]]; then
  cp -a /etc/crypto-policies "${BACKUP_DIR}/crypto-policies/"
  print_success "Crypto-policies com backup (atual: ${CURRENT_POLICY})"
else
  print_warning "Diretório /etc/crypto-policies não encontrado"
fi
echo

# Criar inventário
print_info "Criando inventário de certificados..."
cat > "${BACKUP_DIR}/inventory.txt" << EOF
Backup de Certificados RHEL 8
Data: $(date)
Hostname: $(hostname)
OpenSSL: $(openssl version)
Crypto-Policy: ${CURRENT_POLICY}

Arquivos de certificado:
EOF

find /etc/pki/tls/certs -name "*.crt" -o -name "*.pem" 2>/dev/null | while read cert; do
  if [[ -f "${cert}" ]]; then
    echo "  ${cert}" >> "${BACKUP_DIR}/inventory.txt"
    if openssl x509 -in "${cert}" -noout -text 2>/dev/null >/dev/null; then
      openssl x509 -in "${cert}" -noout -subject -dates >> "${BACKUP_DIR}/inventory.txt" 2>/dev/null || true
    fi
    echo >> "${BACKUP_DIR}/inventory.txt"
  fi
done

print_success "Inventário criado"
echo

# Criar tarball
print_info "Criando arquivo compactado..."
tar czf "${BACKUP_DIR}.tar.gz" -C "$(dirname "${BACKUP_DIR}")" "$(basename "${BACKUP_DIR}")"
print_success "Arquivo criado"
echo

print_success "Backup concluído"
echo
echo "Local do backup: ${BACKUP_DIR}"
echo "Arquivo: ${BACKUP_DIR}.tar.gz"
echo
echo "Tamanho do backup:"
du -sh "${BACKUP_DIR}"
du -sh "${BACKUP_DIR}.tar.gz"
echo
print_info "Armazene o arquivo de backup em local seguro antes da migração!"
