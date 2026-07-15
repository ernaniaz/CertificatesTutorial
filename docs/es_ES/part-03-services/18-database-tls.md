# Capítulo 18: TLS en Bases de Datos (PostgreSQL, MySQL)

> **Datos en Tránsito:** Protege las conexiones de base de datos con cifrado TLS. Aprende cómo configurar PostgreSQL y MySQL/MariaDB con certificados en RHEL.

---

## 18.1 ¿Por Qué TLS en Bases de Datos?

**Proteger Datos Sensibles:**
- ✅ Cifrar consultas y resultados de base de datos
- ✅ Prevenir escucha clandestina de credenciales
- ✅ Autenticar servidores de bases de datos
- ✅ Habilitar autenticación de certificado de cliente
- ✅ Cumplir requisitos de cumplimiento (PCI-DSS, HIPAA)

**Modelo de Amenaza:**
- Sin TLS: Contraseñas y datos viajan en texto claro
- Con TLS: Toda comunicación cifrada

---

## 18.2 PostgreSQL con SSL/TLS

### Instalación

```bash
#============================================#
# INSTALAR POSTGRESQL
#============================================#

# RHEL 7/8/9/10
sudo dnf install postgresql-server -y

# Inicializar base de datos
sudo postgresql-setup --initdb

# Habilitar e iniciar
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Verificar
systemctl status postgresql
ss -tlnp | grep 5432
```

### Generar Certificados PostgreSQL

```bash
#============================================#
# GENERAR CERTIFICADOS POSTGRESQL
#============================================#

# Paso 1: Generar clave del servidor
sudo -u postgres openssl genpkey -algorithm RSA \
  -out /var/lib/pgsql/data/server.key \
  -pkeyopt rsa_keygen_bits:2048

# Paso 2: Establecer permisos (¡crítico!)
sudo chmod 600 /var/lib/pgsql/data/server.key
sudo chown postgres:postgres /var/lib/pgsql/data/server.key

# Paso 3: Generar CSR
sudo -u postgres openssl req -new \
  -key /var/lib/pgsql/data/server.key \
  -out /tmp/postgres.csr \
  -subj "/CN=db.example.com" \
  -addext "subjectAltName=DNS:db.example.com,DNS:postgres.example.com"

# Paso 4: Obtener certificado de CA

# Paso 5: Instalar certificado
sudo cp postgres.crt /var/lib/pgsql/data/server.crt
sudo chmod 600 /var/lib/pgsql/data/server.crt
sudo chown postgres:postgres /var/lib/pgsql/data/server.crt

# Paso 6: Instalar certificado CA
sudo cp ca.crt /var/lib/pgsql/data/root.crt
sudo chmod 644 /var/lib/pgsql/data/root.crt
```

### Configurar PostgreSQL para SSL

```bash
#============================================#
# CONFIGURAR POSTGRESQL SSL
#============================================#

# Editar /var/lib/pgsql/data/postgresql.conf
sudo -u postgres vi /var/lib/pgsql/data/postgresql.conf

# Habilitar SSL
ssl = on

# Archivos de certificado (relativos al directorio de datos)
ssl_cert_file = 'server.crt'
ssl_key_file = 'server.key'
ssl_ca_file = 'root.crt'

# RHEL 7: Especificar versión TLS mínima
# ssl_min_protocol_version = 'TLSv1.2'

# RHEL 8/9/10: Usa crypto-policy del sistema
# (no necesitas especificar ssl_min_protocol_version)

# Opcional: Preferir cifrados del servidor
ssl_prefer_server_ciphers = on

# Reiniciar PostgreSQL
sudo systemctl restart postgresql
```

### Configurar Autenticación de Cliente

```bash
#============================================#
# /var/lib/pgsql/data/pg_hba.conf
#============================================#

# Requerir SSL para todas las conexiones
hostssl all all 0.0.0.0/0 md5

# Requerir certificado de cliente
hostssl all alice 0.0.0.0/0 cert clientcert=verify-full

# Recargar configuración
sudo systemctl reload postgresql
```

**Tipos HBA:**
- `host`: Permitir sin SSL
- `hostssl`: Requerir SSL
- `hostnossl`: Prohibir explícitamente SSL

**Opciones de Cert de Cliente:**
- `md5`: SSL requerido, autenticación por contraseña
- `cert`: SSL + certificado de cliente requerido
- `clientcert=verify-full`: Verificar cert de cliente contra CA

### Probar PostgreSQL SSL

