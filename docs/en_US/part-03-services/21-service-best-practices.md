# Chapter 21: Service Certificate Best Practices

> **Critical for Operations:** Learn the best practices that prevent 90% of certificate problems before they happen.

---

## 21.1 The Cost of Poor Certificate Management

**Real-world impacts:**
- ❌ Expired certificate → Website down (revenue loss)
- ❌ Wrong permissions → Service fails to start (downtime)
- ❌ No backup → CA failure means manual reissue (hours/days)
- ❌ Poor naming → Confusion during incident (delayed response)
- ❌ No monitoring → Surprise expiration (emergency response)

**This chapter prevents these issues.**

---

## 21.2 File Organization Best Practices

### Standard Directory Structure

```bash
/etc/pki/tls/
├── certs/                      # Certificate files (public)
│   ├── service-name.crt        # Actual certificates
│   ├── service-name-chain.crt  # With intermediate chain
│   └── ca-bundle.crt           # CA bundle
│
├── private/                    # Private keys (protected!)
│   └── service-name.key        # Private keys (mode 600)
│
├── csr/                        # Certificate requests (optional)
│   └── service-name.csr        # CSRs for tracking
│
└── backup/                     # Backups (optional but recommended)
    └── YYYY-MM-DD/
        ├── service-name.crt
        └── service-name.key
```

### Naming Conventions

**Good naming prevents confusion:**

```bash
# ✅ GOOD - Clear, descriptive
/etc/pki/tls/certs/web01-example-com.crt
/etc/pki/tls/certs/mail-smtp-example-com.crt
/etc/pki/tls/certs/ldap-primary-example-com.crt

# ❌ BAD - Unclear, generic
/etc/pki/tls/certs/cert1.crt
/etc/pki/tls/certs/new.crt
/etc/pki/tls/certs/temp.crt
```

**Naming pattern:**
```
[service]-[hostname/function]-[domain].crt
[service]-[hostname/function]-[domain].key

Examples:
apache-web01-example-com.crt
nginx-www-example-com.crt
postfix-mail-example-com.crt
ldap-dir01-example-com.crt
postgresql-db-primary-example-com.crt
```

### File Permission Standards

```bash
#============================================#
# CRITICAL: Proper Permissions
#============================================#

# Certificates (public) - readable by all
/etc/pki/tls/certs/*.crt           → 644 (rw-r--r--)
/etc/pki/tls/certs/                → 755 (rwxr-xr-x)

# Private keys (secret!) - only readable by owner
/etc/pki/tls/private/*.key         → 600 (rw-------)
/etc/pki/tls/private/              → 711 (rwx--x--x)

# Service-specific keys - owned by service user
/etc/pki/tls/private/apache.key    → 600, owner: root or apache
/etc/pki/tls/private/postgres.key  → 600, owner: postgres
```

**Set permissions script:**
```bash
#!/bin/bash
# set-cert-permissions.sh
# Sets proper permissions on certificate files

CERT_DIR="/etc/pki/tls/certs"
KEY_DIR="/etc/pki/tls/private"

# Certificate directory
chmod 755 "$CERT_DIR"
chmod 644 "$CERT_DIR"/*.crt 2>/dev/null

# Private key directory
chmod 711 "$KEY_DIR"
chmod 600 "$KEY_DIR"/*.key 2>/dev/null

# Verify
echo "Certificate permissions:"
ls -ld "$CERT_DIR" "$CERT_DIR"/*.crt 2>/dev/null

echo ""
echo "Private key permissions:"
ls -ld "$KEY_DIR" "$KEY_DIR"/*.key 2>/dev/null

# Check for overly permissive keys
echo ""
echo "Checking for security issues:"
find "$KEY_DIR" -type f -not -perm 600 -ls 2>/dev/null && \
  echo "⚠️ WARNING: Some keys have incorrect permissions!" || \
  echo "✅ All keys properly protected"
```

---

## 21.3 Certificate Lifecycle Management

### Renewal Timeline

