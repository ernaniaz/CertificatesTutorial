# Capítulo 21: Mejores Prácticas para Certificados de Servicios

> **Crítico para Operaciones:** Aprende las mejores prácticas que previenen el 90% de los problemas de certificados antes de que sucedan.

---

## 21.1 El Costo de la Mala Gestión de Certificados

**Impactos del mundo real:**
- ❌ Certificado expirado → Sitio web caído (pérdida de ingresos)
- ❌ Permisos incorrectos → Servicio falla al iniciar (tiempo de inactividad)
- ❌ Sin respaldo → Fallo de CA significa reemisión manual (horas/días)
- ❌ Nomenclatura pobre → Confusión durante incidente (respuesta retrasada)
- ❌ Sin monitoreo → Expiración sorpresa (respuesta de emergencia)

**Este capítulo previene estos problemas.**

---

## 21.2 Mejores Prácticas de Organización de Archivos

### Estructura de Directorio Estándar

```bash
/etc/pki/tls/
├── certs/                      # Archivos de certificado (públicos)
│   ├── service-name.crt        # Certificados reales
│   ├── service-name-chain.crt  # Con cadena intermedia
│   └── ca-bundle.crt           # Paquete CA
│
├── private/                    # Claves privadas (¡protegidas!)
│   └── service-name.key        # Claves privadas (modo 600)
│
├── csr/                        # Solicitudes de certificado (opcional)
│   └── service-name.csr        # CSRs para rastreo
│
└── backup/                     # Respaldos (opcional pero recomendado)
    └── YYYY-MM-DD/
        ├── service-name.crt
        └── service-name.key
```

### Convenciones de Nomenclatura

**Una buena nomenclatura previene confusión:**

```bash
# ✅ BUENO - Claro, descriptivo
/etc/pki/tls/certs/web01-example-com.crt
/etc/pki/tls/certs/mail-smtp-example-com.crt
/etc/pki/tls/certs/ldap-primary-example-com.crt

# ❌ MALO - Poco claro, genérico
/etc/pki/tls/certs/cert1.crt
/etc/pki/tls/certs/new.crt
/etc/pki/tls/certs/temp.crt
```

**Patrón de nomenclatura:**
```
[servicio]-[hostname/función]-[dominio].crt
[servicio]-[hostname/función]-[dominio].key

Ejemplos:
apache-web01-example-com.crt
nginx-www-example-com.crt
postfix-mail-example-com.crt
ldap-dir01-example-com.crt
postgresql-db-primary-example-com.crt
```

### Estándares de Permisos de Archivo

```bash
#============================================#
# CRÍTICO: Permisos Apropiados
#============================================#

# Certificados (públicos) - legibles por todos
/etc/pki/tls/certs/*.crt           → 644 (rw-r--r--)
/etc/pki/tls/certs/                → 755 (rwxr-xr-x)

# Claves privadas (¡secretas!) - solo legibles por propietario
/etc/pki/tls/private/*.key         → 600 (rw-------)
/etc/pki/tls/private/              → 711 (rwx--x--x)

# Claves específicas de servicio - propiedad del usuario del servicio
/etc/pki/tls/private/apache.key    → 600, owner: root o apache
/etc/pki/tls/private/postgres.key  → 600, owner: postgres
```

**Script para establecer permisos:**
```bash
#!/bin/bash
# set-cert-permissions.sh
# Establece permisos apropiados en archivos de certificado

CERT_DIR="/etc/pki/tls/certs"
KEY_DIR="/etc/pki/tls/private"

# Directorio de certificados
chmod 755 "$CERT_DIR"
chmod 644 "$CERT_DIR"/*.crt 2>/dev/null

# Directorio de claves privadas
chmod 711 "$KEY_DIR"
chmod 600 "$KEY_DIR"/*.key 2>/dev/null

# Verificar
echo "Permisos de certificados:"
ls -ld "$CERT_DIR" "$CERT_DIR"/*.crt 2>/dev/null

echo ""
echo "Permisos de claves privadas:"
ls -ld "$KEY_DIR" "$KEY_DIR"/*.key 2>/dev/null

# Verificar claves excesivamente permisivas
echo ""
echo "Verificando problemas de seguridad:"
find "$KEY_DIR" -type f -not -perm 600 -ls 2>/dev/null && \
  echo "⚠️ ADVERTENCIA: ¡Algunas claves tienen permisos incorrectos!" || \
  echo "✅ Todas las claves apropiadamente protegidas"
```

