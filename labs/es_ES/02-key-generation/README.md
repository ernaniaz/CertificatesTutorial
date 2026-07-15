# Lab 02: Generación de claves

## Objetivos de aprendizaje

Al completar este laboratorio, podrás:
- Generar pares de claves RSA (2048 bits y 4096 bits)
- Generar pares de claves de curva elíptica (ECC) (P-256 y P-384)
- Extraer claves públicas a partir de claves privadas
- Comprender los formatos de archivo de claves y los permisos
- Comparar diferentes tamaños de claves y algoritmos

## Requisitos previos

- **Lab 01** completado (configuración del entorno)
- **Versión de RHEL:** 7, 8, 9 o 10
- **Acceso al sistema:** Usuario regular (no se requiere root)

## Tiempo estimado

**20-25 minutos**

## Descripción general del laboratorio

Aprende a generar pares de claves criptográficas con OpenSSL. Las claves son la base de las operaciones con certificados: comprender cómo crearlas y gestionarlas es esencial.

---

## Instrucciones

### Paso 1: Generar claves RSA

Ejecuta el script de generación de claves RSA:

```bash
./generate-rsa-keys.sh
```

Esto crea:
- `output/rsa-2048.key` - Clave privada RSA de 2048 bits (mínimo para producción)
- `output/rsa-2048.pub` - Clave pública correspondiente
- `output/rsa-4096.key` - Clave privada RSA de 4096 bits (recomendada para alta seguridad)
- `output/rsa-4096.pub` - Clave pública correspondiente

**Ver una clave:**
```bash
openssl pkey -in output/rsa-2048.key -text -noout | head -20
```

---

### Paso 2: Generar claves ECC

Ejecuta el script de generación de claves ECC:

```bash
./generate-ecc-keys.sh
```

Esto crea:
- `output/ecc-p256.key` - Clave privada P-256 (secp256r1)
- `output/ecc-p256.pub` - Clave pública correspondiente
- `output/ecc-p384.key` - Clave privada P-384 (secp384r1)
- `output/ecc-p384.pub` - Clave pública correspondiente

**Ver una clave ECC:**
```bash
openssl pkey -in output/ecc-p256.key -text -noout
```

---

### Paso 3: Verificar las claves

Ejecuta el script de verificación:

```bash
./verify-keys.sh
```

Esto valida:
- Que todas las claves se generaron correctamente
- Que las claves privadas tienen los permisos correctos (600)
- Que las claves públicas tienen los permisos correctos (644)
- Que las claves tienen formato válido de OpenSSL

---

### Paso 4: Comparar tamaños de claves

Ver los tamaños de archivo:

```bash
ls -lh output/
```

**Observación:**
- Las claves RSA son archivos más grandes
- Las claves ECC son mucho más pequeñas para una seguridad equivalente
- P-256 ECC ≈ seguridad de RSA de 3072 bits
- P-384 ECC ≈ seguridad de RSA de 7680 bits

---

## Validación

Ejecuta el script de prueba:

```bash
./test.sh
```

Todas las comprobaciones deben pasar.

## Resultado esperado

Después de completar este laboratorio, deberías tener:
- ✅ Pares de claves RSA de 2048 y 4096 bits generados
- ✅ Pares de claves ECC P-256 y P-384 generados
- ✅ Todas las claves con permisos correctos
- ✅ Comprensión de las diferencias entre RSA y ECC

---

## Resolución de problemas

### Problema: Permiso denegado

**Síntoma:**
```
Permission denied: output/
```

**Solución:**
```bash
mkdir -p output
chmod 755 output
```

---

### Problema: Comando OpenSSL no encontrado

**Síntoma:**
```
bash: openssl: command not found
```

**Solución:**
Vuelve al Lab 01 y ejecuta el script de configuración.

---

## Conceptos clave

### Tamaños de claves RSA
- **2048 bits:** Mínimo para crypto-policies DEFAULT de RHEL 8+
- **4096 bits:** Recomendado para seguridad a largo plazo

### Curvas ECC
- **P-256 (prime256v1):** Mínimo, equivalente a RSA de 3072 bits
- **P-384 (secp384r1):** Más fuerte, equivalente a RSA de 7680 bits

### Permisos de archivos
- **Claves privadas:** Modo 600 (solo lectura/escritura del propietario)
- **Claves públicas:** Modo 644 (legible por todos)

---

## Limpieza

```bash
./cleanup.sh
```

Esto elimina el directorio `output/` y todas las claves generadas.

---

## Recursos adicionales

**Capítulos relacionados:**
- Capítulo 4: Criptografía básica para administradores de RHEL

**Documentación:**
- `man genpkey`
- `man pkey`
- `man ecparam`

---

## Próximos pasos

Continúa con **Lab 03: Firmas digitales** para aprender a firmar y verificar archivos con estas claves.

---

**Nivel de dificultad:** Principiante
