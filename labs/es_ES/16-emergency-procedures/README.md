# Lab 16: Procedimientos de emergencia para certificados

## Objetivos de aprendizaje

Al completar este lab, usted:
- Realizará reemplazo de emergencia de certificados
- Creará certificados autofirmados temporales
- Omitirá temporalmente la verificación SSL (para pruebas)
- Restaurará desde copias de seguridad rápidamente
- Revertirá cambios de certificados
- Implementará procedimientos de recuperación ante desastres

## Requisitos previos

- **Labs 01-15** completados
- **Versión de RHEL:** 7, 8, 9 o 10
- **Acceso al sistema:** Se requiere root/sudo
- Se requiere **calma bajo presión**

## Tiempo estimado

**30-40 minutos**

## Descripción general

Cuando los certificados fallan en producción, necesita soluciones rápidas. Este lab enseña procedimientos de emergencia para restaurar el servicio rápidamente y luego implementar correcciones adecuadas.

---

## Escenarios de emergencia

### Cuándo usar procedimientos de emergencia

- Servicio de producción caído por un certificado
- Certificado vencido durante la noche
- Certificado incorrecto desplegado
- Clave privada perdida
- CA inaccesible para renovación
- Se requiere restauración inmediata del servicio

### Prioridad de respuesta de emergencia

1. **Restaurar el servicio** - Hacer que funcione (puede usar certificado temporal)
2. **Evaluar el impacto** - Comprender qué ocurrió
3. **Implementar corrección adecuada** - Reemplazar la solución temporal
4. **Evitar recurrencia** - Corregir la causa raíz

---

## Instrucciones

### Reemplazo de emergencia

Reemplace rápidamente un certificado fallido:

```bash
sudo ./emergency-replacement.sh
```

Crea y despliega un nuevo certificado de inmediato.

---

### Crear certificado autofirmado temporal

Genere un certificado autofirmado temporal:

```bash
sudo ./self-signed-temp.sh
```

Úselo cuando:
- La CA no es accesible
- Necesita un certificado de inmediato
- Necesita ganar tiempo para una solución adecuada

---

### Omitir verificación SSL (solo pruebas)

Pruebe la conectividad sin validar el certificado (solo resolución de problemas):

```bash
# curl: omitir validación del certificado
curl -k https://localhost/

# openssl: conectar sin verificar la cadena
openssl s_client -connect localhost:443 </dev/null
```

**ADVERTENCIA:** ¡Solo para resolución de problemas! ¡Nunca en producción!

---

### Restaurar desde copia de seguridad

Restaure certificados desde copia de seguridad:

```bash
sudo ./restore-backup.sh
```

Restaura certificados en buen estado conocido.

---

### Revertir cambios

Revierta cambios recientes de certificados:

```bash
sudo ./rollback.sh
```

Vuelve al estado funcional anterior.

---

## Scripts clave

### emergency-replacement.sh

**Propósito:** Reemplazo rápido de certificados
**Usar cuando:** El certificado falló, se necesita corrección inmediata
**Tiempo:** <5 minutos
**Resultado:** Servicio restaurado con nuevo certificado

### self-signed-temp.sh

**Propósito:** Crear certificado temporal
**Usar cuando:** CA no disponible, se necesita solución rápida
**Tiempo:** <2 minutos
**Resultado:** Certificado autofirmado temporal desplegado

### restore-backup.sh

**Propósito:** Restaurar desde copia de seguridad
**Usar cuando:** Tiene una buena copia de seguridad, necesita revertir
**Tiempo:** <3 minutos
**Resultado:** Certificados en buen estado conocido restaurados

### rollback.sh

**Propósito:** Deshacer cambios recientes
**Usar cuando:** El nuevo certificado causa problemas
**Tiempo:** <3 minutos
**Resultado:** Configuración anterior restaurada

---

## Lista de verificación de emergencia

Cuando ocurre una emergencia de certificados:

### Acciones inmediatas (0-5 minutos)

- [ ] Confirmar que el servicio está caído
- [ ] Verificar vencimiento del certificado
- [ ] Verificar que existen archivos de certificado/clave
- [ ] Revisar registros del servicio
- [ ] Evaluar impacto (cuántos servicios/usuarios)

### Corrección rápida (5-15 minutos)

- [ ] Ejecutar reemplazo de emergencia
- [ ] O desplegar certificado autofirmado temporal
- [ ] Reiniciar servicios afectados
- [ ] Probar funcionalidad básica
- [ ] Notificar a las partes interesadas