---

## 21.3 Gestión del Ciclo de Vida de Certificados

### Cronograma de Renovación

```
Ciclo de Vida del Certificado (validez 365 días):

Día   0: Certificado emitido
Día  30: Primer recordatorio de renovación (quedan 335 días)
Día  60: Segundo recordatorio (quedan 305 días)
Día 300: Comienza ventana crítica de renovación (quedan 65 días)
Día 330: URGENTE - Renovación necesaria (quedan 35 días)
Día 350: CRÍTICO - Renovación atrasada (quedan 15 días)
Día 365: EXPIRADO - ¡Interrupción del servicio!

Acciones Recomendadas:
- Días 300-330: Planificar y ejecutar renovación
- Días 330-350: Renovación de emergencia si se perdió
- Días 350+: Respuesta a incidente, cert temporal
```

### Estrategias de Renovación

**Estrategia 1: Automatizada (Recomendado)**
```bash
# Usando certmonger (RHEL)
sudo getcert request \
  -f /etc/pki/tls/certs/web01-example-com.crt \
  -k /etc/pki/tls/private/web01-example-com.key \
  -D web.example.com \
  -K host/web.example.com@REALM \
  -C "systemctl reload httpd"  # Auto-recargar servicio

# Renovación automática ocurre a 2/3 del tiempo de vida del cert
# Cert de 365 días → renueva en día 243 (quedan 122 días)
```

**Estrategia 2: Renovación Manual Programada**
```bash
# Tarea cron para verificación manual de renovación
# /etc/cron.weekly/check-certificates

#!/bin/bash
# Verificar certificados expirando en 60 días
find /etc/pki/tls/certs/ -name "*.crt" | while read cert; do
  if openssl x509 -in "$cert" -noout -checkend $((86400*60)); then
    echo "✅ $cert: OK"
  else
    echo "⚠️ $cert: ¡Expira dentro de 60 días!"
    # Enviar alerta
    mail -s "Certificado Expirando Pronto: $cert" admin@example.com
  fi
done
```

**Estrategia 3: Recordatorios de Calendario**
```bash
# Para entornos sin automatización
# Crear entradas de calendario:
# - 90 días antes de expiración: Comenzar renovación
# - 60 días antes: Verificar renovación en progreso
# - 30 días antes: Completar renovación
# - 7 días antes: Emergencia si no está hecho
```

---

## 21.4 Rastreo de Metadatos de Certificados

### Inventario de Certificados

Mantener un inventario de certificados (hoja de cálculo o base de datos):

```csv
Service,Hostname,Certificate_Path,Key_Path,Issuer,Issue_Date,Expiry_Date,SANs,Owner,Notes
Apache,web01,/etc/pki/tls/certs/web01-example-com.crt,/etc/pki/tls/private/web01.key,Internal CA,2024-01-01,2025-01-01,"web01.example.com,www.example.com",Juan Pérez,Producción
NGINX,web02,/etc/pki/tls/certs/web02-example-com.crt,/etc/pki/tls/private/web02.key,Let's Encrypt,2024-06-15,2024-09-15,"web02.example.com",María López,Staging
```

