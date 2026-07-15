# Capítulo 3: Resumen de Herramientas de Certificados en RHEL

> **Objetivo de Aprendizaje:** Familiarízate con las herramientas esenciales para gestionar certificados en RHEL para que sepas qué herramienta usar para cada tarea.

---

## 3.1 Tu Caja de Herramientas de Certificados

Al trabajar con certificados en RHEL, usarás estas herramientas principales:

| Herramienta | Uso Principal | Versiones RHEL | Cuándo Usar |
|-------------|---------------|----------------|-------------|
| **openssl** | Operaciones de certificados, pruebas | Todas | Generar claves/CSRs, inspeccionar certs, probar conexiones |
| **certutil** | Gestión de base de datos NSS | Todas | BDs de cert estilo Firefox/Mozilla |
| **update-ca-trust** | Gestión de almacén de confianza | Todas | Agregar/eliminar CAs confiables |
| **certmonger** | Renovación automática | Todas | Rastrear y renovar certificados automáticamente |
| **crypto-policies** | Seguridad en todo el sistema | RHEL 8+ | Controlar versiones TLS y cifrados |
| **getcert** | CLI de certmonger | Todas | Solicitar y gestionar certs rastreados |
| **trust** | Gestión de confianza P11-kit | Todas (mejorado RHEL 8+) | Operaciones avanzadas de confianza |

---

## 3.2 OpenSSL - La Navaja Suiza

**Disponible:** Todas las versiones de RHEL
**Paquete:** `openssl`

### Diferencias de Versión

```bash
# Verificar tu versión
openssl version

# RHEL 7: OpenSSL 1.0.2k-26
# RHEL 8: OpenSSL 1.1.1k-14
# RHEL 9: OpenSSL 3.5.5-2
# RHEL 10: OpenSSL 3.5.5-2
```

### Usos Comunes

```bash
#============================================#
# INSPECCIONAR CERTIFICADOS
#============================================#

# Ver detalles del certificado
openssl x509 -in cert.crt -noout -text

# Verificar expiración
openssl x509 -in cert.crt -noout -dates
openssl x509 -in cert.crt -noout -checkend 86400  # Verificar si expira en 24h

# Ver asunto del certificado
openssl x509 -in cert.crt -noout -subject -issuer


#============================================#
# GENERAR CLAVES
#============================================#

# Estilo RHEL 7 (aún funciona en todas las versiones)
openssl genrsa -out server.key 2048

# Estilo moderno RHEL 8+ (recomendado)
openssl genpkey -algorithm RSA -out server.key -pkeyopt rsa_keygen_bits:2048

# Clave EC RHEL 9+ (curva elíptica)
openssl genpkey -algorithm EC -out ec.key -pkeyopt ec_paramgen_curve:P-256


#============================================#
# CREAR CSR (Solicitud de Firma de Certificado)
#============================================#

# CSR básico
openssl req -new -key server.key -out server.csr \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=server.example.com"

# CSR con SANs (¡requerido para navegadores modernos!)
openssl req -new -key server.key -out server.csr \
  -subj "/CN=server.example.com" \
  -addext "subjectAltName=DNS:server.example.com,DNS:www.example.com"


#============================================#
# PROBAR CONEXIONES
#============================================#

# Probar HTTPS
openssl s_client -connect server.example.com:443 -servername server.example.com

# Probar versión TLS específica
openssl s_client -connect server.example.com:443 -tls1_2
openssl s_client -connect server.example.com:443 -tls1_3

# Probar LDAPS
openssl s_client -connect ldap.example.com:636

# Probar SMTP con STARTTLS
openssl s_client -connect mail.example.com:25 -starttls smtp
```

### Diferencias Específicas por Versión

**RHEL 7 (OpenSSL 1.0.2k):**
- ✅ Estable y bien probado
- ❌ Sin soporte TLS 1.3
- ❌ Sintaxis de comando antigua

**RHEL 8 (OpenSSL 1.1.1k):**
- ✅ Soporte TLS 1.3
- ✅ Sintaxis de comando moderna
- ✅ Mejores valores predeterminados

**RHEL 9/10 (OpenSSL 3.5.5):**
- ✅ Arquitectura de proveedores
- ✅ Soporte FIPS mejorado
- ⚠️ Cambios en API (afecta apps personalizadas)
- ⚠️ Algoritmos heredados requieren `-provider legacy`

---

## 3.3 certutil - Herramienta de Base de Datos NSS

**Disponible:** Todas las versiones de RHEL
**Paquete:** `nss-tools`

Usado para bases de datos de certificados estilo Mozilla/Firefox.

### Usos Comunes

