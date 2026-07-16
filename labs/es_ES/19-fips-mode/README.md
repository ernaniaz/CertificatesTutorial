# Lab 19: Configuración del modo FIPS

## Objetivos de aprendizaje

Al completar este lab, usted:
- Comprenderá los requisitos de cumplimiento FIPS 140-2
- Habilitará el modo FIPS en RHEL
- Configurará certificados para FIPS
- Probará cumplimiento FIPS
- Resolverá problemas de FIPS
- Comprenderá las limitaciones de FIPS

## Requisitos previos

- **RHEL 8 o 9** (soporte para habilitar/deshabilitar FIPS)
- **Labs 01-10** completados
- **Acceso al sistema:** Se requiere root/sudo
- Se requiere **capacidad de reinicio**

> **Nota RHEL 10:** RHEL 10 no permite habilitar o deshabilitar el modo FIPS
> después de la instalación. FIPS debe configurarse durante la instalación del SO
> agregando `fips=1` a los parámetros de arranque del kernel o seleccionando FIPS
> en la política de seguridad del instalador Anaconda. Los scripts de verificación
> y prueba de este lab funcionan en RHEL 10, pero `enable-fips.sh` y
> `disable-fips.sh` no.

## Tiempo estimado

**40-50 minutos** (incluye reinicio)

## Descripción general

FIPS 140-2 es un estándar de seguridad del gobierno de EE. UU. para módulos criptográficos. Aprenda a habilitar y configurar el modo FIPS para requisitos de cumplimiento normativo.

---

## Descripción general del modo FIPS

### ¿Qué es FIPS?

**FIPS 140-2:** Federal Information Processing Standard Publication 140-2
- Programa de validación de módulos criptográficos
- Requerido para sistemas gubernamentales
- Especifica algoritmos aprobados
- Valida implementaciones

### Algoritmos aprobados por FIPS

**Permitidos:**
- AES (128, 192, 256 bits)
- RSA (2048+ bits)
- SHA-256, SHA-384, SHA-512
- ECDSA con curvas aprobadas
- HMAC con SHA-2

**Bloqueados:**
- MD5
- SHA-1 (firmas)
- DES, 3DES
- RC4
- RSA <2048 bits

---

## Instrucciones

### Paso 1: Evaluación pre-FIPS

Verifique el estado actual del sistema:

```bash
./check-fips-readiness.sh
```

### Paso 2: Habilitar modo FIPS

Habilite FIPS (requiere reinicio):

```bash
sudo ./enable-fips.sh
# El sistema se reiniciará
```

### Paso 3: Verificar modo FIPS

Después del reinicio, verifique:

```bash
./verify-fips.sh
```

### Paso 4: Probar certificados

Pruebe compatibilidad de certificados:

```bash
./test-fips-certificates.sh
```

### Paso 5: Configurar servicios

Actualice servicios para FIPS:

```bash
sudo ./configure-services-fips.sh
```

---

## Comandos clave

```bash
# Verificar estado FIPS
fips-mode-setup --check

# Habilitar FIPS (requiere reinicio) — solo RHEL 8 y 9
fips-mode-setup --enable

# Deshabilitar FIPS (requiere reinicio) — solo RHEL 8 y 9
fips-mode-setup --disable

# Verificar bandera FIPS del kernel
cat /proc/sys/crypto/fips_enabled
```

> **RHEL 10:** `fips-mode-setup --enable` y `--disable` no son compatibles.
> FIPS se establece solo en el momento de la instalación.

---

## Validación

Verifique que el modo FIPS esté configurado correctamente:

```bash
./verify-fips.sh
```

**Resultados esperados:**
- ✓ Modo FIPS habilitado: `/proc/sys/crypto/fips_enabled` muestra `1`
- ✓ `fips-mode-setup --check` informa que FIPS está habilitado
- ✓ `openssl md5 /dev/null` falla porque MD5 está deshabilitado en modo FIPS

**Comprobaciones manuales adicionales:**
```bash
# Verificar parámetro FIPS del kernel
cat /proc/sys/crypto/fips_enabled  # Debe mostrar 1

# Verificar crypto-policy
update-crypto-policies --show  # Debe mostrar FIPS

# Probar OpenSSL FIPS
openssl md5 /etc/hosts  # Debe fallar con error FIPS

# Verificar configuraciones de servicios
systemctl status httpd
journalctl -u httpd | grep -i fips
```

---

## Problemas comunes

### Problema: El servicio no inicia

**Síntoma:** El servicio falla con error de "modo FIPS"

**Solución:** Usar solo algoritmos aprobados por FIPS

### Problema: Clave débil rechazada

**Síntoma:** RSA <2048 bits rechazado

**Solución:** Regenerar con 2048+ bits

### Problema: Certificado SHA-1 falla

**Síntoma:** Certificado con firma SHA-1 rechazado

**Solución:** Usar certificados SHA-256+

---

## Limpieza

```bash
sudo ./cleanup.sh
```

**Nota:** Deshabilitar FIPS requiere otro reinicio.

---

**Nivel de dificultad**: Avanzado  
**Nota**: El modo FIPS tiene implicaciones significativas de compatibilidad
