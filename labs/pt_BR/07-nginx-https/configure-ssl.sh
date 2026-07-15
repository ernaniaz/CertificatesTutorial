#!/usr/bin/env bash
#=============================================================================
# Lab 07: Configurar SSL
# Configuração SSL do NGINX
#
# Uso: ./configure-ssl.sh
# Pré-requisitos: RHEL 7, 8, 9, 10, privilégios de root
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
if [[ ${RHEL_VERSION} -lt 7 || ${RHEL_VERSION} -gt 10 ]]; then
  error_exit "Versão do RHEL não suportada. Este script requer RHEL 7, 8, 9 ou 10."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

CERT_DIR="../04-x509-certificates/output"
KEY_DIR="../02-key-generation/output"

print_header "Lab 07: Configurando NGINX SSL"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

# Verificar pré-requisitos
if [[ ! -f "${CERT_DIR}/server.crt" || ! -f "${KEY_DIR}/rsa-2048.key" ]]; then
  print_error "Erro: Certificados não encontrados. Conclua os Labs 02 e 04 primeiro."
  exit 1
fi

# Criar diretórios de certificado
print_info "Criando diretórios de certificado..."
mkdir -p /etc/pki/nginx
mkdir -p /etc/pki/nginx/private

# Copiar certificados para locais do sistema
print_info "Copiando certificados..."
cp "${CERT_DIR}/server.crt" /etc/pki/nginx/server.crt
cp "${KEY_DIR}/rsa-2048.key" /etc/pki/nginx/private/server.key
chmod 644 /etc/pki/nginx/server.crt
chmod 600 /etc/pki/nginx/private/server.key

# Corrigir contextos SELinux para RHEL 9+
if [[ ${RHEL_VERSION} -ge 9 ]]; then
  print_info "Definindo contextos SELinux..."
  restorecon -Rv /etc/pki/nginx/ 2>/dev/null || true
fi

print_success "Certificados copiados"
echo

# Verificar crypto-policy atual
if [[ ${RHEL_VERSION} -ge 8 ]]; then
  POLICY="$(update-crypto-policies --show 2>/dev/null || echo "DEFAULT")"
  echo "Crypto-policy atual: ${POLICY}"
  echo
fi

# Criar configuração de bloco de servidor SSL
print_info "Criando configuração de bloco de servidor SSL..."

if [[ ${RHEL_VERSION} -eq 7 ]]; then
  cat > /etc/nginx/conf.d/lab-ssl.conf << 'EOF'
#
# Lab 07: Configuração NGINX HTTPS (RHEL 7)
# Configuração manual de protocolo e cifras TLS
#

server {
    listen 443 ssl;
    server_name localhost server.example.com;

    # Diretório raiz
    root /usr/share/nginx/html;
    index index.html;

    # Arquivos de certificado
    ssl_certificate /etc/pki/nginx/server.crt;
    ssl_certificate_key /etc/pki/nginx/private/server.key;

    # RHEL 7: Configuração TLS manual
    # Desabilitar protocolos mais antigos, usar TLS 1.2+
    ssl_protocols TLSv1.2 TLSv1.3;

    # Suites de cifra fortes
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers on;

    # Cache de sessão SSL
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # HSTS (HTTP Strict Transport Security)
    add_header Strict-Transport-Security "max-age=31536000" always;

    # Cabeçalhos de segurança
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Registro de log
    access_log /var/log/nginx/ssl_access.log;
    error_log /var/log/nginx/ssl_error.log;

    location / {
        try_files $uri $uri/ =404;
    }
}

# Redirecionar HTTP para HTTPS
server {
    listen 80;
    server_name localhost server.example.com;
    return 301 https://${server_name}${request_uri};
}
EOF
fi
if [[ ${RHEL_VERSION} -eq 8 ]]; then
  cat > /etc/nginx/conf.d/lab-ssl.conf << 'EOF'
#
# Lab 07: Configuração NGINX HTTPS (RHEL 8)
# Usa crypto-policies, mas NGINX requer configuração SSL explícita
#

