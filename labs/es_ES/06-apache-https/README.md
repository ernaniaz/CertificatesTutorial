# Lab 06: Configuración de Apache HTTPS

## Objetivos de aprendizaje

Al completar este laboratorio, podrás:
- Instalar Apache (httpd) con mod_ssl
- Configurar Apache para HTTPS con certificados
- Comprender la configuración SSL específica por versión de RHEL
- Trabajar con crypto-policies (RHEL 8+)
- Probar conexiones HTTPS
- Configurar virtual hosts con TLS

## Requisitos previos

- **Labs 01-05** completados
- **Versión de RHEL:** 7, 8, 9 o 10
- **Acceso al sistema:** Se requiere root/sudo
- **Firewall:** Acceso a los puertos 80 y 443

## Tiempo estimado

**30-40 minutos**

## Descripción general del laboratorio

Apache es el servidor web más común en RHEL. Aprende a configurarlo con certificados TLS en todas las versiones de RHEL, manejando las diferencias específicas por versión.

---

## Instrucciones

### Paso 1: Instalar Apache

Instala Apache con soporte SSL:

```bash
sudo ./install-apache.sh
```

Esto instala:
- `httpd` (servidor web Apache)
- `mod_ssl` (módulo SSL/TLS)
- Abre los puertos 80 y 443 del firewall

---

### Paso 2: Configurar SSL (específico por versión)

Ejecuta el script de configuración:

```bash
sudo ./configure-ssl.sh
```

Esto:
- Copia certificados del Lab 04
- Crea la configuración del VirtualHost SSL
- Aplica ajustes TLS específicos por versión
- Reinicia Apache

---

### Paso 3: Probar la conexión HTTPS

Prueba tu configuración HTTPS de Apache:

```bash
./test-connection.sh
```

Esto prueba:
- Conexión HTTP (puerto 80)
- Conexión HTTPS (puerto 443)
- Validez del certificado
- Versión TLS y cifrados

---

### Paso 4: Verificar la configuración

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
- ✅ Apache instalado y en ejecución
- ✅ HTTPS configurado con certificados
- ✅ Puerto 443 accesible
- ✅ Certificado servido correctamente
- ✅ Comprensión de las diferencias específicas por versión

---

## Conceptos clave

### Archivos de configuración SSL de Apache

```
/etc/httpd/
├── conf/
│   └── httpd.conf          # Configuración principal
├── conf.d/
│   └── ssl.conf            # Configuración SSL (mod_ssl)
└── conf.modules.d/
    └── 00-ssl.conf         # Carga del módulo
```

### Directivas SSL básicas

```apache
SSLEngine on
SSLCertificateFile /path/to/cert.crt
SSLCertificateKeyFile /path/to/key.key
SSLCertificateChainFile /path/to/chain.crt
```

### Diferencias por versión

**RHEL 7:**
- Configuración manual del protocolo TLS
- Configuración manual del conjunto de cifrados
- `SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1`
- Configuración explícita de `SSLCipherSuite`

**RHEL 8+:**
- crypto-policies gestionan TLS/cifrados automáticamente
- Se necesitan pocas directivas SSL
- Aplicación de políticas a nivel del sistema
- `SSLEngine on` + rutas de certificados son suficientes

---

## Resolución de problemas

### Problema: Apache no inicia

**Síntoma:**
```
Job for httpd.service failed
```

**Solución:**
Comprobar sintaxis y registros:
```bash
sudo apachectl configtest
sudo journalctl -xeu httpd
```

---

### Problema: Error de certificado

**Síntoma:**
```
SSL_CTX_use_PrivateKey_file: error
```

**Solución:**
Comprobar rutas y permisos de archivos:
```bash
ls -l /etc/pki/tls/certs/server.crt
ls -l /etc/pki/tls/private/server.key
# La clave privada debe tener modo 600
```

---

### Problema: Firewall bloqueando

**Síntoma:**
No se puede conectar a https://localhost

**Solución** (solo si firewalld está activo):
```bash
systemctl is-active firewalld && sudo firewall-cmd --list-services
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

> **Nota**: En RHEL 7, firewalld puede no estar en ejecución. En ese caso, use `iptables` o simplemente omita este paso.

---

## Notas específicas por versión

### RHEL 7
- Usa `yum` para la instalación
- Requiere configuración explícita de cifrados
- Control manual de la versión TLS

### RHEL 8+
- Usa `dnf` para la instalación
- Se introducen crypto-policies
- Se necesita menos configuración SSL

### RHEL 9+
- SHA-1 bloqueado por defecto
- Validación de certificados más estricta
- SANs obligatorios

---

## Limpieza

```bash
sudo ./cleanup.sh
```

Esto elimina Apache y restaura el estado del sistema.

---

## Recursos adicionales

**Capítulos relacionados:**
- Capítulo 14: Apache httpd en RHEL

**Documentación:**
- `man httpd`
- `man apachectl`
- `/usr/share/doc/httpd/`

---

## Próximos pasos

Continúa con **Lab 07: Configuración de NGINX HTTPS** para aprender la configuración de NGINX.

---

**Nivel de dificultad:** Intermedio
