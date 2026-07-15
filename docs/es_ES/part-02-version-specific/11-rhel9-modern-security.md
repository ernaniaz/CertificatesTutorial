# Capítulo 11: Seguridad Moderna en RHEL 9

> **Estándar Moderno:** RHEL 9 representa el estado del arte actual en gestión de certificados en Linux con OpenSSL 3.x, crypto-policies mejoradas y valores predeterminados de seguridad más estrictos.

---

## 11.1 Resumen de RHEL 9

**Lanzamiento:** 17 de mayo de 2022
**Soporte Hasta:** 31 de mayo de 2032
**Versión Actual:** RHEL 9.8

**Cambios Principales desde RHEL 8:**

| Característica | RHEL 8 | RHEL 9 |
|----------------|--------|--------|
| OpenSSL | 1.1.1k | **3.5.5** |
| Arquitectura | Tradicional | **Basada en proveedores** |
| TLS 1.0/1.1 | Política LEGACY | ❌ **Completamente eliminado** |
| Crypto-Policies | Básicas | **Subpolíticas** |
| Validación | Estándar | **Más Estricta** |
| SHA-1 | Obsoleto | **Bloqueado** |
| certmonger | Mejorado | **Flujos nativos de IPA y seguimiento** |

**Paquete:** `openssl-3.5.5-2.el9_8.x86_64`

---

## 11.2 OpenSSL 3.5.5 - Cambios Principales

### Arquitectura de Proveedores (¡Nuevo!)

**Qué Cambió:**
OpenSSL 3.x introdujo un sistema de "proveedores" para diferentes implementaciones crypto.

```bash
#============================================#
# LISTAR PROVEEDORES (RHEL 9)
#============================================#

openssl list -providers

# Salida:
# Providers:
#   default
#     name: OpenSSL Default Provider
#     version: 3.5.5
#     status: active
#
#   fips
#     name: OpenSSL FIPS Provider
#     version: 3.5.5
#     status: inactive (a menos que modo FIPS habilitado)
#
#   legacy
#     name: OpenSSL Legacy Provider
#     version: 3.5.5
#     status: inactive
#
#   base
#     name: OpenSSL Base Provider
#     version: 3.5.5
#     status: active
```

### Los Algoritmos Legacy Requieren Proveedor Explícito

**Cambio Incompatible:** MD5, Blowfish, CAST5 necesitan `-provider legacy`

```bash
#============================================#
# USAR ALGORITMOS LEGACY (RHEL 9)
#============================================#

# Esto FALLA en RHEL 9:
openssl md5 file.txt
# Error: unsupported

# Esto FUNCIONA (proveedor explícito):
openssl md5 -provider legacy file.txt

# Por qué: Algoritmos legacy deshabilitados por defecto por seguridad
```

### Generación Moderna de Claves (RHEL 9)

```bash
#============================================#
# GENERAR CLAVES (RHEL 9)
#============================================#

# RSA 2048 (estándar)
openssl genpkey -algorithm RSA -out server.key \
  -pkeyopt rsa_keygen_bits:2048

# RSA 4096 (más fuerte)
openssl genpkey -algorithm RSA -out server.key \
  -pkeyopt rsa_keygen_bits:4096

# EC P-256 (curva elíptica, recomendado)
openssl genpkey -algorithm EC -out ec.key \
  -pkeyopt ec_paramgen_curve:P-256

# EC P-384 (más fuerte)
openssl genpkey -algorithm EC -out ec.key \
  -pkeyopt ec_paramgen_curve:P-384


#============================================#
# GENERAR CSR CON SANS (RHEL 9)
#============================================#

openssl req -new -key server.key -out server.csr \
  -subj "/C=US/ST=State/O=Company/CN=server.example.com" \
  -addext "subjectAltName=DNS:server.example.com,DNS:www.example.com,IP:10.0.0.100" \
  -addext "keyUsage=digitalSignature,keyEncipherment" \
  -addext "extendedKeyUsage=serverAuth,clientAuth"

# Verificar
openssl req -in server.csr -noout -text | grep -A5 "Subject Alternative Name"
```

---

## 11.3 Crypto-Policies Mejoradas (RHEL 9)

### Subpolíticas (¡Nueva Característica!)

**RHEL 9 introduce modificadores de política:**

