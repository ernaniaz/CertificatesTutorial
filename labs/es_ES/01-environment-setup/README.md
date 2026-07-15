# Lab 01: Configuración del entorno

## Objetivos de aprendizaje

Al completar este laboratorio, podrás:
- Verificar que tu sistema RHEL esté configurado correctamente
- Instalar herramientas esenciales de gestión de certificados
- Comprender la estructura del directorio /etc/pki/
- Validar la instalación y versión de OpenSSL
- Preparar tu sistema para los laboratorios posteriores de certificados

## Requisitos previos

- **Versión de RHEL:** RHEL 7, 8, 9 o 10
- **Acceso al sistema:** Se requieren privilegios de root o sudo
- **Red:** Conectividad a Internet para la instalación de paquetes

## Tiempo estimado

**15-20 minutos**

## Descripción general del laboratorio

Este laboratorio valida y prepara tu sistema RHEL para los ejercicios de gestión de certificados. Instalarás las herramientas necesarias y verificarás que la infraestructura de certificados esté en su lugar.

---

## Instrucciones

### Paso 1: Identificar tu versión de RHEL

Primero, identifiquemos qué versión de RHEL estás ejecutando:

```bash
cat /etc/redhat-release
```

**Resultado esperado:**
```
Red Hat Enterprise Linux release 8.x (Ootpa)
# o similar para RHEL 7, 9 o 10
```

Comprobar la versión de OpenSSL:
```bash
openssl version
```

**Versión por RHEL:**
- RHEL 7: OpenSSL 1.0.2k
- RHEL 8: OpenSSL 1.1.1k
- RHEL 9: OpenSSL 3.5.5
- RHEL 10: OpenSSL 3.5.5

---

### Paso 2: Ejecutar el script de configuración

Ejecuta el script de configuración:

```bash
sudo ./setup.sh
```

El script instalará:
- OpenSSL (operaciones con certificados)
- Herramientas NSS / certutil (gestión de bases de datos NSS)
- certmonger (renovación automática de certificados)
- ca-certificates (almacén de confianza del sistema)

---

### Paso 3: Verificar la instalación

Después de la instalación, ejecuta el script de verificación:

```bash
./verify-environment.sh
```

**Resultado esperado:**
```
┌─────────────────────────────────────────────────────────┐
│ Lab 01: Verificación del entorno                        │
└─────────────────────────────────────────────────────────┘

Versión de RHEL: 8

  ✓ OpenSSL: OpenSSL 1.1.1k FIPS  25 Mar 2021
  ✓ certutil disponible
  ✓ certmonger disponible
  ✓ Crypto-policies: DEFAULT

Directorios de certificados:
  ✓ /etc/pki/tls/certs
  ✓ /etc/pki/tls/private
  ✓ /etc/pki/ca-trust
  ✓ Bundle de CA: 140 líneas

  ✓ ¡Todas las validaciones pasaron!
  ✓ Lab 01 completado correctamente.

Siguiente: continúe con Lab 02: Generación de claves
```

---

### Paso 4: Explorar la estructura de directorios de certificados

Ver la estructura de directorios de certificados:

```bash
tree -L 2 /etc/pki/
```

**Directorios clave:**
- `/etc/pki/tls/certs/` - Certificados de servidor (públicos)
- `/etc/pki/tls/private/` - Claves privadas (¡modo 600!)
- `/etc/pki/ca-trust/` - Certificados CA de confianza
- `/etc/pki/nssdb/` - Base de datos NSS

Comprobar el paquete CA del sistema:
```bash
ls -lh /etc/pki/tls/certs/ca-bundle.crt
wc -l /etc/pki/tls/certs/ca-bundle.crt
```

---

## Validación

Para verificar que el laboratorio está completo, ejecuta:

```bash
./verify-environment.sh
```

Todas las comprobaciones deben pasar con símbolos ✓.

## Resultado esperado

Después de completar este laboratorio, deberías tener:
- ✅ Versión de RHEL identificada
- ✅ OpenSSL instalado y versión verificada
- ✅ Herramientas de certificados instaladas (certutil, certmonger)
- ✅ Estructura del directorio /etc/pki/ validada
- ✅ Paquete CA del sistema accesible

---

## Resolución de problemas

### Problema 1: Falla la instalación de paquetes

**Síntoma:**
```
Error: Unable to find a match: certmonger
```

**Causa:**
Repositorio no configurado o suscripción de RHEL inactiva

**Solución:**
```bash
# Comprobar el estado de la suscripción de RHEL
sudo subscription-manager status

# Si no está registrado, registrar el sistema
sudo subscription-manager register

# Habilitar los repositorios necesarios
sudo subscription-manager repos --enable=rhel-8-for-x86_64-baseos-rpms
```

---

### Problema 2: Permiso denegado

**Síntoma:**
```
Permission denied when accessing /etc/pki/
```

**Causa:**
El script no se ejecutó con sudo/root

**Solución:**
Ejecutar los scripts de configuración con sudo:
```bash
sudo ./setup.sh
```

---

## Notas específicas por versión

### RHEL 7
- Usa el gestor de paquetes YUM
- OpenSSL 1.0.2k (más antiguo, pero funcional)
- Se requiere configuración manual de SSL/TLS para los servicios

### RHEL 8+
- Usa el gestor de paquetes DNF
- Se introduce el sistema crypto-policies
- Gestión automática de versiones TLS y cifrados

### RHEL 9+
- OpenSSL 3.x (cambio de versión mayor)
- Firmas SHA-1 bloqueadas por defecto
- Validación de certificados más estricta

---

## Limpieza

Este laboratorio no requiere limpieza, ya que solo instala paquetes del sistema. Si deseas eliminar los paquetes:

```bash
sudo ./cleanup.sh
```

**Advertencia:** Ejecuta la limpieza solo si estás seguro de que no necesitarás estas herramientas.

---

## Recursos adicionales

**Capítulos relacionados:**
- Capítulo 1: Criptografía, Estructura PKI y Fundamentos
- Capítulo 2: Introducción a los Certificados en RHEL
- Capítulo 3: Resumen de Herramientas de Certificados en RHEL

**Documentación:**
- `man openssl`
- `man certutil`
- `man getcert` (certmonger)

---

## Próximos pasos

Después de completar este laboratorio, continúa con:

**Lab 02: Generación de claves** - Aprende a generar pares de claves RSA y ECC

---

**Versiones de RHEL probadas:** 7, 8, 9, 10
**Nivel de dificultad:** Principiante
