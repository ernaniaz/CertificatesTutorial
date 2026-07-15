#!/usr/bin/env bash
#=============================================================================
# Lab 06: Configurar SSL
# Configuración SSL de Apache
#
# Uso: ./configure-ssl.sh
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

print_header "Lab 06: Configurando SSL de Apache"

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

# Verificaciones específicas de RHEL 9+
if [[ ${RHEL_VERSION} -ge 9 ]]; then
  # Verificar que el certificado tenga SANs (requerido en RHEL 9+)
  if ! openssl x509 -in "${CERT_DIR}/server.crt" -noout -ext subjectAltName 2>/dev/null | grep -q "DNS"; then
    print_warning "Advertencia: El certificado no tiene SANs (requerido en RHEL 9+)"
    echo "Considere recrear el certificado con SANs en el Lab 04"
  fi

  # Verificar algoritmo de firma del certificado (no SHA-1)
  SIG_ALG=$(openssl x509 -in "${CERT_DIR}/server.crt" -noout -text | grep "Signature Algorithm" | head -1)
  if echo "${SIG_ALG}" | grep -qi "sha1"; then
    print_error "Error: El certificado usa SHA-1 (bloqueado en RHEL 9+)"
    echo "Recrear el certificado con SHA-256+ en el Lab 04"
    exit 1
  else
    print_success "Algoritmo de firma del certificado correcto (no SHA-1)"
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

# Crear archivo VirtualHost SSL
print_info "Creando configuración del VirtualHost SSL..."
if [[ ${RHEL_VERSION} -eq 7 ]]; then
  # Crear VirtualHost SSL (RHEL 7 requiere configuración TLS manual)
  cat > /etc/httpd/conf.d/lab-ssl.conf << 'EOF'
#
# Lab 06: Configuración Apache HTTPS (RHEL 7)
# Se requiere configuración manual de protocolo TLS y cifrado
#

<VirtualHost *:443>
    ServerName localhost
    ServerAlias server.example.com
    DocumentRoot /var/www/html

    # Habilitar SSL/TLS
    SSLEngine on

    # Archivos de certificado
    SSLCertificateFile /etc/pki/tls/certs/lab-server.crt
    SSLCertificateKeyFile /etc/pki/tls/private/lab-server.key

    # RHEL 7: DEBE configurar manualmente versiones TLS
    # Deshabilitar protocolos antiguos e inseguros
    SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1

    # RHEL 7: DEBE configurar manualmente conjuntos de cifrado
    # Usar solo cifrados fuertes
    SSLCipherSuite ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256
    SSLHonorCipherOrder on

    # HSTS (HTTP Strict Transport Security)
    Header always set Strict-Transport-Security "max-age=31536000"

    # Registro
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
  # Crear VirtualHost SSL (RHEL 8 con crypto-policies)
  cat > /etc/httpd/conf.d/lab-ssl.conf << 'EOF'
#
# Lab 06: Configuración Apache HTTPS (RHEL 8)
# Usa crypto-policies para ajustes TLS
#

<VirtualHost *:443>
    ServerName localhost
    ServerAlias server.example.com
    DocumentRoot /var/www/html

    # Habilitar SSL/TLS
    SSLEngine on

    # Archivos de certificado
    SSLCertificateFile /etc/pki/tls/certs/lab-server.crt
    SSLCertificateKeyFile /etc/pki/tls/private/lab-server.key

    # RHEL 8: crypto-policies gestionan versiones TLS y cifrados
    # No es necesario especificar SSLProtocol o SSLCipherSuite

    # HSTS (HTTP Strict Transport Security)
    Header always set Strict-Transport-Security "max-age=31536000"

    # Registro
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
  # Crear VirtualHost SSL (RHEL 9+ con crypto-policies)
  cat > /etc/httpd/conf.d/lab-ssl.conf << 'EOF'
#
# Lab 06: Configuración Apache HTTPS (RHEL 9)
# Usa crypto-policies para ajustes TLS
# OpenSSL 3.x con seguridad mejorada
#

<VirtualHost *:443>
    ServerName localhost
    ServerAlias server.example.com
    DocumentRoot /var/www/html

    # Habilitar SSL/TLS
    SSLEngine on

    # Archivos de certificado
    SSLCertificateFile /etc/pki/tls/certs/lab-server.crt
    SSLCertificateKeyFile /etc/pki/tls/private/lab-server.key

    # RHEL 9: crypto-policies gestionan todo
    # No se necesita SSLProtocol ni SSLCipherSuite
    # Gestionado por: /etc/crypto-policies/config

    # HSTS (HTTP Strict Transport Security)
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"

    # Registro
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

# Crear página de prueba
case ${RHEL_VERSION} in
  7)
    echo "<html><body><h1>Lab 06: Prueba Apache HTTPS</h1><p>RHEL 7 - Configuración TLS manual</p></body></html>" > /var/www/html/index.html
    ;;
  8)
    echo "<html><body><h1>Lab 06: Prueba Apache HTTPS</h1><p>RHEL 8 - crypto-policies habilitadas</p></body></html>" > /var/www/html/index.html
    ;;
  9)
    echo "<html><body><h1>Lab 06: Prueba Apache HTTPS</h1><p>RHEL 9 - OpenSSL 3.x, SHA-1 bloqueado, SANs requeridos</p></body></html>" > /var/www/html/index.html
    ;;
  10)
    echo "<html><body><h1>Lab 06: Prueba Apache HTTPS</h1><p>RHEL 10 - OpenSSL 3.x, SHA-1 bloqueado, SANs requeridos</p></body></html>" > /var/www/html/index.html
    ;;
esac

# Verificar crypto-policy actual
if [[ ${RHEL_VERSION} -ge 8 ]]; then
  POLICY=$(update-crypto-policies --show 2>/dev/null || echo "DEFAULT")
  echo "Crypto-policy actual: ${POLICY}"
  echo
fi

# Probar configuración
print_info "Probando configuración..."
if apachectl configtest 2>&1 | grep -q "Syntax OK"; then
  print_success "Sintaxis de configuración correcta"
else
  print_error "Error de sintaxis en la configuración"
  apachectl configtest
  exit 1
fi

# Reiniciar Apache
echo
print_info "Reiniciando Apache..."
systemctl restart httpd

if systemctl is-active httpd &>/dev/null; then
  print_success "Apache reiniciado correctamente"
else
  print_error "Error al reiniciar Apache"
  journalctl -xeu httpd | tail -20
  exit 1
fi

echo
print_success "Configuración SSL completada"
echo

case ${RHEL_VERSION} in
  7)
    echo "Notas de configuración RHEL 7:"
    echo "  - Protocolos TLS configurados manualmente (sin TLS 1.0/1.1)"
    echo "  - Conjuntos de cifrado establecidos explícitamente"
    echo "  - crypto-policies no disponible en RHEL 7"
    ;;
  8)
    echo "Pruebe su configuración HTTPS:"
    echo "  curl https://localhost/ --insecure"
    echo "  openssl s_client -connect localhost:443 -servername localhost"
    ;;
  9|10)
    echo "Notas de configuración RHEL 9/10:"
    echo "  - OpenSSL 3.x activo"
    echo "  - Firmas SHA-1 bloqueadas"
    echo "  - SANs requeridos para validación de hostname"
    echo "  - crypto-policies: ${POLICY}"
    ;;
esac
