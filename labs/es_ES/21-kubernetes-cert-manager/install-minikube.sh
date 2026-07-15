#!/usr/bin/env bash
#=============================================================================
# Lab 21: Instalar Minikube
# Instala minikube y kubectl para pruebas locales de Kubernetes
#
# Uso: ./install-minikube.sh
# Requisitos previos: RHEL 8, 9, 10, privilegios de root
#=============================================================================

set -e  # Salir en caso de error
set -u  # Salir en variable no definida

#=============================================================================
# CONFIGURACIÓN
#=============================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Versions
readonly MINIKUBE_VERSION="latest"
readonly KUBECTL_VERSION="v1.28.0"

#=============================================================================
# FUNCIONES AUXILIARES
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

trap 'error_exit "Error en la línea ${LINENO}"' ERR

#=============================================================================
# VERIFICACIÓN DE VERSIÓN RHEL
#=============================================================================

if ! grep -q '^ID="rhel"$' /etc/os-release 2>/dev/null; then
  error_exit "Este script requiere Red Hat Enterprise Linux (RHEL)."
fi
readonly RHEL_VERSION="$(grep -oP '^VERSION_ID="\K[0-9]+' /etc/os-release 2>/dev/null)"
if [[ ${RHEL_VERSION} -lt 8 || ${RHEL_VERSION} -gt 10 ]]; then
  error_exit "Versión de RHEL no soportada. Este script requiere RHEL 8, 9 o 10."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

print_header "Lab 21: Instalar Minikube"

# --- Paso 1: Verificar requisitos previos ---
print_step "Verificar requisitos previos"

MINIKUBE_FORCE=""
if [[ ${EUID} -eq 0 ]]; then
  print_warning "Ejecutar como root no es recomendado para minikube."
  print_warning "Los controladores de contenedores (podman/docker) pueden rechazar la ejecución como root."
  echo
  read -p "  ¿Continuar como root con --force? (s/N): " -n 1 -r
  echo
  if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
    echo
    echo "Ejecute este script nuevamente como usuario regular."
    exit 0
  fi
  MINIKUBE_FORCE="--force"
fi
print_success "RHEL ${RHEL_VERSION} detected"
echo

# --- Paso 2: Detectar entorno de contenedores ---
print_step "Detectar entorno de contenedores"

CONTAINER_DRIVER=""
if command -v docker &>/dev/null; then
  print_success "Docker encontrado"
  CONTAINER_DRIVER="docker"
elif command -v podman &>/dev/null; then
  print_success "Podman encontrado"
  CONTAINER_DRIVER="podman"
else
  # minikube necesita un entorno de contenedores para alojar el nodo de Kubernetes
  print_info "No se encontró entorno de contenedores — instalando podman..."
  sudo dnf install -y podman
  print_success "Podman instalado"
  CONTAINER_DRIVER="podman"
fi
echo

# --- Paso 3: Instalar kubectl ---
print_step "Instalar kubectl"

if command -v kubectl &>/dev/null; then
  print_success "kubectl ya instalado: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
  print_info "Descargando kubectl ${KUBECTL_VERSION}..."
  curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
  print_success "kubectl instalado"
fi
echo

# --- Paso 4: Instalar minikube ---
print_step "Instalar minikube"

if command -v minikube &>/dev/null; then
  print_success "minikube ya instalado: $(minikube version --short)"
else
  print_info "Descargando minikube..."
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  chmod +x minikube-linux-amd64
  sudo mv minikube-linux-amd64 /usr/local/bin/minikube
  print_success "minikube instalado"
fi
echo

# --- Paso 5: Iniciar clúster minikube ---
print_step "Iniciar clúster minikube"

if minikube status &>/dev/null; then
  print_success "minikube ya está en ejecución"
else
  print_info "Iniciando minikube con controlador ${CONTAINER_DRIVER}..."
  # El addon ingress habilita pruebas TLS más adelante sin un paso de instalación aparte
  if ! minikube start \
    --driver="${CONTAINER_DRIVER}" \
    --cpus=2 \
    --memory=2048 \
    --kubernetes-version=v1.28.0 \
    --addons=ingress \
    ${MINIKUBE_FORCE}; then
    echo
    print_error "No se pudo iniciar minikube."
    echo
    echo "  Causas comunes:"
    echo "    - CPUs insuficientes: Kubernetes requiere al menos 2 CPUs."
    echo "    - Memoria insuficiente: se necesitan al menos 2 GB de RAM libre."
    echo "    - Runtime de contenedores inactivo: verifique que ${CONTAINER_DRIVER} esté activo."
    echo
    echo "  Para verificar recursos disponibles:"
    echo "    nproc                  # CPUs disponibles"
    echo "    free -h                # memoria disponible"
    echo "    systemctl status ${CONTAINER_DRIVER}  # estado del runtime"
    echo
    echo "  Para reintentar con menos recursos (no recomendado para producción):"
    echo "    minikube start --driver=${CONTAINER_DRIVER} --cpus=2 --memory=1800"
    exit 1
  fi
  print_success "minikube iniciado"
fi
echo

# --- Paso 6: Verificar instalación ---
print_step "Verificar que el clúster esté en ejecución"

if ! minikube status &>/dev/null; then
  error_exit "minikube no está en ejecución"
fi
if ! kubectl cluster-info &>/dev/null; then
  error_exit "kubectl no puede conectar al clúster"
fi
if ! kubectl get nodes &>/dev/null; then
  error_exit "No se pueden obtener los nodos del clúster"
fi
print_success "Todas las verificaciones aprobadas"
echo

print_success "¡Instalación de Minikube completada!"
echo
echo "Información del clúster:"
kubectl cluster-info
echo
echo "Nodos del clúster:"
kubectl get nodes
echo
echo "Próximos pasos:"
echo "  - Ejecute './install-cert-manager.sh' para instalar cert-manager"
echo "  - Use comandos 'kubectl' para interactuar con el clúster"
echo "  - Ejecute 'minikube dashboard' para abrir el panel de Kubernetes"