```
Certificate Lifecycle (365 day validity):

Day   0: Certificate issued
Day  30: First renewal reminder (335 days left)
Day  60: Second reminder (305 days left)
Day 300: Critical renewal window starts (65 days left)
Day 330: URGENT - Renewal needed (35 days left)
Day 350: CRITICAL - Renewal overdue (15 days left)
Day 365: EXPIRED - Service outage!

Recommended Actions:
- Days 300-330: Plan and execute renewal
- Days 330-350: Emergency renewal if missed
- Days 350+: Incident response, temporary cert
```

### Renewal Strategies

**Strategy 1: Automated (Recommended)**
```bash
# Using certmonger (RHEL)
sudo getcert request \
  -f /etc/pki/tls/certs/web01-example-com.crt \
  -k /etc/pki/tls/private/web01-example-com.key \
  -D web.example.com \
  -K host/web.example.com@REALM \
  -C "systemctl reload httpd"  # Auto-reload service

# Auto-renewal happens at 2/3 of cert lifetime
# 365 day cert → renews at day 243 (122 days remaining)
```

**Strategy 2: Scheduled Manual Renewal**
```bash
# Cron job for manual renewal check
# /etc/cron.weekly/check-certificates

#!/bin/bash
# Check certificates expiring in 60 days
find /etc/pki/tls/certs/ -name "*.crt" | while read cert; do
  if openssl x509 -in "$cert" -noout -checkend $((86400*60)); then
    echo "✅ $cert: OK"
  else
    echo "⚠️ $cert: Expires within 60 days!"
    # Send alert
    mail -s "Certificate Expiring Soon: $cert" admin@example.com
  fi
done
```

**Strategy 3: Calendar Reminders**
```bash
# For environments without automation
# Create calendar entries:
# - 90 days before expiration: Start renewal
# - 60 days before: Verify renewal in progress
# - 30 days before: Complete renewal
# - 7 days before: Emergency if not done
```

---

## 21.4 Certificate Metadata Tracking

### Certificate Inventory

Maintain a certificate inventory (spreadsheet or database):

```csv
Service,Hostname,Certificate_Path,Key_Path,Issuer,Issue_Date,Expiry_Date,SANs,Owner,Notes
Apache,web01,/etc/pki/tls/certs/web01-example-com.crt,/etc/pki/tls/private/web01.key,Internal CA,2024-01-01,2025-01-01,"web01.example.com,www.example.com",John Doe,Production
NGINX,web02,/etc/pki/tls/certs/web02-example-com.crt,/etc/pki/tls/private/web02.key,Let's Encrypt,2024-06-15,2024-09-15,"web02.example.com",Jane Smith,Staging
```

**Generate inventory script:**
```bash
#!/bin/bash
# generate-cert-inventory.sh
# Creates certificate inventory from system

echo "Service,Hostname,Certificate_Path,Issuer,Issue_Date,Expiry_Date,Days_Remaining"

# Scan common certificate locations
for cert in /etc/pki/tls/certs/*.crt /etc/httpd/conf/ssl/*.crt /etc/nginx/ssl/*.crt; do
  [ -f "$cert" ] || continue

  subject=$(openssl x509 -in "$cert" -noout -subject 2>/dev/null | sed 's/subject=//')
  issuer=$(openssl x509 -in "$cert" -noout -issuer 2>/dev/null | sed 's/issuer=//')
  notbefore=$(openssl x509 -in "$cert" -noout -startdate 2>/dev/null | cut -d= -f2)
  notafter=$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | cut -d= -f2)

  # Calculate days remaining
  expiry_epoch=$(date -d "$notafter" +%s 2>/dev/null)
  now_epoch=$(date +%s)
  days_remaining=$(( ($expiry_epoch - $now_epoch) / 86400 ))

  # Determine service from path
  service="Unknown"
  [[ "$cert" =~ httpd ]] && service="Apache"
  [[ "$cert" =~ nginx ]] && service="NGINX"

  echo "$service,$(hostname),$cert,\"$issuer\",$notbefore,$notafter,$days_remaining"
done
```