```bash
#============================================#
# PROBAR POSTGRESQL SSL
#============================================#

# Prueba 1: Conectar con SSL requerido
psql "host=db.example.com port=5432 user=testuser dbname=testdb sslmode=require"

# Prueba 2: Conectar con verificación completa
psql "host=db.example.com port=5432 user=testuser dbname=testdb sslmode=verify-full sslrootcert=/etc/pki/tls/certs/ca-bundle.crt"

# Prueba 3: Con certificado de cliente
psql "host=db.example.com port=5432 user=alice dbname=mydb sslmode=verify-full sslcert=/home/alice/.postgresql/client.crt sslkey=/home/alice/.postgresql/client.key sslrootcert=/etc/pki/tls/certs/ca-bundle.crt"

# Prueba 4: Verificar SSL desde dentro de PostgreSQL
psql -h db.example.com -U testuser -d testdb -c "SELECT ssl, version FROM pg_stat_ssl WHERE pid = pg_backend_pid();"

# Prueba 5: Prueba OpenSSL
openssl s_client -connect db.example.com:5432 -starttls postgres
```

**Modos SSL:**
- `disable`: Sin SSL
- `allow`: Intentar SSL, volver a no-SSL
- `prefer`: Preferir SSL, fallback permitido
- `require`: Requerir SSL (no verificar cert)
- `verify-ca`: Requerir SSL, verificar CA
- `verify-full`: Requerir SSL, verificar hostname + CA

---

## 18.3 MySQL/MariaDB con SSL/TLS

### Instalación

```bash
#============================================#
# INSTALAR MARIADB (REEMPLAZO MYSQL EN RHEL 8+)
#============================================#

# RHEL 8/9/10
sudo dnf install mariadb-server -y

# Iniciar y habilitar
sudo systemctl enable mariadb
sudo systemctl start mariadb

# Instalación segura
sudo mysql_secure_installation

# Verificar
systemctl status mariadb
ss -tlnp | grep 3306
```

### Generar Certificados MySQL/MariaDB

```bash
#============================================#
# GENERAR CERTIFICADOS MYSQL/MARIADB
#============================================#

# Crear directorio de certificados
sudo mkdir -p /etc/mysql/certs
sudo chmod 755 /etc/mysql/certs

# Paso 1: Generar clave del servidor
sudo openssl genpkey -algorithm RSA \
  -out /etc/mysql/certs/server.key \
  -pkeyopt rsa_keygen_bits:2048

sudo chmod 600 /etc/mysql/certs/server.key
sudo chown mysql:mysql /etc/mysql/certs/server.key

# Paso 2: Generar CSR
sudo openssl req -new \
  -key /etc/mysql/certs/server.key \
  -out /tmp/mysql.csr \
  -subj "/CN=db.example.com" \
  -addext "subjectAltName=DNS:db.example.com,DNS:mysql.example.com"

# Paso 3: Obtener certificado de CA

# Paso 4: Instalar certificado y CA
sudo cp mysql.crt /etc/mysql/certs/server.crt
sudo cp ca.crt /etc/mysql/certs/ca.crt
sudo chmod 644 /etc/mysql/certs/{server.crt,ca.crt}
sudo chown mysql:mysql /etc/mysql/certs/{server.crt,ca.crt}
```

### Configurar MySQL/MariaDB para SSL

```bash
#============================================#
# CONFIGURAR MYSQL/MARIADB SSL
#============================================#

# Editar /etc/my.cnf.d/server.cnf (o /etc/my.cnf)
sudo vi /etc/my.cnf.d/server.cnf

[mysqld]
# Configuración SSL/TLS
ssl-ca=/etc/mysql/certs/ca.crt
ssl-cert=/etc/mysql/certs/server.crt
ssl-key=/etc/mysql/certs/server.key

# Requerir transporte seguro (opcional, fuerza TLS para todos)
require_secure_transport=ON

# RHEL 7: Especificar versión TLS
# tls_version=TLSv1.2,TLSv1.3

# Reiniciar MySQL/MariaDB
sudo systemctl restart mariadb
```

### Verificar que SSL está Habilitado

```bash
#============================================#
# VERIFICAR MYSQL SSL
#============================================#

# Conectar y verificar estado SSL
mysql -u root -p -e "SHOW VARIABLES LIKE '%ssl%';"

# Debería mostrar:
# have_ssl           | YES
# ssl_ca             | /etc/mysql/certs/ca.crt
# ssl_cert           | /etc/mysql/certs/server.crt
# ssl_key            | /etc/mysql/certs/server.key

# Verificar conexiones activas
mysql -u root -p -e "SHOW STATUS LIKE 'Ssl_cipher';"
```

