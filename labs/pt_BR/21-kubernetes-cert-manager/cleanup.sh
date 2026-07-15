#!/usr/bin/env bash
#=============================================================================
# Lab 21: Limpeza
# Remove todos os recursos do lab e opcionalmente apaga o minikube
#
# Uso: ./cleanup.sh
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

# Full cleanup flag
FULL_CLEANUP=false
if [[ "${1:-}" == "--full" ]]; then
  FULL_CLEANUP=true
fi

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

print_header "Lab 21: Limpeza"

# --- Passo 1: Excluir recursos Kubernetes ---
print_step "Excluir recursos Kubernetes"

if ! command -v kubectl &>/dev/null; then
  print_warning "kubectl não encontrado, skipping Kubernetes cleanup"
else
  print_info "Removendo aplicação de teste e Ingress..."
  kubectl delete deployment test-app -n default 2>/dev/null || true
  kubectl delete service test-app -n default 2>/dev/null || true
  kubectl delete ingress test-app-ingress -n default 2>/dev/null || true
  kubectl delete configmap test-app-html -n default 2>/dev/null || true

  print_info "Excluindo certificados..."
  kubectl delete certificate --all -n default 2>/dev/null || true

  print_info "Excluindo secrets de certificado..."
  kubectl delete secret selfsigned-cert-tls -n default 2>/dev/null || true
  kubectl delete secret ca-signed-cert-tls -n default 2>/dev/null || true
  kubectl delete secret test-app-tls -n default 2>/dev/null || true
  kubectl delete secret ca-key-pair -n cert-manager 2>/dev/null || true

  print_info "Excluindo ClusterIssuers..."
  kubectl delete clusterissuer selfsigned-issuer 2>/dev/null || true
  kubectl delete clusterissuer ca-issuer 2>/dev/null || true
  kubectl delete clusterissuer letsencrypt-staging 2>/dev/null || true
  kubectl delete clusterissuer letsencrypt-production 2>/dev/null || true

  print_success "Recursos Kubernetes removidos"
  echo

  # --- Passo 2: Desinstalar cert-manager ---
  print_step "Desinstalar cert-manager"

  if kubectl get namespace cert-manager &>/dev/null; then
    print_info "Excluindo namespace cert-manager..."
    kubectl delete namespace cert-manager 2>/dev/null || true

    max_attempts=30
    attempt=0
    while kubectl get namespace cert-manager &>/dev/null && [[ ${attempt} -lt ${max_attempts} ]]; do
      sleep 1
      attempt=$((attempt + 1))
    done
    print_success "cert-manager removido"
  else
    print_info "cert-manager já removido"
  fi
  echo
fi

# --- Passo 3: Limpar arquivos locais ---
print_step "Limpar arquivos locais"

if [[ -d "${SCRIPT_DIR}/ca-output" ]]; then
  rm -rf "${SCRIPT_DIR}/ca-output"
  print_success "Diretório ca-output removido"
fi

if [[ -f "${SCRIPT_DIR}/letsencrypt-production-template.yaml" ]]; then
  rm -f "${SCRIPT_DIR}/letsencrypt-production-template.yaml"
  print_success "Modelo Let's Encrypt removido"
fi
echo

# --- Passo 4: Parar ou excluir minikube ---
print_step "Parar ou excluir minikube"

if [[ ${FULL_CLEANUP} == true ]]; then
  print_warning "Executando limpeza COMPLETA — excluindo cluster minikube..."
  if command -v minikube &>/dev/null; then
    minikube delete 2>/dev/null || true
    print_success "Cluster Minikube excluído"
  else
    print_info "Minikube não instalado"
  fi
else
  print_info "Parando minikube (cluster preservado para reinício rápido)..."
  if command -v minikube &>/dev/null; then
    if minikube status &>/dev/null; then
      minikube stop
      print_success "Minikube parado"
    else
      print_info "Minikube já parado"
    fi
  else
    print_info "Minikube não instalado"
  fi
fi
echo

# --- Passo 5: Exibir resumo ---
print_step "Exibir resumo"

echo
echo "Resumo da limpeza"
echo
if [[ ${FULL_CLEANUP} == true ]]; then
  print_success "Limpeza completa concluída"
  echo "  - Recursos Kubernetes excluídos"
  echo "  - cert-manager removido"
  echo "  - Arquivos locais limpos"
  echo "  - Cluster minikube excluído"
else
  print_success "Limpeza concluída"
  echo "  - Recursos Kubernetes excluídos"
  echo "  - cert-manager removido"
  echo "  - Arquivos locais limpos"
  echo "  - minikube parado (não excluído)"
  echo
  print_info "Para remover minikube completamente:"
  echo "  ./cleanup.sh --full"
fi
echo

if [[ ${FULL_CLEANUP} == false ]]; then
  echo "Para reiniciar:"
  echo "  minikube start"
  echo "  ./install-cert-manager.sh"
  echo
  echo "Para executar o laboratório novamente:"
  echo "  ./create-selfsigned-issuer.sh"
  echo "  ./create-ca-issuer.sh"
  echo "  ./request-certificate.sh"
fi
