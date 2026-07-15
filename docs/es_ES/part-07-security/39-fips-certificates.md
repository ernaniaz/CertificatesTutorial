# Capítulo 39: Certificados Compatibles con FIPS

> **Listo para Cumplimiento:** Aprende cómo generar, validar y gestionar certificados compatibles con FIPS en RHEL para entornos federales y regulados.

---

## 39.1 Requisitos de Certificados FIPS

### Requisitos Obligatorios

**Para Cumplimiento FIPS 140-2/140-3:**

```
✅ Algoritmo de Clave: RSA 2048+ o ECC P-256/384/521
✅ Firma: SHA-256, SHA-384, o SHA-512
✅ Protocolos TLS: Solo 1.2 o 1.3
✅ Generado en modo FIPS (para claves nuevas)
✅ Módulo validado usado para operaciones

❌ NO MD5, SHA-1
❌ NO RSA < 2048 bits
❌ NO TLS 1.0/1.1
❌ NO 3DES, RC4, DES
❌ NO algoritmos no aprobados
```

---

## 39.2 Generar Certificados FIPS

### Flujo de Trabajo Completo de Certificado FIPS

```bash
#============================================#
# GENERACIÓN COMPLETA DE CERTIFICADO FIPS
#============================================#

# Prerrequisitos: Modo FIPS debe estar habilitado
fips-mode-setup --check
# FIPS mode is enabled.

# Paso 1: Generar clave RSA conforme a FIPS
openssl genpkey -algorithm RSA \
  -out /etc/pki/tls/private/fips-server.key \
  -pkeyopt rsa_keygen_bits:2048

# O más fuerte (3072/4096)
openssl genpkey -algorithm RSA \
  -out /etc/pki/tls/private/fips-server.key \
  -pkeyopt rsa_keygen_bits:3072

# Paso 2: Establecer permisos
sudo chmod 600 /etc/pki/tls/private/fips-server.key

# Paso 3: Generar CSR con SHA-256
openssl req -new \
  -key /etc/pki/tls/private/fips-server.key \
  -out /tmp/fips-server.csr \
  -sha256 \
  -subj "/C=US/O=Federal Agency/OU=IT/CN=secure.example.gov" \
  -addext "subjectAltName=DNS:secure.example.gov,DNS:www.secure.example.gov"

# Paso 4: Verificar CSR
openssl req -in /tmp/fips-server.csr -noout -text | grep -E "(Signature Algorithm|Public-Key)"
# Signature Algorithm: sha256WithRSAEncryption  ← Debe ser SHA-256+
# Public-Key: (2048 bit)  ← Debe ser 2048+

# Paso 5: Enviar a CA conforme a FIPS
# Recibir certificado de vuelta

# Paso 6: Verificar cumplimiento del certificado
openssl x509 -in fips-server.crt -noout -text | grep "Signature Algorithm"
# Signature Algorithm: sha256WithRSAEncryption  ← ¡Bueno!
```

### Claves EC Conformes a FIPS

```bash
#============================================#
# CLAVES DE CURVA ELÍPTICA PARA FIPS
#============================================#

# P-256 (aprobada por FIPS)
openssl genpkey -algorithm EC \
  -out /etc/pki/tls/private/fips-ec.key \
  -pkeyopt ec_paramgen_curve:P-256

# P-384 (más fuerte, aprobada por FIPS)
openssl genpkey -algorithm EC \
  -out /etc/pki/tls/private/fips-ec.key \
  -pkeyopt ec_paramgen_curve:P-384

# Generar CSR
openssl req -new -key /etc/pki/tls/private/fips-ec.key \
  -out /tmp/fips-ec.csr \
  -sha256 \
  -subj "/CN=secure.example.gov"
```

---

## 39.3 Validar Cumplimiento FIPS

### Verificación de Cumplimiento de Certificado

