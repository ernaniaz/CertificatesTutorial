# Capítulo 20: Otros Servicios RHEL con Certificados

> **Más Allá de lo Básico:** Muchos otros servicios RHEL usan certificados. Este capítulo cubre Cockpit, servicios VPN, registros de contenedores y más.

---

## 20.1 Servicios Cubiertos

Este capítulo proporciona guías de inicio rápido para:

- 🖥️ **Cockpit** (Consola de administración basada en web)
- 🔒 **OpenVPN** (Servicio VPN)
- 🛡️ **strongSwan** (VPN IPsec)
- 📦 **Registro de Contenedores** (Registro Podman/Docker)
- 📡 **HAProxy** (Balanceador de carga)
- 🔌 **Redis** con TLS (usando stunnel)
- ⚙️ **Ansible Tower/AWX** (Plataforma de automatización)

---

## 20.2 Consola Web Cockpit

### ¿Qué es Cockpit?

**Cockpit** es la interfaz de administración basada en web integrada de RHEL.

**Predeterminado:** Usa certificado autofirmado
**Objetivo:** Reemplazar con certificado apropiado

### Configurar Cockpit con Certificados

```bash
#============================================#
# COCKPIT CON CERTIFICADO APROPIADO
#============================================#

# Instalar Cockpit
sudo dnf install cockpit -y
sudo systemctl enable --now cockpit.socket

# Abrir firewall
sudo firewall-cmd --add-service=cockpit --permanent
sudo firewall-cmd --reload

# Ubicación de certificado de Cockpit
ls -l /etc/cockpit/ws-certs.d/

# Método 1: Colocar certificado con nombre específico
# Cockpit usa certificados en /etc/cockpit/ws-certs.d/
# Formato de nombre de archivo: NN-name.cert (donde NN = prioridad, menor = mayor prioridad)

sudo cat server.crt server.key > /etc/cockpit/ws-certs.d/01-server.cert
sudo chmod 644 /etc/cockpit/ws-certs.d/01-server.cert

# Reiniciar Cockpit
sudo systemctl restart cockpit.socket

# Método 2: Usar certmonger
sudo ipa-getcert request \
  -f /etc/cockpit/ws-certs.d/01-cockpit.cert \
  -k /etc/cockpit/ws-certs.d/01-cockpit.cert \
  -K HTTP/$(hostname -f)@REALM \
  -D $(hostname -f) \
  -C "systemctl restart cockpit.socket" \
  -F /etc/cockpit/ws-certs.d/01-cockpit.cert  # Cert+clave combinados

# Acceder a Cockpit
# https://server.example.com:9090/
```

**Nota:** ¡Cockpit espera cert+clave combinados en un solo archivo!

---

## 20.3 OpenVPN

### Configuración de Servidor con Certificados

```bash
#============================================#
# SERVIDOR OPENVPN CON CERTIFICADOS
#============================================#

# Instalar OpenVPN (de EPEL en RHEL 7, repos en RHEL 8+)
sudo dnf install openvpn -y

# Generar u obtener certificados:
# - Certificado CA
# - Certificado de servidor + clave
# - Certificados de cliente

# /etc/openvpn/server/server.conf
port 1194
proto udp
dev tun

ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key /etc/openvpn/server/server.key
dh /etc/openvpn/server/dh2048.pem

tls-auth /etc/openvpn/server/ta.key 0
cipher AES-256-GCM
auth SHA256

server 10.8.0.0 255.255.255.0

# Iniciar OpenVPN
sudo systemctl enable --now openvpn-server@server

# Abrir firewall
sudo firewall-cmd --add-port=1194/udp --permanent
sudo firewall-cmd --reload
```

### Probar OpenVPN

```bash
# Verificar si está ejecutándose
systemctl status openvpn-server@server

# Probar desde cliente
openvpn --config client.ovpn --verb 3
```

---

## 20.4 strongSwan IPsec VPN

### Configurar con Certificados

