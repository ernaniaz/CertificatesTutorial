# Lab 10: Configuración de PostgreSQL TLS

## Objetivos de aprendizaje

Al completar este laboratorio, podrás:
- Instalar y configurar la base de datos PostgreSQL
- Habilitar SSL/TLS en PostgreSQL
- Comprender dónde se añadiría manualmente la autenticación con certificado de cliente
- Probar conexiones seguras a la base de datos
- Comprender la configuración SSL de pg_hba.conf
- Consultar el estado de conexiones SSL

## Requisitos previos

- **Labs 01-05** completados
- **Versión de RHEL:** 7, 8, 9 o 10
- **Acceso al sistema:** Se requiere root/sudo
- **Puerto:** 5432 (PostgreSQL)

## Tiempo estimado

**30-40 minutos**

## Descripción general del laboratorio

PostgreSQL es una potente base de datos relacional de código abierto. Este laboratorio configura TLS del lado del servidor para cifrar la comunicación cliente-servidor. La autenticación con certificados de cliente queda como material opcional posterior y no la configura el `configure-tls.sh` incluido.

---

## Instrucciones

### Paso 1: Instalar PostgreSQL

Instala el servidor de base de datos PostgreSQL:

```bash
sudo ./install-postgresql.sh
```

Esto instala:
- `postgresql-server` (servidor de base de datos)
- `postgresql` (herramientas de cliente)
- Inicializa el clúster de base de datos

---

### Paso 2: Configurar TLS

Configura PostgreSQL con certificados TLS:

```bash
sudo ./configure-tls.sh
```

Esto:
- Copia certificados del Lab 04
- Habilita SSL en postgresql.conf
- Configura reglas `hostssl` para conexiones TLS locales
- Establece permisos de certificados
- Reinicia PostgreSQL

---

### Paso 3: Probar la conexión

Prueba conexiones seguras a la base de datos:

```bash
./test-connection.sh
```

Esto prueba:
- Conexión básica a la base de datos
- Conexión con SSL/TLS habilitado
- Verificación de conexión SSL
- Estado de la conexión SSL y detalles del cifrado

---

### Paso 4: Verificar el estado SSL

Verifica la configuración SSL:

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
- ✅ PostgreSQL instalado y en ejecución
- ✅ SSL/TLS habilitado
- ✅ Conexiones seguras funcionando
- ✅ Estado SSL consultable
- ✅ Comprensión de TLS en PostgreSQL

---

## Conceptos clave

### Archivos de configuración de PostgreSQL

```
/var/lib/pgsql/data/
├── postgresql.conf       # Configuración principal
├── pg_hba.conf          # Autenticación de clientes
├── server.crt           # Certificado de servidor
├── server.key           # Clave privada del servidor
└── root.crt             # Archivo de CA opcional para configuración manual
```

### Configuración SSL en postgresql.conf

```conf
# Habilitar SSL
ssl = on

# Archivos de certificado (relativos al directorio de datos)
ssl_cert_file = 'server.crt'
ssl_key_file = 'server.key'

# Cifrados SSL
ssl_ciphers = 'HIGH:MEDIUM:+3DES:!aNULL'
ssl_prefer_server_ciphers = on

# Versión mínima de TLS (solo PostgreSQL 12+)
ssl_min_protocol_version = 'TLSv1.2'
```

### Reglas SSL de pg_hba.conf

```conf
# TYPE  DATABASE  USER  ADDRESS      METHOD

# Añadido por configure-tls.sh
hostssl    all    all    127.0.0.1/32    md5
hostssl    all    all    ::1/128         md5
```

El laboratorio incluido no añade `ssl_ca_file` ni reglas de autenticación de cliente basadas en `cert`. Si quiere explorar certificados de cliente, añada manualmente el material de CA y reglas `pg_hba.conf` más estrictas después de completar el lab.

### Cadena de conexión con SSL

```bash
# Conexión SSL básica usada en este lab
psql "host=localhost sslmode=require user=postgres"

# Consultar detalles SSL de la sesión actual
sudo -u postgres psql -c "SELECT * FROM pg_stat_ssl WHERE pid = pg_backend_pid();"
```

### Modos SSL

| Modo | Cifrado | Validación de certificado |
|------|---------|---------------------------|
| disable | No | No |
| allow | Tal vez | No |
| prefer | Tal vez | No |
| require | Sí | No |
| verify-ca | Sí | Solo CA |
| verify-full | Sí | CA + nombre de host |

---

## Resolución de problemas

### Problema: PostgreSQL no inicia

**Síntoma:**
```
Job for postgresql.service failed
```

**Solución:**
Comprobar registros y configuración:
```bash
journalctl -xeu postgresql
# Comprobar permisos del directorio de datos
ls -la /var/lib/pgsql/data/
# Comprobar permisos de server.key (debe ser 600)
```

---

### Problema: SSL no habilitado

**Síntoma:**
```
SSL connection (protocol: unknown, cipher: unknown, bits: unknown)
```

**Solución:**
Verificar que SSL esté habilitado:
```bash
sudo -u postgres psql -c "SHOW ssl;"
# Debe devolver 'on'

# Comprobar postgresql.conf
grep "^ssl" /var/lib/pgsql/data/postgresql.conf
```

---

### Problema: Errores de permisos del certificado

**Síntoma:**
```
FATAL: could not load server certificate file
```

**Solución:**
Corregir permisos del certificado:
```bash
cd /var/lib/pgsql/data/
chmod 600 server.key
chmod 644 server.crt
chown postgres:postgres server.key server.crt
```

---

### Problema: Conexión rechazada

**Síntoma:**
```
psql: could not connect to server
```

**Solución:**
Comprobar que PostgreSQL esté escuchando:
```bash
ss -tlnp | grep 5432
# Editar postgresql.conf
listen_addresses = 'localhost'  # o '*' para todas las interfaces
# Reiniciar: systemctl restart postgresql
```

---

## Notas específicas por versión

### RHEL 7
- Usa `yum` para la instalación
- PostgreSQL 9.2.x típicamente — `ssl_min_protocol_version` no disponible (requiere PG 12+)
- Directorio de datos: `/var/lib/pgsql/data/`
- Servicio: `postgresql.service`

### RHEL 8
- Usa `dnf` para la instalación
- PostgreSQL 10.x o 12.x (módulos AppStream)
- `ssl_min_protocol_version` solo disponible si el módulo PG 12+ está habilitado
- Directorio de datos: `/var/lib/pgsql/data/`

### RHEL 9
- PostgreSQL 13.x típicamente
- Valores predeterminados de seguridad mejorados
- Mejor soporte de protocolos TLS
- SHA-1 bloqueado por defecto

---

## Limpieza

```bash
sudo ./cleanup.sh
```

Esto elimina PostgreSQL y restaura el estado del sistema.

---

## Recursos adicionales

**Capítulos relacionados:**
- Capítulo 18: Configuración TLS de bases de datos

**Documentación:**
- `man postgres`
- `man psql`
- `man pg_hba.conf`
- https://www.postgresql.org/docs/current/ssl-tcp.html

**Consultas útiles:**
```sql
-- Verificar estado SSL
SHOW ssl;

-- Ver conexiones actuales con información SSL
SELECT datname, usename, ssl, client_addr, backend_type
FROM pg_stat_ssl
JOIN pg_stat_activity USING (pid);

-- Obtener información de cifrado SSL
SELECT * FROM pg_stat_ssl WHERE pid = pg_backend_pid();
```

---

## Próximos pasos

Continúa con **Lab 11: Fundamentos de certmonger** para aprender la gestión automática de certificados.

---

**Nivel de dificultad**: Intermedio