**Script para generar inventario:**
```bash
#!/bin/bash
# generate-cert-inventory.sh
# Crea inventario de certificados desde el sistema

echo "Service,Hostname,Certificate_Path,Issuer,Issue_Date,Expiry_Date,Days_Remaining"

# Escanear ubicaciones comunes de certificados
for cert in /etc/pki/tls/certs/*.crt /etc/httpd/conf/ssl/*.crt /etc/nginx/ssl/*.crt; do
  [ -f "$cert" ] || continue

  subject=$(openssl x509 -in "$cert" -noout -subject 2>/dev/null | sed 's/subject=//')
  issuer=$(openssl x509 -in "$cert" -noout -issuer 2>/dev/null | sed 's/issuer=//')
  notbefore=$(openssl x509 -in "$cert" -noout -startdate 2>/dev/null | cut -d= -f2)
  notafter=$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | cut -d= -f2)

  # Calcular días restantes
  expiry_epoch=$(date -d "$notafter" +%s 2>/dev/null)
  now_epoch=$(date +%s)
  days_remaining=$(( ($expiry_epoch - $now_epoch) / 86400 ))

  # Determinar servicio desde la ruta
  service="Desconocido"
  [[ "$cert" =~ httpd ]] && service="Apache"
  [[ "$cert" =~ nginx ]] && service="NGINX"

  echo "$service,$(hostname),$cert,\"$issuer\",$notbefore,$notafter,$days_remaining"
done
```

---

## 21.5 Respaldo y Recuperación

### Qué Respaldar

```bash
Archivos críticos para respaldar:
✅ Claves privadas (archivos .key)
✅ Certificados (archivos .crt)
✅ Certificados CA
✅ Cadenas de certificados
✅ CSRs (para referencia)
✅ Archivos de configuración (Apache ssl.conf, etc.)
⚠️ NO contraseñas o frases de contraseña (almacenar separadamente en bóveda)
```

### Script de Respaldo

```bash
#!/bin/bash
# backup-certificates.sh
# Respalda todos los certificados y claves

BACKUP_DIR="/var/backups/certificates"
DATE=$(date +%Y-%m-%d)
BACKUP_PATH="$BACKUP_DIR/$DATE"

# Crear directorio de respaldo
mkdir -p "$BACKUP_PATH"

# Respaldar certificados
echo "Respaldando certificados..."
cp -a /etc/pki/tls/certs/*.crt "$BACKUP_PATH/" 2>/dev/null

# Respaldar claves privadas (¡cifradas!)
echo "Respaldando claves privadas..."
tar czf - /etc/pki/tls/private/*.key 2>/dev/null | \
  openssl enc -aes-256-cbc -salt -out "$BACKUP_PATH/keys.tar.gz.enc" -pass pass:CHANGEME

# Respaldar archivos de configuración
echo "Respaldando configuraciones..."
cp -a /etc/httpd/conf.d/ssl.conf "$BACKUP_PATH/" 2>/dev/null
cp -a /etc/nginx/nginx.conf "$BACKUP_PATH/" 2>/dev/null

# Crear inventario
ls -lh "$BACKUP_PATH"

# Establecer permisos
chmod 700 "$BACKUP_PATH"

echo "✅ Respaldo completo: $BACKUP_PATH"
echo "⚠️ ¡Recuerda cambiar la contraseña de cifrado!"
```

### Procedimiento de Recuperación

```bash
#============================================#
# PROCEDIMIENTO DE RECUPERACIÓN DE CERTIFICADO
#============================================#

# 1. Detener servicio afectado
sudo systemctl stop httpd

# 2. Restaurar certificado
sudo cp /var/backups/certificates/2024-11-15/web.crt /etc/pki/tls/certs/

# 3. Restaurar clave privada (descifrar)
cd /var/backups/certificates/2024-11-15/
openssl enc -aes-256-cbc -d -in keys.tar.gz.enc -pass pass:CHANGEME | \
  sudo tar xzf - -C /

# 4. Establecer permisos
sudo chmod 600 /etc/pki/tls/private/*.key
sudo chmod 644 /etc/pki/tls/certs/*.crt

# 5. Verificar archivos
sudo openssl x509 -in /etc/pki/tls/certs/web01-example-com.crt -noout -text
sudo openssl rsa -in /etc/pki/tls/private/web01-example-com.key -check

# 6. Iniciar servicio
sudo systemctl start httpd

# 7. Probar
curl -v https://localhost/
```