```bash
#============================================#
# STRONGSWAN CON CERTIFICADOS
#============================================#

# Instalar
sudo dnf install strongswan -y

# Ubicaciones de certificados
# CA: /etc/strongswan/ipsec.d/cacerts/
# Certs Servidor/Cliente: /etc/strongswan/ipsec.d/certs/
# Claves privadas: /etc/strongswan/ipsec.d/private/

# Copiar certificados
sudo cp ca.crt /etc/strongswan/ipsec.d/cacerts/
sudo cp server.crt /etc/strongswan/ipsec.d/certs/
sudo cp server.key /etc/strongswan/ipsec.d/private/
sudo chmod 600 /etc/strongswan/ipsec.d/private/server.key

# /etc/strongswan/ipsec.conf
config setup
    charondebug="ike 2, knl 2, cfg 2"

conn example-ipsec
    left=%any
    leftid=@server.example.com
    leftcert=server.crt
    leftsubnet=10.0.0.0/24

    right=%any
    rightid=@client.example.com
    rightcert=client.crt

    auto=add
    type=tunnel
    keyexchange=ikev2

# Iniciar strongSwan
sudo systemctl enable --now strongswan

# Verificar estado
sudo swanctl --list-sas
```

---

## 20.5 Registro de Contenedores con TLS

### Registro Podman/Docker

```bash
#============================================#
# REGISTRO DE CONTENEDOR CON TLS
#============================================#

# Instalar registry
sudo dnf install -y podman
sudo podman pull docker.io/library/registry:2

# Crear certificado para registry
sudo mkdir -p /etc/registry/certs
sudo openssl genpkey -algorithm RSA \
  -out /etc/registry/certs/registry.key \
  -pkeyopt rsa_keygen_bits:2048

sudo openssl req -new -x509 -days 365 \
  -key /etc/registry/certs/registry.key \
  -out /etc/registry/certs/registry.crt \
  -subj "/CN=registry.example.com" \
  -addext "subjectAltName=DNS:registry.example.com"

# Ejecutar registry con TLS
sudo podman run -d \
  --name registry \
  -p 5000:5000 \
  -v /etc/registry/certs:/certs:ro \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
  registry:2

# Probar
curl https://registry.example.com:5000/v2/_catalog
```

### Configuración de Cliente

```bash
# Agregar CA del registry al almacén de confianza del sistema
sudo cp /etc/registry/certs/registry.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust

# Probar pull
podman pull registry.example.com:5000/myimage:latest
```

---

## 20.6 Terminación TLS de HAProxy

### Balanceador de Carga con TLS

```bash
#============================================#
# TERMINACIÓN TLS HAPROXY
#============================================#

# Instalar HAProxy
sudo dnf install haproxy -y

# HAProxy requiere cert+clave+cadena combinados en UN archivo
cat server.crt intermediate.crt server.key > /etc/haproxy/certs/bundle.pem
sudo chmod 600 /etc/haproxy/certs/bundle.pem

# /etc/haproxy/haproxy.cfg
frontend https-in
    bind *:443 ssl crt /etc/haproxy/certs/bundle.pem
    mode http
    default_backend web_servers

    # Forzar HTTPS
    http-request redirect scheme https unless { ssl_fc }

    # Encabezados de seguridad
    http-response set-header Strict-Transport-Security "max-age=31536000"

backend web_servers
    mode http
    balance roundrobin
    server web1 10.0.1.10:80 check
    server web2 10.0.1.11:80 check
    server web3 10.0.1.12:80 check

# Iniciar HAProxy
sudo systemctl enable --now haproxy

# Probar
curl -v https://loadbalancer.example.com/
```

---

## 20.7 Redis con TLS (vía stunnel)

### Proxy TLS de Redis

```bash
#============================================#
# REDIS CON TLS USANDO STUNNEL
#============================================#

# Instalar Redis y stunnel
sudo dnf install redis stunnel -y

# Configurar Redis (escuchar solo en localhost)
# /etc/redis/redis.conf
bind 127.0.0.1

# Iniciar Redis
sudo systemctl enable --now redis

# Configurar stunnel
# /etc/stunnel/redis.conf
[redis-tls]
accept = 0.0.0.0:6380
connect = 127.0.0.1:6379
cert = /etc/pki/tls/certs/redis.crt
key = /etc/pki/tls/private/redis.key
CAfile = /etc/pki/tls/certs/ca-bundle.crt

# Opcional: Requerir certificados de cliente
verify = 2
CApath = /etc/pki/tls/certs/

# Iniciar stunnel
sudo systemctl enable --now stunnel@redis

# Probar
openssl s_client -connect localhost:6380
# Luego escribir: PING
# Debería responder: +PONG
```

---