### Probar Conexión SSL MySQL

```bash
#============================================#
# PROBAR CONEXIÓN SSL MYSQL
#============================================#

# Conectar con SSL
mysql --ssl-ca=/etc/mysql/certs/ca.crt \
  --ssl-mode=REQUIRED \
  -h db.example.com \
  -u testuser \
  -p

# Verificar SSL en uso
mysql> \s
# Buscar: "SSL: Cipher in use is ..."

# O verificar desde línea de comandos
mysql -h db.example.com -u testuser -p -e "STATUS" | grep SSL
```

---

## 18.4 Autenticación de Certificado de Cliente

### PostgreSQL con Certificados de Cliente

```bash
#============================================#
# AUTENTICACIÓN CERT CLIENTE POSTGRESQL
#============================================#

# Lado servidor: pg_hba.conf
hostssl all alice 0.0.0.0/0 cert clientcert=verify-full

# Generar certificado de cliente
openssl genpkey -algorithm RSA -out alice.key -pkeyopt rsa_keygen_bits:2048
openssl req -new -key alice.key -out alice.csr -subj "/CN=alice"
# Obtener firmado por CA

# Conexión de cliente
psql "host=db.example.com user=alice dbname=mydb sslmode=verify-full sslcert=alice.crt sslkey=alice.key sslrootcert=ca.crt"
```

### MySQL/MariaDB con Certificados de Cliente

```bash
#============================================#
# AUTENTICACIÓN CERT CLIENTE MYSQL/MARIADB
#============================================#

# Crear usuario requiriendo X.509
mysql -u root -p << EOF
CREATE USER 'alice'@'%' REQUIRE X509;
GRANT ALL ON mydb.* TO 'alice'@'%';
FLUSH PRIVILEGES;
EOF

# Conexión de cliente
mysql --ssl-ca=ca.crt \
  --ssl-cert=alice.crt \
  --ssl-key=alice.key \
  -h db.example.com \
  -u alice \
  -p mydb
```

---

## 18.5 Solución de Problemas Database TLS

### Solución de Problemas PostgreSQL

```bash
#============================================#
# SOLUCIÓN DE PROBLEMAS SSL POSTGRESQL
#============================================#

# Verificar que SSL está habilitado
sudo -u postgres psql -c "SHOW ssl;"
# Debería mostrar: on

# Ver ajustes SSL
sudo -u postgres psql -c "SHOW ssl_cert_file; SHOW ssl_key_file; SHOW ssl_ca_file;"

# Verificar archivos de certificado
ls -l /var/lib/pgsql/data/server.{crt,key}

# Verificar ownership
# Debería ser: postgres:postgres

# Verificar permisos
# server.key debería ser 600

# Probar conexión con depuración SSL
psql "host=db.example.com sslmode=require" -d postgres -U testuser --set=sslcompression=on

# Verificar logs de PostgreSQL
sudo tail -f /var/lib/pgsql/data/log/postgresql-*.log | grep -i ssl
```

### Solución de Problemas MySQL/MariaDB

```bash
#============================================#
# SOLUCIÓN DE PROBLEMAS SSL MYSQL/MARIADB
#============================================#

# Verificar variables SSL
mysql -u root -p -e "SHOW VARIABLES LIKE '%ssl%';"

# Si have_ssl = NO, verificar:
# 1. Que existan archivos de certificado
ls -l /etc/mysql/certs/

# 2. Permisos
# Deberían ser legibles por usuario mysql

# 3. Reiniciar base de datos
sudo systemctl restart mariadb

# Verificar log de errores
sudo tail -f /var/log/mariadb/mariadb.log | grep -i ssl

# Probar conexión
mysql --ssl-ca=/etc/mysql/certs/ca.crt \
  --ssl-mode=REQUIRED \
  -h localhost \
  -u root \
  -p \
  -e "STATUS" | grep SSL
```

---

## 18.6 Problemas Comunes y Soluciones

### Problema 1: PostgreSQL "Permission denied" en server.key

**Síntoma:** PostgreSQL no inicia, logs muestran error de permiso

**Solución:**
```bash
# Establecer permisos correctos
sudo chmod 600 /var/lib/pgsql/data/server.key
sudo chown postgres:postgres /var/lib/pgsql/data/server.key

# Corregir contexto SELinux
sudo restorecon -Rv /var/lib/pgsql/data/

# Reiniciar
sudo systemctl restart postgresql
```

### Problema 2: MySQL "SSL connection error"