---

## 21.6 Mejores Prácticas de Seguridad

### Protección de Clave Privada

```bash
#============================================#
# LISTA DE VERIFICACIÓN SEGURIDAD CLAVE PRIVADA
#============================================#

✅ Permisos: 600 (o 400 para protección extra)
✅ Ownership: Solo root o usuario del servicio
✅ Ubicación: /etc/pki/tls/private/ (modo 711)
✅ SELinux: Contexto apropiado (cert_t)
✅ Respaldo: Cifrado en reposo
✅ Nunca: Enviar por email, pegar en tickets, commit a git
✅ Nunca: Compartir entre sistemas (generar nueva)
✅ Auditar: Registrar acceso con auditd

# Verificar seguridad
ls -lZ /etc/pki/tls/private/*.key
# -rw------- root root unconfined_u:object_r:cert_t:s0 server01-example-com.key
```

### Mejores Prácticas de Generación de Claves

```bash
#============================================#
# GENERAR CLAVES SEGURAS
#============================================#

# RSA 2048 (mínimo para RHEL 8+)
openssl genpkey -algorithm RSA -out server01-example-com.key -pkeyopt rsa_keygen_bits:2048

# RSA 4096 (recomendado para certs de larga duración)
openssl genpkey -algorithm RSA -out server01-example-com.key -pkeyopt rsa_keygen_bits:4096

# EC P-256 (moderno, más pequeño, rápido)
openssl genpkey -algorithm EC -out server01-example-com.key -pkeyopt ec_paramgen_curve:P-256

# ¡Establecer permisos inmediatamente!
chmod 600 server.key

# ❌ NUNCA hacer esto:
# openssl genrsa -out server01-example-com.key 1024   # ¡Muy débil!
# chmod 644 server01-example-com.key                  # ¡Muy permisivo!
```

### Validación de Certificado Antes de Despliegue

```bash
#!/bin/bash
# validate-certificate.sh
# Valida certificado antes de despliegue

CERT=$1
KEY=$2

echo "=== Validación de Certificado Pre-Despliegue ==="

# Verificación 1: Archivo de certificado existe y es legible
if [ ! -f "$CERT" ]; then
  echo "❌ Archivo de certificado no encontrado: $CERT"
  exit 1
fi

# Verificación 2: Clave privada existe y es legible
if [ ! -f "$KEY" ]; then
  echo "❌ Clave privada no encontrada: $KEY"
  exit 1
fi

# Verificación 3: Certificado es X.509 válido
if ! openssl x509 -in "$CERT" -noout 2>/dev/null; then
  echo "❌ Certificado X.509 inválido"
  exit 1
fi

# Verificación 4: Certificado no expirado
if ! openssl x509 -in "$CERT" -noout -checkend 0; then
  echo "❌ ¡El certificado está expirado!"
  exit 1
fi

# Verificación 5: Par certificado/clave coinciden
CERT_MOD=$(openssl x509 -noout -modulus -in "$CERT" | openssl md5)
KEY_MOD=$(openssl rsa -noout -modulus -in "$KEY" 2>/dev/null | openssl md5)

if [ "$CERT_MOD" != "$KEY_MOD" ]; then
  echo "❌ ¡Certificado y clave no coinciden!"
  exit 1
fi

# Verificación 6: SANs presentes (requerido para navegadores modernos)
if ! openssl x509 -in "$CERT" -noout -ext subjectAltName 2>/dev/null | grep -q "DNS:"; then
  echo "⚠️ ADVERTENCIA: No se encontraron Subject Alternative Names"
fi

# Verificación 7: Algoritmo de firma fuerte
SIG_ALG=$(openssl x509 -in "$CERT" -noout -text | grep "Signature Algorithm" | head -2)
if echo "$SIG_ALG" | grep -qi "sha1\|md5"; then
  echo "❌ Algoritmo de firma débil: $SIG_ALG"
  exit 1
fi

# Verificación 8: Tamaño de clave adecuado
KEY_SIZE=$(openssl x509 -in "$CERT" -noout -text | grep "Public-Key:" | grep -oP '\d+')
if [ "$KEY_SIZE" -lt 2048 ]; then
  echo "❌ Tamaño de clave muy pequeño: $KEY_SIZE bits (mínimo 2048)"
  exit 1
fi

echo ""
echo "✅ ¡Validación de certificado exitosa!"
echo "   Sujeto: $(openssl x509 -in "$CERT" -noout -subject)"
echo "   Emisor: $(openssl x509 -in "$CERT" -noout -issuer)"
echo "   Expira: $(openssl x509 -in "$CERT" -noout -enddate | cut -d= -f2)"
echo "   Tamaño Clave: $KEY_SIZE bits"
```

