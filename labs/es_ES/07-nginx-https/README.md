# Lab 07: Configuración de NGINX HTTPS

## Objetivos de aprendizaje

Al completar este laboratorio, podrás:
- Instalar el servidor web NGINX
- Configurar NGINX para HTTPS con certificados
- Comprender la sintaxis de configuración SSL de NGINX
- Trabajar con server blocks de NGINX
- Probar conexiones HTTPS con NGINX
- Comprender las diferencias específicas por versión de RHEL

## Requisitos previos

- **Labs 01-05** completados
- **Versión de RHEL:** 7, 8, 9 o 10
- **Acceso al sistema:** Se requiere root/sudo
- **Firewall:** Acceso a los puertos 80 y 443

## Tiempo estimado

**30-40 minutos**

## Descripción general del laboratorio

NGINX es un servidor web y proxy inverso de alto rendimiento. Aprende a configurarlo con certificados TLS en todas las versiones de RHEL, comprendiendo cómo difiere de Apache.

---

## Instrucciones

### Paso 1: Instalar NGINX

Instala NGINX:

```bash
sudo ./install-nginx.sh
```

Esto instala:
- Servidor web `nginx`
- Abre los puertos 80 y 443 del firewall
- Crea una configuración básica

**Notas**:
- RHEL 7 no incluye NGINX en sus repositorios base. El script instala EPEL (`epel-release` desde archives.fedoraproject.org, ya que EPEL 7 está archivado) para proporcionar el paquete `nginx`;
- El nombre del servicio es `nginx` en todas las versiones soportadas de RHEL.

---

### Paso 2: Configurar SSL (específico por versión)

Ejecuta el script de configuración:

```bash
sudo ./configure-ssl.sh
```

Esto:
- Copia certificados del Lab 04
- Crea la configuración del server block SSL
- Aplica ajustes TLS específicos por versión
- Reinicia NGINX

---

### Paso 3: Probar la conexión HTTPS

Prueba tu configuración HTTPS de NGINX:

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
- ✅ NGINX instalado y en ejecución
- ✅ HTTPS configurado con certificados
- ✅ Puerto 443 accesible
- ✅ Certificado servido correctamente
- ✅ Comprensión de las diferencias entre NGINX y Apache

---

## Conceptos clave

### Estructura de configuración de NGINX

```
/etc/nginx/
├── nginx.conf               # Configuración principal
├── conf.d/                  # Configuraciones personalizadas
│   └── default.conf         # Server block predeterminado
└── default.d/               # Configuraciones adicionales
```

### Directivas SSL básicas

```nginx
server {
    listen 443 ssl;
    server_name example.com;

    ssl_certificate /path/to/cert.crt;
    ssl_certificate_key /path/to/key.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
}
```

### NGINX vs Apache

**NGINX:**
- Arquitectura orientada a eventos
- Configuración en `nginx.conf` y `/etc/nginx/conf.d/`
- Probar configuración: `nginx -t`
- Recargar: `nginx -s reload`
- Server blocks en lugar de VirtualHosts

**Apache:**
- Orientado a procesos/hilos
- Configuración en `/etc/httpd/conf.d/`
- Probar configuración: `apachectl configtest`
- Recargar: `systemctl reload httpd`
- VirtualHosts

### Diferencias por versión

**RHEL 7:**
- Configuración manual del protocolo TLS
- Configuración explícita del conjunto de cifrados
- `ssl_protocols TLSv1.2 TLSv1.3;`
- Configuración explícita de `ssl_ciphers`

**RHEL 8+:**
- Se pueden usar crypto-policies
- Pero NGINX requiere más configuración explícita que Apache
- Aún hay que especificar protocolos y cifrados
- La política del sistema afecta las opciones disponibles

---

## Resolución de problemas

### Problema: NGINX no inicia

**Síntoma:**
```
Job for nginx.service failed
```

**Solución:**
Comprobar sintaxis y registros:
```bash
sudo nginx -t
sudo journalctl -xeu nginx
```

---

### Problema: Error de sintaxis de configuración

**Síntoma:**
```
nginx: [emerg] unexpected "}" in /etc/nginx/...
```

**Solución:**
Comprobar puntos y comas y llaves faltantes:
```bash
nginx -t
# Cada directiva necesita punto y coma
# Los bloques server necesitan { }
```

---

### Problema: Error de certificado

**Síntoma:**
```
nginx: [emerg] cannot load certificate
```

**Solución:**
Comprobar rutas y permisos de archivos:
```bash
ls -l /etc/pki/nginx/server.crt
ls -l /etc/pki/nginx/private/server.key
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

### Problema: SELinux bloqueando el acceso al certificado

**Síntoma:**
```
nginx: [emerg] BIO_new_file(...) failed
```

**Solución:**
Comprobar contextos SELinux:
```bash
sudo setenforce 0  # Prueba temporal
# Si eso lo soluciona, corregir contextos SELinux:
sudo restorecon -Rv /etc/pki/nginx/
sudo setenforce 1
```

---

## Notas específicas por versión

### RHEL 7
- Usa `yum` para la instalación
- NGINX versión 1.20.x típicamente
- Requiere configuración explícita de cifrados
- Control manual de la versión TLS

### RHEL 8+
- Usa `dnf` para la instalación
- NGINX versión 1.20.x típicamente
- Existen crypto-policies pero NGINX necesita configuración explícita
- Puede hacer referencia a la política del sistema

### RHEL 9+
- NGINX versión 1.20.x o más reciente
- SHA-1 bloqueado por defecto
- Validación de certificados más estricta
- SANs obligatorios
- TLSv1.3 preferido

---

## Limpieza

```bash
sudo ./cleanup.sh
```

Esto elimina NGINX y restaura el estado del sistema.

---

## Recursos adicionales

**Capítulos relacionados:**
- Capítulo 15: NGINX en RHEL

**Documentación:**
- `man nginx`
- `/usr/share/doc/nginx/`
- https://nginx.org/en/docs/

**Módulo SSL de NGINX:**
- http://nginx.org/en/docs/http/ngx_http_ssl_module.html

---

## Próximos pasos

Continúa con **Lab 08: Postfix TLS** para aprender la configuración TLS del servidor de correo.

---

**Nivel de dificultad**: Intermedio
