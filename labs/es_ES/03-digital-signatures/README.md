# Lab 03: Firmas digitales

## Objetivos de aprendizaje

Al completar este laboratorio, podrás:
- Firmar archivos con claves privadas
- Verificar firmas con claves públicas
- Comprender algoritmos hash (SHA-256)
- Demostrar la detección de manipulación
- Practicar flujos de trabajo de validación de firmas

## Requisitos previos

- **Lab 02** completado (generación de claves)
- **Versión de RHEL:** 7, 8, 9 o 10

## Tiempo estimado

**20 minutos**

## Descripción general del laboratorio

Las firmas digitales demuestran autenticidad e integridad. Aprende a firmar archivos y verificar que las firmas detectan cualquier manipulación.

---

## Instrucciones

### Paso 1: Firmar un archivo

Firma el archivo de ejemplo:

```bash
./sign-file.sh
```

Esto crea `sample-data.sig` — una firma digital de `sample-data.txt`.

**Ver la firma (hex):**
```bash
hexdump -C sample-data.sig | head -5
```

---

### Paso 2: Verificar la firma

Verifica la firma:

```bash
./verify-signature.sh
```

**Resultado esperado:**
```
Verified OK
```

---

### Paso 3: Prueba de detección de manipulación

Demuestra que las firmas detectan la manipulación:

```bash
./tamper-test.sh
```

El script:
1. Modifica el archivo
2. Intenta verificar con la firma original
3. **Debe fallar** — demostrando que se detectó la manipulación

---

## Validación

```bash
./test.sh
```

Todas las pruebas deben pasar.

## Resultado esperado

Después de completar este laboratorio:
- ✅ Archivo firmado correctamente
- ✅ La firma se verifica correctamente
- ✅ El archivo manipulado falla la verificación
- ✅ Comprensión del flujo de trabajo de firmas digitales

---

## Conceptos clave

### Proceso de firma digital

1. **Calcular hash** del mensaje (SHA-256)
2. **Cifrar** el hash con la clave privada = firma
3. **Enviar** mensaje + firma
4. **Descifrar** la firma con la clave pública = hash original
5. **Calcular hash** del mensaje recibido
6. **Comparar** hashes — coinciden = válido

### Por qué funciona

- Solo quien posee la clave privada puede crear firmas válidas
- Cualquiera con la clave pública puede verificar
- Cualquier cambio en el mensaje modifica el hash
- La firma no coincidirá si el mensaje fue alterado

---

## Resolución de problemas

### Problema: Claves no encontradas

**Síntoma:**
```
Error: ../02-key-generation/output/rsa-2048.key not found
```

**Solución:**
Completa primero el Lab 02:
```bash
cd ../02-key-generation
./generate-rsa-keys.sh
cd ../03-digital-signatures
```

---

## Limpieza

```bash
./cleanup.sh
```

---

## Recursos adicionales

**Capítulos relacionados:**
- Capítulo 7: Firmas digitales y verificación en RHEL

---

## Próximos pasos

Continúa con **Lab 04: Certificados X.509** para crear certificados reales.

---

**Nivel de dificultad:** Principiante