server {
    listen 443 ssl;
    server_name localhost server.example.com;

    # Diretório raiz
    root /usr/share/nginx/html;
    index index.html;

    # Arquivos de certificado
    ssl_certificate /etc/pki/nginx/server.crt;
    ssl_certificate_key /etc/pki/nginx/private/server.key;

    # RHEL 8: Ainda especifique protocolos (crypto-policies influenciam opções disponíveis)
    ssl_protocols TLSv1.2 TLSv1.3;

    # Deixar crypto-policies influenciar a seleção de cifras
    # Mas ainda é possível especificar preferências
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers off;

    # Cache de sessão SSL
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # HSTS (HTTP Strict Transport Security)
    add_header Strict-Transport-Security "max-age=31536000" always;

    # Cabeçalhos de segurança
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Registro de log
    access_log /var/log/nginx/ssl_access.log;
    error_log /var/log/nginx/ssl_error.log;

    location / {
        try_files $uri $uri/ =404;
    }
}

# Redirecionar HTTP para HTTPS
server {
    listen 80;
    server_name localhost server.example.com;
    return 301 https://${server_name}${request_uri};
}
EOF
fi
if [[ ${RHEL_VERSION} -ge 9 ]]; then
  cat > /etc/nginx/conf.d/lab-ssl.conf << 'EOF'
#
# Lab 07: Configuração NGINX HTTPS (RHEL 9)
# OpenSSL 3.x com padrões mais rigorosos
#

server {
    listen 443 ssl;
    server_name localhost server.example.com;

    # Diretório raiz
    root /usr/share/nginx/html;
    index index.html;

    # Arquivos de certificado
    ssl_certificate /etc/pki/nginx/server.crt;
    ssl_certificate_key /etc/pki/nginx/private/server.key;

    # RHEL 9: Apenas TLS 1.2 e 1.3 (1.3 preferido)
    ssl_protocols TLSv1.2 TLSv1.3;

    # Suites de cifras modernas (RHEL 9 bloqueia cifras fracas)
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305';
    ssl_prefer_server_ciphers off;

    # Cache de sessão SSL
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # HSTS (HTTP Strict Transport Security)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Cabeçalhos de segurança
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Registro de log
    access_log /var/log/nginx/ssl_access.log;
    error_log /var/log/nginx/ssl_error.log;

    location / {
        try_files $uri $uri/ =404;
    }
}

# Redirecionar HTTP para HTTPS
server {
    listen 80;
    server_name localhost server.example.com;
    return 301 https://${server_name}${request_uri};
}
EOF
fi

print_success "Bloco de servidor SSL configurado"
echo

# Criar página de teste
case ${RHEL_VERSION} in
  7)
    echo "<html><body><h1>Lab 07: Teste HTTPS NGINX</h1><p>RHEL 7 - Configuração TLS manual</p></body></html>" > /usr/share/nginx/html/index.html
    ;;
  8)
    echo "<html><body><h1>Lab 07: Teste HTTPS NGINX</h1><p>RHEL 8 - Crypto-policies habilitadas</p></body></html>" > /usr/share/nginx/html/index.html
    ;;
  9)
    echo "<html><body><h1>Lab 07: Teste HTTPS NGINX</h1><p>RHEL 9 - OpenSSL 3.x com segurança rigorosa</p></body></html>" > /usr/share/nginx/html/index.html
    ;;
  10)
    echo "<html><body><h1>Lab 07: Teste HTTPS NGINX</h1><p>RHEL 10 - OpenSSL 3.x com segurança rigorosa</p></body></html>" > /usr/share/nginx/html/index.html
    ;;
esac

# Testar configuração
print_info "Testando configuração..."
if nginx -t; then
  print_success "Sintaxe de configuração OK"
else
  print_error "Erro de sintaxe de configuração"
  exit 1
fi

# Reiniciar NGINX
echo
print_info "Reiniciando NGINX..."
systemctl restart nginx

if systemctl is-active nginx &>/dev/null; then
  print_success "NGINX reiniciado com sucesso"
else
  print_error "NGINX falhou ao reiniciar"
  journalctl -xeu nginx | tail -20
  exit 1
fi

echo
print_success "Configuração SSL concluída"
echo
echo "Teste sua configuração HTTPS:"
echo "  curl https://localhost/ --insecure"
echo "  openssl s_client -connect localhost:443 -servername localhost"
