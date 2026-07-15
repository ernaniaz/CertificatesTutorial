# Chapter 9: RHEL 7 Certificate Management

> **Legacy but Important:** RHEL 7 reached end of maintenance in June 2024, but many enterprises still run it. Learn how certificate management works on RHEL 7.

---

## 9.1 RHEL 7 Overview

**Release:** June 10, 2014
**Maintenance Support Ended:** June 30, 2024
**Extended Life Cycle Support:** Available through 2028

**Key Characteristics:**
- **OpenSSL Version:** 1.0.2k-26 (package: `openssl-1.0.2k-26.el7_9.x86_64`)
- **Default TLS:** TLS 1.0, 1.1, 1.2 all enabled
- **Trust Store:** `/etc/pki/ca-trust/extracted/`
- **Management Approach:** Primarily manual
- **Crypto-Policies:** Not available (RHEL 8+ feature)

> **Note:** If you're still on RHEL 7, plan migration to RHEL 8 or 9. Security updates are limited.

---

## 9.2 OpenSSL 1.0.2k Specifics

### Version Check

```bash
# Check OpenSSL version on RHEL 7
openssl version
# OpenSSL 1.0.2k-fips  12 Jan 2017

# Check package
rpm -q openssl
# openssl-1.0.2k-26.el7_9.x86_64
```

### Key Features and Limitations

**Features:**
- ✅ TLS 1.0, 1.1, 1.2 support
- ✅ Stable and well-tested
- ✅ Wide compatibility
- ✅ RSA, ECC, DSA key types

**Limitations:**
- ❌ No TLS 1.3 support
- ❌ Older command syntax (genrsa vs genpkey)
- ❌ Weaker default ciphers
- ❌ Limited modern cipher suites

### Command Syntax (RHEL 7 Style)

```bash
#============================================#
# GENERATE RSA KEY (RHEL 7)
#============================================#

# Old style (common on RHEL 7)
openssl genrsa -out server.key 2048

# With passphrase protection
openssl genrsa -aes256 -out server.key 2048

# Remove passphrase from key
openssl rsa -in server.key -out server-nopass.key


#============================================#
# GENERATE CSR (RHEL 7)
#============================================#

# Basic CSR
openssl req -new -key server.key -out server.csr

# With subject specified
openssl req -new -key server.key -out server.csr \
  -subj "/C=US/ST=State/L=City/O=Company/CN=server.example.com"

# ⚠️ Note: SANs are harder to add with RHEL 7 OpenSSL
# Need config file for SANs


#============================================#
# VIEW CERTIFICATE
#============================================#

# Full details
openssl x509 -in server.crt -noout -text

# Just expiration
openssl x509 -in server.crt -noout -dates

# Just subject
openssl x509 -in server.crt -noout -subject
```

---

## 9.3 Trust Store Management on RHEL 7

### Adding Custom CAs

```bash
#============================================#
# ADD CUSTOM CA (RHEL 7)
#============================================#

# Step 1: Copy CA certificate to anchors directory
sudo cp corporate-ca.crt /etc/pki/ca-trust/source/anchors/

# Step 2: Update trust store
sudo update-ca-trust extract

# Step 3: Verify
trust list | grep -i "corporate"

# Verify applications use it
openssl verify -CAfile /etc/pki/tls/certs/ca-bundle.crt test-cert.crt
```

### Trust Store Locations (RHEL 7)

```bash
/etc/pki/ca-trust/
├── source/
│   └── anchors/                   ← Add custom CAs here
│
└── extracted/
    ├── pem/
    │   └── tls-ca-bundle.pem      ← OpenSSL, Python, Ruby
    ├── openssl/
    │   └── ca-bundle.trust.crt    ← OpenSSL specific
    └── java/
        └── cacerts                ← Java applications
```

---

## 9.4 Service Configuration (RHEL 7 Approach)

### Apache HTTPS on RHEL 7