---

## 21.5 Backup and Recovery

### What to Backup

```bash
Critical files to backup:
✅ Private keys (.key files)
✅ Certificates (.crt files)
✅ CA certificates
✅ Certificate chains
✅ CSRs (for reference)
✅ Configuration files (Apache ssl.conf, etc.)
⚠️ NOT passwords or passphrases (store separately in vault)
```

### Backup Script

```bash
#!/bin/bash
# backup-certificates.sh
# Backs up all certificates and keys

BACKUP_DIR="/var/backups/certificates"
DATE=$(date +%Y-%m-%d)
BACKUP_PATH="$BACKUP_DIR/$DATE"

# Create backup directory
mkdir -p "$BACKUP_PATH"

# Backup certificates
echo "Backing up certificates..."
cp -a /etc/pki/tls/certs/*.crt "$BACKUP_PATH/" 2>/dev/null

# Backup private keys (encrypted!)
echo "Backing up private keys..."
tar czf - /etc/pki/tls/private/*.key 2>/dev/null | \
  openssl enc -aes-256-cbc -salt -out "$BACKUP_PATH/keys.tar.gz.enc" -pass pass:CHANGEME

# Backup configuration files
echo "Backing up configs..."
cp -a /etc/httpd/conf.d/ssl.conf "$BACKUP_PATH/" 2>/dev/null
cp -a /etc/nginx/nginx.conf "$BACKUP_PATH/" 2>/dev/null

# Create inventory
ls -lh "$BACKUP_PATH"

# Set permissions
chmod 700 "$BACKUP_PATH"

echo "✅ Backup complete: $BACKUP_PATH"
echo "⚠️ Remember to change encryption password!"
```

### Recovery Procedure

```bash
#============================================#
# CERTIFICATE RECOVERY PROCEDURE
#============================================#

# 1. Stop affected service
sudo systemctl stop httpd

# 2. Restore certificate
sudo cp /var/backups/certificates/2024-11-15/web.crt /etc/pki/tls/certs/

# 3. Restore private key (decrypt)
cd /var/backups/certificates/2024-11-15/
openssl enc -aes-256-cbc -d -in keys.tar.gz.enc -pass pass:CHANGEME | \
  sudo tar xzf - -C /

# 4. Set permissions
sudo chmod 600 /etc/pki/tls/private/*.key
sudo chmod 644 /etc/pki/tls/certs/*.crt

# 5. Verify files
sudo openssl x509 -in /etc/pki/tls/certs/web-example-com.crt -noout -text
sudo openssl rsa -in /etc/pki/tls/private/web-example-com.key -check

# 6. Start service
sudo systemctl start httpd

# 7. Test
curl -v https://localhost/
```

---

## 21.6 Security Best Practices

### Private Key Protection

```bash
#============================================#
# PRIVATE KEY SECURITY CHECKLIST
#============================================#

✅ Permissions: 600 (or 400 for extra protection)
✅ Ownership: root or service user only
✅ Location: /etc/pki/tls/private/ (mode 711)
✅ SELinux: Proper context (cert_t)
✅ Backup: Encrypted at rest
✅ Never: Email, paste in tickets, commit to git
✅ Never: Share between systems (generate new)
✅ Audit: Log access with auditd

# Verify security
ls -lZ /etc/pki/tls/private/*.key
# -rw------- root root unconfined_u:object_r:cert_t:s0 server.key
```

### Key Generation Best Practices

```bash
#============================================#
# GENERATE SECURE KEYS
#============================================#

# RSA 2048 (minimum for RHEL 8+)
openssl genpkey -algorithm RSA -out server.key -pkeyopt rsa_keygen_bits:2048

# RSA 4096 (recommended for long-lived certs)
openssl genpkey -algorithm RSA -out server.key -pkeyopt rsa_keygen_bits:4096

# EC P-256 (modern, smaller, fast)
openssl genpkey -algorithm EC -out server.key -pkeyopt ec_paramgen_curve:P-256

# Immediately set permissions!
chmod 600 server.key

# ❌ NEVER do this:
# openssl genrsa -out server.key 1024   # Too weak!
# chmod 644 server.key                  # Too permissive!
```

