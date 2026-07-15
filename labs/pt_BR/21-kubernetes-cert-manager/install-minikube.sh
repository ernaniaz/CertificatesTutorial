#!/usr/bin/env bash
#=============================================================================
# Lab 21: Instalar minikube
# Instala minikube e kubectl para testes locais de Kubernetes
#
# Uso: ./install-minikube.sh
# Pré-requisitos: RHEL 8, 9, 10, privilégios de root
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

# Versions
readonly MINIKUBE_VERSION="latest"
readonly KUBECTL_VERSION="v1.28.0"

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

print_header "Lab 21: Instalar Minikube"

# --- Passo 1: Verificar pré-requisitos ---
print_step "Verificar pré-requisitos"

MINIKUBE_FORCE=""
if [[ ${EUID} -eq 0 ]]; then
  print_warning "Executar como root não é recomendado para o minikube."
  print_warning "Drivers de container (podman/docker) podem recusar execução como root."
  echo
  read -p "  Continuar como root com --force? (s/N): " -n 1 -r
  echo
  if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
    echo
    echo "Execute este script novamente como usuário regular."
    exit 0
  fi
  MINIKUBE_FORCE="--force"
fi
print_success "RHEL ${RHEL_VERSION} detectado"
echo

# --- Passo 2: Detectar runtime de contêiner ---
print_step "Detectar runtime de container"

CONTAINER_DRIVER=""
if command -v docker &>/dev/null; then
  print_success "Docker encontrado"
  CONTAINER_DRIVER="docker"
elif command -v podman &>/dev/null; then
  print_success "Podman encontrado"
  CONTAINER_DRIVER="podman"
else
  # minikube precisa de runtime de container para hospedar o nó Kubernetes
  print_info "Nenhum runtime de container encontrado — instalando podman..."
  sudo dnf install -y podman
  print_success "Podman instalado"
  CONTAINER_DRIVER="podman"
fi
echo

# --- Passo 3: Instalar kubectl ---
print_step "Instalar kubectl"

if command -v kubectl &>/dev/null; then
  print_success "kubectl já instalado: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
  print_info "Baixando kubectl ${KUBECTL_VERSION}..."
  curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
  print_success "kubectl instalado"
fi
echo

# --- Passo 4: Instalar minikube ---
print_step "Instalar minikube"

if command -v minikube &>/dev/null; then
  print_success "minikube já instalado: $(minikube version --short)"
else
  print_info "Baixando minikube..."
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  chmod +x minikube-linux-amd64
  sudo mv minikube-linux-amd64 /usr/local/bin/minikube
  print_success "minikube instalado"
fi
echo

# --- Passo 5: Iniciar cluster minikube ---
print_step "Iniciar cluster minikube"

if minikube status &>/dev/null; then
  print_success "minikube já está em execução"
else
  print_info "Iniciando minikube com driver ${CONTAINER_DRIVER}..."
  # addon ingress habilita testes TLS posteriormente sem etapa de instalação separada
  if ! minikube start \
    --driver="${CONTAINER_DRIVER}" \
    --cpus=2 \
    --memory=2048 \
    --kubernetes-version=v1.28.0 \
    --addons=ingress \
    ${MINIKUBE_FORCE}; then
    echo
    print_error "Falha ao iniciar o minikube."
    echo
    echo "  Causas comuns:"
    echo "    - CPUs insuficientes: Kubernetes requer pelo menos 2 CPUs."
    echo "    - Memória insuficiente: pelo menos 2 GB de RAM livre é necessário."
    echo "    - Runtime de container inativo: verifique se ${CONTAINER_DRIVER} está ativo."
    echo
    echo "  Para verificar recursos disponíveis:"
    echo "    nproc                  # CPUs disponíveis"
    echo "    free -h                # memória disponível"
    echo "    systemctl status ${CONTAINER_DRIVER}  # status do runtime"
    echo
    echo "  Para tentar com menos recursos (não recomendado para produção):"
    echo "    minikube start --driver=${CONTAINER_DRIVER} --cpus=2 --memory=1800"
    exit 1
  fi
  print_success "minikube iniciado"
fi
echo

# --- Passo 6: Verificar instalação ---
print_step "Verificar se cluster está em execução"

if ! minikube status &>/dev/null; then
  error_exit "minikube não está em execução"
fi
if ! kubectl cluster-info &>/dev/null; then
  error_exit "kubectl não consegue conectar ao cluster"
fi
if ! kubectl get nodes &>/dev/null; then
  error_exit "Não foi possível obter os nós do cluster"
fi
print_success "Todas as verificações aprovadas"
echo

print_success "Instalação do Minikube concluída!"
echo
echo "Informações do cluster:"
kubectl cluster-info
echo
echo "Nós do cluster:"
kubectl get nodes
echo
echo "Próximos passos:"
echo "  - Execute './install-cert-manager.sh' para instalar cert-manager"
echo "  - Use comandos 'kubectl' para interagir com o cluster"
echo "  - Execute 'minikube dashboard' para abrir o dashboard Kubernetes"
