# Capítulo 9: Gestión de Certificados en RHEL 7

> **Legado pero Importante:** RHEL 7 alcanzó el fin de mantenimiento en junio de 2024, pero muchas empresas aún lo ejecutan. Aprende cómo funciona la gestión de certificados en RHEL 7.

---

## 9.1 Resumen de RHEL 7

**Lanzamiento:** 10 de junio de 2014
**Fin de Soporte de Mantenimiento:** 30 de junio de 2024
**Soporte de Ciclo de Vida Extendido:** Disponible hasta 2028

**Características Clave:**
- **Versión OpenSSL:** 1.0.2k-26 (paquete: `openssl-1.0.2k-26.el7_9.x86_64`)
- **TLS Por Defecto:** TLS 1.0, 1.1, 1.2 todos habilitados
- **Almacén de Confianza:** `/etc/pki/ca-trust/extracted/`
- **Enfoque de Gestión:** Principalmente manual
- **Crypto-Policies:** No disponible (característica de RHEL 8+)

> **Nota:** Si aún estás en RHEL 7, planifica la migración a RHEL 8 o 9. Las actualizaciones de seguridad son limitadas.

---

## 9.2 Especificaciones de OpenSSL 1.0.2k

### Verificación de Versión

```bash
# Verificar versión de OpenSSL en RHEL 7
openssl version
# OpenSSL 1.0.2k-fips  12 Jan 2017

# Verificar paquete
rpm -q openssl
# openssl-1.0.2k-26.el7_9.x86_64
```

### Características y Limitaciones Clave

**Características:**
- ✅ Soporte TLS 1.0, 1.1, 1.2
- ✅ Estable y bien probado
- ✅ Amplia compatibilidad
- ✅ Tipos de clave RSA, ECC, DSA

**Limitaciones:**
- ❌ Sin soporte TLS 1.3
- ❌ Sintaxis de comando antigua (genrsa vs genpkey)
- ❌ Cifrados predeterminados más débiles
- ❌ Suites de cifrado modernas limitadas

### Sintaxis de Comandos (Estilo RHEL 7)

```bash
#============================================#
# GENERAR CLAVE RSA (RHEL 7)
#============================================#

# Estilo antiguo (común en RHEL 7)
openssl genrsa -out server.key 2048

# Con protección de frase de contraseña
openssl genrsa -aes256 -out server.key 2048

# Eliminar frase de contraseña de clave
openssl rsa -in server.key -out server-nopass.key


#============================================#
# GENERAR CSR (RHEL 7)
#============================================#

# CSR básico
openssl req -new -key server.key -out server.csr

# Con sujeto especificado
openssl req -new -key server.key -out server.csr \
  -subj "/C=US/ST=State/L=City/O=Company/CN=server.example.com"

# ⚠️ Nota: Los SANs son más difíciles de agregar con OpenSSL de RHEL 7
# Se necesita archivo de configuración para SANs


#============================================#
# VER CERTIFICADO
#============================================#

# Detalles completos
openssl x509 -in server.crt -noout -text

# Solo expiración
openssl x509 -in server.crt -noout -dates

# Solo sujeto
openssl x509 -in server.crt -noout -subject
```

---

## 9.3 Gestión del Almacén de Confianza en RHEL 7

### Agregar CAs Personalizadas

```bash
#============================================#
# AGREGAR CA PERSONALIZADA (RHEL 7)
#============================================#

# Paso 1: Copiar certificado CA al directorio de anchors
sudo cp corporate-ca.crt /etc/pki/ca-trust/source/anchors/

# Paso 2: Actualizar almacén de confianza
sudo update-ca-trust extract

# Paso 3: Verificar
trust list | grep -i "corporate"

# Verificar que las aplicaciones lo usen
openssl verify -CAfile /etc/pki/tls/certs/ca-bundle.crt test-cert.crt
```

### Ubicaciones del Almacén de Confianza (RHEL 7)

```bash
/etc/pki/ca-trust/
├── source/
│   └── anchors/                   ← Agregar CAs personalizadas aquí
│
└── extracted/
    ├── pem/
    │   └── tls-ca-bundle.pem      ← OpenSSL, Python, Ruby
    ├── openssl/
    │   └── ca-bundle.trust.crt    ← Específico de OpenSSL
    └── java/
        └── cacerts                ← Aplicaciones Java
```

---

## 9.4 Configuración de Servicios (Enfoque RHEL 7)

### Apache HTTPS en RHEL 7

