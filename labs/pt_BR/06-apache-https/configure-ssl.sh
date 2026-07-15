#!/usr/bin/env bash
#=============================================================================
# Lab 06: Configurar SSL
# Configuração SSL do Apache
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

print_header "Lab 06: Configurando Apache SSL"

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

# Verificações específicas RHEL 9+
if [[ ${RHEL_VERSION} -ge 9 ]]; then
  # Verificar se certificado possui SANs (obrigatório no RHEL 9+)
  if ! openssl x509 -in "${CERT_DIR}/server.crt" -noout -ext subjectAltName 2>/dev/null | grep -q "DNS"; then
    print_warning "Aviso: Certificado não possui SANs (obrigatório no RHEL 9+)"
    echo "Considere recriar o certificado com SANs no Lab 04"
  fi

  # Verificar algoritmo de assinatura do certificado (não SHA-1)
  SIG_ALG=$(openssl x509 -in "${CERT_DIR}/server.crt" -noout -text | grep "Signature Algorithm" | head -1)
  if echo "${SIG_ALG}" | grep -qi "sha1"; then
    print_error "Erro: Certificado usa SHA-1 (bloqueado no RHEL 9+)"
    echo "Recriar certificado com SHA-256+ no Lab 04"
    exit 1
  else
    print_success "Algoritmo de assinatura do certificado OK (não SHA-1)"
  fi
fi

# Copiar certificados
print_info "Copiando certificados..."
cp "${CERT_DIR}/server.crt" /etc/pki/tls/certs/lab-server.crt
cp "${KEY_DIR}/rsa-2048.key" /etc/pki/tls/private/lab-server.key
chmod 644 /etc/pki/tls/certs/lab-server.crt
chmod 600 /etc/pki/tls/private/lab-server.key

print_success "Certificados copiados"
echo

# Criar arquivo SSL VirtualHost
print_info "Criando configuração SSL VirtualHost..."
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  # Criar SSL VirtualHost (RHEL 7 requer configurações TLS manuais)
  cat > /etc/httpd/conf.d/lab-ssl.conf << 'EOF'
#
# Lab 06: Configuração Apache HTTPS (RHEL 7)
# Configuração manual de protocolo e cifras TLS necessária
#

<VirtualHost *:443>
    ServerName localhost
    ServerAlias server.example.com
    DocumentRoot /var/www/html

    # Habilitar SSL/TLS
    SSLEngine on

    # Arquivos de certificado
    SSLCertificateFile /etc/pki/tls/certs/lab-server.crt
    SSLCertificateKeyFile /etc/pki/tls/private/lab-server.key

    # RHEL 7: DEVE configurar manualmente versões TLS
    # Desabilitar protocolos antigos e inseguros
    SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1

    # RHEL 7: DEVE configurar manualmente suites de cifras
    # Usar somente cifras fortes
    SSLCipherSuite ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256
    SSLHonorCipherOrder on

    # HSTS (HTTP Strict Transport Security)
    Header always set Strict-Transport-Security "max-age=31536000"

    # Registro de log
    ErrorLog logs/ssl_error_log
    CustomLog logs/ssl_access_log combined

    <Directory /var/www/html>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
</VirtualHost>
EOF

  print_success "VirtualHost SSL configurado (modo manual RHEL 7)"
fi

if [[ ${RHEL_VERSION} -eq 8 ]]; then
  # Criar SSL VirtualHost (RHEL 8 com crypto-policies)
  cat > /etc/httpd/conf.d/lab-ssl.conf << 'EOF'
#
# Lab 06: Configuração Apache HTTPS (RHEL 8)
# Usa crypto-policies para configurações TLS
#

<VirtualHost *:443>
    ServerName localhost
    ServerAlias server.example.com
    DocumentRoot /var/www/html

    # Habilitar SSL/TLS
    SSLEngine on

    # Arquivos de certificado
    SSLCertificateFile /etc/pki/tls/certs/lab-server.crt
    SSLCertificateKeyFile /etc/pki/tls/private/lab-server.key

    # RHEL 8: Crypto-policies gerenciam versões TLS e cifras
    # Não é necessário especificar SSLProtocol ou SSLCipherSuite

    # HSTS (HTTP Strict Transport Security)
    Header always set Strict-Transport-Security "max-age=31536000"

    # Registro de log
    ErrorLog logs/ssl_error_log
    CustomLog logs/ssl_access_log combined

    <Directory /var/www/html>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
