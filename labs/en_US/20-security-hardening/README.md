# Lab 20: Security Hardening for Certificates

## Learning Objectives

By completing this lab, you will:
- Harden Apache and NGINX SSL/TLS configurations
- Disable weak protocols and ciphers
- Implement security headers
- Enforce TLS 1.3
- Configure HSTS
- Apply security best practices

## Prerequisites

- **Labs 01-10** completed
- **RHEL 8 or 9** recommended
- **System Access:** Root/sudo required
- **Apache or NGINX** installed

## Time Estimate

**30-40 minutes**

## Lab Overview

Learn to apply security hardening best practices to certificate configurations, ensuring maximum protection against known attacks and vulnerabilities.

---

## Instructions

### Step 1: Harden Apache

```bash
sudo ./harden-apache.sh
```

### Step 2: Harden NGINX

```bash
sudo ./harden-nginx.sh
```

### Step 3: Disable Weak Protocols

```bash
sudo ./disable-weak-protocols.sh
```

### Step 4: Enforce TLS 1.3

```bash
sudo ./enforce-tls13.sh
```

### Step 5: Configure HSTS

```bash
sudo ./enable-hsts.sh
```

### Step 6: Audit Configuration

```bash
./audit-security.sh
```

---

## Security Best Practices

### TLS Protocol Versions
- ✅ TLS 1.3 (best)
- ✅ TLS 1.2 (acceptable)
- ❌ TLS 1.1 (deprecated)
- ❌ TLS 1.0 (insecure)
- ❌ SSLv3 (vulnerable)

### Cipher Suites
Use forward secrecy ciphers:
- ECDHE-RSA-AES256-GCM-SHA384
- ECDHE-RSA-AES128-GCM-SHA256
- ECDHE-RSA-CHACHA20-POLY1305

### Security Headers
```
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
```

---

## Validation

Verify security hardening:

```bash
./audit-security.sh
```

**Expected Results:**
- ✓ If `/etc/httpd/conf.d/ssl-hardening.conf` exists, `./audit-security.sh` reports the Apache hardening config
- ✓ If `/etc/nginx/conf.d/ssl-hardening.conf` exists, `./audit-security.sh` reports the NGINX hardening config
- ✓ The script prints a pass/fail summary for whichever hardening drop-in files are present on the system

**Additional Manual Testing:**
```bash
# Test TLS version
openssl s_client -connect localhost:443 -tls1
# Should fail

# Test TLS 1.2
openssl s_client -connect localhost:443 -tls1_2
# Should succeed

# Check headers
curl -I https://localhost
# Should include HSTS and security headers

# Verify cipher strength
nmap --script ssl-enum-ciphers -p 443 localhost
```

---

## Cleanup

```bash
sudo ./cleanup.sh
```

---

**Difficulty Level**: Advanced