```bash
#============================================#
# CONFIGURACIÓN SSL/TLS DE APACHE (RHEL 7)
#============================================#

# Instalar Apache con SSL
sudo yum install httpd mod_ssl -y

# Generar certificado y clave
sudo openssl genrsa -out /etc/pki/tls/private/server.key 2048
sudo openssl req -new -key /etc/pki/tls/private/server.key \
  -out /tmp/server.csr \
  -subj "/CN=$(hostname -f)"

# Obtener certificado de CA (o autofirmado para pruebas)
sudo openssl x509 -req -days 365 -in /tmp/server.csr \
  -signkey /etc/pki/tls/private/server.key \
  -out /etc/pki/tls/certs/server.crt

# Configurar Apache (/etc/httpd/conf.d/ssl.conf)
sudo vi /etc/httpd/conf.d/ssl.conf
# Establecer:
#   SSLCertificateFile /etc/pki/tls/certs/server.crt
#   SSLCertificateKeyFile /etc/pki/tls/private/server.key
#
#   # Recomendado: Deshabilitar versiones TLS débiles
#   SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
#
#   # Recomendado: Solo cifrados fuertes
#   SSLCipherSuite HIGH:!aNULL:!MD5:!3DES:!RC4

# Iniciar Apache
sudo systemctl enable httpd
sudo systemctl start httpd

# Probar
curl -vk https://localhost/
```

### NGINX en RHEL 7

```bash
#============================================#
# CONFIGURACIÓN SSL/TLS DE NGINX (RHEL 7)
#============================================#

# Instalar NGINX (desde EPEL)
sudo yum install epel-release -y
sudo yum install nginx -y

# Generar certificado
sudo openssl genrsa -out /etc/pki/tls/private/nginx.key 2048
sudo openssl req -new -x509 -days 365 \
  -key /etc/pki/tls/private/nginx.key \
  -out /etc/pki/tls/certs/nginx.crt \
  -subj "/CN=$(hostname -f)"

# Configurar NGINX (/etc/nginx/nginx.conf)
# Agregar al bloque de servidor:
#   listen 443 ssl;
#   ssl_certificate /etc/pki/tls/certs/nginx.crt;
#   ssl_certificate_key /etc/pki/tls/private/nginx.key;
#
#   # Recomendado
#   ssl_protocols TLSv1.2;
#   ssl_ciphers HIGH:!aNULL:!MD5;

# Iniciar NGINX
sudo systemctl enable nginx
sudo systemctl start nginx
```

---

## 9.5 Renovación Manual de Certificados (RHEL 7)

**Sin crypto-policies, sin herramientas automáticas - ¡todo es manual!**

### Proceso de Renovación

```bash
#============================================#
# PROCESO DE RENOVACIÓN MANUAL (RHEL 7)
#============================================#

# Paso 1: Verificar expiración (configurar recordatorio de calendario)
openssl x509 -in /etc/pki/tls/certs/server.crt -noout -dates

# Paso 2: Generar nuevo CSR (reutilizar clave existente)
openssl req -new -key /etc/pki/tls/private/server.key \
  -out /tmp/server-renewal.csr \
  -subj "/CN=server.example.com"

# Paso 3: Enviar CSR a CA

# Paso 4: Recibir nuevo certificado de CA

# Paso 5: Hacer respaldo del certificado antiguo
sudo cp /etc/pki/tls/certs/server.crt \
     /etc/pki/tls/certs/server.crt.$(date +%Y%m%d).old

# Paso 6: Instalar nuevo certificado
sudo cp new-server.crt /etc/pki/tls/certs/server.crt
sudo chmod 644 /etc/pki/tls/certs/server.crt

# Paso 7: Recargar servicio
sudo systemctl reload httpd

# Paso 8: Probar
curl -v https://localhost/
openssl s_client -connect localhost:443
```

### Rastrear Renovaciones de Certificados

```bash
#============================================#
# CREAR RASTREO DE RENOVACIÓN (RHEL 7)
#============================================#

# Tarea cron para verificar expiración
cat > /etc/cron.weekly/check-cert-expiration << 'EOF'
#!/bin/bash
# Verificar certificados que expiran en 60 días

for cert in /etc/pki/tls/certs/*.crt; do
  [ -f "$cert" ] || continue

  if ! openssl x509 -in "$cert" -noout -checkend $((86400*60)); then
    echo "⚠️ $cert expira dentro de 60 días!"
    echo "$cert" | mail -s "Certificado Expirando Pronto" admin@example.com
  fi
done
EOF

chmod +x /etc/cron.weekly/check-cert-expiration
```

---

## 9.6 Problemas Comunes de Certificados en RHEL 7

