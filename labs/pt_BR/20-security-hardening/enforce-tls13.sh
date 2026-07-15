#!/usr/bin/env bash
#=============================================================================
# Lab 20: Impor TLS 1.3
# Configura TLS 1.3 como versão mínima
#
# Uso: ./enforce-tls13.sh
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

print_header "Lab 20: Impor TLS 1.3"

# Verificar se está executando como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Erro: Este script deve ser executado como root (use sudo)"
  exit 1
fi

print_warning "Modo somente TLS 1.3"
echo "  Segurança máxima, mas pode quebrar compatibilidade"
echo "  Nem todos os clientes suportam TLS 1.3"
echo

read -p "Impor mínimo TLS 1.3? (s/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Ss]$ ]]; then
  echo "Operação cancelada"
  exit 0
fi

echo

# Verificar versão do OpenSSL (requer 1.1.1+)
OPENSSL_VERSION="$(openssl version | awk '{print $2}')"
echo "Versão do OpenSSL: ${OPENSSL_VERSION}"

if ! openssl version | grep -qE "1\.1\.1|3\."; then
  print_error "TLS 1.3 requer OpenSSL 1.1.1+"
  echo "OpenSSL atual não suporta TLS 1.3"
  exit 1
fi

print_success "OpenSSL suporta TLS 1.3"
echo

# Apache
if [[ -d /etc/httpd/conf.d ]]; then
  print_info "Configurando Apache para TLS 1.3..."

  cat > /etc/httpd/conf.d/tls13-only.conf << 'EOF'
# Lab 20: Apenas TLS 1.3
SSLProtocol -all +TLSv1.3
EOF

  if apachectl configtest 2>&1 | grep -q "Syntax OK"; then
    print_success "Apache configurado"
    systemctl reload httpd 2>/dev/null || true
  fi
fi

# NGINX
if [[ -d /etc/nginx ]]; then
  print_info "Configurando NGINX para TLS 1.3..."

  cat > /etc/nginx/conf.d/tls13-only.conf << 'EOF'
# Lab 20: Apenas TLS 1.3
ssl_protocols TLSv1.3;
EOF

  if nginx -t 2>&1 | grep -q "successful"; then
    print_success "NGINX configurado"
    systemctl reload nginx 2>/dev/null || true
  fi
fi

echo
print_success "Imposição de TLS 1.3 configurada"
echo
print_warning "Aviso: Isso quebra clientes somente TLS 1.2"
echo
echo "Para reverter para TLS 1.2+:"
echo "  Remova /etc/httpd/conf.d/tls13-only.conf"
echo "  Remova /etc/nginx/conf.d/tls13-only.conf"
echo "  Reinicie serviços"