```bash
#============================================#
# SUBPOLÍTICAS DE CRYPTO-POLICY (RHEL 9)
#============================================#

# Política base con módulo NO-SHA1
sudo update-crypto-policies --set DEFAULT:NO-SHA1

# Múltiples módulos
sudo update-crypto-policies --set DEFAULT:NO-SHA1:GOST

# Subpolíticas comunes:
# - NO-SHA1: Deshabilitar completamente SHA-1 (incluso en firmas)
# - NO-ENFORCE-EMS: Deshabilitar Extended Master Secret
# - GOST: Habilitar algoritmos GOST
# - NO-CAMELLIA: Deshabilitar cifrado Camellia

# Ver módulos disponibles
ls /usr/share/crypto-policies/policies/modules/
```

### Módulos Personalizados de Crypto-Policy (RHEL 9)

```bash
#============================================#
# CREAR MÓDULO DE POLÍTICA PERSONALIZADO
#============================================#

# Crear módulo personalizado
sudo vi /etc/crypto-policies/policies/modules/CUSTOM.pmod

# Contenido de ejemplo:
min_rsa_size = 3072
min_dh_size = 3072
min_dsa_size = 3072

# Aplicar
sudo update-crypto-policies --set DEFAULT:CUSTOM

# Probar
openssl ciphers -v | head
```

---

## 11.4 Validación de Certificados Más Estricta

### ¿Qué es Más Estricto en RHEL 9?

```bash
#============================================#
# EJEMPLOS DE VALIDACIÓN MÁS ESTRICTA
#============================================#

# 1. Firmas SHA-1 completamente rechazadas
openssl verify sha1-signed-cert.crt
# Error: CA md too weak

# 2. Autofirmados sin confianza CA apropiada rechazados
curl https://self-signed.example.com/
# Error: certificate verify failed

# 3. La cadena de certificados debe estar completa
# Intermedio faltante → conexión falla

# 4. El hostname debe coincidir (CN o SAN)
openssl s_client -connect server.example.com:443 -servername different.example.com
# Verification error: hostname mismatch

# 5. Claves < 2048 bits rechazadas
# (incluso en política LEGACY, < 1024 rechazadas)
```

### Impacto en Aplicaciones

**Aplicaciones compiladas contra OpenSSL 3.x:**
- Pueden necesitar cambios de código si usan APIs obsoletas
- El manejo de errores puede ser diferente
- El código crypto personalizado necesita pruebas

**Administradores de sistema:**
- ✅ La mayoría de cambios transparentes
- ✅ Los comandos son mayormente iguales
- ⚠️ La validación más estricta captura más problemas (¡esto es bueno!)

---

## 11.5 Automatización en RHEL 9: certmonger, certbot e IdM ACME

### Usa el cliente correcto para la CA correcta

```bash
#============================================#
# OPCIONES DE AUTOMATIZACIÓN EN RHEL 9
#============================================#

# Flujo nativo de certmonger para FreeIPA / IdM
sudo dnf install certmonger -y
sudo systemctl enable --now certmonger
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/internal.crt \
  -k /etc/pki/tls/private/internal.key \
  -K HTTP/$(hostname -f)@REALM \
  -D $(hostname -f) \
  -C "systemctl reload httpd"

# Flujo público con Let's Encrypt
# Usa certbot, no una definición falsa de CA Let's Encrypt en certmonger.
sudo certbot certonly --apache -d web.example.com

# Flujo IdM ACME (opcional)
# Esto apunta al directorio ACME de tu servidor IPA, no a Let's Encrypt.
sudo certbot certonly \
  --server https://ipa.example.com/acme/directory \
  -d host.example.com
```

**Importante:** IdM ACME y Let's Encrypt son CAs distintas. `certmonger` sigue siendo la herramienta nativa de RHEL para IPA, CA local y flujos de renovación con seguimiento.

---

## 11.6 Mejoras del Almacén de Confianza

### Gestión de Confianza Avanzada

```bash
#============================================#
# GESTIÓN DE CONFIANZA RHEL 9
#============================================#

# Agregar CA (igual que RHEL 7/8)
sudo cp corporate-ca.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust

# NUEVO: Confianza específica por propósito
trust anchor /path/to/ca.crt --purpose server-auth

# Listar confianza con detalles
trust list --filter=ca-anchors

# Exportar CA específica
trust extract --format=pem-bundle --filter=ca-anchors \
  --purpose server-auth /tmp/server-cas.pem

# Eliminar confianza específica
trust anchor --remove "pkcs11:id=%CERT_ID%"
```

---

## 11.7 Problemas y Soluciones Comunes en RHEL 9