---

## 21.7 Coordinación Multi-Servicio

### Cuando Múltiples Servicios Comparten Certificados

```bash
# Escenario: Balanceador de carga + múltiples servidores web

# Problema: Certificado en LB, servicios detrás necesitan mismo CN/SANs

# Solución 1: Usar mismo certificado en todos (si hostnames coinciden)
# web01, web02, web03 todos usan cert para: web.example.com

# Solución 2: Certificado comodín
# *.example.com funciona para web01.example.com, web02.example.com, etc.

# Solución 3: SANs comprehensivos
# Cert único con SANs: web.example.com, web01.example.com, web02.example.com
```

### Flujo de Trabajo de Despliegue de Certificados

```bash
#============================================#
# DESPLIEGUE MULTI-SERVIDOR
#============================================#

# Paso 1: Generar certificado en nodo de gestión
openssl genpkey -algorithm RSA -out web.key -pkeyopt rsa_keygen_bits:2048
openssl req -new -key web.key -out web.csr \
  -subj "/CN=web.example.com" \
  -addext "subjectAltName=DNS:web.example.com,DNS:web01.example.com,DNS:web02.example.com"

# Paso 2: Obtener certificado de CA
# (enviar web.csr a CA, recibir web.crt)

# Paso 3: Validar localmente
./validate-certificate.sh web.crt web.key

# Paso 4: Distribuir de forma segura
for host in web01 web02 web03; do
  scp web.crt root@$host:/etc/pki/tls/certs/
  scp web.key root@$host:/etc/pki/tls/private/
  ssh root@$host "chmod 644 /etc/pki/tls/certs/web01-example-com.crt"
  ssh root@$host "chmod 600 /etc/pki/tls/private/web01-example-com.key"
done

# Paso 5: Recargar servicios
for host in web01 web02 web03; do
  ssh root@$host "systemctl reload httpd"
done

# Paso 6: Probar cada servidor
for host in web01 web02 web03; do
  echo "Probando $host..."
  curl -vk https://$host/ 2>&1 | grep "subject:"
done
```

---

## 21.8 Estándares de Documentación

### Plantilla de Documentación de Certificado