</VirtualHost>
EOF

  print_success "VirtualHost SSL configurado"
fi

if [[ ${RHEL_VERSION} -ge 9 ]]; then
  # Criar SSL VirtualHost (RHEL 9+ com crypto-policies)
  cat > /etc/httpd/conf.d/lab-ssl.conf << 'EOF'
#
# Lab 06: Configuração Apache HTTPS (RHEL 9)
# Usa crypto-policies para configurações TLS
# OpenSSL 3.x com segurança aprimorada
#

<VirtualHost *:443>
    ServerName localhost
    ServerAlias server.example.com
    DocumentRoot /var/www/html

    # Habilitar SSL/TLS
    SSLEngine on

    # Arquivos de certificado
    SSLCertificateFile /etc/pki/tls/certs/lab-server.crt
    SSLCertificateKeyFile /etc/pki/tls/private/lab-server.key

    # RHEL 9: Crypto-policies gerenciam tudo
    # Não é necessário SSLProtocol ou SSLCipherSuite
    # Gerenciado por: /etc/crypto-policies/config

    # HSTS (HTTP Strict Transport Security)
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"

    # Registro de log
    ErrorLog logs/ssl_error_log
    CustomLog logs/ssl_access_log combined

    <Directory /var/www/html>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
</VirtualHost>
EOF

  print_success "VirtualHost SSL configurado"
fi

echo

# Criar página de teste
case ${RHEL_VERSION} in
  7)
    echo "<html><body><h1>Lab 06: Teste HTTPS Apache</h1><p>RHEL 7 - Configuração TLS manual</p></body></html>" > /var/www/html/index.html
    ;;
  8)
    echo "<html><body><h1>Lab 06: Teste HTTPS Apache</h1><p>RHEL 8 - Crypto-policies habilitadas</p></body></html>" > /var/www/html/index.html
    ;;
  9)
    echo "<html><body><h1>Lab 06: Teste HTTPS Apache</h1><p>RHEL 9 - OpenSSL 3.x, SHA-1 bloqueado, SANs obrigatórios</p></body></html>" > /var/www/html/index.html
    ;;
  10)
    echo "<html><body><h1>Lab 06: Teste HTTPS Apache</h1><p>RHEL 10 - OpenSSL 3.x, SHA-1 bloqueado, SANs obrigatórios</p></body></html>" > /var/www/html/index.html
    ;;
esac

# Verificar crypto-policy atual
if [[ ${RHEL_VERSION} -ge 8 ]]; then
  POLICY=$(update-crypto-policies --show 2>/dev/null || echo "DEFAULT")
  echo "Crypto-policy atual: ${POLICY}"
  echo
fi

# Testar configuração
print_info "Testando configuração..."
if apachectl configtest 2>&1 | grep -q "Syntax OK"; then
  print_success "Sintaxe de configuração OK"
else
  print_error "Erro de sintaxe de configuração"
  apachectl configtest
  exit 1
fi

# Reiniciar Apache
echo
print_info "Reiniciando Apache..."
systemctl restart httpd

if systemctl is-active httpd &>/dev/null; then
  print_success "Apache reiniciado com sucesso"
else
  print_error "Apache falhou ao reiniciar"
  journalctl -xeu httpd | tail -20
  exit 1
fi

echo
print_success "Configuração SSL concluída"
echo

case ${RHEL_VERSION} in
  7)
    echo "Notas de Configuração RHEL 7:"
    echo "  - Protocolos TLS configurados manualmente (sem TLS 1.0/1.1)"
    echo "  - Conjuntos de cifras definidos explicitamente"
    echo "  - crypto-policies não disponível no RHEL 7"
    ;;
  8)
    echo "Teste sua configuração HTTPS:"
    echo "  curl https://localhost/ --insecure"
    echo "  openssl s_client -connect localhost:443 -servername localhost"
    ;;
  9|10)
    echo "Notas de Configuração RHEL 9/10:"
    echo "  - OpenSSL 3.x ativo"
    echo "  - Assinaturas SHA-1 bloqueadas"
    echo "  - SANs obrigatórios para validação de hostname"
    echo "  - crypto-policies: ${POLICY}"
    ;;
esac
