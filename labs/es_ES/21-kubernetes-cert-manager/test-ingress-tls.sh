#!/usr/bin/env bash
#=============================================================================
# Lab 21: Probar TLS de Ingress
# Despliega una aplicación de prueba con Ingress habilitado para TLS
#
# Uso: ./test-ingress-tls.sh
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

print_header "Lab 21: Probar Ingress TLS"

# --- Paso 1: Verificar requisitos previos ---
print_step "Verificar requisitos previos"

if ! command -v kubectl &>/dev/null; then
  error_exit "kubectl no encontrado"
fi
if ! kubectl get namespace cert-manager &>/dev/null; then
  error_exit "cert-manager no instalado"
fi
if ! kubectl get clusterissuer selfsigned-issuer &>/dev/null; then
  error_exit "selfsigned-issuer no encontrado. Ejecute ./create-selfsigned-issuer.sh primero"
fi
print_success "cert-manager y emisores disponibles"
echo

# --- Paso 2: Habilitar addon ingress de minikube ---
print_step "Habilitar controlador Ingress"

if command -v minikube &>/dev/null; then
  if ! minikube addons list 2>/dev/null | grep -q "ingress.*enabled"; then
    print_info "Habilitando addon ingress de minikube para HTTP-01 y enrutamiento TLS..."
    minikube addons enable ingress
    print_success "Addon Ingress habilitado"
  else
    print_success "Addon Ingress ya habilitado"
  fi
else
  print_warning "minikube no encontrado — se asume que ya hay un controlador Ingress instalado"
fi
echo

# --- Paso 3: Desplegar aplicación de prueba ---
print_step "Desplegar aplicación de prueba"

print_info "Creando deployment nginx con página HTML personalizada..."
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: test-app-html
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-app-html
  namespace: default
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>cert-manager Test App</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                max-width: 800px;
                margin: 50px auto;
                padding: 20px;
                background: #f5f5f5;
            }
            .container {
                background: white;
                padding: 30px;
                border-radius: 10px;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            }
            h1 { color: #2c3e50; }
            .success { color: #27ae60; font-size: 1.2em; }
            .info { color: #3498db; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>Aplicación de Prueba cert-manager</h1>
            <p class="success">¡Certificado TLS desplegado exitosamente!</p>
            <p class="info">Esta página se sirve con un certificado emitido por cert-manager.</p>
            <h2>Lab 21 Exitoso</h2>
            <ul>
                <li>Clúster Kubernetes en ejecución</li>
                <li>cert-manager desplegado</li>
                <li>Emisión automática de certificados funcionando</li>
                <li>Ingress TLS configurado</li>
            </ul>
        </div>
    </body>
    </html>
EOF
print_success "Aplicación de prueba desplegada"
echo

# --- Paso 4: Crear servicio ClusterIP ---
print_step "Crear servicio"

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: test-app
  namespace: default
spec:
  selector:
    app: test-app
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
EOF
print_success "Servicio creado"
echo

# --- Paso 6: Crear Ingress con TLS ---
print_step "Crear Ingress con TLS"

print_info "La anotación Ingress indica a cert-manager qué emisor usar..."
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-app-ingress
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: "selfsigned-issuer"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - test-app.local
    secretName: test-app-tls
  rules:
  - host: test-app.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: test-app
            port:
              number: 80
EOF
print_success "Ingress creado con TLS"
echo

# --- Paso 6: Esperar a que se emita el certificado ---
print_step "Esperar a que se emita el certificado"

print_info "cert-manager crea un recurso Certificate automáticamente desde el bloque TLS del Ingress..."
max_attempts=120
attempt=0
while [[ ${attempt} -lt ${max_attempts} ]]; do
  if kubectl get certificate test-app-tls -n default &>/dev/null; then
    ready="$(kubectl get certificate test-app-tls -n default \
      -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")"
    if [[ "${ready}" == "True" ]]; then
      print_success "Certificado listo"
      break
    fi
  fi
  attempt=$((attempt + 1))
  sleep 1
done
if [[ "${ready:-}" != "True" ]]; then
  print_warning "El certificado puede seguir emitiéndose"
fi
echo

# --- Paso 7: Esperar a que los pods estén listos ---
print_step "Esperar a que los pods estén listos"

kubectl wait --for=condition=Ready --timeout=60s pod -l app=test-app -n default || true
print_success "Pods listos"
echo

print_success "¡Despliegue de aplicación completado!"

echo
echo "Recursos desplegados"
echo
echo "Deployments:"
kubectl get deployments -n default | grep test-app
echo
echo "Services:"
kubectl get services -n default | grep test-app
echo
echo "Ingress:"
kubectl get ingress -n default
echo
echo "Certificates:"
kubectl get certificates -n default | grep -E "NAME|test-app"
echo
echo "Secrets:"
kubectl get secrets -n default | grep -E "NAME|test-app-tls"

echo
echo "Detalles del certificado"
echo
if kubectl get secret test-app-tls -n default &>/dev/null; then
  print_success "Secret TLS existe"
  kubectl get secret test-app-tls -n default \
    -o jsonpath='{.data.tls\.crt}' | base64 -d \
    | openssl x509 -noout -text | grep -A2 "Subject:\|Issuer:\|Validity\|DNS:"
else
  print_warning "Secret TLS aún no creado"
fi

minikube_ip="$(minikube ip 2>/dev/null || echo "N/A")"
echo
echo "Información de acceso"
echo
print_info "Host de aplicación: test-app.local"
print_info "IP de Minikube: ${minikube_ip}"
echo
print_info "Para acceder a la aplicación:"
echo
echo "1. Agregar a /etc/hosts:"
echo "   echo \"${minikube_ip} test-app.local\" | sudo tee -a /etc/hosts"
echo
echo "2. Acceder vía HTTPS:"
echo "   curl -k https://test-app.local"
echo
echo "3. O use minikube tunnel (requiere sudo):"
echo "   minikube tunnel"
echo "   curl -k https://test-app.local"
echo
print_warning "Nota: el certificado es autofirmado, use la opción -k con curl"

echo
echo "Próximos pasos:"
echo "  - Ejecute './verify.sh' para validar todo el lab"
echo "  - Acceda a la aplicación usando las instrucciones anteriores"
echo "  - Inspeccione certificado: kubectl describe certificate test-app-tls"