```markdown
## Certificado: web.example.com

### Información Básica
- **Servicio:** Apache (httpd)
- **Servidor:** web01.example.com
- **Ruta de Certificado:** `/etc/pki/tls/certs/web-example-com.crt`
- **Ruta de Clave:** `/etc/pki/tls/private/web-example-com.key`
- **Propietario:** Equipo Web (webadmin@example.com)

### Detalles del Certificado
- **Common Name (CN):** web.example.com
- **SANs:** web.example.com, www.example.com
- **Emisor:** CA Interna (ca.example.com)
- **Fecha de Emisión:** 2024-01-01
- **Fecha de Expiración:** 2025-01-01
- **Tipo de Clave:** RSA 2048

### Proceso de Renovación
- **Método:** certmonger automático
- **Ventana de Renovación:** 65 días antes de expirar
- **Post-Renovación:** `systemctl reload httpd`
- **Contacto:** webadmin@example.com

### Configuración de Servicio
- **Archivo de Config:** `/etc/httpd/conf.d/ssl.conf`
- **Servicio:** `httpd.service`
- **Comando de Reinicio:** `systemctl reload httpd`

### Solución de Problemas
- **Logs:** `/var/log/httpd/ssl_error_log`
- **Comando de Prueba:** `curl -v https://web.example.com/`
- **Problemas Comunes:** Ninguno reportado

### Historial de Cambios
- 2024-01-01: Despliegue inicial
- 2024-06-15: Agregado SAN www.example.com
```

---

## 21.9 Monitoreo y Alertas

### Qué Monitorear

```bash
✅ Expiración de certificado (60, 30, 7 días antes)
✅ Validez de certificado (no expirado, aún no válido)
✅ Coincidencia de par certificado/clave
✅ Cadena de confianza de certificado
✅ Salud del servicio (¿está usando el cert?)
✅ Estado de rastreo de certmonger
✅ Éxito/fallo de renovación
```

### Script Simple de Monitoreo

```bash
#!/bin/bash
# monitor-certificates.sh
# Monitoreo simple de certificados

WARN_DAYS=30
CRIT_DAYS=7
EMAIL="admin@example.com"

check_cert() {
  local cert=$1
  local name=$(basename "$cert")

  # Verificar si expira dentro del período de advertencia
  if ! openssl x509 -in "$cert" -noout -checkend $((86400*WARN_DAYS)); then
    if ! openssl x509 -in "$cert" -noout -checkend $((86400*CRIT_DAYS)); then
      echo "🚨 CRÍTICO: ¡$name expira dentro de $CRIT_DAYS días!"
      return 2
    else
      echo "⚠️ ADVERTENCIA: $name expira dentro de $WARN_DAYS días"
      return 1
    fi
  fi

  return 0
}

# Verificar todos los certificados
WARNINGS=0
CRITICALS=0

