#!/usr/bin/env bash
#=============================================================================
# Lab 11: Solicitar CA local
# Usa certmonger com o helper de CA local
#
# Uso: ./request-local-ca.sh
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

CERT_DIR="/etc/pki/certmonger"
CA_CERT_FILE="${CERT_DIR}/local-ca.crt"
CA_KEY_FILE="${CERT_DIR}/local-ca.key"
CERT_FILE="${CERT_DIR}/local-ca-signed.crt"
KEY_FILE="${CERT_DIR}/local-ca-signed.key"

print_header "Lab 11: Solicitar da CA Local"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

# Criar diretório
mkdir -p "${CERT_DIR}"

# Verificar se a CA do Lab 05 existe
PREV_CA_DIR="../05-trust-store/output"
if [[ -f "${PREV_CA_DIR}/ca.crt" && -f "${PREV_CA_DIR}/ca.key" ]]; then
  print_info "Usando CA do Lab 05..."
  cp "${PREV_CA_DIR}/ca.crt" "${CA_CERT_FILE}"
  cp "${PREV_CA_DIR}/ca.key" "${CA_KEY_FILE}"
  chmod 600 "${CA_KEY_FILE}"
  print_success "Arquivos CA copiados"
else
  # Criar CA local simples se necessário
  print_info "Criando CA local..."
  openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "${CA_KEY_FILE}" \
    -out "${CA_CERT_FILE}" \
    -days 365 \
    -subj "/CN=Lab11 Local CA"
  chmod 600 "${CA_KEY_FILE}"
  print_success "CA local criada"
fi

echo

# Verificar se já foi solicitado
if getcert list -f "${CERT_FILE}" &>/dev/null; then
  print_warning "Certificado já monitorado, interrompendo o monitoramento primeiro..."
  getcert stop-tracking -f "${CERT_FILE}"
fi

# Solicitar certificado usando CA local (autoassinado para fins de laboratório)
print_info "Solicitando certificado da CA local..."

# Nota: Usando CA 'local' que na verdade é autoassinada
# Em produção, você usaria IPA ou CA externa
getcert request \
  -f "${CERT_FILE}" \
  -k "${KEY_FILE}" \
  -c local \
  -N CN=local-ca-server.example.com \
  -D local-ca-server.example.com \
  -D localhost \
  -U id-kp-serverAuth \
  -T 90

print_success "Solicitação de certificado enviada"
echo

# Aguardar emissão do certificado
print_info "Aguardando emissão do certificado..."
sleep 3

# Verificar status
REQUEST_ID="$(getcert list -f "${CERT_FILE}" 2>/dev/null | grep "Request ID" | awk '{print $3}' | tr -d "':")"

if [[ -n "${REQUEST_ID}" ]]; then
  echo "ID da solicitação: ${REQUEST_ID}"

  # Obter status
  STATUS="$(getcert list -i "${REQUEST_ID}" 2>/dev/null | grep "status:" | awk '{print $2}')"
  echo "Status: ${STATUS}"

  if [[ ${STATUS} == MONITORING ]]; then
    print_success "Certificado emitido e monitorado com sucesso"

    # Mostrar expiração
    EXPIRES="$(getcert list -i "${REQUEST_ID}" 2>/dev/null | grep "expires:" | cut -d: -f2-)"
    echo "Expira: ${EXPIRES}"
  else
    print_warning "Status: ${STATUS}"
  fi
fi

echo

# Exibir detalhes do certificado
if [[ -f "${CERT_FILE}" ]]; then
  print_success "Arquivo de certificado criado"
  echo
  echo "Detalhes do certificado:"
  openssl x509 -in "${CERT_FILE}" -noout -subject -issuer -dates 2>/dev/null

  echo
  echo "Locais dos arquivos:"
  echo "  Certificado: ${CERT_FILE}"
  echo "  Chave privada: ${KEY_FILE}"
  echo "  Certificado CA: ${CA_CERT_FILE}"
else
  print_warning "Arquivo de certificado ainda não criado"
fi

echo
print_success "Solicitação de certificado da CA local concluída"
echo
echo "Verificar status com:"
echo "  getcert list"
echo "  getcert list -i ${REQUEST_ID}"