```bash
#============================================#
# APACHE SSL/TLS SETUP (RHEL 7)
#============================================#

# Install Apache with SSL
sudo yum install httpd mod_ssl -y

# Generate certificate and key
sudo openssl genrsa -out /etc/pki/tls/private/server.key 2048
sudo openssl req -new -key /etc/pki/tls/private/server.key \
  -out /tmp/server.csr \
  -subj "/CN=$(hostname -f)"

# Get certificate from CA (or self-signed for testing)
sudo openssl x509 -req -days 365 -in /tmp/server.csr \
  -signkey /etc/pki/tls/private/server.key \
  -out /etc/pki/tls/certs/server.crt

# Configure Apache (/etc/httpd/conf.d/ssl.conf)
sudo vi /etc/httpd/conf.d/ssl.conf
# Set:
#   SSLCertificateFile /etc/pki/tls/certs/server.crt
#   SSLCertificateKeyFile /etc/pki/tls/private/server.key
#
#   # Recommended: Disable weak TLS versions
#   SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
#
#   # Recommended: Strong ciphers only
#   SSLCipherSuite HIGH:!aNULL:!MD5:!3DES:!RC4

# Start Apache
sudo systemctl enable httpd
sudo systemctl start httpd

# Test
curl -vk https://localhost/
```

### NGINX on RHEL 7

```bash
#============================================#
# NGINX SSL/TLS SETUP (RHEL 7)
#============================================#

# Install NGINX (from EPEL)
sudo yum install epel-release -y
sudo yum install nginx -y

# Generate certificate
sudo openssl genrsa -out /etc/pki/tls/private/nginx.key 2048
sudo openssl req -new -x509 -days 365 \
  -key /etc/pki/tls/private/nginx.key \
  -out /etc/pki/tls/certs/nginx.crt \
  -subj "/CN=$(hostname -f)"

# Configure NGINX (/etc/nginx/nginx.conf)
# Add to server block:
#   listen 443 ssl;
#   ssl_certificate /etc/pki/tls/certs/nginx.crt;
#   ssl_certificate_key /etc/pki/tls/private/nginx.key;
#
#   # Recommended
#   ssl_protocols TLSv1.2;
#   ssl_ciphers HIGH:!aNULL:!MD5;

# Start NGINX
sudo systemctl enable nginx
sudo systemctl start nginx
```

---

## 9.5 Manual Certificate Renewal (RHEL 7)

**No crypto-policies, no automatic tools - everything is manual!**

### Renewal Process

```bash
#============================================#
# MANUAL RENEWAL PROCESS (RHEL 7)
#============================================#

# Step 1: Check expiration (set calendar reminder)
openssl x509 -in /etc/pki/tls/certs/server.crt -noout -dates

# Step 2: Generate new CSR (reuse existing key)
openssl req -new -key /etc/pki/tls/private/server.key \
  -out /tmp/server-renewal.csr \
  -subj "/CN=server.example.com"

# Step 3: Submit CSR to CA

# Step 4: Receive new certificate from CA

# Step 5: Backup old certificate
sudo cp /etc/pki/tls/certs/server.crt \
     /etc/pki/tls/certs/server.crt.$(date +%Y%m%d).old

# Step 6: Install new certificate
sudo cp new-server.crt /etc/pki/tls/certs/server.crt
sudo chmod 644 /etc/pki/tls/certs/server.crt

# Step 7: Reload service
sudo systemctl reload httpd

# Step 8: Test
curl -v https://localhost/
openssl s_client -connect localhost:443
```

### Tracking Certificate Renewals

```bash
#============================================#
# CREATE RENEWAL TRACKING (RHEL 7)
#============================================#

# Cron job to check expiration
cat > /etc/cron.weekly/check-cert-expiration << 'EOF'
#!/bin/bash
# Check certificates expiring in 60 days

for cert in /etc/pki/tls/certs/*.crt; do
  [ -f "$cert" ] || continue

  if ! openssl x509 -in "$cert" -noout -checkend $((86400*60)); then
    echo "⚠️ $cert expires within 60 days!"
    echo "$cert" | mail -s "Certificate Expiring Soon" admin@example.com
  fi
done
EOF

chmod +x /etc/cron.weekly/check-cert-expiration
```

---

