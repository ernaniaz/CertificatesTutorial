# Lab 13: Let's Encrypt con Certbot

## Objetivos de aprendizaje

Al completar este lab, usted:
- Instalará Certbot para el protocolo ACME
- Obtendrá certificados de Let's Encrypt
- Configurará la renovación automática
- Integrará con Apache y NGINX
- Probará el proceso de renovación
- Configurará timers de systemd para automatización
- Comprenderá los tipos de desafío ACME

## Requisitos previos

- **Labs 01-06** completados (conocimiento de Apache o NGINX)
- **Versión de RHEL:** 8, 9 o 10 (RHEL 7 no es compatible)
- **Acceso al sistema:** Se requiere root/sudo
- **Conexión a Internet** requerida
- **Dominio público** (o use staging para pruebas)

## Tiempo estimado

**40-50 minutos**

## Descripción general

Let's Encrypt es una autoridad de certificación gratuita y automatizada. Aprenda a usar Certbot para obtener y renovar automáticamente certificados confiables mediante el protocolo ACME, eliminando la gestión manual de certificados.

---

## Instrucciones

### Paso 1: Instalar Certbot

Instale Certbot:

```bash
sudo ./install-certbot.sh
```

Esto instala:
- La herramienta de línea de comandos `certbot`
- Plugins de servidor web (si están disponibles)
- Dependencias

---

### Paso 2: Obtener certificado (Standalone)

Obtenga un certificado usando el modo standalone:

```bash
sudo ./obtain-standalone.sh
```

Esto:
- Detiene temporalmente los servidores web
- Ejecuta un servidor web integrado
- Completa el desafío HTTP-01
- Obtiene el certificado

---

### Paso 3: Obtener certificado (Apache/NGINX)

Obtenga un certificado con integración al servidor web:

```bash
sudo ./obtain-webserver.sh
```

Esto:
- Se integra con el servidor web en ejecución
- Configura HTTPS automáticamente
- No requiere tiempo de inactividad
- Prueba la configuración

---

### Paso 4: Probar renovación

Pruebe el proceso de renovación de certificados:

```bash
sudo ./test-renewal.sh
```

Esto prueba:
- Renovación en modo dry-run
- Hooks de renovación
- Validación de configuración
- Manejo de errores

---

### Paso 5: Configurar renovación automática

Configure la renovación automática:

```bash
sudo ./setup-autorenewal.sh
```

Esto configura:
- Timer de systemd
- Hooks de renovación
- Notificaciones por correo electrónico

---

### Paso 6: Verificar la configuración

Ejecute una validación integral:

```bash
sudo ./verify.sh
```

---

## Validación

```bash
sudo ./test.sh
```

Todas las comprobaciones deben pasar.

## Resultado esperado

Después de completar este lab:
- ✅ Certbot instalado
- ✅ Certificado de Let's Encrypt obtenido
- ✅ Renovación automática configurada
- ✅ Servidor web configurado
- ✅ Comprensión del protocolo ACME

---

## Conceptos clave

### Descripción general de Let's Encrypt

**Qué es:**
- Autoridad de certificación gratuita y automatizada
- Usa el protocolo ACME
- Confiada por todos los navegadores principales
- Vigencia del certificado de 90 días
- Se recomienda renovación automática

**Límites de tasa:**
- 50 certificados por dominio por semana
- 5 certificados duplicados por semana
- Use el entorno staging para pruebas

### Tipos de desafío ACME

**Desafío HTTP-01:**
- Coloca un archivo en `.well-known/acme-challenge/`
- Requiere que el puerto 80 sea accesible
- No se puede usar con certificados wildcard
- Método más común

**Desafío DNS-01:**
- Crea un registro TXT en DNS
- Funciona con wildcards
- No requiere el puerto 80
- Requiere acceso a la API de DNS

**Desafío TLS-ALPN-01:**
- Usa el puerto 443
- Menos común
- Casos de uso específicos

### Comandos de Certbot