### Problema 1: TLS 1.0/1.1 Obsoleto

**Problema:** Los clientes modernos rechazan TLS 1.0/1.1

**Síntomas:**
```bash
curl: (35) error:14094410:SSL routines:ssl3_read_bytes:sslv3 alert handshake failure
```

**Solución:**
```bash
# Actualizar Apache para deshabilitar versiones TLS antiguas
# /etc/httpd/conf.d/ssl.conf
SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1

# Reiniciar Apache
sudo systemctl restart httpd
```

### Problema 2: Cifrados Débiles

**Problema:** Los escaneos PCI/Seguridad marcan cifrados débiles

**Solución:**
```bash
# Apache: Usar solo cifrados fuertes
# /etc/httpd/conf.d/ssl.conf
SSLCipherSuite HIGH:!aNULL:!MD5:!3DES:!RC4:!EXPORT
SSLHonorCipherOrder on

# Probar
openssl s_client -connect localhost:443 -cipher '3DES'
# Debería fallar si 3DES está deshabilitado
```

### Problema 3: SANs Faltantes

**Problema:** Los navegadores modernos requieren Subject Alternative Names

**Desafío RHEL 7:** Los SANs son más difíciles de agregar con OpenSSL 1.0.2

**Solución: Usar archivo de configuración**
```bash
# Crear configuración OpenSSL
cat > /tmp/san.cnf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]
CN = server.example.com

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = server.example.com
DNS.2 = www.example.com
IP.1 = 10.0.0.100
EOF

# Generar CSR con SANs
openssl req -new -key server.key -out server.csr -config /tmp/san.cnf

# Verificar SANs en CSR
openssl req -in server.csr -noout -text | grep -A3 "Subject Alternative Name"
```

---

## 9.7 certmonger en RHEL 7

**Disponible:** Sí (versión básica)

```bash
#============================================#
# CERTMONGER EN RHEL 7
#============================================#

# Instalar
sudo yum install certmonger -y
sudo systemctl enable certmonger
sudo systemctl start certmonger

# Solicitar certificado de FreeIPA
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/web.crt \
  -k /etc/pki/tls/private/web.key \
  -K host/$(hostname -f)@REALM

# Listar certificados rastreados
sudo getcert list

# Verificar estado de certificado específico
sudo getcert list -f /etc/pki/tls/certs/web.crt

# Monitorear logs de certmonger
sudo tail -f /var/log/messages | grep certmonger
```

