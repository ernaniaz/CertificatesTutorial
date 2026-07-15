#!/usr/bin/env bash
#=============================================================================
# Lab 21: Instalar cert-manager
# Despliega cert-manager en el clúster de Kubernetes
#
# Uso: ./install-cert-manager.sh
# Requisitos previos: RHEL 8, 9, 10
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

# cert-manager version
readonly CERT_MANAGER_VERSION="v1.14.1"
readonly CERT_MANAGER_URL="https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"

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

print_header "Lab 21: Instalar cert-manager"

# --- Paso 1: Verificar requisitos previos ---
print_step "Verificar requisitos previos"

if ! command -v kubectl &>/dev/null; then
  error_exit "kubectl no encontrado. Ejecute ./install-minikube.sh primero"
fi
if ! kubectl cluster-info &>/dev/null; then
  error_exit "No se puede conectar al clúster de Kubernetes. ¿Está minikube en ejecución?"
fi
if ! minikube status &>/dev/null; then
  error_exit "minikube no está en ejecución. Ejecute ./install-minikube.sh primero"
fi
print_success "Verificación de requisitos previos aprobada"
echo

# --- Paso 2: Instalar cert-manager ---
print_step "Instalar cert-manager"

print_info "Aplicando manifiestos de cert-manager ${CERT_MANAGER_VERSION}..."
kubectl apply -f "${CERT_MANAGER_URL}"
print_success "Manifiestos de cert-manager aplicados"
echo

# --- Paso 3: Esperar pods de cert-manager ---
print_step "Esperar pods de cert-manager"

print_info "Esperando pods de cert-manager (puede tardar 1-2 minutos)..."
kubectl wait --for=condition=Ready --timeout=300s \
  namespace/cert-manager 2>/dev/null || true

for deployment in cert-manager cert-manager-webhook cert-manager-cainjector; do
  print_info "Esperando ${deployment}..."
  kubectl wait --for=condition=Available --timeout=300s \
    -n cert-manager "deployment/${deployment}"
  print_success "${deployment} está listo"
done
echo

# --- Paso 4: Verificar instalación ---
print_step "Verificar instalación de cert-manager"

for crd in certificates.cert-manager.io issuers.cert-manager.io clusterissuers.cert-manager.io; do
  if kubectl get crd "${crd}" &>/dev/null; then
    print_success "CRD encontrado: ${crd}"
  else
    error_exit "CRD no encontrado: ${crd}"
  fi
done

print_info "CRDs de cert-manager instalados:"
kubectl get crds | grep cert-manager || true

pod_count="$(kubectl get pods -n cert-manager --no-headers 2>/dev/null | wc -l)"
if [[ ${pod_count} -ge 3 ]]; then
  print_success "Todos los pods de cert-manager en ejecución (${pod_count} pods)"
else
  error_exit "No hay suficientes pods de cert-manager en ejecución (encontrados ${pod_count}, se esperaban 3+)"
fi
echo

print_success "¡Instalación de cert-manager completada!"

echo
echo "Estado de cert-manager"
echo
kubectl get pods -n cert-manager
echo
kubectl get deployments -n cert-manager

echo
echo "Próximos pasos:"
echo "  - Ejecute './create-selfsigned-issuer.sh' para crear un emisor autofirmado"
echo "  - Ejecute './create-ca-issuer.sh' para crear un emisor CA"
echo "  - Ejecute './create-letsencrypt-issuer.sh' para crear un emisor Let's Encrypt"