**Diagnóstico:**
```bash
# Verificar si SSL está disponible
mysql -u root -p -e "SHOW VARIABLES LIKE 'have_ssl';"
# Debería mostrar: YES

# Si muestra: DISABLED
# Verificar rutas de certificado en my.cnf
```

**Solución:**
```bash
# Verificar rutas en /etc/my.cnf.d/server.cnf
[mysqld]
ssl-ca=/etc/mysql/certs/ca.crt
ssl-cert=/etc/mysql/certs/server.crt
ssl-key=/etc/mysql/certs/server.key

# Reiniciar
sudo systemctl restart mariadb
```

### Problema 3: Certificado de Cliente Rechazado

**Síntoma:** La conexión falla con cert de cliente

**Solución PostgreSQL:**
```bash
# Verificar pg_hba.conf
cat /var/lib/pgsql/data/pg_hba.conf | grep hostssl

# Asegurar que CA de cliente está instalada
sudo cp client-ca.crt /var/lib/pgsql/data/root.crt

# Recargar
sudo systemctl reload postgresql
```

**Solución MySQL:**
```bash
# Verificar que usuario requiere X.509
mysql -u root -p -e "SELECT user, host, ssl_type FROM mysql.user WHERE user='alice';"
# Debería mostrar: X509

# Verificar archivo CA configurado
mysql -u root -p -e "SHOW VARIABLES LIKE 'ssl_ca';"
```

---

## 18.7 Consideraciones Específicas por Versión

### Versiones PostgreSQL en RHEL

| Versión RHEL | PostgreSQL | Soporte SSL | Notas |
|--------------|------------|-------------|-------|
| RHEL 7 | 9.2 | ✅ Sí | Config manual versión TLS |
| RHEL 8 | 10.x+ | ✅ Sí | Crypto-policy del sistema |
| RHEL 9 | 13.x+ | ✅ Sí | Mejorado, crypto-policy |
| RHEL 10 | 15.x+ | ✅ Sí | Último, crypto-policy |

### Versiones MySQL/MariaDB en RHEL

| Versión RHEL | Base de Datos | Soporte SSL | Notas |
|--------------|---------------|-------------|-------|
| RHEL 7 | MariaDB 5.5 | ✅ Sí | Config manual |
| RHEL 8 | MariaDB 10.3+ | ✅ Sí | Compatible crypto-policy |
| RHEL 9 | MariaDB 10.5+ | ✅ Sí | TLS moderno |
| RHEL 10 | MariaDB 10.11+ | ✅ Sí | Últimas características |

---

## 18.8 Consideraciones de Rendimiento

### Rendimiento SSL PostgreSQL

```ini
#============================================#
# AJUSTE DE RENDIMIENTO SSL POSTGRESQL
#============================================#

# /var/lib/pgsql/data/postgresql.conf

# SSL habilitado
ssl = on

# Compresión SSL (deshabilitada por seguridad, ataque CRIME)
ssl_compression = off

# Cifrados SSL (RHEL 7 - manual)
# ssl_ciphers = 'HIGH:!aNULL:!MD5'

# RHEL 8/9/10: crypto-policy maneja cifrados

# Connection pooling ayuda (usar pgBouncer)
# Terminación SSL en proxy puede mejorar rendimiento
```

### Rendimiento SSL MySQL

```ini
#============================================#
# RENDIMIENTO SSL MYSQL
#============================================#

# [mysqld] en /etc/my.cnf.d/server.cnf

# SSL habilitado
ssl-ca=/etc/mysql/certs/ca.crt
ssl-cert=/etc/mysql/certs/server.crt
ssl-key=/etc/mysql/certs/server.key

# Deshabilitar cifrados débiles (RHEL 7)
# tls_version=TLSv1.2,TLSv1.3
# ssl_cipher='ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256'

# RHEL 8/9/10: crypto-policy lo maneja

# Connection pooling (usar ProxySQL o similar)
```

---

## 18.9 Monitorear Database TLS

### Monitoreo PostgreSQL

```bash
#============================================#
# MONITOREAR SSL POSTGRESQL
#============================================#

# Verificar conexiones SSL
sudo -u postgres psql -c "SELECT datname, usename, ssl, version FROM pg_stat_ssl JOIN pg_stat_activity ON pg_stat_ssl.pid = pg_stat_activity.pid;"

# Contar SSL vs no-SSL
sudo -u postgres psql -c "SELECT ssl, COUNT(*) FROM pg_stat_ssl GROUP BY ssl;"

# Verificar expiración de certificado
openssl x509 -in /var/lib/pgsql/data/server.crt -noout -checkend $((86400*30))

# Monitorear conexiones
sudo -u postgres psql -c "SELECT COUNT(*) FROM pg_stat_activity WHERE ssl = true;"
```