### Certificate Validation Before Deployment

```bash
#!/bin/bash
# validate-certificate.sh
# Validates certificate before deployment

CERT=$1
KEY=$2

echo "=== Pre-Deployment Certificate Validation ==="

# Check 1: Certificate file exists and readable
if [ ! -f "$CERT" ]; then
  echo "❌ Certificate file not found: $CERT"
  exit 1
fi

# Check 2: Private key exists and readable
if [ ! -f "$KEY" ]; then
  echo "❌ Private key not found: $KEY"
  exit 1
fi

# Check 3: Certificate is valid X.509
if ! openssl x509 -in "$CERT" -noout 2>/dev/null; then
  echo "❌ Invalid X.509 certificate"
  exit 1
fi

# Check 4: Certificate not expired
if ! openssl x509 -in "$CERT" -noout -checkend 0; then
  echo "❌ Certificate is expired!"
  exit 1
fi

# Check 5: Certificate/key pair match
CERT_MOD=$(openssl x509 -noout -modulus -in "$CERT" | openssl md5)
KEY_MOD=$(openssl rsa -noout -modulus -in "$KEY" 2>/dev/null | openssl md5)

if [ "$CERT_MOD" != "$KEY_MOD" ]; then
  echo "❌ Certificate and key do not match!"
  exit 1
fi

# Check 6: SANs present (required for modern browsers)
if ! openssl x509 -in "$CERT" -noout -ext subjectAltName 2>/dev/null | grep -q "DNS:"; then
  echo "⚠️ WARNING: No Subject Alternative Names found"
fi

# Check 7: Strong signature algorithm
SIG_ALG=$(openssl x509 -in "$CERT" -noout -text | grep "Signature Algorithm" | head -2)
if echo "$SIG_ALG" | grep -qi "sha1\|md5"; then
  echo "❌ Weak signature algorithm: $SIG_ALG"
  exit 1
fi

# Check 8: Adequate key size
KEY_SIZE=$(openssl x509 -in "$CERT" -noout -text | grep "Public-Key:" | grep -oP '\d+')
if [ "$KEY_SIZE" -lt 2048 ]; then
  echo "❌ Key size too small: $KEY_SIZE bits (minimum 2048)"
  exit 1
fi

echo ""
echo "✅ Certificate validation passed!"
echo "   Subject: $(openssl x509 -in "$CERT" -noout -subject)"
echo "   Issuer: $(openssl x509 -in "$CERT" -noout -issuer)"
echo "   Expires: $(openssl x509 -in "$CERT" -noout -enddate | cut -d= -f2)"
echo "   Key Size: $KEY_SIZE bits"
```

---

## 21.7 Multi-Service Coordination

### When Multiple Services Share Certificates

```bash
# Scenario: Load balancer + multiple web servers

# Problem: Certificate on LB, services behind need same CN/SANs

# Solution 1: Use same certificate on all (if hostnames match)
# web01, web02, web03 all use cert for: web.example.com

# Solution 2: Wildcard certificate
# *.example.com works for web01.example.com, web02.example.com, etc.

# Solution 3: Comprehensive SANs
# Single cert with SANs: web.example.com, web01.example.com, web02.example.com
```

### Certificate Deployment Workflow

