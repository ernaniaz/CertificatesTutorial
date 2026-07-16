# Lab 05: Gestión del almacén de confianza

## Objetivos de aprendizaje

Al completar este laboratorio, podrás:
- Crear una Certificate Authority (CA) personalizada
- Agregar una CA personalizada al almacén de confianza del sistema
- Usar update-ca-trust para actualizar el sistema
- Verificar operaciones de confianza de CA
- Eliminar CAs personalizadas de la confianza
- Comprender la estructura de /etc/pki/ca-trust/

## Requisitos previos

- **Lab 04** completado (certificados X.509)
- **Versión de RHEL:** 7, 8, 9 o 10
- **Acceso al sistema:** Se requiere root/sudo

## Tiempo estimado

**25 minutos**

## Descripción general del laboratorio

Aprende a gestionar la confianza de certificados a nivel del sistema en RHEL. Esto es esencial para trabajar con CAs internas, certificados autofirmados e infraestructura PKI personalizada.

---

## Instrucciones

### Paso 1: Crear un certificado CA de prueba

Genera un certificado CA personalizado:

```bash
./create-test-ca.sh
```

Crea:
- `output/test-ca.key` - Clave privada de la CA
- `output/test-ca.crt` - Certificado de la CA

---

### Paso 2: Agregar la CA al almacén de confianza del sistema

Agrega la CA al almacén de confianza del sistema:

```bash
sudo ./add-custom-ca.sh
```

Esto copia el certificado de la CA a:
```
/etc/pki/ca-trust/source/anchors/lab-test-ca.crt
```

---

### Paso 3: Actualizar la confianza del sistema

Ejecuta update-ca-trust para reconstruir el paquete del sistema:

```bash
sudo ./update-trust.sh
```

Esto regenera `/etc/pki/tls/certs/ca-bundle.crt` para incluir tu CA personalizada.

---

### Paso 4: Verificar la confianza

Prueba que tu CA ahora es de confianza:

```bash
./verify-trust.sh
```

Esto:
1. Crea un certificado firmado por tu CA
2. Lo verifica con la confianza del sistema (debe tener éxito)
3. Demuestra que la CA es de confianza a nivel del sistema

---

### Paso 5: Eliminar la CA personalizada

Limpia eliminando la CA de la confianza:

```bash
sudo ./remove-ca.sh
```

---

## Validación

```bash
sudo ./test.sh
```

Todas las pruebas deben pasar.

## Resultado esperado

Después de completar este laboratorio:
- ✅ CA personalizada creada
- ✅ CA agregada al almacén de confianza del sistema
- ✅ Confianza del sistema actualizada correctamente
- ✅ Los certificados firmados por la CA se verifican correctamente
- ✅ CA eliminada de la confianza
- ✅ Comprensión de la gestión del almacén de confianza en RHEL

---

## Conceptos clave

### Estructura del almacén de confianza de RHEL

```
/etc/pki/ca-trust/
├── source/
│   └── anchors/          ← Agregar CAs personalizadas aquí
├── extracted/
│   ├── openssl/          ← Paquetes generados
│   ├── pem/
│   └── java/
└── ca-bundle.trust.p11-kit
```

### Comando update-ca-trust

Reconstruye los paquetes de confianza del sistema a partir de:
1. CAs del sistema (`/usr/share/pki/ca-trust-source/`)
2. CAs personalizadas (`/etc/pki/ca-trust/source/anchors/`)

Después de ejecutarlo:
- `/etc/pki/tls/certs/ca-bundle.crt` actualizado
- Todas las aplicaciones que usan la confianza del sistema recogen los cambios

### Casos de uso

**Agregar una CA personalizada cuando:**
- Usas una CA interna/corporativa
- Trabajas con certificados autofirmados
- Pruebas con PKI privada
- Integras con servicios empresariales

---

## Resolución de problemas

### Problema: Permiso denegado

**Síntoma:**
```
Permission denied: /etc/pki/ca-trust/source/anchors/
```

**Solución:**
Todas las operaciones de confianza requieren root:
```bash
sudo ./add-custom-ca.sh
```

---

### Problema: CA no de confianza después de agregarla

**Síntoma:**
El certificado aún no se verifica

**Solución:**
¿Ejecutaste update-ca-trust?
```bash
sudo update-ca-trust extract
```

---

## Notas específicas por versión

### Todas las versiones de RHEL (7, 8, 9, 10)
- Misma estructura del almacén de confianza
- Mismo comando update-ca-trust
- CAs agregadas a `/etc/pki/ca-trust/source/anchors/`

### Buenas prácticas
- Usar nombres descriptivos para los archivos de CA
- Documentar por qué se confía en cada CA
- Eliminar CAs cuando ya no se necesiten
- Probar después de agregar CAs

---

## Limpieza

```bash
sudo ./cleanup.sh
```

Esto elimina:
- La CA personalizada del almacén de confianza del sistema
- Certificados y claves generados
- Actualiza el almacén de confianza del sistema

---

## Recursos adicionales

**Capítulos relacionados:**
- Capítulo 6: Inmersión profunda en el almacén de confianza de RHEL

**Documentación:**
- `man update-ca-trust`
- `/usr/share/doc/ca-certificates/`

---

## Próximos pasos

**¡Laboratorios de fundamentos completados!** Ahora puedes:
- Continuar con **Lab 06: Configuración de Apache HTTPS** para la configuración de servicios
- O explorar la automatización con **Lab 11: Fundamentos de certmonger**
- O ir directamente a **Lab 15: Escenarios de resolución de problemas** para resolver problemas de forma práctica

---

**Nivel de dificultad**: Principiante
