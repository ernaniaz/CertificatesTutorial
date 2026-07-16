# Lab 08: Configuración de Postfix TLS

## Objetivos de aprendizaje

Al completar este laboratorio, podrás:
- Instalar y configurar el servidor de correo Postfix
- Configurar SMTP con cifrado STARTTLS
- Habilitar TLS en el puerto de envío (587)
- Probar conexiones SMTP TLS
- Comprender los requisitos de certificados del servidor de correo
- Configurar el registro de Postfix para TLS

## Requisitos previos

- **Labs 01-05** completados
- **Versión de RHEL:** 7, 8, 9 o 10
- **Acceso al sistema:** Se requiere root/sudo
- **Puertos:** 25 (SMTP), 587 (submission)

## Tiempo estimado

**30-40 minutos**

## Descripción general del laboratorio

Postfix es el agente de transferencia de correo (MTA) predeterminado en RHEL. Aprende a configurarlo con TLS para la transmisión segura de correo usando STARTTLS en el puerto 25 y TLS obligatorio en el puerto de envío (587).

---

## Instrucciones

### Paso 1: Instalar Postfix

Instala el servidor de correo Postfix:

```bash
sudo ./install-postfix.sh
```

Esto instala:
- Servidor de correo `postfix`
- Dependencias necesarias
- Configura ajustes básicos

---

### Paso 2: Configurar TLS

Configura Postfix con certificados TLS:

```bash
sudo ./configure-tls.sh
```

Esto:
- Copia certificados del Lab 04
- Configura parámetros TLS en main.cf
- Habilita STARTTLS en el puerto 25
- Configura TLS obligatorio en el puerto 587
- Reinicia Postfix

---

### Paso 3: Probar STARTTLS

Prueba STARTTLS en el puerto 25:

```bash
./test-starttls.sh
```

Esto prueba:
- Conexión SMTP básica
- Capacidad STARTTLS
- Handshake TLS
- Presentación del certificado

---

### Paso 4: Probar el puerto de envío

Prueba el envío seguro en el puerto 587:

```bash
./test-submission.sh
```

Esto prueba:
- Conectividad del puerto de envío
- Aplicación obligatoria de TLS
- Requisitos de autenticación
- Cifrado TLS

---

### Paso 5: Verificar la configuración

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
- ✅ Postfix instalado y en ejecución
- ✅ STARTTLS disponible en el puerto 25
- ✅ TLS obligatorio en el puerto 587
- ✅ Certificados configurados correctamente
- ✅ Comprensión de TLS en servidores de correo

---

## Conceptos clave

### Archivos de configuración de Postfix

```
/etc/postfix/
├── main.cf              # Configuración principal
├── master.cf            # Definiciones de servicios
├── transport            # Mapas de transporte
└── virtual              # Alias virtuales
```

### Directivas TLS en main.cf

```conf
# TLS para conexiones entrantes (modo servidor)
smtpd_tls_cert_file = /etc/pki/tls/certs/postfix.crt
smtpd_tls_key_file = /etc/pki/tls/private/postfix.key
smtpd_tls_security_level = may
smtpd_tls_loglevel = 1

# TLS para conexiones salientes (modo cliente)
smtp_tls_security_level = may
smtp_tls_loglevel = 1

# Protocolos TLS y cifrados
smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtpd_tls_ciphers = high
smtpd_tls_exclude_ciphers = aNULL, MD5
```

### Puerto 25 vs puerto 587

**Puerto 25 (SMTP):**
- Puerto tradicional de transferencia de correo
- Comunicación servidor a servidor
- TLS opcional (STARTTLS)
- Normalmente no se requiere autenticación

**Puerto 587 (Submission):**
- Envío de correo desde clientes
- Requiere autenticación
- TLS debe ser obligatorio
- Mejor práctica moderna para el envío de correo desde clientes

### Proceso STARTTLS

1. El cliente se conecta en un puerto de texto plano
2. El servidor anuncia la capacidad STARTTLS
3. El cliente emite el comando STARTTLS
4. La negociación se actualiza a TLS
5. La comunicación cifrada continúa

---

## Resolución de problemas

### Problema: Postfix no inicia

**Síntoma:**
```
Job for postfix.service failed
```

**Solución:**
Comprobar configuración y registros:
```bash
sudo postfix check
sudo journalctl -xeu postfix
sudo tail -f /var/log/maillog
```

---

### Problema: STARTTLS no anunciado

**Síntoma:**
EHLO no muestra la capacidad STARTTLS

**Solución:**
Verificar la configuración TLS:
```bash
postconf -n | grep tls
# Asegurarse de que smtpd_tls_cert_file y smtpd_tls_key_file estén configurados
# Reiniciar postfix: systemctl restart postfix
```

---

### Problema: Errores de certificado

**Síntoma:**
```
warning: cannot get RSA private key
```

**Solución:**
Comprobar permisos del certificado:
```bash
ls -l /etc/pki/tls/certs/postfix.crt
ls -l /etc/pki/tls/private/postfix.key
# La clave privada debe ser legible por postfix
chmod 600 /etc/pki/tls/private/postfix.key
chown root:root /etc/pki/tls/private/postfix.key
```

---

### Problema: Puerto 25 bloqueado

**Síntoma:**
No se puede conectar al puerto 25

**Solución:**
Muchos ISP bloquean el puerto 25 saliente. Esto es normal. Usa el puerto 587 para conexiones de clientes:
```bash
# Probar localmente
telnet localhost 25
# Si eso funciona, es la red/firewall bloqueando el acceso externo
```

---

## Notas específicas por versión

### RHEL 7
- Usa `yum` para la instalación
- Registros en `/var/log/maillog`
- Postfix 2.10.x típicamente

### RHEL 8
- Usa `dnf` para la instalación
- Postfix 3.3.x o 3.5.x
- crypto-policies afectan TLS
- Puede hacer referencia a `/etc/crypto-policies/back-ends/postfix.config`

### RHEL 9
- Postfix 3.5.x
- Valores predeterminados TLS más estrictos
- SHA-1 bloqueado
- Requiere cifrados fuertes

---

## Limpieza

```bash
sudo ./cleanup.sh
```

Esto elimina Postfix y restaura el estado del sistema.

---

## Recursos adicionales

**Capítulos relacionados:**
- Capítulo 16: TLS del servidor de correo Postfix

**Documentación:**
- `man 5 postconf`
- `man postfix`
- `/usr/share/doc/postfix/`
- http://www.postfix.org/TLS_README.html

**Herramientas de prueba:**
- `openssl s_client -starttls smtp`
- `swaks` (navaja suiza para SMTP)

---

## Próximos pasos

Continúa con **Lab 09: OpenLDAP LDAPS** para aprender LDAP sobre TLS.

---

**Nivel de dificultad**: Intermedio