### Corrección adecuada (15-60 minutos)

- [ ] Obtener certificado adecuado de la CA
- [ ] Probar certificado antes del despliegue
- [ ] Desplegar certificado adecuado
- [ ] Verificar toda la funcionalidad
- [ ] Eliminar soluciones temporales

### Post-incidente (después de restaurar el servicio)

- [ ] Documentar qué ocurrió
- [ ] Analizar la causa raíz
- [ ] Implementar monitoreo
- [ ] Actualizar procedimientos
- [ ] Realizar post-mortem

---

## Validación

Para verificar su conocimiento de procedimientos de emergencia:

```bash
./verify.sh
```

**Resultados esperados:**
- ✓ `emergency-replacement.sh`, `self-signed-temp.sh`, `restore-backup.sh` y `rollback.sh` existen y son ejecutables
- ✓ `/etc/pki/tls/certs` y `/etc/pki/tls/private` existen en el sistema
- ✓ Se cuentan y reportan los directorios de copia de seguridad de emergencia existentes bajo `/root/cert-backup-*`
- ✓ Cualquier archivo `emergency.crt` o `temp-*.crt` encontrado en `/etc/pki/tls/certs` se lista con detalles de subject y validez

**Verificación manual:**
1. ¿Puede generar un certificado temporal en < 2 minutos?
2. ¿Comprende cuándo usar cada procedimiento?
3. ¿Tiene al menos una copia de seguridad conocida y válida para restaurar?
4. ¿Está documentado y listo para probar manualmente el plan de reversión?

---

## Mejores prácticas

### Siempre tenga copias de seguridad

```bash
# Copia de seguridad antes de cambios
cp /etc/pki/tls/certs/server.crt /etc/pki/tls/certs/server.crt.backup
cp /etc/pki/tls/private/server.key /etc/pki/tls/private/server.key.backup

# Con marca de tiempo
DATE=$(date +%Y%m%d-%H%M%S)
cp /etc/pki/tls/certs/server.crt /etc/pki/tls/certs/server.crt.$DATE
```

### Probar antes de desplegar

```bash
# Probar que el certificado coincide con la clave
diff <(openssl x509 -noout -modulus -in cert.pem | openssl md5) \
     <(openssl rsa -noout -modulus -in key.pem | openssl md5)

# Probar validez del certificado
openssl x509 -in cert.pem -noout -checkend 0

# Probar con el servicio
# Desplegar primero en sistema de prueba
```

### Documentar todo

- Qué falló
- Cuándo falló
- Qué hizo
- Qué funcionó
- Qué no funcionó
- Cómo evitarlo

---

## Escenarios comunes de emergencia

### Escenario: Certificado vencido durante la noche

```bash
# Corrección rápida
sudo ./self-signed-temp.sh
sudo systemctl restart httpd

# Luego obtener certificado adecuado
sudo certbot renew --force-renewal
```

### Escenario: Certificado incorrecto desplegado

```bash
# Revertir
sudo ./rollback.sh
sudo systemctl restart nginx

# Verificar
curl -v https://localhost/
```

### Escenario: Clave privada perdida

```bash
# Generar nuevo par
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout new.key -out new.crt -days 90

# Desplegar
sudo cp new.crt /etc/pki/tls/certs/
sudo cp new.key /etc/pki/tls/private/
sudo systemctl restart httpd
```

---

## Limpieza

```bash
sudo ./cleanup.sh
```

Elimina certificados de emergencia y restaura el estado normal.

---

## Recursos adicionales

**Capítulos relacionados:**
- Capítulo 33: Procedimientos de Emergencia
- Capítulo 27: Metodología de Solución de Problemas de Certificados RHEL

**Contactos de emergencia:**
- Soporte de la autoridad de certificación
- Administradores de sistemas
- Propietarios de aplicaciones
- Escalamiento a gerencia

**Herramientas:**
- `openssl` - Generación de certificados
- `systemctl` - Gestión de servicios
- `journalctl` - Análisis de registros

---

## Próximos pasos

¡Ha completado los labs de resolución de problemas! A continuación:
- **Lab 17-18:** Procedimientos de migración
- **Lab 19-20:** Seguridad y FIPS
- **Lab 21-22:** Temas avanzados (Kubernetes, Vault)

---

**Nivel de dificultad**: Avanzado  
**Nota**: ¡Practique estos procedimientos antes de necesitarlos!
