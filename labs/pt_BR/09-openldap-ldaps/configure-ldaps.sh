#!/usr/bin/env bash
#=============================================================================
# Lab 09: Configurar LDAPS
# Configura OpenLDAP com certificados TLS
#
# Uso: ./configure-ldaps.sh
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

print_header "Lab 09: Configurando OpenLDAP LDAPS"

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

# Criar diretório de certificado para OpenLDAP
print_info "Criando diretórios de certificado..."
mkdir -p /etc/openldap/certs
chmod 755 /etc/openldap/certs

# Copiar certificados
print_info "Copiando certificados..."
cp "${CERT_DIR}/server.crt" /etc/openldap/certs/ldap.crt
cp "${KEY_DIR}/rsa-2048.key" /etc/openldap/certs/ldap.key
chmod 644 /etc/openldap/certs/ldap.crt
chmod 600 /etc/openldap/certs/ldap.key
chown ldap:ldap /etc/openldap/certs/ldap.crt
chown ldap:ldap /etc/openldap/certs/ldap.key

print_success "Certificados copiados"
echo

# Corrigir contextos SELinux
print_info "Definindo contextos SELinux..."
restorecon -Rv /etc/openldap/certs/ 2>/dev/null || true

# Configurar TLS em cn=config
print_info "Configurando TLS em cn=config..."

# Criar LDIF para configurar TLS
cat > /tmp/tls-config.ldif << EOF
dn: cn=config
changetype: modify
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/openldap/certs/ldap.crt
-
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/openldap/certs/ldap.key
-
add: olcTLSProtocolMin
olcTLSProtocolMin: 3.3
-
add: olcTLSCipherSuite
olcTLSCipherSuite: HIGH:!aNULL:!MD5
EOF

# Aplicar configuração TLS
if ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/tls-config.ldif 2>/dev/null; then
  print_success "Configuração TLS aplicada"
else
  print_warning "TLS pode já estar configurado, continuando..."
fi

rm -f /tmp/tls-config.ldif
echo

# Habilitar LDAPS (porta 636)
print_info "Habilitando LDAPS na porta 636..."

# Verificar SLAPD_URLS atual
if [[ -f /etc/sysconfig/slapd ]]; then
  # Backup original
  if [[ ! -f /etc/sysconfig/slapd.lab-backup ]]; then
    cp /etc/sysconfig/slapd /etc/sysconfig/slapd.lab-backup
  fi

  # Atualizar SLAPD_URLS para incluir ldaps://
  if grep -q "^SLAPD_URLS=" /etc/sysconfig/slapd; then
    sed -i 's|^SLAPD_URLS=.*|SLAPD_URLS="ldapi:/// ldap:/// ldaps:///"|' /etc/sysconfig/slapd
  else
    echo 'SLAPD_URLS="ldapi:/// ldap:/// ldaps:///"' >> /etc/sysconfig/slapd
  fi
  print_success "LDAPS habilitado na configuração"
fi

echo

# Reiniciar slapd
print_info "Reiniciando slapd..."
systemctl restart slapd

if systemctl is-active slapd &>/dev/null; then
  print_success "slapd reiniciado com sucesso"
else
  print_error "slapd falhou ao reiniciar"
  journalctl -xeu slapd | tail -20
  exit 1
fi

echo

# Verificar portas
print_info "Verificando portas em escuta..."
sleep 2  # Give slapd time to bind ports

if ss -tlnp | grep -q ':389'; then
  print_success "Porta LDAP 389 escutando"
fi

if ss -tlnp | grep -q ':636'; then
  print_success "Porta LDAPS 636 escutando"
else
  print_warning "Porta LDAPS 636 não está escutando"
  echo "Verificar configuração de /etc/sysconfig/slapd"
fi

echo
print_success "Configuração LDAPS concluída"
echo
echo "Testar conexão LDAPS:"
echo "  ldapsearch -x -H ldaps://localhost -b \"\" -s base"
echo "  openssl s_client -connect localhost:636"
