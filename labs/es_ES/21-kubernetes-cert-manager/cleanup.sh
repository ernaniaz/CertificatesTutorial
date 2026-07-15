#!/usr/bin/env bash
#=============================================================================
# Lab 21: Limpieza
# Elimina todos los recursos del lab y opcionalmente borra minikube
#
# Uso: ./cleanup.sh
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

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Full cleanup flag
FULL_CLEANUP=false
if [[ "${1:-}" == "--full" ]]; then
  FULL_CLEANUP=true
fi

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

print_header "Lab 21: Limpieza"

# --- Paso 1: Eliminar recursos de Kubernetes ---
print_step "Eliminar recursos de Kubernetes"

if ! command -v kubectl &>/dev/null; then
  print_warning "kubectl no encontrado, omitiendo limpieza de Kubernetes"
else
  print_info "Eliminando aplicación de prueba e Ingress..."
  kubectl delete deployment test-app -n default 2>/dev/null || true
  kubectl delete service test-app -n default 2>/dev/null || true
  kubectl delete ingress test-app-ingress -n default 2>/dev/null || true
  kubectl delete configmap test-app-html -n default 2>/dev/null || true

  print_info "Eliminando certificados..."
  kubectl delete certificate --all -n default 2>/dev/null || true

  print_info "Eliminando secrets de certificados..."
  kubectl delete secret selfsigned-cert-tls -n default 2>/dev/null || true
  kubectl delete secret ca-signed-cert-tls -n default 2>/dev/null || true
  kubectl delete secret test-app-tls -n default 2>/dev/null || true
  kubectl delete secret ca-key-pair -n cert-manager 2>/dev/null || true

  print_info "Eliminando ClusterIssuers..."
  kubectl delete clusterissuer selfsigned-issuer 2>/dev/null || true
  kubectl delete clusterissuer ca-issuer 2>/dev/null || true
  kubectl delete clusterissuer letsencrypt-staging 2>/dev/null || true
  kubectl delete clusterissuer letsencrypt-production 2>/dev/null || true

  print_success "Recursos de Kubernetes limpiados"
  echo

  # --- Paso 2: Desinstalar cert-manager ---
  print_step "Desinstalar cert-manager"

  if kubectl get namespace cert-manager &>/dev/null; then
    print_info "Eliminando namespace cert-manager..."
    kubectl delete namespace cert-manager 2>/dev/null || true

    max_attempts=30
    attempt=0
    while kubectl get namespace cert-manager &>/dev/null && [[ ${attempt} -lt ${max_attempts} ]]; do
      sleep 1
      attempt=$((attempt + 1))
    done
    print_success "cert-manager eliminado"
  else
    print_info "cert-manager ya eliminado"
  fi
  echo
fi

# --- Paso 3: Limpiar archivos locales ---
print_step "Limpiar archivos locales"

if [[ -d "${SCRIPT_DIR}/ca-output" ]]; then
  rm -rf "${SCRIPT_DIR}/ca-output"
  print_success "Directorio ca-output eliminado"
fi

if [[ -f "${SCRIPT_DIR}/letsencrypt-production-template.yaml" ]]; then
  rm -f "${SCRIPT_DIR}/letsencrypt-production-template.yaml"
  print_success "Plantilla Let's Encrypt eliminada"
fi
echo

# --- Paso 4: Detener o eliminar minikube ---
print_step "Detener o eliminar minikube"

if [[ ${FULL_CLEANUP} == true ]]; then
  print_warning "Realizando limpieza COMPLETA — eliminando clúster minikube..."
  if command -v minikube &>/dev/null; then
    minikube delete 2>/dev/null || true
    print_success "Clúster Minikube eliminado"
  else
    print_info "Minikube no instalado"
  fi
else
  print_info "Deteniendo minikube (clúster conservado para reinicio rápido)..."
  if command -v minikube &>/dev/null; then
    if minikube status &>/dev/null; then
      minikube stop
      print_success "Minikube detenido"
    else
      print_info "Minikube ya detenido"
    fi
  else
    print_info "Minikube no instalado"
  fi
fi
echo

# --- Paso 5: Mostrar resumen ---
print_step "Mostrar resumen"

echo
echo "Resumen de limpieza"
echo
if [[ ${FULL_CLEANUP} == true ]]; then
  print_success "Limpieza completa finalizada"
  echo "  - Recursos de Kubernetes eliminados"
  echo "  - cert-manager eliminado"
  echo "  - Archivos locales limpiados"
  echo "  - Clúster Minikube eliminado"
else
  print_success "Limpieza completada"
  echo "  - Recursos de Kubernetes eliminados"
  echo "  - cert-manager eliminado"
  echo "  - Archivos locales limpiados"
  echo "  - Minikube detenido (no eliminado)"
  echo
  print_info "Para eliminar minikube por completo:"
  echo "  ./cleanup.sh --full"
fi
echo

if [[ ${FULL_CLEANUP} == false ]]; then
  echo "Para reiniciar:"
  echo "  minikube start"
  echo "  ./install-cert-manager.sh"
  echo
  echo "Para ejecutar el lab de nuevo:"
  echo "  ./create-selfsigned-issuer.sh"
  echo "  ./create-ca-issuer.sh"
  echo "  ./request-certificate.sh"
fi
