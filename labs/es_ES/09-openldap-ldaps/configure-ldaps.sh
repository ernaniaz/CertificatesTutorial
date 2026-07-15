#!/usr/bin/env bash
#=============================================================================
# Lab 09: Configurar LDAPS
# Configura OpenLDAP con certificados TLS
#
# Uso: ./configure-ldaps.sh
# Requisitos previos: RHEL 7, 8, 9, 10, privilegios de root
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
if [[ ${RHEL_VERSION} -lt 7 || ${RHEL_VERSION} -gt 10 ]]; then
  error_exit "Versión de RHEL no soportada. Este script requiere RHEL 7, 8, 9 o 10."
fi

#=============================================================================
# PRINCIPAL
#=============================================================================

CERT_DIR="../04-x509-certificates/output"
KEY_DIR="../02-key-generation/output"

print_header "Lab 09: Configurando OpenLDAP LDAPS"

# Verificar si se ejecuta como root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: Este script debe ejecutarse como root (use sudo)"
  exit 1
fi

# Verificar requisitos previos
if [[ ! -f "${CERT_DIR}/server.crt" || ! -f "${KEY_DIR}/rsa-2048.key" ]]; then
  print_error "Error: No se encontraron certificados. Complete primero los Labs 02 y 04."
  exit 1
fi

# Crear directorio de certificados para OpenLDAP
print_info "Creando directorios de certificados..."
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

# Corregir contextos SELinux
print_info "Configurando contextos SELinux..."
restorecon -Rv /etc/openldap/certs/ 2>/dev/null || true

# Configurar TLS en cn=config
print_info "Configurando TLS en cn=config..."

# Crear LDIF para configurar TLS
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

# Aplicar configuración TLS
if ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/tls-config.ldif 2>/dev/null; then
  print_success "Configuración TLS aplicada"
else
  print_warning "TLS puede estar ya configurado, continuando..."
fi

rm -f /tmp/tls-config.ldif
echo

# Habilitar LDAPS (puerto 636)
print_info "Habilitando LDAPS en el puerto 636..."

# Verificar SLAPD_URLS actual
if [[ -f /etc/sysconfig/slapd ]]; then
  # Crear respaldo original
  if [[ ! -f /etc/sysconfig/slapd.lab-backup ]]; then
    cp /etc/sysconfig/slapd /etc/sysconfig/slapd.lab-backup
  fi

  # Actualizar SLAPD_URLS para incluir ldaps://
  if grep -q "^SLAPD_URLS=" /etc/sysconfig/slapd; then
    sed -i 's|^SLAPD_URLS=.*|SLAPD_URLS="ldapi:/// ldap:/// ldaps:///"|' /etc/sysconfig/slapd
  else
    echo 'SLAPD_URLS="ldapi:/// ldap:/// ldaps:///"' >> /etc/sysconfig/slapd
  fi
  print_success "LDAPS habilitado en la configuración"
fi

echo

# Reiniciar slapd
print_info "Reiniciando slapd..."
systemctl restart slapd

if systemctl is-active slapd &>/dev/null; then
  print_success "slapd reiniciado correctamente"
else
  print_error "Error al reiniciar slapd"
  journalctl -xeu slapd | tail -20
  exit 1
fi

echo

# Verificar puertos
print_info "Verificando puertos escuchando..."
sleep 2  # Dar tiempo a slapd para enlazar puertos

if ss -tlnp | grep -q ':389'; then
  print_success "Puerto LDAP 389 escuchando"
fi

if ss -tlnp | grep -q ':636'; then
  print_success "Puerto LDAPS 636 escuchando"
else
  print_warning "Puerto LDAPS 636 no escuchando"
  echo "Verifique la configuración de /etc/sysconfig/slapd"
fi

echo
print_success "Configuración LDAPS completada"
echo
echo "Probar conexión LDAPS:"
echo "  ldapsearch -x -H ldaps://localhost -b \"\" -s base"
echo "  openssl s_client -connect localhost:636"
