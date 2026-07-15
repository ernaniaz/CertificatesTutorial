#!/usr/bin/env bash
#=============================================================================
# Lab 16: Substituição de emergência
# Substituição rápida de certificados para emergências em produção
#
# Uso: ./emergency-replacement.sh
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
CERT_NAME="emergency"

print_header "Lab 16: Substituição Emergencial de Certificado"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

print_warning "PROCEDIMENTO DE EMERGÊNCIA"
echo "Isso cria e implanta um novo certificado imediatamente"
echo

read -p "Continuar com substituição de emergência? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Operação cancelada"
  exit 0
fi

echo

# Passo 1: Fazer backup dos certificados existentes
print_info "Passo 1: Fazendo backup dos certificados existentes..."
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p "/root/cert-backup-${TIMESTAMP}"

if [[ -f "${CERT_DIR}/${CERT_NAME}.crt" ]]; then
  cp "${CERT_DIR}/${CERT_NAME}.crt" "/root/cert-backup-${TIMESTAMP}/"
  print_success "Certificado com backup"
fi

if [[ -f "${KEY_DIR}/${CERT_NAME}.key" ]]; then
  cp "${KEY_DIR}/${CERT_NAME}.key" "/root/cert-backup-${TIMESTAMP}/"
  print_success "Chave privada com backup"
fi

echo "  Local do backup: /root/cert-backup-${TIMESTAMP}/"
echo

# Passo 2: Gerar novo certificado
print_info "Passo 2: Gerando novo certificado..."
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "${KEY_DIR}/${CERT_NAME}.key" \
  -out "${CERT_DIR}/${CERT_NAME}.crt" \
  -days 90 \
  -subj "/CN=$(hostname)" \
  -extensions v3_req \
  -config <(cat /etc/pki/tls/openssl.cnf <(printf "[v3_req]\nsubjectAltName=DNS:$(hostname),DNS:localhost")) 2>/dev/null

chmod 644 "${CERT_DIR}/${CERT_NAME}.crt"
chmod 600 "${KEY_DIR}/${CERT_NAME}.key"

print_success "Novo certificado gerado"
echo

# Passo 3: Verificar novo certificado
print_info "Passo 3: Verificando novo certificado..."
if openssl x509 -in "${CERT_DIR}/${CERT_NAME}.crt" -noout -checkend 0 2>/dev/null; then
  print_success "Certificado é válido"
  openssl x509 -in "${CERT_DIR}/${CERT_NAME}.crt" -noout -subject -dates
else
  print_error "Validação de certificado falhou"
  exit 1
fi

echo

# Passo 4: Instruções para reinicialização do serviço
print_info "Passo 4: Reiniciar serviços afetados"
echo
echo "Serviços que podem precisar de reinicialização:"
echo "  systemctl restart httpd"
echo "  systemctl restart nginx"
echo "  systemctl restart postfix"
echo

print_success "Substituição de emergência concluída"
echo
echo "Certificado: ${CERT_DIR}/${CERT_NAME}.crt"
echo "Chave privada: ${KEY_DIR}/${CERT_NAME}.key"
echo "Backup: /root/cert-backup-${TIMESTAMP}/"
echo
print_warning "IMPORTANTE: Este é um certificado temporário de 90 dias"
echo "Obtenha certificado adequado da CA o mais rápido possível"
