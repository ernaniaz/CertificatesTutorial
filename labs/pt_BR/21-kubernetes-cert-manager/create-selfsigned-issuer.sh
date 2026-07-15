#!/usr/bin/env bash
#=============================================================================
# Lab 21: Criar emissor autoassinado
# Cria um ClusterIssuer para certificados autoassinados
#
# Uso: ./create-selfsigned-issuer.sh
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

print_header "Lab 21: Criar Emissor Autoassinado"

# --- Passo 1: Verificar pré-requisitos ---
print_step "Verificar pré-requisitos"

if ! command -v kubectl &>/dev/null; then
  error_exit "kubectl não encontrado"
fi
if ! kubectl get namespace cert-manager &>/dev/null; then
  error_exit "cert-manager não instalado. Execute ./install-cert-manager.sh primeiro"
fi
print_success "Verificação de pré-requisitos aprovada"
echo

# --- Passo 2: Criar ClusterIssuer autoassinado ---
print_step "Criar ClusterIssuer autoassinado"

print_info "Aplicando ClusterIssuer com spec.selfSigned..."
# Emissores selfSigned não precisam de CA externa — ideal para testes locais de laboratório
cat <<'EOF' | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF
print_success "ClusterIssuer autoassinado criado"
echo

# --- Passo 3: Aguardar emissor ficar pronto ---
print_step "Aguardar emissor ficar pronto"

max_attempts=30
attempt=0
while [[ ${attempt} -lt ${max_attempts} ]]; do
  ready="$(kubectl get clusterissuer selfsigned-issuer \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")"
  if [[ "${ready}" == "True" ]]; then
    print_success "Emissor está pronto"
    break
  fi
  attempt=$((attempt + 1))
  sleep 1
done
if [[ "${ready:-}" != "True" ]]; then
  print_warning "Status do emissor incerto, mas isso é normal para emissores autoassinados"
fi
echo

print_success "Configuração do emissor autoassinado concluída!"

echo
echo "Status do emissor autoassinado"
echo
kubectl get clusterissuer
kubectl describe clusterissuer selfsigned-issuer

echo
echo "Uso:"
echo "  Referencie este emissor em recursos Certificate:"
echo "  issuerRef:"
echo "    name: selfsigned-issuer"
echo "    kind: ClusterIssuer"
echo
echo "Próximos passos:"
echo "  - Execute './request-certificate.sh' para solicitar um certificado autoassinado"