### Monitoreo MySQL

```bash
#============================================#
# MONITOREAR SSL MYSQL
#============================================#

# Verificar estado SSL
mysql -u root -p -e "SHOW STATUS LIKE 'Ssl%';"

# Contar conexiones SSL
mysql -u root -p -e "SHOW STATUS LIKE 'Ssl_accepts';"

# Conexiones SSL actuales
mysql -u root -p -e "SELECT user, host, connection_type FROM information_schema.processlist WHERE connection_type = 'SSL/TLS';"

# Expiración de certificado
openssl x509 -in /etc/mysql/certs/server.crt -noout -checkend $((86400*30))
```

---

## 18.10 Scripts de Configuración Completos

### Script de Configuración SSL PostgreSQL

```bash
#!/bin/bash
# setup-postgresql-ssl.sh

echo "=== Configuración SSL PostgreSQL ==="

# Generar cert autofirmado (¡reemplazar con cert apropiado de CA!)
sudo -u postgres openssl req -new -x509 -days 365 -nodes \
  -out /var/lib/pgsql/data/server.crt \
  -keyout /var/lib/pgsql/data/server.key \
  -subj "/CN=$(hostname -f)"

# Establecer permisos
sudo chmod 600 /var/lib/pgsql/data/server.{crt,key}
sudo chown postgres:postgres /var/lib/pgsql/data/server.{crt,key}

# Habilitar SSL en postgresql.conf
sudo -u postgres psql -c "ALTER SYSTEM SET ssl = on;"

# Reiniciar
sudo systemctl restart postgresql

# Probar
sudo -u postgres psql -c "SHOW ssl;"

echo "✅ SSL PostgreSQL habilitado"
echo "⚠️ Reemplazar cert autofirmado con certificado apropiado de CA"
```

---

## 18.11 Conclusiones Clave

1. **PostgreSQL y MySQL soportan SSL/TLS**
2. **Ownership de archivo crítico** - postgres:postgres o mysql:mysql
3. **Permisos:** 600 para claves, 644 para certs
4. **pg_hba.conf controla** acceso PostgreSQL (hostssl)
5. **sslmode importante** para clientes PostgreSQL
6. **Certificados de cliente habilitan** autenticación fuerte
7. **Probar exhaustivamente** antes de forzar TLS
8. **Monitorear uso SSL** - Asegurar que los clientes realmente lo usen

---

## Tarjeta de Referencia Rápida

```
┌──────────────────────────────────────────────────────────────┐
│ REFERENCIA RÁPIDA DATABASE TLS                               │
├──────────────────────────────────────────────────────────────┤
│ === POSTGRESQL ===                                           │
│ Config:       /var/lib/pgsql/data/postgresql.conf            │
│ Acceso:       /var/lib/pgsql/data/pg_hba.conf                │
│ Certs:        /var/lib/pgsql/data/server.{crt,key}           │
│ Owner:        postgres:postgres                              │
│ Habilitar:    ssl = on                                       │
│ Probar:       psql "sslmode=require"                         │
│                                                              │
│ === MYSQL/MARIADB ===                                        │
│ Config:       /etc/my.cnf.d/server.cnf                       │
│ Certs:        /etc/mysql/certs/server.{crt,key}              │
│ Owner:        mysql:mysql                                    │
│ Habilitar:    ssl-ca, ssl-cert, ssl-key en [mysqld]          │
│ Probar:       mysql --ssl-mode=REQUIRED                      │
│                                                              │
│ Permisos:     chmod 600 *.key                                │
│               chmod 644 *.crt                                │
└──────────────────────────────────────────────────────────────┘

⚠️ ¡Ownership y permisos de archivos son críticos!
✅ Usar hostssl en pg_hba.conf para requerir SSL
```

---

## 🧪 Laboratorio Práctico

**Lab 10: TLS de PostgreSQL**

Configura TLS para conexiones de base de datos PostgreSQL

- 📁 **Ubicación:** `labs/es_ES/10-postgresql-tls/`
- ⏱️ **Tiempo:** 25-30 minutos
- 🎯 **Nivel:** Intermedio

---

**Navegación del Capítulo**

| [← Anterior: Capítulo 17 - OpenLDAP y Servicios de Directorio](17-openldap-ldaps.md) | [Siguiente: Capítulo 19 - Servicios de Certificados FreeIPA →](19-freeipa-services.md) |
|:---|---:|
