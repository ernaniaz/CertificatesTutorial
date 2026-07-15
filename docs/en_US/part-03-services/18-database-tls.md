# Chapter 18: Database TLS (PostgreSQL, MySQL)

> **Data in Transit:** Protect database connections with TLS encryption. Learn how to configure PostgreSQL and MySQL/MariaDB with certificates on RHEL.

---

## 18.1 Why Database TLS?

**Protect Sensitive Data:**
- ✅ Encrypt database queries and results
- ✅ Prevent eavesdropping on credentials
- ✅ Authenticate database servers
- ✅ Enable client certificate authentication
- ✅ Meet compliance requirements (PCI-DSS, HIPAA)

**Threat Model:**
- Without TLS: Passwords and data travel in cleartext
- With TLS: All communication encrypted

---

## 18.2 PostgreSQL with SSL/TLS

### Installation

```bash
#============================================#
# INSTALL POSTGRESQL
#============================================#

# RHEL 7/8/9/10
sudo dnf install postgresql-server -y

# Initialize database
sudo postgresql-setup --initdb

# Enable and start
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Verify
systemctl status postgresql
ss -tlnp | grep 5432
```

### Generate PostgreSQL Certificates

```bash
#============================================#
# GENERATE POSTGRESQL CERTIFICATES
#============================================#

# Step 1: Generate server key
sudo -u postgres openssl genpkey -algorithm RSA \
  -out /var/lib/pgsql/data/server.key \
  -pkeyopt rsa_keygen_bits:2048

# Step 2: Set permissions (critical!)
sudo chmod 600 /var/lib/pgsql/data/server.key
sudo chown postgres:postgres /var/lib/pgsql/data/server.key

# Step 3: Generate CSR
sudo -u postgres openssl req -new \
  -key /var/lib/pgsql/data/server.key \
  -out /tmp/postgres.csr \
  -subj "/CN=db.example.com" \
  -addext "subjectAltName=DNS:db.example.com,DNS:postgres.example.com"

# Step 4: Get certificate from CA

# Step 5: Install certificate
sudo cp postgres.crt /var/lib/pgsql/data/server.crt
sudo chmod 600 /var/lib/pgsql/data/server.crt
sudo chown postgres:postgres /var/lib/pgsql/data/server.crt

# Step 6: Install CA certificate
sudo cp ca.crt /var/lib/pgsql/data/root.crt
sudo chmod 644 /var/lib/pgsql/data/root.crt
```

### Configure PostgreSQL for SSL

```bash
#============================================#
# CONFIGURE POSTGRESQL SSL
#============================================#

# Edit /var/lib/pgsql/data/postgresql.conf
sudo -u postgres vi /var/lib/pgsql/data/postgresql.conf

# Enable SSL
ssl = on

# Certificate files (relative to data directory)
ssl_cert_file = 'server.crt'
ssl_key_file = 'server.key'
ssl_ca_file = 'root.crt'

# RHEL 7: Specify minimum TLS version
# ssl_min_protocol_version = 'TLSv1.2'

# RHEL 8/9/10: Uses system crypto-policy
# (no need to specify ssl_min_protocol_version)

# Optional: Prefer server ciphers
ssl_prefer_server_ciphers = on

# Restart PostgreSQL
sudo systemctl restart postgresql
```

### Configure Client Authentication

```bash
#============================================#
# /var/lib/pgsql/data/pg_hba.conf
#============================================#

# Require SSL for all connections
hostssl all all 0.0.0.0/0 md5

# Require client certificate
hostssl all alice 0.0.0.0/0 cert clientcert=verify-full

# Reload configuration
sudo systemctl reload postgresql
```

**HBA Types:**
- `host`: Allow non-SSL
- `hostssl`: Require SSL
- `hostnossl`: Explicitly forbid SSL

**Client Cert Options:**
- `md5`: SSL required, password auth
- `cert`: SSL + client certificate required
- `clientcert=verify-full`: Verify client cert against CA

### Test PostgreSQL SSL

