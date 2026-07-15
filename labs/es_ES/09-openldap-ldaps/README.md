# Lab 09: Configuración de OpenLDAP LDAPS

## Objetivos de aprendizaje

Al completar este laboratorio, podrás:
- Instalar y configurar el servidor OpenLDAP
- Configurar LDAP sobre TLS (LDAPS) en el puerto 636
- Configurar STARTTLS en el puerto 389
- Configurar TLS del cliente LDAP
- Probar conexiones LDAP seguras
- Comprender cn=config vs slapd.conf

## Requisitos previos

- **Labs 01-05** completados
- **Versión de RHEL:** 7, 8, 9 o 10
- **Acceso al sistema:** Se requiere root/sudo
- **Puertos:** 389 (LDAP), 636 (LDAPS)

## Tiempo estimado

**40-50 minutos**

## Descripción general del laboratorio

OpenLDAP es una implementación de servicio de directorio. Aprende a configurarlo con TLS para autenticación segura y consultas de directorio usando LDAPS (puerto TLS dedicado) y STARTTLS (actualización de conexión en texto plano).

---

## Instrucciones

### Paso 1: Instalar OpenLDAP

Instala el servidor OpenLDAP:

```bash
sudo ./install-openldap.sh
```

Esto instala:
- `openldap-servers` (servidor LDAP)
- `openldap-clients` (herramientas de cliente)
- Estructura básica del directorio

> **Nota:** En RHEL 9+, `openldap-servers` fue eliminado de los repositorios base. El script habilita automáticamente EPEL para instalarlo.

---

### Paso 2: Configurar LDAPS

Configura LDAP con certificados TLS:

```bash
sudo ./configure-ldaps.sh
```

Esto:
- Copia certificados del Lab 04
- Configura TLS en cn=config
- Habilita LDAPS en el puerto 636
- Configura rutas de certificados
- Reinicia slapd

---

### Paso 3: Configurar el cliente LDAP

Configura el cliente LDAP para TLS:

```bash
sudo ./configure-client.sh
```

Esto:
- Configura `/etc/openldap/ldap.conf`
- Establece la ruta del certificado TLS
- Configura opciones TLS
- Habilita la validación de certificados

---

### Paso 4: Probar conexiones

Prueba conexiones LDAP y LDAPS:

```bash
./test-connection.sh
```

Esto prueba:
- LDAP en texto plano (puerto 389)
- STARTTLS en el puerto 389
- LDAPS en el puerto 636
- Validación de certificados

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
- ✅ OpenLDAP instalado y en ejecución
- ✅ LDAPS funcionando en el puerto 636
- ✅ STARTTLS funcionando en el puerto 389
- ✅ Cliente configurado para TLS
- ✅ Comprensión de la configuración TLS de LDAP

---

## Conceptos clave

### Configuración de OpenLDAP

**RHEL 7:**
- Usa `/etc/openldap/slapd.conf` (tradicional)
- Configuración basada en texto
- Requiere reinicio para aplicar cambios

**RHEL 8+:**
- Usa cn=config (configuración dinámica)
- Basado en LDIF en `/etc/openldap/slapd.d/`
- Cambios aplicados sin reinicio

### Puertos LDAP

**Puerto 389 (LDAP):**
- LDAP en texto plano
- Soporta actualización STARTTLS
- Puerto LDAP predeterminado

**Puerto 636 (LDAPS):**
- LDAP sobre TLS desde el inicio
- Como HTTPS vs HTTP
- Puerto seguro dedicado

### Directivas de configuración TLS

**Servidor (cn=config):**
```ldif
olcTLSCertificateFile: /etc/pki/tls/certs/ldap.crt
olcTLSCertificateKeyFile: /etc/pki/tls/private/ldap.key
olcTLSCACertificateFile: /etc/pki/tls/certs/ca-bundle.crt
olcTLSProtocolMin: 3.3
olcTLSCipherSuite: HIGH:!aNULL:!MD5
```