for cert in /etc/pki/tls/certs/*.crt; do
  [ -f "$cert" ] || continue
  check_cert "$cert"
  ret=$?
  [ $ret -eq 1 ] && ((WARNINGS++))
  [ $ret -eq 2 ] && ((CRITICALS++))
done

# Alertar si se encuentran problemas
if [ $CRITICALS -gt 0 ] || [ $WARNINGS -gt 0 ]; then
  echo "Problemas de certificados encontrados: $CRITICALS críticos, $WARNINGS advertencias" | \
    mail -s "Alerta de Certificados: $(hostname)" "$EMAIL"
fi
```

---

## 21.10 Procedimientos de Respuesta a Incidentes

### Incidente de Expiración de Certificado

```bash
#============================================#
# EMERGENCIA DE CERTIFICADO EXPIRADO
#============================================#

# Paso 1: Evaluar impacto
systemctl status httpd
journalctl -xe | grep -i cert

# Paso 2: Solución rápida - Obtener cert temporal
# Opción A: Autofirmado (¡solo para interno!)
openssl req -x509 -nodes -days 30 -newkey rsa:2048 \
  -keyout /etc/pki/tls/private/temp-web01-example-com.key \
  -out /etc/pki/tls/certs/temp-web01-example-com.crt \
  -subj "/CN=$(hostname)"

# Opción B: Restaurar desde respaldo
cp /var/backups/certificates/latest/*.crt /etc/pki/tls/certs/
cp /var/backups/certificates/latest/*.key /etc/pki/tls/private/

# Paso 3: Actualizar configuración del servicio para usar cert temporal
# Editar /etc/httpd/conf.d/ssl.conf
# SSLCertificateFile /etc/pki/tls/certs/temp-web01-example-com.crt
# SSLCertificateKeyFile /etc/pki/tls/private/temp-web01-example-com.key

# Paso 4: Reiniciar servicio
systemctl restart httpd

# Paso 5: Obtener certificado apropiado LO ANTES POSIBLE
# Seguir proceso normal de solicitud de cert

# Paso 6: Documentar incidente
# Qué sucedió, por qué, cómo se arregló, prevención
```

---

## 21.11 Lista de Verificación de Mejores Prácticas

```markdown
## Lista de Verificación de Gestión de Certificados

### Organización de Archivos
- [ ] Estructura de directorio estándar usada
- [ ] Convención de nomenclatura consistente
- [ ] Permisos de archivo apropiados (600 para claves, 644 para certs)
- [ ] Contextos SELinux correctos

### Gestión del Ciclo de Vida
- [ ] Proceso de renovación definido y documentado
- [ ] Recordatorios de renovación establecidos (60, 30, 7 días)
- [ ] Renovación automatizada si es posible (certmonger)
- [ ] Acciones post-renovación definidas

### Seguridad
- [ ] Claves privadas protegidas (permisos 600)
- [ ] Claves nunca compartidas/enviadas por email
- [ ] Algoritmo de clave fuerte (RSA 2048+ o EC P-256)
- [ ] Firma fuerte (SHA-256+)

### Respaldo
- [ ] Certificados respaldados
- [ ] Claves privadas respaldadas (cifradas)
- [ ] Respaldo probado y validado
- [ ] Procedimiento de restauración documentado

### Documentación
- [ ] Inventario de certificados mantenido
- [ ] Cada certificado documentado
- [ ] Procedimientos escritos
- [ ] Contactos listados

### Monitoreo
- [ ] Monitoreo de expiración habilitado
- [ ] Alertas configuradas
- [ ] Verificaciones de salud en lugar
- [ ] Plan de respuesta a incidentes listo

### Validación
- [ ] Validación pre-despliegue
- [ ] Pruebas post-despliegue
- [ ] Auditorías regulares programadas
```

---

## 21.12 Conclusiones Clave

1. **La organización previene confusión** - Estructura y nomenclatura consistentes
2. **Los permisos son críticos** - 600 para claves, 644 para certs
3. **Automatizar renovación** - Usar certmonger cuando sea posible
4. **Respaldar todo** - Pero cifrar claves privadas
5. **Documentar exhaustivamente** - Tu yo futuro te lo agradecerá
6. **Monitorear proactivamente** - No esperar a la expiración
7. **Validar antes de desplegar** - Capturar problemas temprano
8. **Planificar para incidentes** - Tener procedimientos de recuperación listos

---

## Referencia Rápida

```
┌──────────────────────────────────────────────────────────────┐
│ MEJORES PRÁCTICAS CERTIFICADOS DE SERVICIO                   │
├──────────────────────────────────────────────────────────────┤
│ Archivos:    /etc/pki/tls/certs/*.crt (644)                  │
│              /etc/pki/tls/private/*.key (600)                │
│ Nombres:     [servicio]-[host]-[dominio].[crt|key]           │
│ Renovación:  Automatizar con certmonger                      │
│ Respaldo:    Diario, cifrado, probado                        │
│ Monitoreo:   60, 30, 7 días antes de expirar                 │
│ Validar:     Antes de cada despliegue                        │
│ Documentar:  Todo, siempre                                   │
└──────────────────────────────────────────────────────────────┘
```
---

**Navegación del Capítulo**

| [← Anterior: Capítulo 20 - Otros Servicios RHEL con Certificados](20-other-rhel-services.md) | [Siguiente: Capítulo 22 - Dominio de certmonger →](../part-04-automation/22-certmonger-mastery.md) |
|:---|---:|
