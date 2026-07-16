# Lab 11: Fundamentos de certmonger

## Objetivos de aprendizaje

Al completar este laboratorio, podrás:
- Instalar y configurar certmonger
- Solicitar certificados autofirmados
- Solicitar certificados de una CA local
- Rastrear la expiración de certificados
- Configurar renovación automática
- Configurar comandos post-save para reinicios de servicios
- Comprender el uso del comando getcert

## Requisitos previos

- **Labs 01-05** completados
- **Versión de RHEL:** 7, 8, 9 o 10
- **Acceso al sistema:** Se requiere root/sudo
- Paquete **certmonger** disponible

## Tiempo estimado

**40-50 minutos**

## Descripción general del laboratorio

certmonger es un daemon de seguimiento y renovación de certificados para RHEL. Aprende a usarlo para la gestión automática del ciclo de vida de certificados, incluyendo solicitud, seguimiento y renovación sin intervención manual.

---

## Instrucciones

### Paso 1: Instalar certmonger

Instala el servicio certmonger:

```bash
sudo ./install-certmonger.sh
```

Esto instala:
- Daemon `certmonger`
- Inicia y habilita el servicio
- Configura ajustes básicos

---

### Paso 2: Solicitar un certificado autofirmado

Solicita un certificado autofirmado:

```bash
sudo ./request-self-signed.sh
```

Esto:
- Usa el comando `getcert request`
- Crea certificado y clave
- Rastrea el estado del certificado
- Muestra detalles del certificado

---

### Paso 3: Solicitar de una CA local

Solicita un certificado de una CA local:

```bash
sudo ./request-local-ca.sh
```

Esto:
- Configura una CA local con certmonger
- Solicita un certificado firmado por la CA
- Configura ajustes de renovación
- Prueba el seguimiento

---

### Paso 4: Comprobar el estado del certificado

Comprueba el estado de seguimiento del certificado:

```bash
./check-status.sh
```

Esto muestra:
- Todos los certificados rastreados
- Fechas de expiración
- Estado de renovación
- IDs de seguimiento

---

### Paso 5: Probar la renovación

Simula la renovación del certificado:

```bash
sudo ./test-renewal.sh
```

Esto:
- Fuerza la renovación del certificado
- Prueba el proceso de renovación automática
- Verifica comandos post-save
- Comprueba el nuevo certificado

---

### Paso 6: Verificar la configuración

Ejecuta la validación completa:

```bash
sudo ./verify.sh
```

---

## Validación

```bash
sudo ./test.sh
```

Todas las comprobaciones deben pasar.

## Resultado esperado

Después de completar este laboratorio:
- ✅ certmonger instalado y en ejecución
- ✅ Certificado autofirmado rastreado
- ✅ Certificado de CA local rastreado
- ✅ Renovación automática configurada
- ✅ Comprensión del flujo de trabajo de certmonger

---

## Conceptos clave

### Arquitectura de certmonger

```
certmonger daemon (certmonger.service)
    ↓
Base de datos de seguimiento de certificados
    ↓
CAs (Autoridades de certificación)
  - Autofirmado
  - CA local (certmonger-local)
  - CA IPA
  - Proveedores ACME
```

### Comando getcert

**Solicitar certificado:**
```bash
getcert request \
  -f /path/to/cert.crt \
  -k /path/to/key.key \
  -c IPA \
  -N CN=server.example.com
```

**Listar certificados:**
```bash
getcert list
getcert list -i <request-id>
```

**Comprobar estado:**
```bash
getcert status -i <request-id>
```

**Forzar renovación:**
```bash
getcert resubmit -i <request-id>
getcert refresh -i <request-id>
```

**Detener seguimiento:**
```bash
getcert stop-tracking -i <request-id>
# o
getcert stop-tracking -f /path/to/cert.crt
```

### Estados del certificado

| Estado | Descripción |
|--------|-------------|
| MONITORING | Certificado rastreado, se renovará automáticamente |
| NEED_GUIDANCE | Se requiere intervención manual |
| SUBMITTING | Solicitud en envío |
| GENERATING_KEY | Generando par de claves |
| ISSUED | Certificado emitido correctamente |

### Comandos post-save

Ejecutar comandos después de la renovación del certificado:

```bash
getcert request \
  -f /etc/httpd/cert.crt \
  -k /etc/httpd/key.key \
  -C "systemctl reload httpd"
```

### Momento de renovación

- certmonger comprueba certificados diariamente
- Predeterminado: renovar cuando queden <30 días
- Configurable con la opción `-T`
- Puede forzar renovación inmediata

---

## Resolución de problemas

### Problema: certmonger no está en ejecución

**Síntoma:**
```
Cannot connect to certmonger service
```

**Solución:**
Iniciar el servicio:
```bash
systemctl start certmonger
systemctl enable certmonger
systemctl status certmonger
```

---

### Problema: Solicitud de certificado bloqueada

**Síntoma:**
```
status: SUBMITTING
stuck: yes
```

**Solución:**
Comprobar registros y reenviar:
```bash
journalctl -u certmonger | tail -50
getcert resubmit -i <request-id>
# O detener y empezar de nuevo
getcert stop-tracking -i <request-id>
```

---

### Problema: CA no disponible

**Síntoma:**
```
CA 'IPA' not available
```

**Solución:**
Listar CAs disponibles:
```bash
getcert list-cas
# Usar CA disponible (como 'local' para autofirmado)
getcert request -c local ...
```

---

### Problema: Permiso denegado

**Síntoma:**
```
unable to write certificate file
```

**Solución:**
Comprobar permisos del directorio:
```bash
# certmonger se ejecuta como root, pero comprueba:
ls -ld /path/to/cert/directory
# Asegurarse de que el directorio existe y es escribible
mkdir -p /path/to/certs
chmod 755 /path/to/certs
```

---

## Notas específicas por versión

### RHEL 7
- Usa `yum` para la instalación
- certmonger 0.79.x típicamente
- Soporte básico de CA
- Autofirmado y CA local

### RHEL 8
- Usa `dnf` para la instalación
- certmonger 0.79.x
- Soporte mejorado de CA
- Mejor integración con IPA

### RHEL 9
- certmonger 0.79.x o más reciente
- Soporte ACME mejorado
- Mejor manejo de errores
- Registro mejorado

---

## Limpieza

```bash
sudo ./cleanup.sh
```

Esto elimina certmonger y los certificados rastreados.

---

## Recursos adicionales

**Capítulos relacionados:**
- Capítulo 22: Dominio de certmonger

**Documentación:**
- `man getcert`
- `man getcert-request`
- `man getcert-list`
- `man certmonger`
- `/usr/share/doc/certmonger/`

**Comandos útiles:**
```bash
# Listar todos los certificados rastreados
getcert list

# Mostrar estado detallado
getcert list -i <ID>

# Listar CAs disponibles
getcert list-cas

# Actualizar todos los certificados
getcert refresh-ca -c <CA-name>

# Ver registros de certmonger
journalctl -u certmonger -f
```

---

## Próximos pasos

Continúa con **Lab 12: Crypto-Policies** para aprender la gestión de políticas criptográficas a nivel del sistema.

---

**Nivel de dificultad**: Intermedio a avanzado