## 20.8 Ansible Tower/AWX

### Tower/AWX con Certificado Personalizado

```bash
#============================================#
# CERTIFICADO PERSONALIZADO ANSIBLE TOWER/AWX
#============================================#

# Ubicación de certificado de Tower
# /etc/tower/tower.cert
# /etc/tower/tower.key

# Reemplazar con certificado apropiado
sudo cp tower.example.com.crt /etc/tower/tower.cert
sudo cp tower.example.com.key /etc/tower/tower.key
sudo chmod 600 /etc/tower/tower.key

# Reiniciar servicios de Tower
sudo ansible-tower-service restart

# O para AWX (containerizado)
# Actualizar docker-compose.yml o secretos k8s

# Probar
curl -v https://tower.example.com/
```

---

## 20.9 SSH con Certificados (Avanzado)

### Autenticación de Certificado SSH

**Nota:** ¡Diferente de claves SSH! Esto usa certificados X.509.

```bash
#============================================#
# SSH CON CERTIFICADOS X.509 (AVANZADO)
#============================================#

# Requiere: openssh-server con parche X.509 o ssh-keysign

# Generar certificado para usuario SSH
openssl genpkey -algorithm RSA -out ssh-user.key -pkeyopt rsa_keygen_bits:2048
openssl req -new -key ssh-user.key -out ssh-user.csr -subj "/CN=user@example.com"
# Obtener firmado por CA

# Configurar sshd (experimental, no estándar RHEL)
# /etc/ssh/sshd_config
# X509KeyAlgorithm x509v3-rsa2048-sha256
# X509TrustAnchor /etc/ssh/ca.crt

# Enfoque estándar: Usar claves SSH, no X.509
# El soporte X.509 SSH es limitado en RHEL
```

**Recomendación:** Usar autenticación basada en claves SSH estándar para SSH, usar X.509 para otros servicios.

---

## 20.10 Monitorear Múltiples Servicios

### Verificación de Certificados Multi-Servicio

```bash
#!/bin/bash
# check-all-services.sh
# Verificar certificados para todos los servicios

echo "=== Verificación de Certificados Multi-Servicio ==="

# Apache
echo "1. Apache (puerto 443):"
timeout 3 openssl s_client -connect localhost:443 </dev/null 2>&1 | grep -E "(subject=|issuer=)" | head -2

# NGINX (si está instalado)
echo "2. NGINX (puerto 8443 o personalizado):"
timeout 3 openssl s_client -connect localhost:8443 </dev/null 2>&1 | grep -E "(subject=|issuer=)" | head -2

# Postfix
echo "3. Postfix SMTPS (puerto 465):"
timeout 3 openssl s_client -connect localhost:465 </dev/null 2>&1 | grep -E "(subject=|issuer=)" | head -2

# LDAPS
echo "4. LDAP (puerto 636):"
timeout 3 openssl s_client -connect localhost:636 </dev/null 2>&1 | grep -E "(subject=|issuer=)" | head -2

# PostgreSQL
echo "5. PostgreSQL (puerto 5432):"
sudo -u postgres psql -c "SHOW ssl;" 2>/dev/null

# Cockpit
echo "6. Cockpit (puerto 9090):"
timeout 3 openssl s_client -connect localhost:9090 </dev/null 2>&1 | grep -E "(subject=|issuer=)" | head -2

# Rastreo de certmonger
echo ""
echo "7. Certificados rastreados por certmonger:"
sudo getcert list | grep -c "Request ID"
echo "total de certificados rastreados"

echo ""
echo "=== Verificación Completa ==="
```

---

## 20.11 Referencias Rápidas Específicas por Servicio

### Cockpit

```bash
# Instalar: dnf install cockpit
# Ubicación cert: /etc/cockpit/ws-certs.d/
# Formato: Cert+clave combinados
# Recargar: systemctl restart cockpit.socket
# Probar: https://server:9090/
```

### OpenVPN

```bash
# Instalar: dnf install openvpn (EPEL)
# Ubicación cert: /etc/openvpn/server/
# Archivos: ca.crt, server.crt, server.key
# Iniciar: systemctl start openvpn-server@server
# Probar: openvpn --config client.ovpn
```

### strongSwan

```bash
# Instalar: dnf install strongswan
# Ubicación cert: /etc/strongswan/ipsec.d/
# Subdirectorios: cacerts/, certs/, private/
# Iniciar: systemctl start strongswan
# Probar: swanctl --list-sas
```

