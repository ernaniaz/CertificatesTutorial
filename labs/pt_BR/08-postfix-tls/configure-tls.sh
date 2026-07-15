#!/usr/bin/env bash
#=============================================================================
# Lab 08: Configurar TLS
# Configura TLS para SMTP e submission
#
# Uso: ./configure-tls.sh
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

print_header "Lab 08: Configurando Postfix TLS"

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

# Backup da configuração original
print_info "Fazendo backup da configuração original..."
if [[ ! -f /etc/postfix/main.cf.lab-backup ]]; then
  cp /etc/postfix/main.cf /etc/postfix/main.cf.lab-backup
  print_success "Configuração salva em backup"
else
  echo "Backup já existe"
fi
echo

# Copiar certificados para locais do sistema
print_info "Copiando certificados..."
cp "${CERT_DIR}/server.crt" /etc/pki/tls/certs/postfix.crt
cp "${KEY_DIR}/rsa-2048.key" /etc/pki/tls/private/postfix.key
chmod 644 /etc/pki/tls/certs/postfix.crt
chmod 600 /etc/pki/tls/private/postfix.key
chown root:root /etc/pki/tls/private/postfix.key

print_success "Certificados copiados"
echo

# Configurar TLS em main.cf
print_info "Configurando parâmetros TLS..."

# Remover qualquer configuração TLS existente para evitar duplicatas
sed -i '/^smtpd_tls_/d' /etc/postfix/main.cf
sed -i '/^smtp_tls_/d' /etc/postfix/main.cf
sed -i '/^tls_ssl_options/d' /etc/postfix/main.cf

# Adicionar configuração TLS
cat >> /etc/postfix/main.cf << 'EOF'

# Lab 08: Configuração TLS
# TLS do servidor (conexões de entrada)
smtpd_tls_cert_file = /etc/pki/tls/certs/postfix.crt
smtpd_tls_key_file = /etc/pki/tls/private/postfix.key
smtpd_tls_security_level = may
smtpd_tls_loglevel = 1
smtpd_tls_session_cache_database = btree:/var/lib/postfix/smtpd_tls_cache
smtpd_tls_received_header = yes

# TLS do cliente (conexões de saída)
smtp_tls_security_level = may
smtp_tls_loglevel = 1
smtp_tls_session_cache_database = btree:/var/lib/postfix/smtp_tls_cache

# Protocolos TLS (desabilitar versões antigas)
smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtp_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1

# Somente cifras fortes
smtpd_tls_ciphers = high
smtpd_tls_exclude_ciphers = aNULL, MD5, DES, 3DES, RC4
smtpd_tls_mandatory_ciphers = high

EOF

# Desabilitar compressão (ataque CRIME) - requer Postfix 2.11+ (RHEL 8+)
if [[ ${RHEL_VERSION} -ge 8 ]]; then
  postconf -e "tls_ssl_options = NO_COMPRESSION"
fi

print_success "Parâmetros TLS configurados"
echo

# Configurar porta submission (587) em master.cf
print_info "Configurando porta submission (587)..."

# Verificar se submission já está descomentado
if grep -q "^submission inet" /etc/postfix/master.cf; then
  echo "Submission já habilitado"
else
  # Descomentar linhas de submission
  sed -i '/^#submission inet/,/^#  -o smtpd_reject_unlisted_recipient=no/ s/^#//' /etc/postfix/master.cf

  # Se isso não funcionou, adicione submission manualmente
  if ! grep -q "^submission inet" /etc/postfix/master.cf; then
    cat >> /etc/postfix/master.cf << 'EOF'

# Lab 08: Configuração da porta de submissão
submission inet n       -       n       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_reject_unlisted_recipient=no
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
EOF
  fi
fi

print_success "Porta de submission configurada"
echo

# Verificar configuração
print_info "Verificando configuração..."
if postfix check; then
  print_success "Configuração OK"
else
  print_error "Erro de configuração"
  exit 1
fi

# Reiniciar Postfix
echo
print_info "Reiniciando Postfix..."
systemctl restart postfix

if systemctl is-active postfix &>/dev/null; then
  print_success "Postfix reiniciado com sucesso"
else
  print_error "Postfix falhou ao reiniciar"
  journalctl -xeu postfix | tail -20
  exit 1
fi

echo
print_success "Configuração TLS concluída"
echo
echo "Configurações TLS:"
postconf -n | grep tls

echo
echo "Testar STARTTLS:"
echo "  openssl s_client -connect localhost:25 -starttls smtp"
