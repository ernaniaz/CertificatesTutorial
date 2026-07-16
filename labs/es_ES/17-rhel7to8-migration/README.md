# Lab 17: Migración de certificados RHEL 7→8

## Objetivos de aprendizaje

Al completar este lab, usted:
- Comprenderá la compatibilidad de certificados entre RHEL 7 y 8
- Migrará certificados durante la actualización del SO
- Manejará la introducción de crypto-policies
- Actualizará configuraciones de certificados
- Probará certificados después de la migración
- Resolverá problemas de migración

## Requisitos previos

- **Comprensión de las diferencias** entre RHEL 7 y 8
- **Labs 01-10** completados (fundamentos de certificados)
- **El lab abarca ambos sistemas** — ejecute evaluación/copia de seguridad/preparación en RHEL 7 y luego ejecute `configure-rhel8.sh` y `validate-migration.sh` en el sistema RHEL 8 ya actualizado
- **Acceso al sistema:** Se requiere root/sudo

## Tiempo estimado

**40-50 minutos**

## Descripción general

RHEL 8 introduce cambios significativos en la gestión de certificados, principalmente el sistema crypto-policies. Aprenda a migrar certificados de RHEL 7 a RHEL 8 manteniendo seguridad y compatibilidad.

---

## Diferencias clave: RHEL 7 vs RHEL 8

### Crypto-Policies

**RHEL 7:**
- Sin crypto-policies a nivel de todo el sistema
- Configuración TLS manual en cada servicio
- Configuración de cifrado específica por aplicación

**RHEL 8:**
- Marco crypto-policies a nivel de todo el sistema
- Estándares criptográficos centralizados
- Configuración automática para servicios

### Protocolos TLS

**RHEL 7:**
- TLS 1.0, 1.1, 1.2 soportados por defecto
- Selección manual de protocolo
- Se permiten cifrados antiguos

**RHEL 8:**
- TLS 1.2+ por defecto (política DEFAULT)
- TLS 1.0/1.1 deshabilitados
- Requisitos de cifrado más estrictos

### Validación de certificados

**RHEL 7:**
- Validación más permisiva
- Se permiten firmas SHA-1
- Requisitos de certificados más flexibles

**RHEL 8:**
- Validación más estricta
- SHA-1 bloqueado en la política DEFAULT
- SANs preferidos sobre CN

---

## Instrucciones

### Paso 1: Evaluación pre-migración

Evalúe el estado actual de certificados:

```bash
./assess-rhel7.sh
```

Esto verifica:
- Certificados actuales
- Configuraciones TLS
- Posibles problemas de compatibilidad
- Servicios que usan certificados

---

### Paso 2: Copia de seguridad de certificados

Realice copia de seguridad de todos los certificados antes de la migración:

```bash
sudo ./backup-certificates.sh
```

Crea una copia de seguridad integral de:
- Todos los archivos de certificados
- Archivos de configuración
- Almacén de confianza
- Configuraciones de servicios

---

### Paso 3: Preparación para migración

Prepare la migración:

```bash
./prepare-migration.sh
```

Esto:
- Identifica certificados incompatibles
- Verifica firmas SHA-1
- Revisa configuraciones TLS
- Crea lista de verificación de migración

---

### Paso 4: Configuración post-actualización (RHEL 8)

En el sistema RHEL 8 ya actualizado, configure crypto-policies:

```bash
sudo ./configure-rhel8.sh
```

Esto:
- Establece la crypto-policy adecuada
- Actualiza configuraciones de servicios
- Migra configuraciones TLS
- Prueba conectividad

---

### Paso 5: Validar migración en RHEL 8

En el sistema RHEL 8 ya actualizado, verifique que todo funcione:

```bash
./validate-migration.sh
```

Prueba:
- Validez de certificados
- Funcionalidad de servicios
- Conexiones TLS
- Aplicación de crypto-policy

---

## Validación

Verifique una migración exitosa en RHEL 8:

```bash
./validate-migration.sh
```