```bash
#============================================#
# GESTIONAR BASE DE DATOS NSS
#============================================#

# Crear nueva base de datos
certutil -N -d /etc/pki/nssdb

# Listar certificados
certutil -L -d /etc/pki/nssdb

# Agregar certificado CA
certutil -A -n "My CA" -t "CT,C,C" -d /etc/pki/nssdb -i ca.crt

# Eliminar certificado
certutil -D -n "Certificate Name" -d /etc/pki/nssdb

# Exportar certificado
certutil -L -n "Certificate Name" -d /etc/pki/nssdb -a > exported.crt
```

### Cuándo Usar certutil

- Gestionar certificados de Firefox/Thunderbird
- Trabajar con aplicaciones que usan NSS (muchos servicios Red Hat)
- Cuando veas archivos `.db` en `/etc/pki/nssdb/`

---

## 3.4 update-ca-trust - Gestión del Almacén de Confianza

**Disponible:** Todas las versiones de RHEL
**Paquete:** `ca-certificates` (instalado por defecto)

Gestiona qué Autoridades Certificadoras (CAs) confía tu sistema.

### Cómo Funciona

```
Tus CAs Personalizadas
  ↓
/etc/pki/ca-trust/source/anchors/
  ↓
update-ca-trust extract
  ↓
/etc/pki/ca-trust/extracted/
  ├── pem/tls-ca-bundle.pem       (OpenSSL/Python/Ruby)
  ├── openssl/ca-bundle.trust.crt (Específico de OpenSSL)
  └── java/cacerts                (Aplicaciones Java)
```

### Usos Comunes

```bash
#============================================#
# AGREGAR CA PERSONALIZADA
#============================================#

# Paso 1: Copiar certificado CA
sudo cp corporate-ca.crt /etc/pki/ca-trust/source/anchors/

# Paso 2: Actualizar almacén de confianza
sudo update-ca-trust extract

# ¡Eso es todo! Ahora todas las aplicaciones confían en esta CA


#============================================#
# ELIMINAR/PONER EN LISTA NEGRA CA (RHEL 8+)
#============================================#

# Poner en lista negra una CA comprometida
sudo cp compromised-ca.crt /etc/pki/ca-trust/source/blacklist/
sudo update-ca-trust extract


#============================================#
# VERIFICAR CONFIANZA
#============================================#

# Verificar si el certificado es confiable
openssl verify /path/to/cert.crt

# Listar todas las CAs confiables
trust list | grep "certificate-authority"

# Buscar CA específica
trust list | grep -i "Let's Encrypt"
```

### Directorios Clave

```
/etc/pki/ca-trust/
├── source/
│   ├── anchors/          ← Agrega tus CAs confiables aquí
│   └── blacklist/        ← Lista negra de CAs (RHEL 8+)
└── extracted/
    ├── pem/              ← Usado por la mayoría de apps
    ├── openssl/          ← Específico de OpenSSL
    └── java/             ← Aplicaciones Java
```

---

## 3.5 certmonger - Renovación Automática de Certificados

**Disponible:** Todas las versiones de RHEL
**Paquete:** `certmonger`

La herramienta "configúralo y olvídate" para certificados.

### Qué Hace