**Limitaciones de RHEL 7:**
- Sin soporte ACME (Let's Encrypt requiere certbot manual)
- Salida de estado menos detallada
- Menos opciones de comandos post-guardado

---

## 9.8 Consideraciones de Migración

### Cuándo Migrar desde RHEL 7

**Deberías migrar si:**
- ✅ El soporte terminó (junio 2024) y necesitas actualizaciones
- ✅ Necesitas soporte TLS 1.3
- ✅ Quieres crypto-policies para gestión más fácil
- ✅ Requieres características de seguridad modernas
- ✅ El cumplimiento requiere SO soportado

### Tareas de Certificados Pre-Migración

```bash
#============================================#
# AUDITORÍA DE CERTIFICADOS PRE-MIGRACIÓN RHEL 7
#============================================#

# 1. Listar todos los certificados
find /etc/pki/tls/ -name "*.crt" -o -name "*.key"

# 2. Verificar expiraciones
for cert in /etc/pki/tls/certs/*.crt; do
  echo "=== $cert ==="
  openssl x509 -in "$cert" -noout -subject -dates
  echo ""
done

# 3. Verificar algoritmos de firma (SHA-1 no funcionará en RHEL 8+)
for cert in /etc/pki/tls/certs/*.crt; do
  SIG=$(openssl x509 -in "$cert" -noout -text | grep "Signature Algorithm" | head -2)
  echo "$cert: $SIG"
done | grep -i sha1
# ¡Si se encuentra alguno, reemitir antes de migración!

# 4. Documentar CAs personalizadas
ls -l /etc/pki/ca-trust/source/anchors/

# 5. Exportar certificados y claves
tar czf rhel7-certificates-backup-$(date +%Y%m%d).tar.gz \
  /etc/pki/tls/certs/*.crt \
  /etc/pki/tls/private/*.key \
  /etc/pki/ca-trust/source/anchors/*
```

---

## 9.9 Flujos de Trabajo Comunes en RHEL 7

### Flujo de Trabajo 1: Configuración Manual de Apache HTTPS

```bash
# Flujo de trabajo completo desde cero

# 1. Instalar Apache con SSL
sudo yum install httpd mod_ssl -y

# 2. Generar clave privada
sudo openssl genrsa -out /etc/pki/tls/private/$(hostname -s).key 2048

# 3. Establecer permisos de clave
sudo chmod 600 /etc/pki/tls/private/$(hostname -s).key

# 4. Crear CSR
sudo openssl req -new \
  -key /etc/pki/tls/private/$(hostname -s).key \
  -out /tmp/$(hostname -s).csr \
  -subj "/C=US/O=Company/CN=$(hostname -f)"

# 5. Enviar CSR a CA, esperar certificado

# 6. Instalar certificado
sudo cp $(hostname -s).crt /etc/pki/tls/certs/

# 7. Configurar Apache
sudo vi /etc/httpd/conf.d/ssl.conf
# Editar:
#   SSLCertificateFile /etc/pki/tls/certs/$(hostname -s).crt
#   SSLCertificateKeyFile /etc/pki/tls/private/$(hostname -s).key
#   SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
#   SSLCipherSuite HIGH:!aNULL:!MD5:!3DES

# 8. Probar configuración
sudo apachectl configtest

# 9. Abrir firewall
sudo firewall-cmd --add-service=https --permanent
sudo firewall-cmd --reload

# 10. Iniciar Apache
sudo systemctl enable httpd
sudo systemctl start httpd

# 11. Probar
curl -vk https://$(hostname -f)/
```

### Flujo de Trabajo 2: Integración con FreeIPA

```bash
#============================================#
# FLUJO DE TRABAJO DE CERTIFICADO FREEIPA (RHEL 7)
#============================================#

# Prerrequisitos: El sistema debe estar inscrito en IPA
ipa-client-install

# Instalar certmonger
sudo yum install certmonger -y
sudo systemctl enable certmonger
sudo systemctl start certmonger

# Solicitar certificado para Apache
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/$(hostname -s).crt \
  -k /etc/pki/tls/private/$(hostname -s).key \
  -K host/$(hostname -f)@REALM.EXAMPLE.COM \
  -D $(hostname -f)

# Verificar estado
sudo getcert list

# Esperar estado MONITORING (certificado emitido)

# Configurar Apache para usar cert
# /etc/httpd/conf.d/ssl.conf

# Recargar Apache cuando el cert se renueve
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/$(hostname -s).crt \
  -k /etc/pki/tls/private/$(hostname -s).key \
  -K host/$(hostname -f)@REALM \
  -C "systemctl reload httpd"
```

---

## 9.10 Solución de Problemas de Certificados en RHEL 7

### Comandos de Diagnóstico

```bash
#============================================#
# DIAGNÓSTICO DE CERTIFICADOS RHEL 7
#============================================#

# Verificar versión de OpenSSL
openssl version

# Probar HTTPS localmente
openssl s_client -connect localhost:443

# Verificar configuración SSL de Apache
sudo apachectl -t -D DUMP_VHOSTS | grep 443

# Ver errores SSL de Apache
sudo tail -f /var/log/httpd/ssl_error_log

# Verificar denegaciones SELinux
sudo grep AVC /var/log/audit/audit.log | grep cert

# Verificar permisos de archivos
ls -lZ /etc/pki/tls/certs/*.crt
ls -lZ /etc/pki/tls/private/*.key

# Verificar par certificado/clave
openssl x509 -noout -modulus -in /etc/pki/tls/certs/server.crt | openssl md5
openssl rsa -noout -modulus -in /etc/pki/tls/private/server.key | openssl md5
# Los hashes MD5 deberían coincidir
```

### Errores Comunes de RHEL 7

| Error | Causa | Solución |
|-------|-------|----------|
| "certificate verify failed" | CA faltante en almacén de confianza | Agregar CA a /etc/pki/ca-trust/source/anchors/ |
| "permission denied" en clave | Permisos incorrectos | chmod 600 en archivo .key |
| "certificate has expired" | Certificado expirado | Renovar certificado manualmente |
| "no shared cipher" | Desajuste de cifrado cliente/servidor | Actualizar SSLCipherSuite |
| "wrong version number" | Desajuste de versión TLS | Actualizar SSLProtocol |

---

## 9.11 Fortalecimiento de Seguridad en RHEL 7

### Configuración Recomendada

```bash
#============================================#
# ENDURECIMIENTO SSL/TLS DE APACHE (RHEL 7)
#============================================#

# /etc/httpd/conf.d/ssl.conf

# Deshabilitar protocolos antiguos
SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1

# Solo cifrados fuertes
SSLCipherSuite ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!3DES:!DES

# Honrar preferencia de cifrado del servidor
SSLHonorCipherOrder on

# Habilitar HSTS (HTTP Strict Transport Security)
Header always set Strict-Transport-Security "max-age=31536000"

# OCSP Stapling (no disponible en OpenSSL 1.0.2 de RHEL 7 por defecto)
# Disponible en algunos backports

# Perfect Forward Secrecy
SSLCipherSuite ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256
```

---

## 9.12 Ruta de Migración a RHEL 8+

### Pasos de Migración Específicos de Certificados

```bash
#============================================#
# PREPARAR CERTIFICADOS PARA MIGRACIÓN
#============================================#

# 1. Verificar que todos los certificados usen SHA-256+ (sin SHA-1 ni MD5)
for cert in /etc/pki/tls/certs/*.crt; do
  openssl x509 -in "$cert" -noout -text | grep "Signature Algorithm"
done | grep -i sha1 && echo "⚠️ ¡Certificados SHA-1 encontrados! ¡Reemitir antes de migración!"

# 2. Verificar tamaños de clave (2048+ bits)
for cert in /etc/pki/tls/certs/*.crt; do
  SIZE=$(openssl x509 -in "$cert" -noout -text | grep "Public-Key" | grep -oP '\d+')
  if [ "$SIZE" -lt 2048 ]; then
    echo "⚠️ $cert: Clave muy pequeña ($SIZE bits)"
  fi
done

# 3. Respaldar todo
tar czf rhel7-certs-$(hostname)-$(date +%Y%m%d).tar.gz \
  /etc/pki/tls/ \
  /etc/pki/ca-trust/source/anchors/ \
  /etc/httpd/conf.d/ssl.conf \
  /etc/nginx/nginx.conf

# 4. Documentar inventario de certificados
./generate-cert-inventory.sh > cert-inventory-pre-migration.csv

# 5. Probar compatibilidad TLS 1.2
# Asegurar que todos los servicios funcionen solo con TLS 1.2
```

---

## 9.13 Cuándo RHEL 7 Tiene Sentido

### ¿Aún Usando RHEL 7? Considera:

**Razones para Quedarse (Temporalmente):**
- Contrato de Soporte de Ciclo de Vida Extendido activo
- Aplicaciones legacy críticas que requieren TLS 1.0/1.1
- Migración planificada para futuro cercano
- Probando RHEL 8/9 en paralelo

**Razones para Migrar:**
- ✅ Mantenimiento extendido terminó en junio 2024
- ✅ Sin crypto-policies (más difícil de gestionar)
- ✅ Sin TLS 1.3
- ✅ Actualizaciones de seguridad limitadas
- ✅ Aplicaciones modernas dejando de soportar TLS 1.0/1.1

---

## 9.14 Conclusiones Clave

1. **RHEL 7 es manual** - Sin crypto-policies, se necesita configuración cuidadosa
2. **OpenSSL 1.0.2k** - Sintaxis antigua, sin TLS 1.3
3. **TLS 1.0/1.1 habilitado por defecto** - Deshabilitarlos manualmente
4. **SHA-1 aún funciona** - Pero no después de migración a RHEL 8+
5. **certmonger disponible** - Pero básico comparado con RHEL 8+
6. **Planificar migración** - El soporte de RHEL 7 está terminando
7. **Documentar todo** - Facilita la migración

---

## Referencia Rápida

```
┌─────────────────────────────────────────────────────────┐
│ REFERENCIA RÁPIDA DE CERTIFICADOS RHEL 7                │
├─────────────────────────────────────────────────────────┤
│ OpenSSL:     1.0.2k-26                                  │
│ TLS:         1.0, 1.1, 1.2 (no 1.3)                     │
│ Política:    Configuración manual (sin crypto-policies) │
│                                                         │
│ Generar:     openssl genrsa -out key.pem 2048           │
│ CSR:         openssl req -new -key key.pem -out req.csr │
│ Ver:         openssl x509 -in cert.crt -noout -text     │
│ Probar:      openssl s_client -connect host:443         │
│                                                         │
│ Fortalecer:  SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1     │
│              SSLCipherSuite HIGH:!aNULL:!MD5:!3DES      │
└─────────────────────────────────────────────────────────┘
```
---

**Navegación del Capítulo**

| [← Anterior: Capítulo 8 - Versiones de RHEL y Evolución de Certificados](08-rhel-versions-overview.md) | [Siguiente: Capítulo 10 - RHEL 8 y Crypto-Policies →](10-rhel8-crypto-policies.md) |
|:---|---:|