### HAProxy

```bash
# Instalar: dnf install haproxy
# Formato cert: PEM combinado (cert+clave+cadena)
# Ubicación: /etc/haproxy/certs/
# Config: bind *:443 ssl crt /path/to/bundle.pem
# Probar: curl -v https://loadbalancer/
```

### Registro de Contenedor

```bash
# Ejecutar: podman run -d -p 5000:5000 registry:2
# Certs: Montar como volúmenes (-v)
# Variables de entorno: REGISTRY_HTTP_TLS_CERTIFICATE
#                       REGISTRY_HTTP_TLS_KEY
# Probar: curl https://registry:5000/v2/_catalog
```

---

## 20.12 Certificados Comodín para Múltiples Servicios

### Cuándo Usar Comodines

**Escenario:** Múltiples subdominios en el mismo servidor

```
web.example.com    → Apache
api.example.com    → NGINX
admin.example.com  → Cockpit
mail.example.com   → Postfix
```

**Solución:** Usar certificado comodín `*.example.com`

### Generar Certificado Comodín

```bash
#============================================#
# CERTIFICADO COMODÍN
#============================================#

# Generar clave
openssl genpkey -algorithm RSA -out wildcard.key -pkeyopt rsa_keygen_bits:2048

# Generar CSR
openssl req -new -key wildcard.key -out wildcard.csr \
  -subj "/CN=*.example.com" \
  -addext "subjectAltName=DNS:*.example.com,DNS:example.com"

# Enviar a CA, recibir wildcard.crt

# Usar para múltiples servicios
sudo cp wildcard.crt /etc/pki/tls/certs/
sudo cp wildcard.key /etc/pki/tls/private/
sudo chmod 600 /etc/pki/tls/private/wildcard.key

# Configurar cada servicio para usarlo
# Apache: SSLCertificateFile /etc/pki/tls/certs/wildcard.crt
# NGINX: ssl_certificate /etc/pki/tls/certs/wildcard.crt
# Postfix: smtpd_tls_cert_file = /etc/pki/tls/certs/wildcard.crt
```

**Pros:**
- ✅ Un certificado para múltiples subdominios
- ✅ Gestión más fácil
- ✅ Rentable (si se compra)

**Contras:**
- ⚠️ Si se compromete, afecta todos los subdominios
- ⚠️ No funciona para multi-nivel (*.*.example.com)
- ⚠️ Algunas políticas de seguridad prohíben comodines

---

## 20.13 Matriz de Certificados por Servicio

### Requisitos de Certificado por Servicio

| Servicio | CN/SAN | Cert Cliente | Renovación Auto | Notas Especiales |
|----------|--------|--------------|-----------------|------------------|
| **Apache** | Requerido | Opcional (mTLS) | certmonger | Más común |
| **NGINX** | Requerido | Opcional (mTLS) | certmonger | Alto rendimiento |
| **Postfix** | Requerido | Opcional | certmonger | SMTP/SMTPS |
| **OpenLDAP** | Requerido | Opcional | certmonger | Debe ser legible por usuario ldap |
| **PostgreSQL** | Requerido | Opcional | Manual o script | Ownership usuario postgres |
| **MySQL** | Requerido | Opcional | Manual o script | Ownership usuario mysql |
| **FreeIPA** | Automático | N/A | Automático | Auto-gestionado |
| **Cockpit** | Requerido | No | certmonger | Archivo cert+clave combinado |
| **OpenVPN** | Requerido | Requerido | Manual | PKI complejo |
| **strongSwan** | Requerido | Requerido | Manual | Específico IPsec |
| **HAProxy** | Requerido | No | certmonger | Formato PEM combinado |
| **Registry** | Requerido | Opcional | Manual | Específico contenedor |

---

## 20.14 Guía Rápida de Solución de Problemas

### Solución de Problemas TLS Genérica de Servicio

