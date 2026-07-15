#!/usr/bin/env bash
#=============================================================================
# Lab 21: Verificar
# Valida que todos os componentes do lab estejam configurados corretamente
#
# Uso: ./verify.sh
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

# Counters
PASS=0
FAIL=0

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

print_header "Lab 21: Verificação"

# --- Passo 1: Testar minikube e kubectl ---
print_step "Testar minikube e kubectl"

print_info "Executando testes de validação..."
echo

if minikube status &>/dev/null; then
  print_success "PASS: Minikube está em execução"
  PASS=$((PASS + 1))
else
  print_error "FALHA: Minikube está em execução"
  FAIL=$((FAIL + 1))
fi

if kubectl cluster-info &>/dev/null; then
  print_success "PASS: kubectl está configurado"
  PASS=$((PASS + 1))
else
  print_error "FALHA: kubectl está configurado"
  FAIL=$((FAIL + 1))
fi

# --- Passo 2: Testar pods do cert-manager ---
print_step "Testar pods cert-manager"

if kubectl get namespace cert-manager &>/dev/null; then
  print_success "PASS: Namespace cert-manager existe"
  PASS=$((PASS + 1))
else
  print_error "FALHA: Namespace cert-manager existe"
  FAIL=$((FAIL + 1))
fi

if kubectl get pods -n cert-manager 2>/dev/null | grep -q Running; then
  print_success "PASS: Pods cert-manager estão em execução"
  PASS=$((PASS + 1))
else
  print_error "FALHA: Pods cert-manager estão em execução"
  FAIL=$((FAIL + 1))
fi

for deployment in cert-manager cert-manager-webhook cert-manager-cainjector; do
  if kubectl get deployment "${deployment}" -n cert-manager \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null | grep -q 1; then
    print_success "PASS: ${deployment} está pronto"
    PASS=$((PASS + 1))
  else
    print_error "FALHA: ${deployment} está pronto"
    FAIL=$((FAIL + 1))
  fi
done

for crd in certificates.cert-manager.io issuers.cert-manager.io clusterissuers.cert-manager.io; do
  if kubectl get crd "${crd}" &>/dev/null; then
    print_success "PASS: CRD ${crd} existe"
    PASS=$((PASS + 1))
  else
    print_error "FALHA: CRD ${crd} existe"
    FAIL=$((FAIL + 1))
  fi
done

# --- Passo 3: Testar se emissores existem e estão prontos ---
print_step "Testar emissores"

for issuer in selfsigned-issuer ca-issuer letsencrypt-staging; do
  if kubectl get clusterissuer "${issuer}" &>/dev/null; then
    print_success "PASS: ClusterIssuer ${issuer} existe"
    PASS=$((PASS + 1))
  else
    print_error "FALHA: ClusterIssuer ${issuer} existe"
    FAIL=$((FAIL + 1))
  fi

  if kubectl get clusterissuer "${issuer}" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q True; then
    print_success "PASS: ClusterIssuer ${issuer} está Ready"
    PASS=$((PASS + 1))
  else
    print_error "FALHA: ClusterIssuer ${issuer} está Ready"
    FAIL=$((FAIL + 1))
  fi
done

# --- Passo 4: Testar se certificados existem e estão prontos ---
print_step "Testar certificados"

for cert in selfsigned-cert ca-signed-cert test-app-tls; do
  if kubectl get certificate "${cert}" -n default &>/dev/null; then
    print_success "PASS: Certificado ${cert} existe"
    PASS=$((PASS + 1))
  else
    print_error "FALHA: Certificado ${cert} existe"
    FAIL=$((FAIL + 1))
  fi

  if kubectl get certificate "${cert}" -n default \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q True; then
    print_success "PASS: Certificado ${cert} está Ready"
    PASS=$((PASS + 1))
  else
    print_error "FALHA: Certificado ${cert} está Ready"
    FAIL=$((FAIL + 1))
  fi
done

# --- Passo 5: Testar secrets TLS e recursos ingress ---
print_step "Testar secrets TLS e recursos da aplicação"

for secret in selfsigned-cert-tls ca-signed-cert-tls test-app-tls; do
  if kubectl get secret "${secret}" -n default &>/dev/null; then
    print_success "PASS: Secret TLS ${secret} existe"
    PASS=$((PASS + 1))
  else
    print_error "FALHA: Secret TLS ${secret} existe"
    FAIL=$((FAIL + 1))
  fi
done

if kubectl get deployment test-app -n default &>/dev/null; then
  print_success "PASS: Deployment da aplicação de teste existe"
  PASS=$((PASS + 1))
else
  print_error "FALHA: Deployment da aplicação de teste existe"
  FAIL=$((FAIL + 1))
fi

if kubectl get pods -l app=test-app -n default 2>/dev/null | grep -q Running; then
  print_success "PASS: Pods da aplicação de teste estão em execução"
  PASS=$((PASS + 1))
else
  print_error "FALHA: Pods da aplicação de teste estão em execução"
  FAIL=$((FAIL + 1))
fi

if kubectl get service test-app -n default &>/dev/null; then
  print_success "PASS: Service da aplicação de teste existe"
  PASS=$((PASS + 1))
else
  print_error "FALHA: Serviço da aplicação de teste existe"
  FAIL=$((FAIL + 1))
fi

if kubectl get ingress test-app-ingress -n default &>/dev/null; then
  print_success "PASS: Ingress da aplicação de teste existe"
  PASS=$((PASS + 1))
else
  print_error "FALHA: Ingress da aplicação de teste existe"
  FAIL=$((FAIL + 1))
fi

# --- Passo 6: Exibir resumo aprovado/reprovado ---
print_step "Exibir resumo"

echo
echo "Resumo dos testes"
echo
echo "Aprovados: ${PASS}"
echo "Falhou: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "Todas as validações aprovadas!"
  print_success "Lab 21 concluído com sucesso."
  echo
  echo "Você concluiu com sucesso:"
  echo "  - minikube instalado e configurado"
  echo "  - cert-manager implantado"
  echo "  - Múltiplos emissores de certificados criados"
  echo "  - Certificados solicitados e emitidos"
  echo "  - TLS configurado para Kubernetes Ingress"
  echo
  echo "Próximos passos:"
  echo "  - Prossiga para o Lab 22: HashiCorp Vault PKI"
  echo "  - Experimente diferentes tipos de emissor"
  echo "  - Implante suas próprias aplicações com TLS"
  exit 0
else
  print_error "Algumas validações falharam."
  echo
  echo "Solução de problemas:"
  echo "  - Verifique o status dos pods: kubectl get pods --all-namespaces"
  echo "  - Verifique os logs do cert-manager: kubectl logs -n cert-manager deployment/cert-manager"
  echo "  - Verifique o status do certificado: kubectl describe certificate <name>"
  echo "  - Execute novamente scripts de lab com falha"
  exit 1
fi