### Problema 1: Cambios en API de OpenSSL 3.x

**Problema:** La aplicación personalizada falla con errores de OpenSSL

**Síntomas:**
```
Error: EVP_PKEY_RSA no longer supported
Error: Provider not available
```

**Solución:**
```bash
# Verificar si la aplicación está usando APIs obsoletas
# La aplicación necesita recompilación contra OpenSSL 3.x

# Temporal: Establecer variable de entorno de compatibilidad (si está disponible)
export OPENSSL_CONF=/etc/pki/tls/openssl-compat.cnf

# Largo plazo: Actualizar aplicación
```

### Problema 2: Certificados SHA-1 Rechazados

**Problema:** Certificados legacy con firmas SHA-1 fallan

**Síntomas:**
```bash
openssl verify cert.crt
# error 3: CA md too weak
```

**Solución:**
```bash
# Reemitir certificado con SHA-256+
# No hay solución alternativa - SHA-1 está bloqueado por seguridad

# Verificar firma del certificado
openssl x509 -in cert.crt -noout -text | grep "Signature Algorithm"
# Debe mostrar: sha256WithRSAEncryption o mejor
```

### Problema 3: Algoritmo Legacy No Disponible

**Problema:** La aplicación necesita MD5/RC4/etc.

**Síntomas:**
```bash
openssl md5 file.txt
# Error: unsupported
```

**Solución:**
```bash
# Usar proveedor legacy explícitamente
openssl md5 -provider legacy file.txt

# Para aplicaciones: Actualizar para usar SHA-256+
# O configurar para cargar proveedor legacy
```

---

## 11.8 Modo FIPS en RHEL 9

### Soporte FIPS Mejorado

```bash
#============================================#
# MODO FIPS (RHEL 9)
#============================================#

# Habilitar modo FIPS
sudo fips-mode-setup --enable
sudo reboot

# Verificar estado FIPS
fips-mode-setup --check
# FIPS mode is enabled.

# Verificar proveedor FIPS cargado
openssl list -providers | grep -A3 fips
#   fips
#     name: OpenSSL FIPS Provider
#     version: 3.5.5
#     status: active

# Generar certificado compatible con FIPS
openssl req -new -x509 -days 365 -newkey rsa:2048 \
  -keyout fips.key -out fips.crt \
  -subj "/CN=$(hostname)" -provider fips
```

**FIPS en RHEL 9:**
- Usa proveedor FIPS de OpenSSL 3.x
- Módulos validados FIPS 140-2
- Transición a FIPS 140-3 en progreso

---

## 11.9 Migración desde RHEL 8

### Impacto en Certificados

**Impacto Moderado:**
- Cambios en API de OpenSSL (afecta apps personalizadas)
- Validación más estricta (captura más problemas)
- Algoritmos legacy eliminados
- SHA-1 completamente bloqueado

### Verificaciones Pre-Migración

```bash
#============================================#
# PRE-MIGRACIÓN DE CERTIFICADOS RHEL 8 → 9
#============================================#

# 1. Verificar certificados SHA-1 (fallarán en RHEL 9)
for cert in /etc/pki/tls/certs/*.crt; do
  SIG=$(openssl x509 -in "$cert" -noout -text | grep "Signature Algorithm" | head -2)
  echo "$cert: $SIG"
done | grep -i sha1
# ⚠️ ¡Reemitir cualquier cert SHA-1 antes de migración!

# 2. Verificar aplicaciones personalizadas usando OpenSSL
rpm -qa | grep -E "custom|local"
# Probar estas aplicaciones en entorno RHEL 9

# 3. Verificar compatibilidad de crypto-policy
update-crypto-policies --show

# 4. Probar operaciones de certificados
openssl s_client -connect localhost:443

# 5. Respaldar todo
tar czf rhel8-certs-backup-$(date +%Y%m%d).tar.gz \
  /etc/pki/tls/ \
  /etc/pki/ca-trust/source/anchors/
```

---

## 11.10 Mejores Prácticas para RHEL 9

### Configuración Recomendada

