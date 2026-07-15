# Chapter 3: RHEL Certificate Tools Overview

> **Learning Objective:** Get familiar with the essential tools for managing certificates on RHEL so you know which tool to use for each task.

---

## 3.1 Your Certificate Toolkit

When working with certificates on RHEL, you'll use these core tools:

| Tool | Primary Use | RHEL Versions | When to Use |
|------|-------------|---------------|-------------|
| **openssl** | Certificate operations, testing | All | Generate keys/CSRs, inspect certs, test connections |
| **certutil** | NSS database management | All | Firefox/Mozilla-style cert DBs |
| **update-ca-trust** | Trust store management | All | Add/remove trusted CAs |
| **certmonger** | Automatic renewal | All | Track and auto-renew certificates |
| **crypto-policies** | System-wide security | RHEL 8+ | Control TLS versions and ciphers |
| **getcert** | certmonger CLI | All | Request and manage tracked certs |
| **trust** | P11-kit trust management | All (enhanced RHEL 8+) | Advanced trust operations |

---

## 3.2 OpenSSL - The Swiss Army Knife

**Available:** All RHEL versions
**Package:** `openssl`

### Version Differences

```bash
# Check your version
openssl version

# RHEL 7: OpenSSL 1.0.2k-26
# RHEL 8: OpenSSL 1.1.1k-14
# RHEL 9: OpenSSL 3.5.5-2
# RHEL 10: OpenSSL 3.5.5-2
```

### Common Uses

```bash
#============================================#
# INSPECT CERTIFICATES
#============================================#

# View certificate details
openssl x509 -in cert.crt -noout -text

# Check expiration
openssl x509 -in cert.crt -noout -dates
openssl x509 -in cert.crt -noout -checkend 86400  # Check if expires in 24h

# View certificate subject
openssl x509 -in cert.crt -noout -subject -issuer


#============================================#
# GENERATE KEYS
#============================================#

# RHEL 7 style (still works on all versions)
openssl genrsa -out server.key 2048

# RHEL 8+ modern style (recommended)
openssl genpkey -algorithm RSA -out server.key -pkeyopt rsa_keygen_bits:2048

# RHEL 9+ EC key (elliptic curve)
openssl genpkey -algorithm EC -out ec.key -pkeyopt ec_paramgen_curve:P-256


#============================================#
# CREATE CSR (Certificate Signing Request)
#============================================#

# Basic CSR
openssl req -new -key server.key -out server.csr \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=server.example.com"

# CSR with SANs (required for modern browsers!)
openssl req -new -key server.key -out server.csr \
  -subj "/CN=server.example.com" \
  -addext "subjectAltName=DNS:server.example.com,DNS:www.example.com"


#============================================#
# TEST CONNECTIONS
#============================================#

# Test HTTPS
openssl s_client -connect server.example.com:443 -servername server.example.com

# Test specific TLS version
openssl s_client -connect server.example.com:443 -tls1_2
openssl s_client -connect server.example.com:443 -tls1_3

# Test LDAPS
openssl s_client -connect ldap.example.com:636

# Test SMTP with STARTTLS
openssl s_client -connect mail.example.com:25 -starttls smtp
```

### Version-Specific Differences

**RHEL 7 (OpenSSL 1.0.2k):**
- ✅ Stable and well-tested
- ❌ No TLS 1.3 support
- ❌ Older command syntax

**RHEL 8 (OpenSSL 1.1.1k):**
- ✅ TLS 1.3 support
- ✅ Modern command syntax
- ✅ Better defaults

**RHEL 9/10 (OpenSSL 3.5.5):**
- ✅ Provider architecture
- ✅ Enhanced FIPS support
- ⚠️ API changes (affects custom apps)
- ⚠️ Legacy algorithms require `-provider legacy`

---

## 3.3 certutil - NSS Database Tool

**Available:** All RHEL versions
**Package:** `nss-tools`

Used for Mozilla/Firefox-style certificate databases.

### Common Uses