```bash
#!/bin/bash
# check-fips-compliance.sh
# Verificar que certificado es conforme a FIPS

CERT=$1

if [ -z "$CERT" ] || [ ! -f "$CERT" ]; then
  echo "Uso: $0 /path/to/certificate.crt"
  exit 1
fi

echo "=== Verificación de Cumplimiento FIPS ==="
echo "Certificado: $CERT"
echo ""

COMPLIANT=true

# Verificar algoritmo de firma
SIG_ALG=$(openssl x509 -in "$CERT" -noout -text | grep "Signature Algorithm" | head -2)
echo "Algoritmo de Firma: $SIG_ALG"

if echo "$SIG_ALG" | grep -Eqi "md5|sha1"; then
  echo "  ❌ FALLÓ: MD5/SHA-1 no aprobados por FIPS"
  COMPLIANT=false
else
  echo "  ✅ PASÓ: Firma aprobada por FIPS"
fi

# Verificar tamaño de clave
KEY_SIZE=$(openssl x509 -in "$CERT" -noout -text | grep "Public-Key" | grep -oP '\d+')
echo ""
echo "Tamaño de Clave: $KEY_SIZE bits"

if [ "$KEY_SIZE" -lt 2048 ]; then
  echo "  ❌ FALLÓ: Tamaño de clave < 2048 bits"
  COMPLIANT=false
else
  echo "  ✅ PASÓ: Tamaño de clave adecuado"
fi

# Verificar algoritmo de clave
KEY_ALG=$(openssl x509 -in "$CERT" -noout -text | grep "Public Key Algorithm")
echo ""
echo "Algoritmo de Clave: $KEY_ALG"

if echo "$KEY_ALG" | grep -qi "dsa"; then
  echo "  ❌ FALLÓ: DSA no aprobado por FIPS"
  COMPLIANT=false
fi

# Resultado final
echo ""
echo "================================"
if [ "$COMPLIANT" = true ]; then
  echo "✅ El certificado es CONFORME A FIPS"
  exit 0
else
  echo "❌ El certificado NO es conforme a FIPS"
  echo "   Reemitir con parámetros aprobados por FIPS"
  exit 1
fi
```

---

## 39.4 Selección de CA FIPS

### La CA Debe Estar Validada por FIPS

**CA Interna:**
- Usar FreeIPA en modo FIPS
- Dogtag PKI (CA de FreeIPA) tiene validación FIPS

**CA Externa:**
- Verificar que CA esté validada FIPS 140-2/140-3
- Solicitar documentación de cumplimiento FIPS
- CAs FIPS comunes: DigiCert Federal, Entrust, IdenTrust

---

## 39.5 Configuración de Servicios para FIPS

### Servicios Automáticamente Conformes a FIPS

Cuando se habilita modo FIPS, todos los servicios usan automáticamente crypto-policy FIPS:

```bash
# Apache - no se necesita configuración especial
# Solo asegurar que certificado es conforme a FIPS

# NGINX - usa automáticamente política FIPS

# Postfix - conforme a FIPS automáticamente

# Verificar cada servicio
openssl s_client -connect localhost:443
# Verificar cifrado usado - debería ser aprobado por FIPS
```

---

## 39.6 Conclusiones Clave

1. **FIPS 140-2 es el estándar** validado actual en RHEL
2. **Transición FIPS 140-3** está en progreso
3. **Habilitar en instalación** para mejores resultados
4. **Solo RSA 2048+ o ECC P-256/384**
5. **Firmas SHA-256+** requeridas
6. **Los servicios cumplen automáticamente** con política FIPS
7. **Probar aplicaciones** antes de habilitar FIPS

---

## Tarjeta de Referencia Rápida

```
┌───────────────────────────────────────────────────────────────┐
│ REFERENCIA RÁPIDA CERTIFICADOS CONFORMES A FIPS               │
├───────────────────────────────────────────────────────────────┤
│ Estándar:   FIPS 140-2 (validado actual)                      │
│             FIPS 140-3 (transición en progreso)               │
│                                                               │
│ Claves:     RSA 2048/3072/4096                                │
│             ECC P-256/384/521                                 │
│                                                               │
│ Firma:      SHA-256, SHA-384, SHA-512                         │
│             (NO MD5, NO SHA-1)                                │
│                                                               │
│ Generar:    openssl genpkey -algorithm RSA ... (en modo FIPS) │
│ CSR:        openssl req -new -sha256 ...                      │
│ Verificar:  Verificar alg firma, tamaño clave                 │
│                                                               │
│ Probar:     echo test | openssl md5                           │
│             (debería fallar si FIPS funciona)                 │
└───────────────────────────────────────────────────────────────┘

✅ Modo FIPS debe estar habilitado para cumplimiento
✅ Todas las operaciones usan módulos criptográficos validados
⚠️ Verificar estado actual 140-2/140-3 para tus necesidades
```
---

**Navegación del Capítulo**

| [← Anterior: Capítulo 38 - Guía Completa del Modo FIPS](38-fips-mode-guide.md) | [Siguiente: Capítulo 40 - Fortalecimiento de Seguridad RHEL para Certificados →](40-security-hardening.md) |
|:---|---:|