**Cliente (/etc/openldap/ldap.conf):**
```conf
TLS_CACERTDIR /etc/openldap/certs
TLS_REQCERT allow
URI ldaps://localhost
```

### Comandos ldapsearch

```bash
# LDAP sin cifrado
ldapsearch -x -H ldap://localhost -b "" -s base

# LDAP con STARTTLS
ldapsearch -x -H ldap://localhost -b "" -s base -ZZ

# LDAPS
ldapsearch -x -H ldaps://localhost -b "" -s base
```

---

## Resolución de problemas

### Problema: slapd no inicia

**Síntoma:**
```
Job for slapd.service failed
```

**Solución:**
Comprobar registros y configuración:
```bash
journalctl -xeu slapd
slapd -d 1  # Modo de depuración
# Comprobar permisos de archivos en certificados
```

---

### Problema: Fallo en el handshake TLS

**Síntoma:**
```
ldap_start_tls: Connect error (-11)
TLS: can't connect: TLS error
```

**Solución:**
Comprobar la configuración de certificados:
```bash
# Verificar que los certificados son legibles por el usuario ldap
ls -l /etc/openldap/certs/
# Comprobar contextos SELinux
ls -Z /etc/openldap/certs/
# Restaurar contextos si es necesario
restorecon -Rv /etc/openldap/certs/
```

---

### Problema: Fallo en la verificación del certificado

**Síntoma:**
```
TLS certificate verification: Error, self signed certificate
```

**Solución:**
Configurar el cliente para confiar en el certificado:
```bash
# Opción 1: Usar TLS_REQCERT allow (para laboratorio/pruebas)
echo "TLS_REQCERT allow" >> /etc/openldap/ldap.conf

# Opción 2: Agregar certificado CA (producción)
cp /path/to/ca.crt /etc/openldap/certs/
echo "TLS_CACERT /etc/openldap/certs/ca.crt" >> /etc/openldap/ldap.conf
```

---

### Problema: Puerto 636 no escuchando

**Síntoma:**
No se puede conectar a ldaps://localhost:636

**Solución:**
Habilitar LDAPS en la configuración de slapd:
```bash
# Comprobar argumentos de slapd
systemctl cat slapd | grep ExecStart

# RHEL 8+: Editar /etc/sysconfig/slapd
# Agregar: SLAPD_URLS="ldap:/// ldaps:/// ldapi:///"

systemctl restart slapd
ss -tlnp | grep 636
```

---

## Notas específicas por versión

### RHEL 7
- Usa `yum` para la instalación
- Puede usar slapd.conf (configuración tradicional)
- Configuración manual del protocolo TLS
- Soporte TLS vía OpenSSL

### RHEL 8
- Usa `dnf` para la instalación
- Solo cn=config (sin slapd.conf)
- crypto-policies afectan TLS
- OpenLDAP 2.4.x

### RHEL 9
- **`openldap-servers` eliminado de los repos base** — se instala desde EPEL
- OpenLDAP 2.4.x o 2.5.x
- Valores predeterminados TLS más estrictos
- SHA-1 bloqueado por defecto
- Políticas de seguridad mejoradas
- Mejor integración con SELinux

---

## Limpieza

```bash
sudo ./cleanup.sh
```

Esto elimina OpenLDAP y restaura el estado del sistema.

---

## Recursos adicionales

**Capítulos relacionados:**
- Capítulo 17: OpenLDAP LDAPS

**Documentación:**
- `man slapd`
- `man slapd.conf` (RHEL 7)
- `man slapd-config` (cn=config)
- `man ldap.conf`
- https://www.openldap.org/doc/admin24/tls.html

**Herramientas de cliente:**
- `ldapsearch` - buscar en el directorio
- `ldapadd` - agregar entradas
- `ldapmodify` - modificar entradas

---

## Próximos pasos

Continúa con **Lab 10: PostgreSQL TLS** para aprender la configuración TLS de bases de datos.

---

**Nivel de dificultad:** Intermedio a avanzado