```bash
#============================================#
# MANAGE NSS DATABASE
#============================================#

# Create new database
certutil -N -d /etc/pki/nssdb

# List certificates
certutil -L -d /etc/pki/nssdb

# Add CA certificate
certutil -A -n "My CA" -t "CT,C,C" -d /etc/pki/nssdb -i ca.crt

# Delete certificate
certutil -D -n "Certificate Name" -d /etc/pki/nssdb

# Export certificate
certutil -L -n "Certificate Name" -d /etc/pki/nssdb -a > exported.crt
```

### When to Use certutil

- Managing Firefox/Thunderbird certificates
- Working with applications that use NSS (many Red Hat services)
- When you see `.db` files in `/etc/pki/nssdb/`

---

## 3.4 update-ca-trust - Trust Store Management

**Available:** All RHEL versions
**Package:** `ca-certificates` (installed by default)

Manages which Certificate Authorities (CAs) your system trusts.

### How It Works

```
Your Custom CAs
  ↓
/etc/pki/ca-trust/source/anchors/
  ↓
update-ca-trust extract
  ↓
/etc/pki/ca-trust/extracted/
  ├── pem/tls-ca-bundle.pem       (OpenSSL/Python/Ruby)
  ├── openssl/ca-bundle.trust.crt (OpenSSL specific)
  └── java/cacerts                (Java applications)
```

### Common Uses

```bash
#============================================#
# ADD CUSTOM CA
#============================================#

# Step 1: Copy CA certificate
sudo cp corporate-ca.crt /etc/pki/ca-trust/source/anchors/

# Step 2: Update trust store
sudo update-ca-trust extract

# That's it! Now all applications trust this CA


#============================================#
# REMOVE/BLACKLIST CA (RHEL 8+)
#============================================#

# Blacklist a compromised CA
sudo cp compromised-ca.crt /etc/pki/ca-trust/source/blacklist/
sudo update-ca-trust extract


#============================================#
# VERIFY TRUST
#============================================#

# Check if certificate is trusted
openssl verify /path/to/cert.crt

# List all trusted CAs
trust list | grep "certificate-authority"

# Search for specific CA
trust list | grep -i "Let's Encrypt"
```

### Key Directories

```
/etc/pki/ca-trust/
├── source/
│   ├── anchors/          ← Add your trusted CAs here
│   └── blacklist/        ← Blacklist CAs (RHEL 8+)
└── extracted/
    ├── pem/              ← Used by most apps
    ├── openssl/          ← OpenSSL-specific
    └── java/             ← Java applications
```

---

## 3.5 certmonger - Automatic Certificate Renewal

**Available:** All RHEL versions
**Package:** `certmonger`

The "set it and forget it" tool for certificates.

### What It Does

certmonger:
- Tracks certificate expiration dates
- Automatically renews before expiry
- Works with multiple CA workflows (IPA, local CA, external helpers)
- Runs post-renewal commands (e.g., restart services)

### Basic Workflow

```bash
#============================================#
# INSTALLATION
#============================================#

sudo dnf install certmonger  # RHEL 8/9/10; use yum on RHEL 7
sudo systemctl enable --now certmonger


#============================================#
# REQUEST CERTIFICATE
#============================================#

# From FreeIPA
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/web.crt \
  -k /etc/pki/tls/private/web.key \
  -D web.example.com \
  -K host/web.example.com@REALM

# Self-signed (for testing)
sudo getcert request \
  -f /etc/pki/tls/certs/test.crt \
  -k /etc/pki/tls/private/test.key


#============================================#
# MONITOR CERTIFICATES
#============================================#

# List all tracked certificates
sudo getcert list

# Check specific certificate
sudo getcert list -f /etc/pki/tls/certs/web.crt

# Watch for renewal
sudo journalctl -u certmonger -f
```

### Key Features by Version

**RHEL 7:**
- Basic tracking and renewal
- IPA integration
- Manual configuration

**RHEL 8:**
- Enhanced IPA integration
- Better error reporting
- Post-save commands

**RHEL 9:**
- Improved monitoring
- Better status reporting
- Same strong fit for IPA and tracked renewals