**Obtener certificado:**
```bash
# Standalone (detiene el servidor web)
certbot certonly --standalone -d example.com

# Webroot (sin tiempo de inactividad)
certbot certonly --webroot -w /var/www/html -d example.com

# Plugin de Apache
certbot --apache -d example.com

# Plugin de NGINX
certbot --nginx -d example.com

# DNS manual
certbot certonly --manual --preferred-challenges dns -d example.com
```

**Gestionar certificados:**
```bash
# Listar certificados
certbot certificates

# Renovar todos
certbot renew

# Renovar uno específico
certbot renew --cert-name example.com

# Probar renovación (dry-run)
certbot renew --dry-run

# Revocar certificado
certbot revoke --cert-path /etc/letsencrypt/live/example.com/cert.pem
```

**Eliminar certificado:**
```bash
certbot delete --cert-name example.com
```

### Ubicaciones de certificados

```
/etc/letsencrypt/
├── live/
│   └── example.com/
│       ├── cert.pem         # Certificado
│       ├── chain.pem        # Cadena intermedia
│       ├── fullchain.pem    # cert.pem + chain.pem
│       └── privkey.pem      # Clave privada
├── archive/                 # Todas las versiones
├── renewal/                 # Configs de renovación
└── accounts/                # Info de cuenta ACME
```

### Automatización de renovación

**Timer de systemd (RHEL 8+):**
```bash
systemctl list-timers certbot
systemctl status certbot-renew.timer
```

### Hooks de renovación

```bash
# Pre-hook (antes de la renovación)
certbot renew --pre-hook "systemctl stop nginx"

# Post-hook (después de la renovación)
certbot renew --post-hook "systemctl reload nginx"

# deploy-hook (solo si se renovó)
certbot renew --deploy-hook "systemctl reload httpd"
```

---

## Resolución de problemas

### Problema: Falla el desafío HTTP

**Síntoma:**
```
Failed authorization procedure
Connection refused
```

**Solución:**
```bash
# Asegúrese de que el puerto 80 sea accesible
sudo firewall-cmd --add-service=http
sudo firewall-cmd --reload

# Verifique el servidor web
sudo systemctl status httpd
```

---

### Problema: Límite de tasa excedido

**Síntoma:**
```
too many certificates already issued
```

**Solución:**
Use el entorno staging para pruebas:
```bash
certbot --staging -d example.com
```

---

### Problema: Falla la validación del dominio

**Síntoma:**
```
DNS problem: NXDOMAIN
```

**Solución:**
Verifique DNS:
```bash
dig example.com
nslookup example.com
# Asegúrese de que el dominio apunte a su servidor
```

---

### Problema: Falla la renovación

**Síntoma:**
El certificado no se renovó automáticamente

**Solución:**
```bash
# Probar renovación
certbot renew --dry-run

# Revisar registros
journalctl -u certbot-renew

# Renovación manual
certbot renew --force-renewal
```

---

## Notas específicas por versión

### RHEL 8
- Disponible en AppStream
- Usa timers de systemd
- Mejor integración de plugins

### RHEL 9
- certbot 1.x o 2.x
- Seguridad mejorada
- Automatización mejorada

---

## Limpieza

```bash
sudo ./cleanup.sh
```

Esto elimina Certbot y los certificados.

---

## Recursos adicionales

**Capítulos relacionados:**
- Capítulo 24: Let's Encrypt con Certbot

**Documentación:**
- `man certbot`
- https://letsencrypt.org/docs/
- https://certbot.eff.org/
- https://community.letsencrypt.org/

**Límites de tasa:**
- https://letsencrypt.org/docs/rate-limits/

**Entorno staging:**
```bash
certbot --staging ...
# URL staging: https://acme-staging-v02.api.letsencrypt.org/directory
```

---

## Próximos pasos

Continúe con **Lab 14: Automatización con Ansible** para aprender despliegue de certificados a escala.

---

**Nivel de dificultad:** Intermedio
**Nota:** Requiere conexión a Internet e idealmente un dominio real para certificados de producción