```bash
#============================================#
# MULTI-SERVER DEPLOYMENT
#============================================#

# Step 1: Generate certificate on management node
openssl genpkey -algorithm RSA -out web.key -pkeyopt rsa_keygen_bits:2048
openssl req -new -key web.key -out web.csr \
  -subj "/CN=web.example.com" \
  -addext "subjectAltName=DNS:web.example.com,DNS:web01.example.com,DNS:web02.example.com"

# Step 2: Get certificate from CA
# (submit web.csr to CA, receive web.crt)

# Step 3: Validate locally
./validate-certificate.sh web.crt web.key

# Step 4: Distribute securely
for host in web01 web02 web03; do
  scp web.crt root@$host:/etc/pki/tls/certs/
  scp web.key root@$host:/etc/pki/tls/private/
  ssh root@$host "chmod 644 /etc/pki/tls/certs/web-example-com.crt"
  ssh root@$host "chmod 600 /etc/pki/tls/private/web-example-com.key"
done

# Step 5: Reload services
for host in web01 web02 web03; do
  ssh root@$host "systemctl reload httpd"
done

# Step 6: Test each server
for host in web01 web02 web03; do
  echo "Testing $host..."
  curl -vk https://$host/ 2>&1 | grep "subject:"
done
```

---

## 21.8 Documentation Standards

### Certificate Documentation Template

```markdown
## Certificate: web.example.com

### Basic Information
- **Service:** Apache (httpd)
- **Server:** web01.example.com
- **Certificate Path:** `/etc/pki/tls/certs/web-example-com.crt`
- **Key Path:** `/etc/pki/tls/private/web-example-com.key`
- **Owner:** Web Team (webadmin@example.com)

### Certificate Details
- **Common Name (CN):** web.example.com
- **SANs:** web.example.com, www.example.com
- **Issuer:** Internal CA (ca.example.com)
- **Issue Date:** 2024-01-01
- **Expiry Date:** 2025-01-01
- **Key Type:** RSA 2048

### Renewal Process
- **Method:** certmonger automatic
- **Renewal Window:** 65 days before expiry
- **Post-Renewal:** `systemctl reload httpd`
- **Contact:** webadmin@example.com

### Service Configuration
- **Config File:** `/etc/httpd/conf.d/ssl.conf`
- **Service:** `httpd.service`
- **Restart Command:** `systemctl reload httpd`

### Troubleshooting
- **Logs:** `/var/log/httpd/ssl_error_log`
- **Test Command:** `curl -v https://web.example.com/`
- **Common Issues:** None reported

### Change History
- 2024-01-01: Initial deployment
- 2024-06-15: Added www.example.com SAN
```

---

## 21.9 Monitoring and Alerting

### What to Monitor

```bash
✅ Certificate expiration (60, 30, 7 days before)
✅ Certificate validity (not expired, not yet valid)
✅ Certificate/key pair match
✅ Certificate trust chain
✅ Service health (is it using the cert?)
✅ certmonger tracking status
✅ Renewal success/failure
```

### Simple Monitoring Script

```bash
#!/bin/bash
# monitor-certificates.sh
# Simple certificate monitoring

WARN_DAYS=30
CRIT_DAYS=7
EMAIL="admin@example.com"

check_cert() {
  local cert=$1
  local name=$(basename "$cert")

  # Check if expires within warning period
  if ! openssl x509 -in "$cert" -noout -checkend $((86400*WARN_DAYS)); then
    if ! openssl x509 -in "$cert" -noout -checkend $((86400*CRIT_DAYS)); then
      echo "🚨 CRITICAL: $name expires within $CRIT_DAYS days!"
      return 2
    else
      echo "⚠️ WARNING: $name expires within $WARN_DAYS days"
      return 1
    fi
  fi

  return 0
}

# Check all certificates
WARNINGS=0
CRITICALS=0