```bash
#============================================#
# CONFIGURACIÓN RECOMENDADA (RHEL 9)
#============================================#

# 1. Usar crypto-policy DEFAULT (a menos que necesidad específica)
sudo update-crypto-policies --set DEFAULT

# 2. Usar certmonger para automatización nativa
sudo dnf install certmonger
sudo systemctl enable --now certmonger

# 3. Para sitios públicos: usar certbot con Let's Encrypt
sudo certbot certonly --apache -d web.example.com

# 4. Para interno: usar FreeIPA con certmonger
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/internal.crt \
  -k /etc/pki/tls/private/internal.key \
  -K host/$(hostname -f)@REALM

# 5. Generar claves EC (más pequeñas, más rápidas)
openssl genpkey -algorithm EC -out ec.key \
  -pkeyopt ec_paramgen_curve:P-256

# 6. Siempre usar SANs
openssl req -new -addext "subjectAltName=DNS:..."
```

---

## 11.11 Nuevas Características Que Deberías Usar

### Característica 1: Flujos más sólidos de certmonger + IPA

```bash
# Automatización nativa de RHEL para certificados internos
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/internal.crt \
  -k /etc/pki/tls/private/internal.key \
  -K HTTP/$(hostname -f)@REALM \
  -D $(hostname -f) \
  -C "systemctl reload httpd"

# Mejor salida de estado en RHEL 9
sudo getcert list -v
```

### Característica 2: Reporte de Estado Mejorado

```bash
# Estado más detallado
sudo getcert list -v

# Mejores mensajes de error
sudo getcert list -f /etc/pki/tls/certs/web.crt
# Muestra razón exacta del error si la renovación falla
```

### Característica 3: Subpolíticas de Crypto-Policy

```bash
# Afinar política DEFAULT
sudo update-crypto-policies --set DEFAULT:NO-SHA1

# Múltiples modificadores
sudo update-crypto-policies --set FUTURE:AD-SUPPORT
```

---

## 11.12 Cambios Incompatibles desde RHEL 8

### Cambios en API

**Si tienes aplicaciones personalizadas:**

```c
// RHEL 8 (OpenSSL 1.1.1) - OBSOLETO en RHEL 9:
RSA *rsa = RSA_new();

// RHEL 9 (OpenSSL 3.x) - API NUEVA:
EVP_PKEY *pkey = EVP_PKEY_new();
```

**Impacto:** Las aplicaciones compiladas personalizadas pueden necesitar actualizaciones

### Cambios en Comandos

```bash
# La mayoría de comandos funcionan igual, pero algunos casos especiales:

# RHEL 8: Esto funciona
openssl md5 file.txt

# RHEL 9: Requiere proveedor
openssl md5 -provider legacy file.txt

# Solución: Usar SHA-256 en su lugar
openssl sha256 file.txt
```

---

## 11.13 Escenarios Comunes en RHEL 9

### Escenario 1: Configuración HTTPS Apache Nueva en RHEL 9 (CA interna)

```bash
#============================================#
# CONFIGURACIÓN COMPLETA APACHE HTTPS (RHEL 9)
#============================================#

# 1. Instalar Apache con mod_ssl
sudo dnf install httpd mod_ssl -y

# 2. Usar certmonger + FreeIPA / IdM
sudo dnf install certmonger -y
sudo systemctl enable --now certmonger

# 3. Solicitar certificado
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/web.crt \
  -k /etc/pki/tls/private/web.key \
  -K HTTP/$(hostname -f)@REALM \
  -D $(hostname -f) \
  -C "systemctl reload httpd"

# 4. Esperar certificado (verificar estado)
sudo getcert list

# 5. Configurar Apache para usar certificado
# /etc/httpd/conf.d/ssl.conf ya apunta a:
#   SSLCertificateFile /etc/pki/tls/certs/localhost.crt
# Actualizar a:
#   SSLCertificateFile /etc/pki/tls/certs/web.crt
#   SSLCertificateKeyFile /etc/pki/tls/private/web.key

# 6. ¡Crypto-policy maneja ajustes TLS automáticamente!
# No necesitas establecer SSLProtocol o SSLCipherSuite

# 7. Abrir firewall
sudo firewall-cmd --add-service=https --permanent
sudo firewall-cmd --reload

# 8. Iniciar Apache
sudo systemctl enable httpd
sudo systemctl start httpd

# 9. Probar
curl -v https://$(hostname -f)/

# 10. ¡La renovación automática ocurre mucho antes de la expiración!
```

**Resultado:** ¡HTTPS interno totalmente automatizado con FreeIPA y certmonger!

---

## 11.14 Solución de Problemas de Certificados en RHEL 9

### Comandos de Diagnóstico

