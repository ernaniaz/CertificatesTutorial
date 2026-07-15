# Lab 10: PostgreSQL TLS Configuration

## Learning Objectives

By completing this lab, you will:
- Install and configure PostgreSQL database
- Enable SSL/TLS in PostgreSQL
- Understand where client certificate authentication would be added manually
- Test secure database connections
- Understand pg_hba.conf SSL configuration
- Query SSL connection status

## Prerequisites

- **Labs 01-05** completed
- **RHEL Version:** 7, 8, 9, or 10
- **System Access:** Root/sudo required
- **Port:** 5432 (PostgreSQL)

## Time Estimate

**30-40 minutes**

## Lab Overview

PostgreSQL is a powerful open-source relational database. This lab configures server-side TLS for encrypted client-server communication. Client certificate authentication is optional follow-on material and is not configured by the shipped `configure-tls.sh`.

---

## Instructions

### Step 1: Install PostgreSQL

Install PostgreSQL database server:

```bash
sudo ./install-postgresql.sh
```

This installs:
- `postgresql-server` (database server)
- `postgresql` (client tools)
- Initializes database cluster

---

### Step 2: Configure TLS

Configure PostgreSQL with TLS certificates:

```bash
sudo ./configure-tls.sh
```

This:
- Copies certificates from Lab 04
- Enables SSL in postgresql.conf
- Configures `hostssl` access rules for local TLS connections
- Sets certificate permissions
- Restarts PostgreSQL

---

### Step 3: Test Connection

Test secure database connections:

```bash
./test-connection.sh
```

This tests:
- Basic database connection
- SSL/TLS enabled connection
- SSL connection verification
- SSL connection status and cipher details

---

### Step 4: Verify SSL Status

Verify SSL configuration:

```bash
sudo ./verify.sh
```

---

## Validation

```bash
sudo ./test.sh
```

All checks should pass.

## Expected Outcome

After completing this lab:
- ✅ PostgreSQL installed and running
- ✅ SSL/TLS enabled
- ✅ Secure connections working
- ✅ SSL status queryable
- ✅ Understanding of PostgreSQL TLS

---

## Key Concepts

### PostgreSQL Configuration Files

```
/var/lib/pgsql/data/
├── postgresql.conf       # Main configuration
├── pg_hba.conf          # Client authentication
├── server.crt           # Server certificate
├── server.key           # Server private key
└── root.crt             # Optional manual CA trust file
```

### SSL Configuration in postgresql.conf

```conf
# Enable SSL
ssl = on

# Certificate files (relative to data directory)
ssl_cert_file = 'server.crt'
ssl_key_file = 'server.key'

# SSL ciphers
ssl_ciphers = 'HIGH:MEDIUM:+3DES:!aNULL'
ssl_prefer_server_ciphers = on

# Minimum TLS version (PostgreSQL 12+ only)
ssl_min_protocol_version = 'TLSv1.2'
```

### pg_hba.conf SSL Rules

```conf
# TYPE  DATABASE  USER  ADDRESS      METHOD

# Added by configure-tls.sh
hostssl    all    all    127.0.0.1/32    md5
hostssl    all    all    ::1/128         md5
```

The shipped lab does not add `ssl_ca_file` or `cert`-based client authentication rules. If you want to explore client certificates, add CA material and stricter `pg_hba.conf` rules manually after completing the lab.

### Connection String with SSL

```bash
# Basic SSL connection used in this lab
psql "host=localhost sslmode=require user=postgres"

# Query the current session's SSL details
sudo -u postgres psql -c "SELECT * FROM pg_stat_ssl WHERE pid = pg_backend_pid();"
```

### SSL Modes

| Mode | Encryption | Certificate Validation |
|------|------------|------------------------|
| disable | No | No |
| allow | Maybe | No |
| prefer | Maybe | No |
| require | Yes | No |
| verify-ca | Yes | CA only |
| verify-full | Yes | CA + hostname |

---

## Troubleshooting

### Issue: PostgreSQL Won't Start

**Symptom:**
```
Job for postgresql.service failed
```

**Solution:**
Check logs and configuration:
```bash
journalctl -xeu postgresql
# Check data directory permissions
ls -la /var/lib/pgsql/data/
# Check server.key permissions (should be 600)
```

---

### Issue: SSL Not Enabled

**Symptom:**
```
SSL connection (protocol: unknown, cipher: unknown, bits: unknown)
```

**Solution:**
Verify SSL is enabled:
```bash
sudo -u postgres psql -c "SHOW ssl;"
# Should return 'on'

# Check postgresql.conf
grep "^ssl" /var/lib/pgsql/data/postgresql.conf
```

---

### Issue: Certificate Permission Errors

**Symptom:**
```
FATAL: could not load server certificate file
```

**Solution:**
Fix certificate permissions:
```bash
cd /var/lib/pgsql/data/
chmod 600 server.key
chmod 644 server.crt
chown postgres:postgres server.key server.crt
```

---

### Issue: Connection Refused

**Symptom:**
```
psql: could not connect to server
```

**Solution:**
Check PostgreSQL is listening:
```bash
ss -tlnp | grep 5432
# Edit postgresql.conf
listen_addresses = 'localhost'  # or '*' for all interfaces
# Restart: systemctl restart postgresql
```

---

## Version-Specific Notes

### RHEL 7
- Uses `yum` for installation
- PostgreSQL 9.2.x typically — `ssl_min_protocol_version` not available (requires PG 12+)
- Data directory: `/var/lib/pgsql/data/`
- Service: `postgresql.service`

### RHEL 8
- Uses `dnf` for installation
- PostgreSQL 10.x or 12.x (AppStream modules)
- `ssl_min_protocol_version` only available if PG 12+ module is enabled
- Data directory: `/var/lib/pgsql/data/`

### RHEL 9
- PostgreSQL 13.x typically
- Enhanced security defaults
- Better TLS protocol support
- SHA-1 blocked by default

---

## Cleanup

```bash
sudo ./cleanup.sh
```

This removes PostgreSQL and restores system state.

---

## Additional Resources

**Related Chapters:**
- Chapter 18: Database TLS Configuration

**Documentation:**
- `man postgres`
- `man psql`
- `man pg_hba.conf`
- https://www.postgresql.org/docs/current/ssl-tcp.html

**Useful Queries:**
```sql
-- Check SSL status
SHOW ssl;

-- View current connections with SSL info
SELECT datname, usename, ssl, client_addr, backend_type
FROM pg_stat_ssl
JOIN pg_stat_activity USING (pid);

-- Get SSL cipher information
SELECT * FROM pg_stat_ssl WHERE pid = pg_backend_pid();
```

---

## Next Steps

Proceed to **Lab 11: certmonger Basics** to learn automatic certificate management.

---

**Difficulty Level:** Intermediate
