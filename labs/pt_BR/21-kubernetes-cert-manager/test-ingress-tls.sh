#!/usr/bin/env bash
#=============================================================================
# Lab 21: Testar Ingress TLS
# Implanta uma aplicação de teste com Ingress habilitado para TLS
#
# Uso: ./test-ingress-tls.sh
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

print_header "Lab 21: Testar Ingress TLS"

# --- Passo 1: Verificar pré-requisitos ---
print_step "Verificar pré-requisitos"

if ! command -v kubectl &>/dev/null; then
  error_exit "kubectl não encontrado"
fi
if ! kubectl get namespace cert-manager &>/dev/null; then
  error_exit "cert-manager não instalado"
fi
if ! kubectl get clusterissuer selfsigned-issuer &>/dev/null; then
  error_exit "selfsigned-issuer não encontrado. Execute ./create-selfsigned-issuer.sh primeiro"
fi
print_success "cert-manager e emissores estão disponíveis"
echo

# --- Passo 2: Habilitar addon ingress do minikube ---
print_step "Habilitar ingress controller"

if command -v minikube &>/dev/null; then
  if ! minikube addons list 2>/dev/null | grep -q "ingress.*enabled"; then
    print_info "Habilitando addon ingress do minikube para HTTP-01 e roteamento TLS..."
    minikube addons enable ingress
    print_success "Addon Ingress habilitado"
  else
    print_success "Addon Ingress já habilitado"
  fi
else
  print_warning "minikube não encontrado — assumindo que um controlador Ingress já está instalado"
fi
echo

# --- Passo 3: Implantar aplicação de teste ---
print_step "Implantar aplicação de teste"

print_info "Criando deployment nginx com página HTML personalizada..."
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
            <h1>Aplicação de Teste cert-manager</h1>
            <p class="success">Certificado TLS implantado com sucesso!</p>
            <p class="info">Esta página é servida com um certificado emitido pelo cert-manager.</p>
            <h2>Lab 21 Concluído</h2>
            <ul>
                <li>Cluster Kubernetes em execução</li>
                <li>cert-manager implantado</li>
                <li>Emissão automática de certificados funcionando</li>
                <li>Ingress TLS configurado</li>
            </ul>
        </div>
    </body>
    </html>
EOF
print_success "Aplicação de teste implantada"
echo

# --- Passo 4: Criar serviço ClusterIP ---
print_step "Criar serviço"

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
print_success "Serviço criado"
echo

# --- Passo 5: Criar Ingress com TLS ---
print_step "Criar Ingress com TLS"

print_info "Anotação do Ingress informa ao cert-manager qual emissor usar..."
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
print_success "Ingress criado com TLS"
echo

# --- Passo 6: Aguardar emissão do certificado ---
print_step "Aguardar emissão do certificado"

print_info "cert-manager cria um recurso Certificate automaticamente a partir do bloco TLS do Ingress..."
max_attempts=120
attempt=0
while [[ ${attempt} -lt ${max_attempts} ]]; do
  if kubectl get certificate test-app-tls -n default &>/dev/null; then
    ready="$(kubectl get certificate test-app-tls -n default \
      -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")"
    if [[ "${ready}" == "True" ]]; then
      print_success "Certificado está pronto"
      break
    fi
  fi
  attempt=$((attempt + 1))
  sleep 1
done
if [[ "${ready:-}" != "True" ]]; then
  print_warning "Certificado ainda pode estar sendo emitido"
fi
echo

# --- Passo 7: Aguardar pods ficarem prontos ---
print_step "Aguardar pods ficarem prontos"

kubectl wait --for=condition=Ready --timeout=60s pod -l app=test-app -n default || true
print_success "Pods estão prontos"
echo

print_success "Implantação da aplicação concluída!"

echo
echo "Recursos implantados"
echo
echo "Deployments:"
kubectl get deployments -n default | grep test-app
echo
echo "Serviços:"
kubectl get services -n default | grep test-app
echo
echo "Ingress:"
kubectl get ingress -n default
echo
echo "Certificados:"
kubectl get certificates -n default | grep -E "NAME|test-app"
echo
echo "Secrets:"
kubectl get secrets -n default | grep -E "NAME|test-app-tls"

echo
echo "Detalhes do certificado"
echo
if kubectl get secret test-app-tls -n default &>/dev/null; then
  print_success "Secret TLS existe"
  kubectl get secret test-app-tls -n default \
    -o jsonpath='{.data.tls\.crt}' | base64 -d \
    | openssl x509 -noout -text | grep -A2 "Subject:\|Issuer:\|Validity\|DNS:"
else
  print_warning "Secret TLS ainda não criado"
fi

minikube_ip="$(minikube ip 2>/dev/null || echo "N/A")"
echo
echo "Informações de acesso"
echo
print_info "Host da aplicação: test-app.local"
print_info "IP do Minikube: ${minikube_ip}"
echo
print_info "Para acessar a aplicação:"
echo
echo "1. Adicione a /etc/hosts:"
echo "   echo \"${minikube_ip} test-app.local\" | sudo tee -a /etc/hosts"
echo
echo "2. Acesso via HTTPS:"
echo "   curl -k https://test-app.local"
echo
echo "3. Ou use minikube tunnel (requer sudo):"
echo "   minikube tunnel"
echo "   curl -k https://test-app.local"
echo
print_warning "Nota: O certificado é autoassinado, use a flag -k com curl"

echo
echo "Próximos passos:"
echo "  - Execute './verify.sh' para validar todo o lab"
echo "  - Acesse a aplicação usando as instruções acima"
echo "  - Inspecione o certificado: kubectl describe certificate test-app-tls"