```bash
#============================================#
# SOLUCIÓN DE PROBLEMAS TLS UNIVERSAL
#============================================#

# 1. Identificar servicio y puerto
ss -tlnp | grep <servicio>

# 2. Verificar si TLS está habilitado
# (comando específico del servicio)

# 3. Probar conexión TLS
openssl s_client -connect localhost:<puerto>
# O con STARTTLS:
openssl s_client -connect localhost:<puerto> -starttls <protocolo>

# 4. Verificar archivos de certificado
ls -lZ /path/to/certs/

# 5. Verificar ownership/permisos
# - Certificado: 644, propiedad del usuario del servicio
# - Clave: 600, propiedad del usuario del servicio

# 6. Verificar configuración
# (archivo de configuración específico del servicio)

# 7. Verificar logs
sudo journalctl -u <servicio> | grep -i tls
sudo tail -f /var/log/<servicio>/ | grep -i tls

# 8. Probar desde cliente remoto
openssl s_client -connect server.example.com:<puerto>
```

---

## 20.15 Gestión Centralizada de Certificados

### Usar certmonger para Todos los Servicios

```bash
#============================================#
# ESTRATEGIA DE GESTIÓN CENTRALIZADA DE CERTIFICADOS
#============================================#

# Rastrear todos los certificados de servicio con certmonger

# Apache
sudo ipa-getcert request -f /etc/pki/tls/certs/apache.crt \
  -k /etc/pki/tls/private/apache.key \
  -K HTTP/$(hostname -f)@REALM \
  -C "systemctl reload httpd"

# NGINX
sudo ipa-getcert request -f /etc/pki/tls/certs/nginx.crt \
  -k /etc/pki/tls/private/nginx.key \
  -K HTTP/$(hostname -f)@REALM \
  -C "systemctl reload nginx"

# Postfix
sudo ipa-getcert request -f /etc/pki/tls/certs/postfix.crt \
  -k /etc/pki/tls/private/postfix.key \
  -K smtp/$(hostname -f)@REALM \
  -C "postfix reload"

# OpenLDAP
sudo ipa-getcert request -f /etc/openldap/certs/ldap.crt \
  -k /etc/openldap/certs/ldap.key \
  -K ldap/$(hostname -f)@REALM \
  -o ldap:ldap \
  -m 600 \
  -C "systemctl restart slapd"

# Monitorear todos
sudo getcert list
```

**Beneficios:**
- ✅ Herramienta única para todos los servicios
- ✅ Renovación automática
- ✅ Monitoreo centralizado
- ✅ Enfoque consistente

---

## 20.16 Conclusiones Clave

1. **Muchos servicios usan certificados** más allá de servidores web
2. **Cada servicio tiene requisitos únicos** - Verificar ownership, permisos
3. **certmonger funciona con la mayoría** de servicios para automatización
4. **Certificados comodín** pueden simplificar configuraciones multi-servicio
5. **Probar cada servicio** independientemente
6. **Rastreo centralizado** con certmonger recomendado
7. **Documentar configuraciones** específicas de servicio

---

## Tarjeta de Referencia Rápida

```
┌───────────────────────────────────────────────────────────────┐
│ REFERENCIA RÁPIDA CERTIFICADOS OTROS SERVICIOS                │
├───────────────────────────────────────────────────────────────┤
│ Cockpit:     /etc/cockpit/ws-certs.d/NN-name.cert             │
│              (cert+clave combinados)                          │
│                                                               │
│ OpenVPN:     /etc/openvpn/server/{ca,server}.{crt,key}        │
│              PKI complejo con certs de cliente                │
│                                                               │
│ strongSwan:  /etc/strongswan/ipsec.d/{cacerts,certs,private}/ │
│              Configuración específica IPsec                   │
│                                                               │
│ HAProxy:     PEM combinado (cert+clave+cadena en un archivo)  │
│              /etc/haproxy/certs/bundle.pem                    │
│                                                               │
│ Registry:    Variables de entorno para contenedor             │
│              REGISTRY_HTTP_TLS_CERTIFICATE/KEY                │
│                                                               │
│ Genérico:    Verificar ownership, permisos, SELinux           │
│              Probar con: openssl s_client -connect :port      │
└───────────────────────────────────────────────────────────────┘

✅ Usar certmonger para automatización donde sea posible
✅ Cada servicio tiene requisitos únicos de formato/ubicación de archivo
```
---

**Navegación del Capítulo**

| [← Anterior: Capítulo 19 - Servicios de Certificados FreeIPA](19-freeipa-services.md) | [Siguiente: Capítulo 21 - Mejores Prácticas para Certificados de Servicios →](21-service-best-practices.md) |
|:---|---:|