for cert in /etc/pki/tls/certs/*.crt; do
  [ -f "$cert" ] || continue
  check_cert "$cert"
  ret=$?
  [ $ret -eq 1 ] && ((WARNINGS++))
  [ $ret -eq 2 ] && ((CRITICALS++))
done

# Alert if issues found
if [ $CRITICALS -gt 0 ] || [ $WARNINGS -gt 0 ]; then
  echo "Certificate issues found: $CRITICALS critical, $WARNINGS warnings" | \
    mail -s "Certificate Alert: $(hostname)" "$EMAIL"
fi
```

---

## 21.10 Incident Response Procedures

### Certificate Expiration Incident

```bash
#============================================#
# EXPIRED CERTIFICATE EMERGENCY
#============================================#

# Step 1: Assess impact
systemctl status httpd
journalctl -xe | grep -i cert

# Step 2: Quick fix - Get temporary cert
# Option A: Self-signed (for internal only!)
openssl req -x509 -nodes -days 30 -newkey rsa:2048 \
  -keyout /etc/pki/tls/private/temp-web01-example-com.key \
  -out /etc/pki/tls/certs/temp-web01-example-com.crt \
  -subj "/CN=$(hostname)"

# Option B: Restore from backup
cp /var/backups/certificates/latest/*.crt /etc/pki/tls/certs/
cp /var/backups/certificates/latest/*.key /etc/pki/tls/private/

# Step 3: Update service config to use temp cert
# Edit /etc/httpd/conf.d/ssl.conf
# SSLCertificateFile /etc/pki/tls/certs/temp-web01-example-com.crt
# SSLCertificateKeyFile /etc/pki/tls/private/temp-web01-example-com.key

# Step 4: Restart service
systemctl restart httpd

# Step 5: Get proper certificate ASAP
# Follow normal cert request process

# Step 6: Document incident
# What happened, why, how fixed, prevention
```

---

## 21.11 Best Practices Checklist

```markdown
## Certificate Management Checklist

### File Organization
- [ ] Standard directory structure used
- [ ] Consistent naming convention
- [ ] Proper file permissions (600 for keys, 644 for certs)
- [ ] SELinux contexts correct

### Lifecycle Management
- [ ] Renewal process defined and documented
- [ ] Renewal reminders set (60, 30, 7 days)
- [ ] Automated renewal if possible (certmonger)
- [ ] Post-renewal actions defined

### Security
- [ ] Private keys protected (600 permissions)
- [ ] Keys never shared/emailed
- [ ] Strong key algorithm (RSA 2048+ or EC P-256)
- [ ] Strong signature (SHA-256+)

### Backup
- [ ] Certificates backed up
- [ ] Private keys backed up (encrypted)
- [ ] Backup tested and validated
- [ ] Restore procedure documented

### Documentation
- [ ] Certificate inventory maintained
- [ ] Each certificate documented
- [ ] Procedures written
- [ ] Contacts listed

### Monitoring
- [ ] Expiration monitoring enabled
- [ ] Alerts configured
- [ ] Health checks in place
- [ ] Incident response plan ready

### Validation
- [ ] Pre-deployment validation
- [ ] Post-deployment testing
- [ ] Regular audits scheduled
```

---

## 21.12 Key Takeaways

1. **Organization prevents confusion** - Consistent structure and naming
2. **Permissions are critical** - 600 for keys, 644 for certs
3. **Automate renewal** - Use certmonger whenever possible
4. **Backup everything** - But encrypt private keys
5. **Document thoroughly** - Your future self will thank you
6. **Monitor proactively** - Don't wait for expiration
7. **Validate before deploy** - Catch issues early
8. **Plan for incidents** - Have recovery procedures ready

---

## Quick Reference

```
┌─────────────────────────────────────────────────────────────┐
│ SERVICE CERTIFICATE BEST PRACTICES                          │
├─────────────────────────────────────────────────────────────┤
│ Files:     /etc/pki/tls/certs/*.crt (644)                   │
│            /etc/pki/tls/private/*.key (600)                 │
│ Naming:    [service]-[host]-[domain].[crt|key]              │
│ Renewal:   Automate with certmonger                         │
│ Backup:    Daily, encrypted, tested                         │
│ Monitor:   60, 30, 7 days before expiry                     │
│ Validate:  Before every deployment                          │
│ Document:  Everything, everyone                             │
└─────────────────────────────────────────────────────────────┘
```
---

**Chapter Navigation**

| [← Previous: Chapter 20 - Other RHEL Services with Certificates](20-other-rhel-services.md) | [Next: Chapter 22 - certmonger Mastery →](../part-04-automation/22-certmonger-mastery.md) |
|:---|---:|
