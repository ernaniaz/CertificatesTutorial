# Lab 15: Escenarios de resolución de problemas

## Objetivos de aprendizaje

Al completar este lab, usted:
- Diagnosticará un problema de certificado vencido
- Usará herramientas de resolución de problemas de forma efectiva
- Corregirá certificados vencidos
- Seguirá una metodología estructurada de resolución de problemas

## Requisitos previos

- **Labs 01-10** completados (comprensión de certificados y servicios)
- **Versión de RHEL:** 7, 8, 9 o 10
- **Acceso al sistema:** Se requiere root/sudo
- Se requiere **mentalidad de resolución de problemas**

## Tiempo estimado

**15-20 minutos**

## Descripción general

¡Escenario real de resolución de problemas! Este lab crea un problema específico de certificados y lo guía a través del diagnóstico y la resolución. Es uno de los problemas más comunes que encontrará en producción.

---

## Estructura del lab

Este lab contiene actualmente **un escenario implementado**:

```
15-troubleshooting-scenarios/
├── scenario-01-expired-cert/
├── run-all.sh
└── cleanup-all.sh
```

Cada escenario incluye:
- **create-problem.sh** - Configura el problema
- **diagnose.sh** - Pasos de diagnóstico para encontrar el problema
- **fix.sh** - Solución para corregir el problema
- **verify-fix.sh** - Valida que la corrección funcionó
- **README.md** - Descripción del escenario y notas de aprendizaje

---

## Instrucciones

### Ejecutar el escenario

```bash
cd scenario-01-expired-cert
sudo ./create-problem.sh
./diagnose.sh
sudo ./fix.sh
sudo ./verify-fix.sh
```

O use el script auxiliar desde el directorio del lab:

```bash
sudo ./run-all.sh
```

---

## Escenarios

### Escenario 01: Certificado vencido

**Problema:** El certificado ha vencido, causando fallos de conexión

**Síntomas:**
- "certificate has expired"
- Fallos en el handshake SSL
- Advertencias de seguridad del navegador

**Herramientas:** `openssl x509 -dates`, inspección de certificados

**Aprendizaje:** Gestión del ciclo de vida de certificados, importancia de la renovación

Consulte `scenario-01-expired-cert/README.md` para los detalles completos del escenario.

---

## Validación

Para verificar que completó este lab exitosamente:

```bash
cd scenario-01-expired-cert
sudo ./verify-fix.sh
```

**Resultados esperados:**
- `verify-fix.sh` informa que todas las comprobaciones pasaron
- El archivo de certificado existe en `/etc/pki/tls/certs/expired.crt`
- El certificado es válido y no está vencido
- El certificado es válido por al menos 30 días
- El subject del certificado coincide con `expired.example.com`

---

## Metodología de resolución de problemas

Cada escenario sigue esta metodología:

1. **Observar** - Identificar síntomas
2. **Recopilar** - Obtener registros y datos de diagnóstico
3. **Analizar** - Determinar la causa raíz
4. **Corregir** - Implementar la solución
5. **Verificar** - Confirmar la resolución
6. **Documentar** - Registrar para referencia futura

---

## Comandos clave de resolución de problemas

### Inspección de certificados
```bash
# Ver certificado
openssl x509 -in cert.pem -text -noout

# Verificar vencimiento
openssl x509 -in cert.pem -noout -dates

# Verificar cadena de certificados
openssl verify -CAfile ca.pem cert.pem

# Verificar que el certificado coincide con la clave
openssl x509 -noout -modulus -in cert.pem | openssl md5
openssl rsa -noout -modulus -in key.pem | openssl md5
```

### Pruebas de conexión
```bash
# Probar conexión TLS
openssl s_client -connect host:443 -servername host

# Mostrar cadena de certificados
openssl s_client -connect host:443 -showcerts

# Probar versión TLS específica
openssl s_client -connect host:443 -tls1_2

# Verificar cifrados disponibles
openssl s_client -connect host:443 -cipher 'HIGH'
```

### Depuración de servicios
```bash
# Revisar registros del servicio
journalctl -xeu httpd
journalctl -xeu nginx

# Probar configuración
apachectl configtest
nginx -t

# Verificar denegaciones SELinux
ausearch -m avc -ts recent
sealert -a /var/log/audit/audit.log
```

---

## Limpieza

Cada escenario tiene su propia limpieza, o use la limpieza maestra:

```bash
sudo ./cleanup-all.sh
```

---

## Recursos adicionales

**Capítulos relacionados:**
- Capítulo 27: Metodología de Solución de Problemas de Certificados RHEL
- Capítulo 28: Errores Comunes de Certificados en RHEL
- Capítulo 29: Solución de Problemas Específica por Servicio

**Herramientas útiles:**
- `openssl` - Navaja suiza para certificados
- `curl` - Pruebas HTTP/HTTPS
- `journalctl` - Registros del sistema
- `ausearch` - Registros de auditoría SELinux
- `tcpdump` - Captura de paquetes de red

---

## Próximos pasos

Continúe con **Lab 16: Procedimientos de emergencia** para aprender técnicas de recuperación rápida.

---

**Nivel de dificultad:** Avanzado
**Nota:** Estos escenarios simulan problemas reales de producción
