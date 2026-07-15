#!/usr/bin/env bash
#=============================================================================
# Lab 21: Verificar
# Valida que todos los componentes del lab estén configurados correctamente
#
# Uso: ./verify.sh
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

# Counters
PASS=0
FAIL=0

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

print_header "Lab 21: Verificación"

# --- Paso 1: Probar minikube y kubectl ---
print_step "Probar minikube y kubectl"

print_info "Ejecutando pruebas de validación..."
echo

if minikube status &>/dev/null; then
  print_success "APROBADO: Minikube en ejecución"
  PASS=$((PASS + 1))
else
  print_error "FALLÓ: Minikube en ejecución"
  FAIL=$((FAIL + 1))
fi

if kubectl cluster-info &>/dev/null; then
  print_success "APROBADO: kubectl configurado"
  PASS=$((PASS + 1))
else
  print_error "FALLÓ: kubectl configurado"
  FAIL=$((FAIL + 1))
fi

# --- Paso 2: Probar pods de cert-manager ---
print_step "Probar pods de cert-manager"

if kubectl get namespace cert-manager &>/dev/null; then
  print_success "APROBADO: namespace cert-manager existe"
  PASS=$((PASS + 1))
else
  print_error "FALLÓ: namespace cert-manager existe"
  FAIL=$((FAIL + 1))
fi

if kubectl get pods -n cert-manager 2>/dev/null | grep -q Running; then
  print_success "APROBADO: pods de cert-manager en ejecución"
  PASS=$((PASS + 1))
else
  print_error "FALLÓ: pods de cert-manager en ejecución"
  FAIL=$((FAIL + 1))
fi

for deployment in cert-manager cert-manager-webhook cert-manager-cainjector; do
  if kubectl get deployment "${deployment}" -n cert-manager \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null | grep -q 1; then
    print_success "APROBADO: ${deployment} listo"
    PASS=$((PASS + 1))
  else
    print_error "FALLÓ: ${deployment} listo"
    FAIL=$((FAIL + 1))
  fi
done

for crd in certificates.cert-manager.io issuers.cert-manager.io clusterissuers.cert-manager.io; do
  if kubectl get crd "${crd}" &>/dev/null; then
    print_success "APROBADO: CRD ${crd} existe"
    PASS=$((PASS + 1))
  else
    print_error "FALLÓ: CRD ${crd} existe"
    FAIL=$((FAIL + 1))
  fi
done

# --- Paso 3: Probar que los emisores existen y estén listos ---
print_step "Probar emisores"

for issuer in selfsigned-issuer ca-issuer letsencrypt-staging; do
  if kubectl get clusterissuer "${issuer}" &>/dev/null; then
    print_success "APROBADO: ClusterIssuer ${issuer} existe"
    PASS=$((PASS + 1))
  else
    print_error "FALLÓ: ClusterIssuer ${issuer} existe"
    FAIL=$((FAIL + 1))
  fi

  if kubectl get clusterissuer "${issuer}" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q True; then
    print_success "APROBADO: ClusterIssuer ${issuer} está Ready"
    PASS=$((PASS + 1))
  else
    print_error "FALLÓ: ClusterIssuer ${issuer} está Ready"
    FAIL=$((FAIL + 1))
  fi
done

# --- Paso 4: Probar que los certificados existen y estén listos ---
print_step "Probar certificados"

for cert in selfsigned-cert ca-signed-cert test-app-tls; do
  if kubectl get certificate "${cert}" -n default &>/dev/null; then
    print_success "APROBADO: Certificate ${cert} existe"
    PASS=$((PASS + 1))
  else
    print_error "FALLÓ: Certificate ${cert} existe"
    FAIL=$((FAIL + 1))
  fi

  if kubectl get certificate "${cert}" -n default \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q True; then
    print_success "APROBADO: Certificate ${cert} está Ready"
    PASS=$((PASS + 1))
  else
    print_error "FALLÓ: Certificate ${cert} está Ready"
    FAIL=$((FAIL + 1))
  fi
done

# --- Paso 5: Probar secrets TLS y recursos Ingress ---
print_step "Probar secrets TLS y recursos de aplicación"

for secret in selfsigned-cert-tls ca-signed-cert-tls test-app-tls; do
  if kubectl get secret "${secret}" -n default &>/dev/null; then
    print_success "APROBADO: secret TLS ${secret} existe"
    PASS=$((PASS + 1))
  else
    print_error "FALLÓ: secret TLS ${secret} existe"
    FAIL=$((FAIL + 1))
  fi
done

if kubectl get deployment test-app -n default &>/dev/null; then
  print_success "APROBADO: deployment de aplicación de prueba existe"
  PASS=$((PASS + 1))
else
  print_error "FALLÓ: deployment de aplicación de prueba existe"
  FAIL=$((FAIL + 1))
fi

if kubectl get pods -l app=test-app -n default 2>/dev/null | grep -q Running; then
  print_success "APROBADO: pods de aplicación de prueba en ejecución"
  PASS=$((PASS + 1))
else
  print_error "FALLÓ: pods de aplicación de prueba en ejecución"
  FAIL=$((FAIL + 1))
fi

if kubectl get service test-app -n default &>/dev/null; then
  print_success "APROBADO: servicio de aplicación de prueba existe"
  PASS=$((PASS + 1))
else
  print_error "FALLÓ: servicio de aplicación de prueba existe"
  FAIL=$((FAIL + 1))
fi

if kubectl get ingress test-app-ingress -n default &>/dev/null; then
  print_success "APROBADO: Ingress de aplicación de prueba existe"
  PASS=$((PASS + 1))
else
  print_error "FALLÓ: Ingress de aplicación de prueba existe"
  FAIL=$((FAIL + 1))
fi

# --- Paso 6: Mostrar resumen de aprobados/fallidos ---
print_step "Mostrar resumen"

echo
echo "Resumen de pruebas"
echo
echo "Aprobados: ${PASS}"
echo "Fallidos: ${FAIL}"
echo

if [[ ${FAIL} -eq 0 ]]; then
  print_success "¡Todas las validaciones pasaron!"
  print_success "Lab 21 completado exitosamente."
  echo
  echo "Ha completado exitosamente:"
  echo "  - Instaló y configuró minikube"
  echo "  - Desplegó cert-manager"
  echo "  - Creó múltiples emisores de certificados"
  echo "  - Solicitó y emitió certificados"
  echo "  - Configuró TLS para Kubernetes Ingress"
  echo
  echo "Próximos pasos:"
  echo "  - Continúe con Lab 22: HashiCorp Vault PKI"
  echo "  - Experimente con distintos tipos de emisores"
  echo "  - Despliegue sus propias aplicaciones con TLS"
  exit 0
else
  print_error "Algunas validaciones fallaron."
  echo
  echo "Solución de problemas:"
  echo "  - Verifique estado de pods: kubectl get pods --all-namespaces"
  echo "  - Verifique registros de cert-manager: kubectl logs -n cert-manager deployment/cert-manager"
  echo "  - Verifique estado del certificado: kubectl describe certificate <name>"
  echo "  - Vuelva a ejecutar los scripts del lab que fallaron"
  exit 1
fi
