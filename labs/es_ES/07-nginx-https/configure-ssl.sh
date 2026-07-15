#!/usr/bin/env bash
#=============================================================================
# Lab 07: Configurar SSL
# Configuración SSL de NGINX
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

print_header "Lab 07: Configurando SSL de NGINX"

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

# Crear directorios de certificados
print_info "Creando directorios de certificados..."
mkdir -p /etc/pki/nginx
mkdir -p /etc/pki/nginx/private

# Copiar certificados a ubicaciones del sistema
print_info "Copiando certificados..."
cp "${CERT_DIR}/server.crt" /etc/pki/nginx/server.crt
cp "${KEY_DIR}/rsa-2048.key" /etc/pki/nginx/private/server.key
chmod 644 /etc/pki/nginx/server.crt
chmod 600 /etc/pki/nginx/private/server.key

# Corregir contextos SELinux para RHEL 9+
if [[ ${RHEL_VERSION} -ge 9 ]]; then
  print_info "Configurando contextos SELinux..."
  restorecon -Rv /etc/pki/nginx/ 2>/dev/null || true
fi

print_success "Certificados copiados"
echo

# Verificar crypto-policy actual
if [[ ${RHEL_VERSION} -ge 8 ]]; then
  POLICY="$(update-crypto-policies --show 2>/dev/null || echo "DEFAULT")"
  echo "Crypto-policy actual: ${POLICY}"
  echo
fi

# Crear configuración del bloque server SSL
print_info "Creando configuración del bloque server SSL..."

if [[ ${RHEL_VERSION} -eq 7 ]]; then
  cat > /etc/nginx/conf.d/lab-ssl.conf << 'EOF'
#
# Lab 07: Configuración NGINX HTTPS (RHEL 7)
# Configuración manual de protocolo TLS y cifrado
#

server {
    listen 443 ssl;
    server_name localhost server.example.com;

    # Directorio raíz
    root /usr/share/nginx/html;
    index index.html;

    # Archivos de certificado
    ssl_certificate /etc/pki/nginx/server.crt;
    ssl_certificate_key /etc/pki/nginx/private/server.key;

    # RHEL 7: Configuración TLS manual
    # Deshabilitar protocolos antiguos, usar TLS 1.2+
    ssl_protocols TLSv1.2 TLSv1.3;

    # Conjuntos de cifrado fuertes
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers on;

    # Caché de sesión SSL
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # HSTS (HTTP Strict Transport Security)
    add_header Strict-Transport-Security "max-age=31536000" always;

    # Encabezados de seguridad
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Registro
    access_log /var/log/nginx/ssl_access.log;
    error_log /var/log/nginx/ssl_error.log;

    location / {
        try_files ${uri} ${uri}/ =404;
    }
}

# Redirigir HTTP a HTTPS
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
# Lab 07: Configuración NGINX HTTPS (RHEL 8)
# Usa crypto-policies pero NGINX requiere configuración SSL explícita
#

server {
    listen 443 ssl;
    server_name localhost server.example.com;

    # Directorio raíz
    root /usr/share/nginx/html;
    index index.html;

    # Archivos de certificado
    ssl_certificate /etc/pki/nginx/server.crt;
    ssl_certificate_key /etc/pki/nginx/private/server.key;

    # RHEL 8: Aún especificar protocolos (crypto-policies influyen en opciones disponibles)
    ssl_protocols TLSv1.2 TLSv1.3;

    # Dejar que crypto-policies influyan en la selección de cifrado
    # Pero aún se pueden especificar preferencias
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers off;

    # Caché de sesión SSL
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # HSTS (HTTP Strict Transport Security)
    add_header Strict-Transport-Security "max-age=31536000" always;

    # Encabezados de seguridad
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Registro
    access_log /var/log/nginx/ssl_access.log;
    error_log /var/log/nginx/ssl_error.log;

    location / {
        try_files ${uri} ${uri}/ =404;
    }
}

# Redirigir HTTP a HTTPS
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
# Lab 07: Configuración NGINX HTTPS (RHEL 9)
# OpenSSL 3.x con valores predeterminados más estrictos
#

server {
    listen 443 ssl;
    server_name localhost server.example.com;

    # Directorio raíz
    root /usr/share/nginx/html;
    index index.html;

    # Archivos de certificado
    ssl_certificate /etc/pki/nginx/server.crt;
    ssl_certificate_key /etc/pki/nginx/private/server.key;

    # RHEL 9: Solo TLS 1.2 y 1.3 (1.3 preferido)
    ssl_protocols TLSv1.2 TLSv1.3;

    # Conjuntos de cifrado modernos (RHEL 9 bloquea cifrados débiles)
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305';
    ssl_prefer_server_ciphers off;

    # Caché de sesión SSL
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # HSTS (HTTP Strict Transport Security)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Encabezados de seguridad
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Registro
    access_log /var/log/nginx/ssl_access.log;
    error_log /var/log/nginx/ssl_error.log;

    location / {
        try_files ${uri} ${uri}/ =404;
    }
}

# Redirigir HTTP a HTTPS
server {
    listen 80;
    server_name localhost server.example.com;
    return 301 https://${server_name}${request_uri};
}
EOF
fi

print_success "Bloque server SSL configurado"
echo

# Crear página de prueba
case ${RHEL_VERSION} in
  7)
    echo "<html><body><h1>Lab 07: Prueba NGINX HTTPS</h1><p>RHEL 7 - Configuración TLS manual</p></body></html>" > /usr/share/nginx/html/index.html
    ;;
  8)
    echo "<html><body><h1>Lab 07: Prueba NGINX HTTPS</h1><p>RHEL 8 - crypto-policies habilitadas</p></body></html>" > /usr/share/nginx/html/index.html
    ;;
  9)
    echo "<html><body><h1>Lab 07: Prueba NGINX HTTPS</h1><p>RHEL 9 - OpenSSL 3.x con seguridad estricta</p></body></html>" > /usr/share/nginx/html/index.html
    ;;
  10)
    echo "<html><body><h1>Lab 07: Prueba NGINX HTTPS</h1><p>RHEL 10 - OpenSSL 3.x con seguridad estricta</p></body></html>" > /usr/share/nginx/html/index.html
    ;;
esac

# Probar configuración
print_info "Probando configuración..."
if nginx -t; then
  print_success "Sintaxis de configuración correcta"
else
  print_error "Error de sintaxis en la configuración"
  exit 1
fi

# Reiniciar NGINX
echo
print_info "Reiniciando NGINX..."
systemctl restart nginx

if systemctl is-active nginx &>/dev/null; then
  print_success "NGINX reiniciado correctamente"
else
  print_error "Error al reiniciar NGINX"
  journalctl -xeu nginx | tail -20
  exit 1
fi

echo
print_success "Configuración SSL completada"
echo
echo "Pruebe su configuración HTTPS:"
echo "  curl https://localhost/ --insecure"
echo "  openssl s_client -connect localhost:443 -servername localhost"