## 9.6 Common RHEL 7 Certificate Issues

### Issue 1: TLS 1.0/1.1 Deprecated

**Problem:** Modern clients reject TLS 1.0/1.1

**Symptoms:**
```bash
curl: (35) error:14094410:SSL routines:ssl3_read_bytes:sslv3 alert handshake failure
```

**Fix:**
```bash
# Update Apache to disable old TLS versions
# /etc/httpd/conf.d/ssl.conf
SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1

# Restart Apache
sudo systemctl restart httpd
```

### Issue 2: Weak Ciphers

**Problem:** PCI/Security scans flag weak ciphers

**Fix:**
```bash
# Apache: Use strong ciphers only
# /etc/httpd/conf.d/ssl.conf
SSLCipherSuite HIGH:!aNULL:!MD5:!3DES:!RC4:!EXPORT
SSLHonorCipherOrder on

# Test
openssl s_client -connect localhost:443 -cipher '3DES'
# Should fail if 3DES is disabled
```

### Issue 3: Missing SANs

**Problem:** Modern browsers require Subject Alternative Names

**RHEL 7 Challenge:** SANs are harder to add with OpenSSL 1.0.2

**Solution: Use config file**
```bash
# Create OpenSSL config
cat > /tmp/san.cnf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]
CN = server.example.com

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = server.example.com
DNS.2 = www.example.com
IP.1 = 10.0.0.100
EOF

# Generate CSR with SANs
openssl req -new -key server.key -out server.csr -config /tmp/san.cnf

# Verify SANs in CSR
openssl req -in server.csr -noout -text | grep -A3 "Subject Alternative Name"
```

---

## 9.7 certmonger on RHEL 7

**Available:** Yes (basic version)

```bash
#============================================#
# CERTMONGER ON RHEL 7
#============================================#

# Install
sudo yum install certmonger -y
sudo systemctl enable certmonger
sudo systemctl start certmonger

# Request certificate from FreeIPA
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/web.crt \
  -k /etc/pki/tls/private/web.key \
  -K host/$(hostname -f)@REALM

# List tracked certificates
sudo getcert list

# Check specific certificate status
sudo getcert list -f /etc/pki/tls/certs/web.crt

# Monitor certmonger logs
sudo tail -f /var/log/messages | grep certmonger
```