certmonger:
- Rastrea fechas de expiración de certificados
- Renueva automáticamente antes de expirar
- Funciona con múltiples CAs (IPA, Let's Encrypt, externa)
- Ejecuta comandos post-renovación (ej: reiniciar servicios)

### Flujo de Trabajo Básico

```bash
#============================================#
# INSTALACIÓN
#============================================#

sudo dnf install certmonger
sudo systemctl enable --now certmonger


#============================================#
# SOLICITAR CERTIFICADO
#============================================#

# Desde FreeIPA
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/web.crt \
  -k /etc/pki/tls/private/web.key \
  -D web.example.com \
  -K host/web.example.com@REALM

# Autofirmado (para pruebas)
sudo getcert request \
  -f /etc/pki/tls/certs/test.crt \
  -k /etc/pki/tls/private/test.key


#============================================#
# MONITOREAR CERTIFICADOS
#============================================#

# Listar todos los certificados rastreados
sudo getcert list

# Verificar certificado específico
sudo getcert list -f /etc/pki/tls/certs/web.crt

# Observar renovación
sudo journalctl -u certmonger -f
```

### Características Clave por Versión

**RHEL 7:**
- Rastreo y renovación básicos
- Integración con IPA
- Configuración manual

**RHEL 8:**
- Integración mejorada con IPA
- Mejor reporte de errores
- Comandos post-guardado

**RHEL 9:**
- Soporte ACME (¡Let's Encrypt!)
- Monitoreo mejorado
- Mejor reporte de estado

```bash
# RHEL 9 - Integración con Let's Encrypt
sudo getcert request \
  -f /etc/pki/tls/certs/acme.crt \
  -k /etc/pki/tls/private/acme.key \
  -D example.com \
  -c acme-letsencrypt \
  -C "systemctl reload httpd"
```

---

## 3.6 crypto-policies - Seguridad en Todo el Sistema (RHEL 8+)

**Disponible:** Solo RHEL 8, 9, 10
**Paquete:** `crypto-policies` (instalado por defecto)

**CAMBIO DE JUEGO:** ¡Controla versiones TLS, cifrados y tamaños de clave en todo el sistema!

### La Gran Idea

En lugar de configurar cada aplicación individualmente:

```
❌ FORMA ANTIGUA (RHEL 7):
- Configurar cifrados SSL de Apache
- Configurar cifrados SSL de NGINX
- Configurar ajustes TLS de Postfix
- Configurar ajustes TLS de OpenLDAP
- Configurar cada aplicación...

✅ FORMA NUEVA (RHEL 8+):
- Establecer UNA política del sistema
- ¡Todas las aplicaciones la siguen automáticamente!
```

### Políticas Disponibles

```bash
# Verificar política actual
update-crypto-policies --show

# Políticas:
# DEFAULT  - Seguridad equilibrada (TLS 1.2+, RSA 2048+)
# LEGACY   - Modo de compatibilidad (permite TLS 1.0/1.1)
# FUTURE   - Seguridad más estricta (TLS 1.2+, RSA 3072+)
# FIPS     - Modo de cumplimiento federal
```

### Comparación de Políticas

| Característica | LEGACY | DEFAULT | FUTURE | FIPS |
|----------------|--------|---------|--------|------|
| TLS 1.0/1.1 | ✅ Permitido | ❌ Bloqueado | ❌ Bloqueado | ❌ Bloqueado |
| TLS 1.2 | ✅ Sí | ✅ Sí | ✅ Sí | ✅ Sí |
| TLS 1.3 | ✅ Sí | ✅ Sí | ✅ Sí | ✅ Sí |
| RSA Mín | 1024 bits | 2048 bits | 3072 bits | 2048 bits |
| Firmas SHA-1 | ⚠️ Permitido | ❌ Bloqueado | ❌ Bloqueado | ❌ Bloqueado |
| Cifrado 3DES | ⚠️ Permitido | ❌ Bloqueado | ❌ Bloqueado | ❌ Bloqueado |

### Usos Comunes

```bash
#============================================#
# CAMBIAR POLÍTICA
#============================================#

# Establecer política FUTURE (más estricta)
sudo update-crypto-policies --set FUTURE
# Reiniciar o reiniciar servicios

# Usar temporalmente LEGACY (para sistemas antiguos)
sudo update-crypto-policies --set LEGACY
# Nota: ¡LEGACY debe ser temporal!


#============================================#
# POLÍTICAS PERSONALIZADAS (RHEL 9+)
#============================================#

# Subpolíticas - modificar política existente
sudo update-crypto-policies --set DEFAULT:NO-SHA1
sudo update-crypto-policies --set FUTURE:AD-SUPPORT


#============================================#
# RESOLVER PROBLEMAS DE POLÍTICA
#============================================#

# Si el servicio falla después del cambio de política:
# 1. Verificar política actual
update-crypto-policies --show

# 2. Verificar configuración de aplicación
cat /etc/crypto-policies/back-ends/opensslcnf.config

# 3. Probar con LEGACY temporalmente
sudo update-crypto-policies --set LEGACY
sudo systemctl restart <service>
```

### Qué Controla crypto-policies

Configura automáticamente:
- OpenSSL
- GnuTLS
- NSS
- OpenJDK/Java
- BIND
- Kerberos
- OpenSSH
- ¡Y más!

**Conclusión:** Cambia un ajuste, actualiza la seguridad de todo el sistema. ¡Brillante!

---

## 3.7 Guía de Selección de Herramientas

### "¿Qué herramienta debo usar?"

```
┌─────────────────────────────────────────────────────────────┐
│ ÁRBOL DE DECISIÓN DE HERRAMIENTAS DE CERTIFICADOS           │
└─────────────────────────────────────────────────────────────┘

Necesito...
│
├─ Inspeccionar un certificado
│  └─ Usar: openssl x509 -in cert.crt -noout -text
│
├─ Generar una clave/CSR
│  └─ Usar: openssl genpkey / openssl req
│
├─ Probar una conexión TLS
│  └─ Usar: openssl s_client -connect host:port
│
├─ Agregar una CA confiable en todo el sistema
│  └─ Usar: copiar a /etc/pki/ca-trust/source/anchors/
│          luego: update-ca-trust
│
├─ Renovar certificados automáticamente
│  └─ Usar: certmonger (getcert/ipa-getcert)
│
├─ Cambiar política TLS del sistema (RHEL 8+)
│  └─ Usar: update-crypto-policies --set <POLICY>
│
├─ Trabajar con bases de datos Firefox/NSS
│  └─ Usar: certutil
│
└─ Resolver problemas de certificados
   └─ Usar: ¡Metodología del Capítulo 27!
```

---

## 3.8 Matriz de Disponibilidad de Herramientas

| Herramienta | RHEL 7 | RHEL 8 | RHEL 9 | RHEL 10 | Notas |
|-------------|--------|--------|--------|---------|-------|
| openssl | 1.0.2k | 1.1.1k | 3.5.5 | 3.5.5 | Herramienta principal |
| certutil | ✅ | ✅ | ✅ | ✅ | Herramienta NSS |
| update-ca-trust | ✅ | ✅ Mejorado | ✅ Mejorado | ✅ Mejorado | Gestión confianza |
| certmonger | ✅ | ✅ Mejorado | ✅ ACME | ✅ ACME | Renovación auto |
| crypto-policies | ❌ | ✅ | ✅ Subpolíticas | ✅ Mejorado | Política sistema |
| getcert | ✅ | ✅ | ✅ | ✅ | CLI certmonger |
| trust | ✅ Básico | ✅ | ✅ | ✅ | Herramienta p11-kit |

---

## 3.9 Verificación de Instalación

Verifica que tienes las herramientas esenciales:

```bash
#============================================#
# VERIFICAR HERRAMIENTAS INSTALADAS
#============================================#

# OpenSSL (debe estar instalado por defecto)
openssl version

# Herramientas NSS
rpm -q nss-tools || echo "Instalar con: sudo dnf install nss-tools"

# certmonger
rpm -q certmonger || echo "Instalar con: sudo dnf install certmonger"

# Verificar crypto-policies (solo RHEL 8+)
which update-crypto-policies &>/dev/null && \
  echo "Crypto-policies disponible: $(update-crypto-policies --show)" || \
  echo "Crypto-policies no disponible (RHEL 7 o anterior)"
```

---

## 3.10 Comandos de Referencia Rápida

```bash
# === OpenSSL ===
openssl version                          # Verificar versión
openssl x509 -in cert.crt -noout -text   # Inspeccionar certificado
openssl s_client -connect host:443       # Probar HTTPS

# === Almacén de Confianza ===
sudo cp ca.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust                     # Agregar CA confiable

# === certmonger ===
sudo getcert list                        # Listar certs rastreados
sudo getcert list -f /path/to/cert.crt   # Verificar cert específico
sudo journalctl -u certmonger -f         # Ver logs

# === Crypto-Policies (RHEL 8+) ===
update-crypto-policies --show            # Política actual
sudo update-crypto-policies --set <POL>  # Cambiar política

# === NSS ===
certutil -L -d /etc/pki/nssdb            # Listar certs NSS
```

---

## 3.11 ¿Qué Sigue?

Ahora que conoces las herramientas, aprenderás:
- **Capítulo 4:** Conceptos básicos de criptografía
- **Capítulo 5:** Entender certificados X.509
- **Capítulo 6:** Inmersión Profunda en almacén de confianza RHEL
- **Capítulo 22:** Dominio de certmonger (detallado)
- **Capítulo 23:** Inmersión Profunda en Crypto-policies (detallado)

---

## Tarjeta de Referencia Rápida

```
┌────────────────────────────────────────────────────────────┐
│ HOJA DE TRUCOS DE HERRAMIENTAS DE CERTIFICADOS RHEL        │
├────────────────────────────────────────────────────────────┤
│ Inspeccionar:  openssl x509 -in cert.crt -noout -text      │
│ Probar:        openssl s_client -connect host:443          │
│ Agregar CA:    cp ca.crt /etc/pki/ca-trust/source/anchors/ │
│                sudo update-ca-trust                        │
│ Renovar auto:  sudo getcert list                           │
│ Política:      update-crypto-policies --show  (RHEL 8+)    │
│ NSS:           certutil -L -d /etc/pki/nssdb               │
└────────────────────────────────────────────────────────────┘
```
---

**Navegación del Capítulo**

| [← Anterior: Capítulo 2 - Introducción a los Certificados en RHEL](02-intro.md) | [Siguiente: Capítulo 4 - Criptografía Básica para Administradores RHEL →](04-basic-cryptography.md) |
|:---|---:|