```bash
#============================================#
# DIAGNÓSTICO DE CERTIFICADOS RHEL 9
#============================================#

# Verificar versión de OpenSSL
openssl version
# OpenSSL 3.5.5

# Verificar proveedores
openssl list -providers

# Verificar crypto-policy
update-crypto-policies --show

# Probar conexión con TLS 1.3
openssl s_client -connect server:443 -tls1_3

# Verificar algoritmo de firma del certificado
openssl x509 -in cert.crt -noout -text | grep "Signature Algorithm"
# Debe ser SHA-256+ en RHEL 9

# Probar con proveedor legacy (si es necesario)
openssl md5 -provider legacy file.txt

# Verificar rastreo de certmonger
sudo getcert list

# Ver logs de certmonger
sudo journalctl -u certmonger -f
```

### Errores Comunes en RHEL 9

| Error | Causa | Solución |
|-------|-------|----------|
| "CA md too weak" | Firma SHA-1 | Reemitir con SHA-256+ |
| "Provider not available" | Algoritmo legacy usado | Agregar `-provider legacy` o actualizar a algoritmo moderno |
| "unsupported" en comando openssl | Algoritmo deshabilitado | Usar alternativa moderna o proveedor legacy |
| "no shared cipher" (app migrada) | Cliente usa cifrados antiguos | Actualizar cliente o usar política LEGACY temporalmente |
| "certificate verify failed" | Validación más estricta | Verificar cadena cert, SANs, expiración |

---

## 11.15 Cuándo Usar RHEL 9

### Ideal Para:

✅ **Nuevos despliegues** - Comenzar con seguridad moderna
✅ **Entornos enfocados en seguridad** - Valores predeterminados más estrictos
✅ **Aplicaciones modernas** - Beneficiarse de TLS 1.3
✅ **Soporte a largo plazo** - 10 años de mantenimiento
✅ **Requisitos de cumplimiento** - Estándares de seguridad modernos

### Momento de Migración:

**Desde RHEL 7:**
- ✅ ¡Sí! El mantenimiento de RHEL 7 terminó en junio 2024
- Planificar cuidadosamente - gran salto (probar exhaustivamente)

**Desde RHEL 8:**
- Moderado - OpenSSL 3.x es el cambio principal
- Probar aplicaciones personalizadas primero
- Los certificados SHA-1 deben ser reemitidos

---

## 11.16 Conclusiones Clave

1. **Arquitectura de proveedores OpenSSL 3.5.5** - Entender proveedores
2. **Validación más estricta** - Captura problemas de seguridad (¡bien!)
3. **SHA-1 completamente bloqueado** - Reemitir certificados antiguos
4. **Subpolíticas de crypto-policy** - Afinar seguridad
5. **certmonger sigue siendo valioso** para IPA y flujos de renovación con seguimiento
6. **Soporte obligatorio TLS 1.3** - Más rápido, más seguro
7. **Planificar pruebas** - Apps personalizadas pueden necesitar actualizaciones

---

## Referencia Rápida

```
┌──────────────────────────────────────────────────────────────┐
│ REFERENCIA RÁPIDA DE CERTIFICADOS RHEL 9                     │
├──────────────────────────────────────────────────────────────┤
│ OpenSSL:        3.5.5 (arquitectura de proveedores)          │
│ TLS:            1.2, 1.3 (1.0/1.1 eliminados completamente)  │
│ Característica: Subpolíticas, validación más estricta         │
│                                                              │
│ Proveedores:    openssl list -providers                      │
│ Política:       update-crypto-policies --show                │
│ Subpolítica:    update-crypto-policies --set DEFAULT:NO-SHA1 │
│                                                              │
│ Generar clave:  openssl genpkey -algorithm RSA -out key.pem  │
│ Clave EC:       openssl genpkey -algorithm EC -out ec.pem    │
│                 -pkeyopt ec_paramgen_curve:P-256             │
│                                                              │
│ ACME público:   certbot certonly --apache -d example.com     │
│ certmonger:     ipa-getcert request ...                      │
│ Algo legacy:    openssl md5 -provider legacy file.txt        │
└──────────────────────────────────────────────────────────────┘

⚠️ SHA-1 está BLOQUEADO - ¡reemitir certificados antiguos!
✅ Usar certmonger para IPA y automatización con seguimiento
✅ La política DEFAULT funciona para la mayoría de casos
```
---

**Navegación del Capítulo**

| [← Anterior: Capítulo 10 - RHEL 8 y Crypto-Policies](10-rhel8-crypto-policies.md) | [Siguiente: Capítulo 12 - Características Actuales de RHEL 10 →](12-rhel10-current.md) |
|:---|---:|
