#!/usr/bin/env bash
#=============================================================================
# Lab 21: Criar emissor CA
# Cria um ClusterIssuer usando um certificado CA personalizado
#
# Uso: ./create-ca-issuer.sh
# Pré-requisitos: RHEL 8, 9, 10
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

# Diretório do script
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly OUTPUT_DIR="${SCRIPT_DIR}/ca-output"

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
if [[ ${RHEL_VERSION} -lt 8 || ${RHEL_VERSION} -gt 10 ]]; then
  error_exit "Versão do RHEL não suportada. Este script requer RHEL 8, 9 ou 10."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

print_header "Lab 21: Criar Emissor CA"

# --- Passo 1: Verificar pré-requisitos ---
print_step "Verificar pré-requisitos"

if ! command -v kubectl &>/dev/null; then
  error_exit "kubectl não encontrado"
fi
if ! command -v openssl &>/dev/null; then
  error_exit "openssl not found"
fi
if ! kubectl get namespace cert-manager &>/dev/null; then
  error_exit "cert-manager não instalado. Execute ./install-cert-manager.sh primeiro"
fi
print_success "Verificação de pré-requisitos aprovada"
echo

# --- Passo 2: Gerar certificado e chave CA ---
print_step "Gerar certificado e chave CA"

print_info "Criando CA personalizada em ${OUTPUT_DIR}..."
mkdir -p "${OUTPUT_DIR}"

# Chave de 4096 bits corresponde a políticas CA empresariais comuns para realismo do lab
openssl genrsa -out "${OUTPUT_DIR}/ca.key" 4096
openssl req -x509 -new -nodes \
  -key "${OUTPUT_DIR}/ca.key" \
  -sha256 -days 3650 \
  -out "${OUTPUT_DIR}/ca.crt" \
  -subj "/C=US/ST=State/L=City/O=Lab Organization/CN=Lab CA"
print_success "Certificado CA criado"
echo

# --- Passo 3: Armazenar credenciais CA em um secret Kubernetes ---
print_step "Criar secret Kubernetes com CA"

print_info "Armazenando cert/chave CA no secret ca-key-pair..."
kubectl delete secret ca-key-pair -n cert-manager 2>/dev/null || true
kubectl create secret tls ca-key-pair \
  -n cert-manager \
  --cert="${OUTPUT_DIR}/ca.crt" \
  --key="${OUTPUT_DIR}/ca.key"
print_success "Secret CA criado"
echo

# --- Passo 4: Criar ClusterIssuer CA ---
print_step "Criar CA ClusterIssuer"

print_info "Aplicando ClusterIssuer referenciando secret ca-key-pair..."
cat <<'EOF' | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: ca-key-pair
EOF
print_success "CA ClusterIssuer criado"
echo

# --- Passo 5: Aguardar emissor ficar pronto ---
print_step "Aguardar emissor ficar pronto"

max_attempts=30
attempt=0
while [[ ${attempt} -lt ${max_attempts} ]]; do
  ready="$(kubectl get clusterissuer ca-issuer \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")"
  if [[ "${ready}" == "True" ]]; then
    print_success "Emissor está pronto"
    break
  fi
  attempt=$((attempt + 1))
  sleep 1
done
if [[ "${ready:-}" != "True" ]]; then
  print_warning "O emissor ainda pode estar inicializando"
fi
echo

print_success "Configuração do emissor CA concluída!"

echo
echo "Informações do certificado CA"
echo
openssl x509 -in "${OUTPUT_DIR}/ca.crt" -noout -text | grep -A2 "Subject:"
openssl x509 -in "${OUTPUT_DIR}/ca.crt" -noout -text | grep -A2 "Validity"
echo
echo "Status do emissor CA"
echo
kubectl get clusterissuer ca-issuer
kubectl describe clusterissuer ca-issuer

echo
echo "Uso:"
echo "  Referencie este emissor em recursos Certificate:"
echo "  issuerRef:"
echo "    name: ca-issuer"
echo "    kind: ClusterIssuer"
echo
echo "Próximos passos:"
echo "  - Execute './request-certificate.sh' para solicitar um certificado assinado por CA"