```bash
# RHEL 9 - Native FreeIPA integration
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/internal.crt \
  -k /etc/pki/tls/private/internal.key \
  -K HTTP/$(hostname -f)@REALM \
  -D $(hostname -f) \
  -C "systemctl reload httpd"
```

---

## 3.6 crypto-policies - System-Wide Security (RHEL 8+)

**Available:** RHEL 8, 9, 10 only
**Package:** `crypto-policies` (installed by default)

**GAME CHANGER:** Control TLS versions, ciphers, and key sizes system-wide!

### The Big Idea

Instead of configuring every application individually:

```
❌ OLD WAY (RHEL 7):
- Configure Apache SSL ciphers
- Configure NGINX SSL ciphers
- Configure Postfix TLS settings
- Configure OpenLDAP TLS settings
- Configure every application...

✅ NEW WAY (RHEL 8+):
- Set ONE system policy
- All applications follow it automatically!
```

### Available Policies

```bash
# Check current policy
update-crypto-policies --show

# Policies:
# DEFAULT  - Balanced security (TLS 1.2+, RSA 2048+)
# LEGACY   - Compatibility mode (allows TLS 1.0/1.1)
# FUTURE   - Stricter security (TLS 1.2+, RSA 3072+)
# FIPS     - Federal compliance mode
```

### Policy Comparison

| Feature | LEGACY | DEFAULT | FUTURE | FIPS |
|---------|--------|---------|--------|------|
| TLS 1.0/1.1 | ✅ Allowed | ❌ Blocked | ❌ Blocked | ❌ Blocked |
| TLS 1.2 | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |
| TLS 1.3 | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |
| Min RSA | 1024 bits | 2048 bits | 3072 bits | 2048 bits |
| SHA-1 sigs | ⚠️ Allowed | ❌ Blocked | ❌ Blocked | ❌ Blocked |
| 3DES cipher | ⚠️ Allowed | ❌ Blocked | ❌ Blocked | ❌ Blocked |

### Common Uses

```bash
#============================================#
# CHANGE POLICY
#============================================#

# Set FUTURE policy (stricter)
sudo update-crypto-policies --set FUTURE
# Reboot or restart services

# Temporarily use LEGACY (for old systems)
sudo update-crypto-policies --set LEGACY
# Note: LEGACY should be temporary!


#============================================#
# CUSTOM POLICIES (RHEL 9+)
#============================================#

# Subpolicies - modify existing policy
sudo update-crypto-policies --set DEFAULT:NO-SHA1
sudo update-crypto-policies --set FUTURE:AD-SUPPORT


#============================================#
# TROUBLESHOOT POLICY ISSUES
#============================================#

# If service fails after policy change:
# 1. Check current policy
update-crypto-policies --show

# 2. Check application config
cat /etc/crypto-policies/back-ends/opensslcnf.config

# 3. Test with LEGACY temporarily
sudo update-crypto-policies --set LEGACY
sudo systemctl restart <service>
```

### What crypto-policies Controls

Automatically configures:
- OpenSSL
- GnuTLS
- NSS
- OpenJDK/Java
- BIND
- Kerberos
- OpenSSH
- And more!

**Bottom line:** Change one setting, update system-wide security. Brilliant!

---

## 3.7 Tool Selection Guide

### "Which tool should I use?"

```
┌─────────────────────────────────────────────────────────────┐
│ CERTIFICATE TOOL DECISION TREE                              │
└─────────────────────────────────────────────────────────────┘

I need to...
│
├─ Inspect a certificate
│  └─ Use: openssl x509 -in cert.crt -noout -text
│
├─ Generate a key/CSR
│  └─ Use: openssl genpkey / openssl req
│
├─ Test a TLS connection
│  └─ Use: openssl s_client -connect host:port
│
├─ Add a trusted CA system-wide
│  └─ Use: copy to /etc/pki/ca-trust/source/anchors/
│          then: update-ca-trust
│
├─ Auto-renew certificates
│  └─ Use: certmonger (getcert/ipa-getcert)
│
├─ Change system TLS policy (RHEL 8+)
│  └─ Use: update-crypto-policies --set <POLICY>
│
├─ Work with Firefox/NSS databases
│  └─ Use: certutil
│
└─ Troubleshoot certificate issues
   └─ Use: Chapter 27 methodology!
```

