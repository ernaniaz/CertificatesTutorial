#!/usr/bin/env bash
#=============================================================================
# Lab 21: Criar emissor Let's Encrypt
# Cria um ClusterIssuer para certificados ACME do Let's Encrypt
#
# Uso: ./create-letsencrypt-issuer.sh
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

# Default email (can be overridden)
EMAIL="${1:-admin@example.com}"

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

print_header "Lab 21: Criar Emissor Let's Encrypt"

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

# --- Passo 2: Criar ClusterIssuer de staging ---
print_step "Criar ClusterIssuer staging do Let's Encrypt"

print_info "Aplicando emissor de staging (ACME HTTP-01 com classe ingress nginx)..."
print_warning "Usando ambiente STAGING — certificados não são confiáveis pelo navegador"
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ${EMAIL}
    privateKeySecretRef:
      name: letsencrypt-staging-account
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
print_success "Emissor staging Let's Encrypt criado"
echo

# --- Passo 3: Criar template de produção (não aplicado) ---
print_step "Criar template de emissor de produção"

print_info "Salvando modelo de produção — requer um domínio público real para uso seguro..."
cat <<'EOF' > letsencrypt-production-template.yaml
# Emissor de Produção Let's Encrypt (TEMPLATE)
# AVISO: Use somente quando tiver um domínio público válido
# Produção tem limites de taxa rigorosos!
#
# Para aplicar: kubectl apply -f letsencrypt-production-template.yaml

apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-production-account
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
print_success "Template do emissor de produção salvo em letsencrypt-production-template.yaml"
echo

# --- Passo 4: Aguardar emissor de staging ficar pronto ---
print_step "Aguardar emissor de staging ficar pronto"

print_info "Registro de conta ACME pode levar um momento..."
max_attempts=60
attempt=0
while [[ ${attempt} -lt ${max_attempts} ]]; do
  ready="$(kubectl get clusterissuer letsencrypt-staging \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")"
  if [[ "${ready}" == "True" ]]; then
    print_success "Emissor está pronto"
    break
  fi
  attempt=$((attempt + 1))
  sleep 1
done
if [[ "${ready:-}" != "True" ]]; then
  print_warning "A inicialização do emissor ainda pode estar em andamento"
  print_info "Verificar status com: kubectl describe clusterissuer letsencrypt-staging"
fi
echo

print_success "Configuração do emissor Let's Encrypt concluída!"

echo
echo "Status do Emissor Let's Encrypt"
echo
kubectl get clusterissuer letsencrypt-staging
kubectl describe clusterissuer letsencrypt-staging

echo
echo "Informações de Uso do Let's Encrypt"
echo
print_info "Ambiente de staging"
echo "  - Use para testes"
echo "  - Sem limites de taxa"
echo "  - Certificados não confiáveis pelos navegadores"
echo "  - issuerRef.name: letsencrypt-staging"
echo
print_warning "Ambiente de Produção"
echo "  - Requer domínio público válido"
echo "  - Limites de taxa: 50 certificados/semana por domínio"
echo "  - Certificados confiáveis por todos os navegadores"
echo "  - Edite letsencrypt-production-template.yaml antes de aplicar"
echo
print_info "Requisitos do desafio HTTP-01:"
echo "  - Ingress deve ser publicamente acessível"
echo "  - Porta 80 deve estar aberta"
echo "  - O domínio deve resolver para o seu cluster"
echo
print_info "Para teste local:"
echo "  - Use emissor autoassinado ou CA em vez disso"
echo "  - Let's Encrypt requer DNS público"

echo
echo "Próximos passos:"
echo "  - Para testes locais, use emissor autoassinado ou CA"
echo "  - Para produção com domínio válido, edite e aplique o template"