```bash
#============================================#
# TEST POSTGRESQL SSL
#============================================#

# Test 1: Connect with SSL required
psql "host=db.example.com port=5432 user=testuser dbname=testdb sslmode=require"

# Test 2: Connect with full verification
psql "host=db.example.com port=5432 user=testuser dbname=testdb sslmode=verify-full sslrootcert=/etc/pki/tls/certs/ca-bundle.crt"

# Test 3: With client certificate
psql "host=db.example.com port=5432 user=alice dbname=mydb sslmode=verify-full sslcert=/home/alice/.postgresql/client.crt sslkey=/home/alice/.postgresql/client.key sslrootcert=/etc/pki/tls/certs/ca-bundle.crt"

# Test 4: Check SSL from within PostgreSQL
psql -h db.example.com -U testuser -d testdb -c "SELECT ssl, version FROM pg_stat_ssl WHERE pid = pg_backend_pid();"

# Test 5: OpenSSL test
openssl s_client -connect db.example.com:5432 -starttls postgres
```

**SSL Modes:**
- `disable`: No SSL
- `allow`: Try SSL, fallback to non-SSL
- `prefer`: Prefer SSL, fallback allowed
- `require`: Require SSL (don't verify cert)
- `verify-ca`: Require SSL, verify CA
- `verify-full`: Require SSL, verify hostname + CA

---

## 18.3 MySQL/MariaDB with SSL/TLS

### Installation

```bash
#============================================#
# INSTALL MARIADB (MYSQL REPLACEMENT ON RHEL 8+)
#============================================#

# RHEL 8/9/10
sudo dnf install mariadb-server -y

# Start and enable
sudo systemctl enable mariadb
sudo systemctl start mariadb

# Secure installation
sudo mysql_secure_installation

# Verify
systemctl status mariadb
ss -tlnp | grep 3306
```

### Generate MySQL/MariaDB Certificates

```bash
#============================================#
# GENERATE MYSQL/MARIADB CERTIFICATES
#============================================#

# Create certificate directory
sudo mkdir -p /etc/mysql/certs
sudo chmod 755 /etc/mysql/certs

# Step 1: Generate server key
sudo openssl genpkey -algorithm RSA \
  -out /etc/mysql/certs/server.key \
  -pkeyopt rsa_keygen_bits:2048

sudo chmod 600 /etc/mysql/certs/server.key
sudo chown mysql:mysql /etc/mysql/certs/server.key

# Step 2: Generate CSR
sudo openssl req -new \
  -key /etc/mysql/certs/server.key \
  -out /tmp/mysql.csr \
  -subj "/CN=db.example.com" \
  -addext "subjectAltName=DNS:db.example.com,DNS:mysql.example.com"

# Step 3: Get certificate from CA

# Step 4: Install certificate and CA
sudo cp mysql.crt /etc/mysql/certs/server.crt
sudo cp ca.crt /etc/mysql/certs/ca.crt
sudo chmod 644 /etc/mysql/certs/{server.crt,ca.crt}
sudo chown mysql:mysql /etc/mysql/certs/{server.crt,ca.crt}
```

### Configure MySQL/MariaDB for SSL

```bash
#============================================#
# CONFIGURE MYSQL/MARIADB SSL
#============================================#

# Edit /etc/my.cnf.d/server.cnf (or /etc/my.cnf)
sudo vi /etc/my.cnf.d/server.cnf

[mysqld]
# SSL/TLS configuration
ssl-ca=/etc/mysql/certs/ca.crt
ssl-cert=/etc/mysql/certs/server.crt
ssl-key=/etc/mysql/certs/server.key

# Require secure transport (optional, forces TLS for all)
require_secure_transport=ON

# RHEL 7: Specify TLS version
# tls_version=TLSv1.2,TLSv1.3

# Restart MySQL/MariaDB
sudo systemctl restart mariadb
```

### Verify SSL is Enabled

```bash
#============================================#
# VERIFY MYSQL SSL
#============================================#

# Connect and check SSL status
mysql -u root -p -e "SHOW VARIABLES LIKE '%ssl%';"

# Should show:
# have_ssl           | YES
# ssl_ca             | /etc/mysql/certs/ca.crt
# ssl_cert           | /etc/mysql/certs/server.crt
# ssl_key            | /etc/mysql/certs/server.key

# Check active connections
mysql -u root -p -e "SHOW STATUS LIKE 'Ssl_cipher';"
```

### Test MySQL SSL Connection

```bash
#============================================#
# TEST MYSQL SSL CONNECTION
#============================================#

# Connect with SSL
mysql --ssl-ca=/etc/mysql/certs/ca.crt \
  --ssl-mode=REQUIRED \
  -h db.example.com \
  -u testuser \
  -p

# Verify SSL in use
mysql> \s
# Look for: "SSL: Cipher in use is ..."

# Or check from command line
mysql -h db.example.com -u testuser -p -e "STATUS" | grep SSL
```

---

## 18.4 Client Certificate Authentication

### PostgreSQL with Client Certificates

```bash
#============================================#
# POSTGRESQL CLIENT CERT AUTH
#============================================#

# Server side: pg_hba.conf
hostssl all alice 0.0.0.0/0 cert clientcert=verify-full

# Generate client certificate
openssl genpkey -algorithm RSA -out alice.key -pkeyopt rsa_keygen_bits:2048
openssl req -new -key alice.key -out alice.csr -subj "/CN=alice"
# Get signed by CA

# Client connection
psql "host=db.example.com user=alice dbname=mydb sslmode=verify-full sslcert=alice.crt sslkey=alice.key sslrootcert=ca.crt"
```

### MySQL/MariaDB with Client Certificates

```bash
#============================================#
# MYSQL/MARIADB CLIENT CERT AUTH
#============================================#

# Create user requiring X.509
mysql -u root -p << EOF
CREATE USER 'alice'@'%' REQUIRE X509;
GRANT ALL ON mydb.* TO 'alice'@'%';
FLUSH PRIVILEGES;
EOF

# Client connection
mysql --ssl-ca=ca.crt \
  --ssl-cert=alice.crt \
  --ssl-key=alice.key \
  -h db.example.com \
  -u alice \
  -p mydb
```

---

## 18.5 Troubleshooting Database TLS

### PostgreSQL Troubleshooting

```bash
#============================================#
# POSTGRESQL SSL TROUBLESHOOTING
#============================================#

# Check SSL is enabled
sudo -u postgres psql -c "SHOW ssl;"
# Should show: on

# View SSL settings
sudo -u postgres psql -c "SHOW ssl_cert_file; SHOW ssl_key_file; SHOW ssl_ca_file;"

# Check certificate files
ls -l /var/lib/pgsql/data/server.{crt,key}

# Verify ownership
# Should be: postgres:postgres

# Check permissions
# server.key should be 600

# Test connection with SSL debugging
psql "host=db.example.com sslmode=require" -d postgres -U testuser --set=sslcompression=on

# Check PostgreSQL logs
sudo tail -f /var/lib/pgsql/data/log/postgresql-*.log | grep -i ssl
```

### MySQL/MariaDB Troubleshooting

```bash
#============================================#
# MYSQL/MARIADB SSL TROUBLESHOOTING
#============================================#

# Check SSL variables
mysql -u root -p -e "SHOW VARIABLES LIKE '%ssl%';"

# If have_ssl = NO, check:
# 1. Certificate files exist
ls -l /etc/mysql/certs/

# 2. Permissions
# Should be readable by mysql user

# 3. Restart database
sudo systemctl restart mariadb

# Check error log
sudo tail -f /var/log/mariadb/mariadb.log | grep -i ssl

# Test connection
mysql --ssl-ca=/etc/mysql/certs/ca.crt \
  --ssl-mode=REQUIRED \
  -h localhost \
  -u root \
  -p \
  -e "STATUS" | grep SSL
```

---

## 18.6 Common Issues and Solutions

### Issue 1: PostgreSQL "Permission denied" on server.key

**Symptom:** PostgreSQL won't start, logs show permission error

**Fix:**
```bash
# Set correct permissions
sudo chmod 600 /var/lib/pgsql/data/server.key
sudo chown postgres:postgres /var/lib/pgsql/data/server.key

# Fix SELinux context
sudo restorecon -Rv /var/lib/pgsql/data/

# Restart
sudo systemctl restart postgresql
```

### Issue 2: MySQL "SSL connection error"

**Diagnosis:**
```bash
# Check if SSL is available
mysql -u root -p -e "SHOW VARIABLES LIKE 'have_ssl';"
# Should show: YES

# If shows: DISABLED
# Check certificate paths in my.cnf
```

**Fix:**
```bash
# Verify paths in /etc/my.cnf.d/server.cnf
[mysqld]
ssl-ca=/etc/mysql/certs/ca.crt
ssl-cert=/etc/mysql/certs/server.crt
ssl-key=/etc/mysql/certs/server.key

# Restart
sudo systemctl restart mariadb
```

### Issue 3: Client Certificate Rejected

**Symptom:** Connection fails with client cert

**PostgreSQL Fix:**
```bash
# Check pg_hba.conf
cat /var/lib/pgsql/data/pg_hba.conf | grep hostssl

# Ensure client CA is installed
sudo cp client-ca.crt /var/lib/pgsql/data/root.crt

# Reload
sudo systemctl reload postgresql
```

**MySQL Fix:**
```bash
# Verify user requires X.509
mysql -u root -p -e "SELECT user, host, ssl_type FROM mysql.user WHERE user='alice';"
# Should show: X509

# Verify CA file configured
mysql -u root -p -e "SHOW VARIABLES LIKE 'ssl_ca';"
```

---

## 18.7 Version-Specific Considerations

### PostgreSQL Versions on RHEL

| RHEL Version | PostgreSQL | SSL Support | Notes |
|--------------|------------|-------------|-------|
| RHEL 7 | 9.2 | ✅ Yes | Manual TLS version config |
| RHEL 8 | 10.x+ | ✅ Yes | System crypto-policy |
| RHEL 9 | 13.x+ | ✅ Yes | Enhanced, crypto-policy |
| RHEL 10 | 15.x+ | ✅ Yes | Latest, crypto-policy |

### MySQL/MariaDB Versions on RHEL

| RHEL Version | Database | SSL Support | Notes |
|--------------|----------|-------------|-------|
| RHEL 7 | MariaDB 5.5 | ✅ Yes | Manual config |
| RHEL 8 | MariaDB 10.3+ | ✅ Yes | Crypto-policy aware |
| RHEL 9 | MariaDB 10.5+ | ✅ Yes | Modern TLS |
| RHEL 10 | MariaDB 10.11+ | ✅ Yes | Latest features |

---

## 18.8 Performance Considerations

### PostgreSQL SSL Performance

```ini
#============================================#
# POSTGRESQL SSL PERFORMANCE TUNING
#============================================#

# /var/lib/pgsql/data/postgresql.conf

# SSL enabled
ssl = on

# SSL compression (disabled for security, CRIME attack)
ssl_compression = off

# SSL ciphers (RHEL 7 - manual)
# ssl_ciphers = 'HIGH:!aNULL:!MD5'

# RHEL 8/9/10: crypto-policy handles ciphers

# Connection pooling helps (use pgBouncer)
# SSL termination at proxy can improve performance
```

### MySQL SSL Performance

```ini
#============================================#
# MYSQL SSL PERFORMANCE
#============================================#

# [mysqld] in /etc/my.cnf.d/server.cnf

# SSL enabled
ssl-ca=/etc/mysql/certs/ca.crt
ssl-cert=/etc/mysql/certs/server.crt
ssl-key=/etc/mysql/certs/server.key

# Disable weak ciphers (RHEL 7)
# tls_version=TLSv1.2,TLSv1.3
# ssl_cipher='ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256'

# RHEL 8/9/10: crypto-policy handles it

# Connection pooling (use ProxySQL or similar)
```

---

## 18.9 Monitoring Database TLS

### PostgreSQL Monitoring

```bash
#============================================#
# MONITOR POSTGRESQL SSL
#============================================#

# Check SSL connections
sudo -u postgres psql -c "SELECT datname, usename, ssl, version FROM pg_stat_ssl JOIN pg_stat_activity ON pg_stat_ssl.pid = pg_stat_activity.pid;"

# Count SSL vs non-SSL
sudo -u postgres psql -c "SELECT ssl, COUNT(*) FROM pg_stat_ssl GROUP BY ssl;"

# Check certificate expiration
openssl x509 -in /var/lib/pgsql/data/server.crt -noout -checkend $((86400*30))

# Monitor connections
sudo -u postgres psql -c "SELECT COUNT(*) FROM pg_stat_activity WHERE ssl = true;"
```

### MySQL Monitoring

```bash
#============================================#
# MONITOR MYSQL SSL
#============================================#

# Check SSL status
mysql -u root -p -e "SHOW STATUS LIKE 'Ssl%';"

# Count SSL connections
mysql -u root -p -e "SHOW STATUS LIKE 'Ssl_accepts';"

# Current SSL connections
mysql -u root -p -e "SELECT user, host, connection_type FROM information_schema.processlist WHERE connection_type = 'SSL/TLS';"

# Certificate expiration
openssl x509 -in /etc/mysql/certs/server.crt -noout -checkend $((86400*30))
```

---

## 18.10 Complete Setup Scripts

### PostgreSQL SSL Setup Script

```bash
#!/bin/bash
# setup-postgresql-ssl.sh

echo "=== PostgreSQL SSL Setup ==="

# Generate self-signed cert (replace with proper CA cert!)
sudo -u postgres openssl req -new -x509 -days 365 -nodes \
  -out /var/lib/pgsql/data/server.crt \
  -keyout /var/lib/pgsql/data/server.key \
  -subj "/CN=$(hostname -f)"

# Set permissions
sudo chmod 600 /var/lib/pgsql/data/server.{crt,key}
sudo chown postgres:postgres /var/lib/pgsql/data/server.{crt,key}

# Enable SSL in postgresql.conf
sudo -u postgres psql -c "ALTER SYSTEM SET ssl = on;"

# Restart
sudo systemctl restart postgresql

# Test
sudo -u postgres psql -c "SHOW ssl;"

echo "✅ PostgreSQL SSL enabled"
echo "⚠️ Replace self-signed cert with proper certificate from CA"
```

---

## 18.11 Key Takeaways

1. **Both PostgreSQL and MySQL support SSL/TLS**
2. **File ownership critical** - postgres:postgres or mysql:mysql
3. **Permissions:** 600 for keys, 644 for certs
4. **pg_hba.conf controls** PostgreSQL access (hostssl)
5. **sslmode important** for PostgreSQL clients
6. **Client certificates enable** strong authentication
7. **Test thoroughly** before enforcing TLS
8. **Monitor SSL usage** - Ensure clients actually use it

---

## Quick Reference Card

```
┌──────────────────────────────────────────────────────────────┐
│ DATABASE TLS QUICK REFERENCE                                 │
├──────────────────────────────────────────────────────────────┤
│ === POSTGRESQL ===                                           │
│ Config:       /var/lib/pgsql/data/postgresql.conf            │
│ Access:       /var/lib/pgsql/data/pg_hba.conf                │
│ Certs:        /var/lib/pgsql/data/server.{crt,key}           │
│ Owner:        postgres:postgres                              │
│ Enable:       ssl = on                                       │
│ Test:         psql "sslmode=require"                         │
│                                                              │
│ === MYSQL/MARIADB ===                                        │
│ Config:       /etc/my.cnf.d/server.cnf                       │
│ Certs:        /etc/mysql/certs/server.{crt,key}              │
│ Owner:        mysql:mysql                                    │
│ Enable:       ssl-ca, ssl-cert, ssl-key in [mysqld]          │
│ Test:         mysql --ssl-mode=REQUIRED                      │
│                                                              │
│ Permissions:  chmod 600 *.key                                │
│               chmod 644 *.crt                                │
└──────────────────────────────────────────────────────────────┘

⚠️ File ownership and permissions are critical!
✅ Use hostssl in pg_hba.conf to require SSL
```

---

## 🧪 Hands-On Lab

**Lab 10: PostgreSQL TLS**

Configure TLS for PostgreSQL database connections

- 📁 **Location:** `labs/en_US/10-postgresql-tls/`
- ⏱️ **Time:** 25-30 minutes
- 🎯 **Level:** Intermediate

---

**Chapter Navigation**

| [← Previous: Chapter 17 - OpenLDAP & Directory Services](17-openldap-ldaps.md) | [Next: Chapter 19 - FreeIPA Certificate Services →](19-freeipa-services.md) |
|:---|---:|