---

## 3.8 Tool Availability Matrix

| Tool | RHEL 7 | RHEL 8 | RHEL 9 | RHEL 10 | Notes |
|------|--------|--------|--------|---------|-------|
| openssl | 1.0.2k | 1.1.1k | 3.5.5 | 3.5.5 | Core tool |
| certutil | ✅ | ✅ | ✅ | ✅ | NSS tool |
| update-ca-trust | ✅ | ✅ Enhanced | ✅ Enhanced | ✅ Enhanced | Trust mgmt |
| certmonger | ✅ | ✅ Enhanced | ✅ ACME | ✅ ACME | Auto-renewal |
| crypto-policies | ❌ | ✅ | ✅ Subpolicies | ✅ Enhanced | System policy |
| getcert | ✅ | ✅ | ✅ | ✅ | certmonger CLI |
| trust | ✅ Basic | ✅ | ✅ | ✅ | p11-kit tool |

---

## 3.9 Installation Check

Verify you have the essential tools:

```bash
#============================================#
# CHECK INSTALLED TOOLS
#============================================#

# OpenSSL (should be installed by default)
openssl version

# NSS tools
rpm -q nss-tools || echo "Install with: sudo dnf install nss-tools"

# certmonger
rpm -q certmonger || echo "Install with: sudo dnf install certmonger (RHEL 8+); sudo yum install certmonger (RHEL 7)"

# Check crypto-policies (RHEL 8+ only)
which update-crypto-policies &>/dev/null && \
  echo "Crypto-policies available: $(update-crypto-policies --show)" || \
  echo "Crypto-policies not available (RHEL 7 or earlier)"
```

---

## 3.10 Quick Reference Commands

```bash
# === OpenSSL ===
openssl version                          # Check version
openssl x509 -in cert.crt -noout -text   # Inspect certificate
openssl s_client -connect host:443       # Test HTTPS

# === Trust Store ===
sudo cp ca.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust                     # Add trusted CA

# === certmonger ===
sudo getcert list                        # List tracked certs
sudo getcert list -f /path/to/cert.crt   # Check specific cert
sudo journalctl -u certmonger -f         # Watch logs

# === Crypto-Policies (RHEL 8+) ===
update-crypto-policies --show            # Current policy
sudo update-crypto-policies --set <POL>  # Change policy

# === NSS ===
certutil -L -d /etc/pki/nssdb            # List NSS certs
```

---

## 3.11 What's Next?

Now that you know the tools, you'll learn:
- **Chapter 4:** Basic cryptography concepts
- **Chapter 5:** Understanding X.509 certificates
- **Chapter 6:** RHEL trust store deep dive
- **Chapter 22:** certmonger mastery (detailed)
- **Chapter 23:** Crypto-policies deep dive (detailed)

---

## Quick Reference Card

```
┌──────────────────────────────────────────────────────────┐
│ RHEL CERTIFICATE TOOLS CHEAT SHEET                       │
├──────────────────────────────────────────────────────────┤
│ Inspect:     openssl x509 -in cert.crt -noout -text      │
│ Test:        openssl s_client -connect host:443          │
│ Add CA:      cp ca.crt /etc/pki/ca-trust/source/anchors/ │
│              sudo update-ca-trust                        │
│ Auto-renew:  sudo getcert list                           │
│ Policy:      update-crypto-policies --show  (RHEL 8+)    │
│ NSS:         certutil -L -d /etc/pki/nssdb               │
└──────────────────────────────────────────────────────────┘
```
---

**Chapter Navigation**

| [← Previous: Chapter 2 - Introduction to Certificates on RHEL](02-intro.md) | [Next: Chapter 4 - Basic Cryptography for RHEL Admins →](04-basic-cryptography.md) |
|:---|---:|
