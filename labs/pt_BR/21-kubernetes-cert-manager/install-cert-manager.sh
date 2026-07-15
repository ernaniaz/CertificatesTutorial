#!/usr/bin/env bash
#=============================================================================
# Lab 21: Instalar cert-manager
# Implanta o cert-manager no cluster do Kubernetes
#
# Uso: ./install-cert-manager.sh
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

# Versão do cert-manager
readonly CERT_MANAGER_VERSION="v1.14.1"
readonly CERT_MANAGER_URL="https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"

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

print_header "Lab 21: Instalar cert-manager"

# --- Passo 1: Verificar pré-requisitos ---
print_step "Verificar pré-requisitos"

if ! command -v kubectl &>/dev/null; then
  error_exit "kubectl não encontrado. Execute ./install-minikube.sh primeiro"
fi
if ! kubectl cluster-info &>/dev/null; then
  error_exit "Não foi possível conectar ao cluster Kubernetes. O minikube está em execução?"
fi
if ! minikube status &>/dev/null; then
  error_exit "minikube não está em execução. Execute ./install-minikube.sh primeiro"
fi
print_success "Verificação de pré-requisitos aprovada"
echo

# --- Passo 2: Instalar cert-manager ---
print_step "Instalar cert-manager"

print_info "Aplicando manifests cert-manager ${CERT_MANAGER_VERSION}..."
kubectl apply -f "${CERT_MANAGER_URL}"
print_success "Manifests cert-manager aplicados"
echo

# --- Passo 3: Aguardar pods do cert-manager ---
print_step "Aguardar pods cert-manager"

print_info "Aguardando pods cert-manager ficarem prontos (pode levar 1-2 minutos)..."
kubectl wait --for=condition=Ready --timeout=300s \
  namespace/cert-manager 2>/dev/null || true

for deployment in cert-manager cert-manager-webhook cert-manager-cainjector; do
  print_info "Aguardando ${deployment}..."
  kubectl wait --for=condition=Available --timeout=300s \
    -n cert-manager "deployment/${deployment}"
  print_success "${deployment} está pronto"
done
echo

# --- Passo 4: Verificar instalação ---
print_step "Verificar instalação cert-manager"

for crd in certificates.cert-manager.io issuers.cert-manager.io clusterissuers.cert-manager.io; do
  if kubectl get crd "${crd}" &>/dev/null; then
    print_success "CRD encontrado: ${crd}"
  else
    error_exit "CRD não encontrado: ${crd}"
  fi
done

print_info "CRDs do cert-manager instalados:"
kubectl get crds | grep cert-manager || true

pod_count="$(kubectl get pods -n cert-manager --no-headers 2>/dev/null | wc -l)"
if [[ ${pod_count} -ge 3 ]]; then
  print_success "Todos os pods cert-manager estão em execução (${pod_count} pods)"
else
  error_exit "Pods cert-manager insuficientes em execução (encontrados ${pod_count}, esperados 3+)"
fi
echo

print_success "Instalação cert-manager concluída!"

echo
echo "Status cert-manager"
echo
kubectl get pods -n cert-manager
echo
kubectl get deployments -n cert-manager

echo
echo "Próximos passos:"
echo "  - Execute './create-selfsigned-issuer.sh' para criar um emissor autoassinado"
echo "  - Execute './create-ca-issuer.sh' para criar um emissor CA"
echo "  - Execute './create-letsencrypt-issuer.sh' para criar um emissor Let's Encrypt"