**Resultados esperados:**
- ✓ Todos los servicios ejecutándose en RHEL 8
- ✓ Certificados válidos y aceptados
- ✓ Crypto-policies activas y aplicadas
- ✓ Conexiones TLS funcionando
- ✓ Sin errores de compatibilidad en los registros

**Comprobaciones manuales:**
1. Verificar crypto-policy: `update-crypto-policies --show`
2. Probar conexiones de servicios: `curl https://localhost`
3. Verificar validez del certificado: `openssl s_client -connect localhost:443`
4. Revisar registros de servicios en busca de errores

---

## Lista de verificación de migración

### Antes de la migración (RHEL 7)

- [ ] Documentar todos los certificados en uso
- [ ] Copia de seguridad de archivos de certificados
- [ ] Copia de seguridad de configuraciones de servicios
- [ ] Probar funcionalidad actual
- [ ] Identificar certificados SHA-1
- [ ] Verificar fechas de vencimiento de certificados
- [ ] Documentar configuraciones TLS personalizadas

### Durante la migración

- [ ] Realizar actualización del SO a RHEL 8
- [ ] Preservar directorio `/etc/pki/`
- [ ] Anotar advertencias de crypto-policy
- [ ] Conservar registros de migración

### Después de la migración (RHEL 8)

- [ ] Verificar que los certificados estén presentes
- [ ] Verificar configuración de crypto-policy
- [ ] Actualizar configs de servicios para crypto-policies
- [ ] Probar todos los servicios
- [ ] Reemplazar certificados SHA-1 si es necesario
- [ ] Actualizar monitoreo
- [ ] Documentar cambios

---

## Problemas comunes

### Problema: Clientes TLS 1.0/1.1 fallan

**Síntoma:** Clientes antiguos no pueden conectarse después de la migración

**Solución:**
```bash
# Usar temporalmente la política LEGACY
sudo update-crypto-policies --set LEGACY

# O crear política personalizada que permita TLS 1.0/1.1
```

---

### Problema: Certificados SHA-1 rechazados

**Síntoma:** Certificados con firmas SHA-1 fallan

**Solución:**
```bash
# Reemplazar con certificados SHA-256
# O usar temporalmente la política LEGACY
sudo update-crypto-policies --set LEGACY
```

---

### Problema: El servicio no inicia

**Síntoma:** El servicio falla después de la migración con errores SSL

**Solución:**
```bash
# Revisar configuración del servicio
journalctl -xeu service-name

# Actualizar para usar crypto-policies
# Eliminar configuraciones manuales de protocolo/cifrado TLS
```

---

## Mejores prácticas

### Requisitos de certificados para RHEL 8

1. **Usar SHA-256 o superior** - Sin SHA-1
2. **Incluir SANs** - No depender solo de CN
3. **RSA 2048+ o ECC** - Tamaños de clave fuertes
4. **Cadena de certificados válida** - Incluir intermedios
5. **No vencido** - Fechas válidas

### Migración de configuración

**Eliminar de configs de servicios:**
- Configuraciones manuales de `SSLProtocol`
- Configuraciones manuales de `SSLCipherSuite`
- Versiones TLS codificadas
- Listas de cifrado

**Dejar que crypto-policies maneje:**
- Versiones del protocolo TLS
- Selección de conjuntos de cifrado
- Niveles de seguridad

---

## Limpieza

```bash
sudo ./cleanup.sh
```

Elimina artefactos de migración y archivos de prueba.

---

## Recursos adicionales

**Capítulos relacionados:**
- Capítulo 35: Migración RHEL 7→8
- Capítulo 10: RHEL 8 y Crypto-Policies

**Documentación:**
- Guía de actualización de RHEL 8
- `man update-crypto-policies`
- `/usr/share/doc/crypto-policies/`

**Cambios clave:**
- https://access.redhat.com/articles/3642912 (Crypto-policies)
- https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/

---

## Próximos pasos

Continúe con **Lab 18: Migración RHEL 8→9** para aprender sobre la siguiente ruta de actualización.

---

**Nivel de dificultad**: Avanzado  
**Nota**: Pruebe la migración primero en un entorno que no sea de producción
