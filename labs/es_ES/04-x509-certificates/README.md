# Lab 04: Certificados X.509

## Objetivos de aprendizaje

Al completar este laboratorio, podrás:
- Crear certificados X.509 autofirmados
- Generar Certificate Signing Requests (CSR)
- Inspeccionar campos del certificado (subject, issuer, fechas, SANs)
- Comprender Subject Alternative Names (SANs)
- Convertir entre formatos PEM y DER
- Verificar la validez del certificado

## Requisitos previos

- **Lab 02** completado (generación de claves)
- **Versión de RHEL:** 7, 8, 9 o 10

## Tiempo estimado

**25-30 minutos**

## Descripción general del laboratorio

X.509 es el formato estándar de certificados usado en todas partes en RHEL. Aprende a crear, inspeccionar y validar certificados X.509.

---

## Instrucciones

### Paso 1: Crear un certificado autofirmado

Genera un certificado autofirmado:

```bash
./create-self-signed.sh
```

Esto crea:
- `output/server.crt` - Certificado autofirmado
- Usa la clave RSA-2048 del Lab 02
- Incluye Subject Alternative Names (SANs)

**Inspeccionar el certificado:**
```bash
openssl x509 -in output/server.crt -text -noout | head -40
```

---

### Paso 2: Crear un Certificate Signing Request (CSR)

Genera un CSR (para enviarlo a una CA):

```bash
./create-csr.sh
```

Crea `output/server.csr` con:
- Subject: /CN=server.example.com/O=Lab/C=US
- SANs: server.example.com, www.example.com

**Inspeccionar el CSR:**
```bash
openssl req -in output/server.csr -text -noout
```

---

### Paso 3: Inspeccionar campos del certificado

Ejecuta el script de inspección:

```bash
./inspect-cert.sh
```

Esto muestra:
- Subject (a quién identifica el certificado)
- Issuer (quién lo firmó — igual en certificados autofirmados)
- Fechas de validez (Not Before / Not After)
- Subject Alternative Names (SANs) — OBLIGATORIO en RHEL 9+
- Algoritmo y tamaño de la clave pública
- Algoritmo de firma

---

### Paso 4: Convertir formatos

Convierte entre PEM y DER:

```bash
./convert-formats.sh
```

Crea:
- `output/server.der` - Formato DER binario
- `output/server-from-der.pem` - Convertido de vuelta a PEM

**Comparar tamaños de archivo:**
```bash
ls -lh output/server.{crt,der}
```

DER es binario (más pequeño), PEM es Base64 (legible por humanos).

---

## Validación

```bash
./test.sh
```

Todas las comprobaciones deben pasar.

## Resultado esperado

Después de completar este laboratorio:
- ✅ Certificado autofirmado creado
- ✅ CSR creado correctamente
- ✅ Comprensión de la estructura del certificado
- ✅ Capacidad de inspeccionar campos del certificado
- ✅ Capacidad de convertir entre PEM y DER

---

## Conceptos clave

### Estructura del certificado X.509

| Campo | Propósito |
|-------|-----------|
| Version | v3 (incluye extensiones) |
| Serial Number | Identificador único |
| Signature Algorithm | Cómo se firma el certificado (p. ej., sha256WithRSAEncryption) |
| Issuer | Quién firmó el certificado (CA) |
| Validity | Fechas Not Before / Not After |
| Subject | A quién identifica el certificado |
| Public Key | Clave pública del subject |
| Extensions | SANs, Key Usage, etc. |
| Signature | Firma digital de la CA |

### Subject Alternative Names (SANs)

**Crítico para RHEL 9+**: Los certificados DEBEN incluir SANs para la validación del nombre de host.

Ejemplo:
```
X509v3 Subject Alternative Name:
    DNS:server.example.com, DNS:www.example.com, IP:192.168.1.10
```

### PEM vs DER

- **PEM**: Codificado en Base64, encabezados `-----BEGIN CERTIFICATE-----`
- **DER**: ASN.1 binario, usado por algunas aplicaciones y dispositivos

---

## Resolución de problemas

### Problema: SANs no incluidos

**Síntoma:**
El certificado no incluye Subject Alternative Names

**Solución:**
RHEL 9+ requiere configuración explícita de SANs. Los scripts incluyen SANs automáticamente.

---

### Problema: Certificado ya expirado

**Síntoma:**
```
notAfter=... (certificate has expired)
```

**Solución:**
Los certificados autofirmados se crean con validez de 365 días. Regenera si expiró:
```bash
./create-self-signed.sh
```

---

## Notas específicas por versión

### RHEL 7-8
- SANs recomendados pero no estrictamente obligatorios
- Advertencias del navegador sin SANs

### RHEL 9+
- SANs **OBLIGATORIOS** para la validación
- Firmas SHA-1 bloqueadas
- Usar SHA-256 o superior

---

## Limpieza

```bash
./cleanup.sh
```

---

## Recursos adicionales

**Capítulos relacionados:**
- Capítulo 5: Certificados X.509 en RHEL

**Documentación:**
- `man x509`
- `man req`

---

## Próximos pasos

Continúa con **Lab 05: Gestión del almacén de confianza** para aprender sobre la confianza CA a nivel del sistema.

---

**Nivel de dificultad**: Principiante