**RHEL 7 Limitations:**
- No ACME support (Let's Encrypt requires manual certbot)
- Less detailed status output
- Fewer post-save command options

---

## 9.8 Migration Considerations

### When to Migrate from RHEL 7

**You should migrate if:**
- ✅ Support ended (June 2024) and you need updates
- ✅ Need TLS 1.3 support
- ✅ Want crypto-policies for easier management
- ✅ Require modern security features
- ✅ Compliance requires supported OS

### Pre-Migration Certificate Tasks

```bash
#============================================#
# RHEL 7 CERTIFICATE PRE-MIGRATION AUDIT
#============================================#

# 1. List all certificates
find /etc/pki/tls/ -name "*.crt" -o -name "*.key"

# 2. Check expirations
for cert in /etc/pki/tls/certs/*.crt; do
  echo "=== $cert ==="
  openssl x509 -in "$cert" -noout -subject -dates
  echo ""
done

# 3. Check signature algorithms (SHA-1 won't work on RHEL 8+)
for cert in /etc/pki/tls/certs/*.crt; do
  SIG=$(openssl x509 -in "$cert" -noout -text | grep "Signature Algorithm" | head -2)
  echo "$cert: $SIG"
done | grep -i sha1
# If any found, reissue before migration!

# 4. Document custom CAs
ls -l /etc/pki/ca-trust/source/anchors/

# 5. Export certificates and keys
tar czf rhel7-certificates-backup-$(date +%Y%m%d).tar.gz \
  /etc/pki/tls/certs/*.crt \
  /etc/pki/tls/private/*.key \
  /etc/pki/ca-trust/source/anchors/*
```

---

## 9.9 Common RHEL 7 Workflows

### Workflow 1: Manual Apache HTTPS Setup

```bash
# Complete workflow from scratch

# 1. Install Apache with SSL
sudo yum install httpd mod_ssl -y

# 2. Generate private key
sudo openssl genrsa -out /etc/pki/tls/private/$(hostname -s).key 2048

# 3. Set key permissions
sudo chmod 600 /etc/pki/tls/private/$(hostname -s).key

# 4. Create CSR
sudo openssl req -new \
  -key /etc/pki/tls/private/$(hostname -s).key \
  -out /tmp/$(hostname -s).csr \
  -subj "/C=US/O=Company/CN=$(hostname -f)"

# 5. Submit CSR to CA, wait for certificate

# 6. Install certificate
sudo cp $(hostname -s).crt /etc/pki/tls/certs/

# 7. Configure Apache
sudo vi /etc/httpd/conf.d/ssl.conf
# Edit:
#   SSLCertificateFile /etc/pki/tls/certs/$(hostname -s).crt
#   SSLCertificateKeyFile /etc/pki/tls/private/$(hostname -s).key
#   SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
#   SSLCipherSuite HIGH:!aNULL:!MD5:!3DES

# 8. Test configuration
sudo apachectl configtest

# 9. Open firewall
sudo firewall-cmd --add-service=https --permanent
sudo firewall-cmd --reload

# 10. Start Apache
sudo systemctl enable httpd
sudo systemctl start httpd

# 11. Test
curl -vk https://$(hostname -f)/
```

### Workflow 2: FreeIPA Integration

```bash
#============================================#
# FREEIPA CERTIFICATE WORKFLOW (RHEL 7)
#============================================#

# Prerequisites: System must be IPA-enrolled
ipa-client-install

# Install certmonger
sudo yum install certmonger -y
sudo systemctl enable certmonger
sudo systemctl start certmonger

# Request certificate for Apache
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/$(hostname -s).crt \
  -k /etc/pki/tls/private/$(hostname -s).key \
  -K host/$(hostname -f)@REALM.EXAMPLE.COM \
  -D $(hostname -f)

# Check status
sudo getcert list

# Wait for MONITORING status (certificate issued)

# Configure Apache to use cert
# /etc/httpd/conf.d/ssl.conf

# Reload Apache when cert renews
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/$(hostname -s).crt \
  -k /etc/pki/tls/private/$(hostname -s).key \
  -K host/$(hostname -f)@REALM \
  -C "systemctl reload httpd"
```

---

## 9.10 Troubleshooting RHEL 7 Certificates

### Diagnostic Commands

```bash
#============================================#
# RHEL 7 CERTIFICATE DIAGNOSTICS
#============================================#

# Check OpenSSL version
openssl version

# Test HTTPS locally
openssl s_client -connect localhost:443

# Check Apache SSL configuration
sudo apachectl -t -D DUMP_VHOSTS | grep 443

# View Apache SSL errors
sudo tail -f /var/log/httpd/ssl_error_log

# Check SELinux denials
sudo grep AVC /var/log/audit/audit.log | grep cert

# Check file permissions
ls -lZ /etc/pki/tls/certs/*.crt
ls -lZ /etc/pki/tls/private/*.key

# Verify certificate/key pair
openssl x509 -noout -modulus -in /etc/pki/tls/certs/server.crt | openssl md5
openssl rsa -noout -modulus -in /etc/pki/tls/private/server.key | openssl md5
# MD5 hashes should match
```

### Common RHEL 7 Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "certificate verify failed" | Missing CA in trust store | Add CA to /etc/pki/ca-trust/source/anchors/ |
| "permission denied" on key | Wrong permissions | chmod 600 on .key file |
| "certificate has expired" | Cert expired | Renew certificate manually |
| "no shared cipher" | Client/server cipher mismatch | Update SSLCipherSuite |
| "wrong version number" | TLS version mismatch | Update SSLProtocol |

---

## 9.11 Security Hardening on RHEL 7

### Recommended Configuration

```bash
#============================================#
# APACHE SSL/TLS HARDENING (RHEL 7)
#============================================#

# /etc/httpd/conf.d/ssl.conf

# Disable old protocols
SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1

# Strong ciphers only
SSLCipherSuite ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!3DES:!DES

# Honor server cipher preference
SSLHonorCipherOrder on

# Enable HSTS (HTTP Strict Transport Security)
Header always set Strict-Transport-Security "max-age=31536000"

# OCSP Stapling (not available in RHEL 7 OpenSSL 1.0.2 by default)
# Available in some backports

# Perfect Forward Secrecy
SSLCipherSuite ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256
```

---

## 9.12 Migration Path to RHEL 8+

### Certificate-Specific Migration Steps

```bash
#============================================#
# PREPARE CERTIFICATES FOR MIGRATION
#============================================#

# 1. Verify all certificates use SHA-256+ (no SHA-1 or MD5)
for cert in /etc/pki/tls/certs/*.crt; do
  openssl x509 -in "$cert" -noout -text | grep "Signature Algorithm"
done | grep -i sha1 && echo "⚠️ SHA-1 certificates found! Reissue before migration!"

# 2. Verify key sizes (2048+ bits)
for cert in /etc/pki/tls/certs/*.crt; do
  SIZE=$(openssl x509 -in "$cert" -noout -text | grep "Public-Key" | grep -oP '\d+')
  if [ "$SIZE" -lt 2048 ]; then
    echo "⚠️ $cert: Key too small ($SIZE bits)"
  fi
done

# 3. Backup everything
tar czf rhel7-certs-$(hostname)-$(date +%Y%m%d).tar.gz \
  /etc/pki/tls/ \
  /etc/pki/ca-trust/source/anchors/ \
  /etc/httpd/conf.d/ssl.conf \
  /etc/nginx/nginx.conf

# 4. Document certificate inventory
./generate-cert-inventory.sh > cert-inventory-pre-migration.csv

# 5. Test TLS 1.2 compatibility
# Ensure all services work with TLS 1.2 only
```

---

## 9.13 When RHEL 7 Makes Sense

### Still Using RHEL 7? Consider:

**Reasons to Stay (Temporarily):**
- Extended Life Cycle Support contract active
- Critical legacy applications requiring TLS 1.0/1.1
- Migration planned for near future
- Testing RHEL 8/9 in parallel

**Reasons to Migrate:**
- ✅ Extended maintenance ended June 2024
- ✅ No crypto-policies (harder to manage)
- ✅ No TLS 1.3
- ✅ Security updates limited
- ✅ Modern applications dropping TLS 1.0/1.1 support

---

## 9.14 Key Takeaways

1. **RHEL 7 is manual** - No crypto-policies, careful configuration needed
2. **OpenSSL 1.0.2k** - Older syntax, no TLS 1.3
3. **TLS 1.0/1.1 enabled by default** - Disable them manually
4. **SHA-1 still works** - But won't after migration to RHEL 8+
5. **certmonger available** - But basic compared to RHEL 8+
6. **Plan migration** - RHEL 7 support is ending
7. **Document everything** - Makes migration easier

---

## Quick Reference

```
┌───────────────────────────────────────────────────────┐
│ RHEL 7 CERTIFICATE QUICK REFERENCE                    │
├───────────────────────────────────────────────────────┤
│ OpenSSL:   1.0.2k-26                                  │
│ TLS:       1.0, 1.1, 1.2 (no 1.3)                     │
│ Policy:    Manual configuration (no crypto-policies)  │
│                                                       │
│ Generate:  openssl genrsa -out key.pem 2048           │
│ CSR:       openssl req -new -key key.pem -out req.csr │
│ View:      openssl x509 -in cert.crt -noout -text     │
│ Test:      openssl s_client -connect host:443         │
│                                                       │
│ Harden:    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1     │
│            SSLCipherSuite HIGH:!aNULL:!MD5:!3DES      │
└───────────────────────────────────────────────────────┘
```
---

**Chapter Navigation**

| [← Previous: Chapter 8 - RHEL Versions & Certificate Evolution](08-rhel-versions-overview.md) | [Next: Chapter 10 - RHEL 8 & Crypto-Policies →](10-rhel8-crypto-policies.md) |
|:---|---:|
