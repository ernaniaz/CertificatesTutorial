# Chapter 11: RHEL 9 Modern Security

> **Modern Standard:** RHEL 9 represents the current state-of-the-art in Linux certificate management with OpenSSL 3.x, enhanced crypto-policies, and stricter security defaults.

---

## 11.1 RHEL 9 Overview

**Release:** May 17, 2022
**Support Until:** May 31, 2032
**Current Version:** RHEL 9.8

**Major Changes from RHEL 8:**

| Feature | RHEL 8 | RHEL 9 |
|---------|--------|--------|
| OpenSSL | 1.1.1k | **3.5.5** |
| Architecture | Traditional | **Provider-based** |
| TLS 1.0/1.1 | LEGACY policy | ❌ **Completely removed** |
| Crypto-Policies | Basic | **Subpolicies** |
| Validation | Standard | **Stricter** |
| SHA-1 | Deprecated | **Blocked** |
| certmonger | Enhanced | **Native IPA/tracking workflows** |

**Package:** `openssl-3.5.5-2.el9_8.x86_64`

---

## 11.2 OpenSSL 3.5.5 - Major Changes

### Provider Architecture (New!)

**What Changed:**
OpenSSL 3.x introduced a "provider" system for different crypto implementations.

```bash
#============================================#
# LIST PROVIDERS (RHEL 9)
#============================================#

openssl list -providers

# Output:
# Providers:
#   default
#     name: OpenSSL Default Provider
#     version: 3.5.5
#     status: active
#
#   fips
#     name: OpenSSL FIPS Provider
#     version: 3.5.5
#     status: inactive (unless FIPS mode enabled)
#
#   legacy
#     name: OpenSSL Legacy Provider
#     version: 3.5.5
#     status: inactive
#
#   base
#     name: OpenSSL Base Provider
#     version: 3.5.5
#     status: active
```

### Legacy Algorithms Require Explicit Provider

**Breaking Change:** MD5, Blowfish, CAST5 need `-provider legacy`

```bash
#============================================#
# USING LEGACY ALGORITHMS (RHEL 9)
#============================================#

# This FAILS on RHEL 9:
openssl md5 file.txt
# Error: unsupported

# This WORKS (explicit provider):
openssl md5 -provider legacy file.txt

# Why: Legacy algorithms disabled by default for security
```

### Modern Key Generation (RHEL 9)

```bash
#============================================#
# GENERATE KEYS (RHEL 9)
#============================================#

# RSA 2048 (standard)
openssl genpkey -algorithm RSA -out server.key \
  -pkeyopt rsa_keygen_bits:2048

# RSA 4096 (stronger)
openssl genpkey -algorithm RSA -out server.key \
  -pkeyopt rsa_keygen_bits:4096

# EC P-256 (elliptic curve, recommended)
openssl genpkey -algorithm EC -out ec.key \
  -pkeyopt ec_paramgen_curve:P-256

# EC P-384 (stronger)
openssl genpkey -algorithm EC -out ec.key \
  -pkeyopt ec_paramgen_curve:P-384


#============================================#
# GENERATE CSR WITH SANS (RHEL 9)
#============================================#

openssl req -new -key server.key -out server.csr \
  -subj "/C=US/ST=State/O=Company/CN=server.example.com" \
  -addext "subjectAltName=DNS:server.example.com,DNS:www.example.com,IP:10.0.0.100" \
  -addext "keyUsage=digitalSignature,keyEncipherment" \
  -addext "extendedKeyUsage=serverAuth,clientAuth"

# Verify
openssl req -in server.csr -noout -text | grep -A5 "Subject Alternative Name"
```

---

## 11.3 Enhanced Crypto-Policies (RHEL 9)

### Subpolicies (New Feature!)

**RHEL 9 introduces policy modifiers:**

```bash
#============================================#
# CRYPTO-POLICY SUBPOLICIES (RHEL 9)
#============================================#

# Base policy with NO-SHA1 module
sudo update-crypto-policies --set DEFAULT:NO-SHA1

# Multiple modules
sudo update-crypto-policies --set DEFAULT:NO-SHA1:GOST

# Common subpolicies:
# - NO-SHA1: Completely disable SHA-1 (even in signatures)
# - NO-ENFORCE-EMS: Disable Extended Master Secret
# - GOST: Enable GOST algorithms
# - NO-CAMELLIA: Disable Camellia cipher

# View available modules
ls /usr/share/crypto-policies/policies/modules/
```

### Custom Crypto-Policy Modules (RHEL 9)

```bash
#============================================#
# CREATE CUSTOM POLICY MODULE
#============================================#

# Create custom module
sudo vi /etc/crypto-policies/policies/modules/CUSTOM.pmod

# Example content:
min_rsa_size = 3072
min_dh_size = 3072
min_dsa_size = 3072

# Apply
sudo update-crypto-policies --set DEFAULT:CUSTOM

# Test
openssl ciphers -v | head
```

---

## 11.4 Stricter Certificate Validation

### What's Stricter in RHEL 9?

```bash
#============================================#
# STRICTER VALIDATION EXAMPLES
#============================================#

# 1. SHA-1 signatures completely rejected
openssl verify sha1-signed-cert.crt
# Error: CA md too weak

# 2. Self-signed without proper CA trust rejected
curl https://self-signed.example.com/
# Error: certificate verify failed

# 3. Certificate chain must be complete
# Missing intermediate → connection fails

# 4. Hostname must match (CN or SAN)
openssl s_client -connect server.example.com:443 -servername different.example.com
# Verification error: hostname mismatch

# 5. Keys < 2048 bits rejected
# (even in LEGACY policy, < 1024 rejected)
```

### Impact on Applications

**Applications compiled against OpenSSL 3.x:**
- May need code changes if using deprecated APIs
- Error handling may be different
- Custom crypto code needs testing

**System administrators:**
- ✅ Most changes transparent
- ✅ Commands mostly the same
- ⚠️ Stricter validation catches more issues (this is good!)

---

## 11.5 RHEL 9 Automation: certmonger, certbot, and IdM ACME

### Use the Right Client for the Right CA

```bash
#============================================#
# AUTOMATION CHOICES ON RHEL 9
#============================================#

# Native certmonger workflow for FreeIPA / IdM
sudo dnf install certmonger -y
sudo systemctl enable --now certmonger
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/internal.crt \
  -k /etc/pki/tls/private/internal.key \
  -K HTTP/$(hostname -f)@REALM \
  -D $(hostname -f) \
  -C "systemctl reload httpd"

# Public Let's Encrypt workflow
# Use certbot, not a fake certmonger Let's Encrypt CA definition.
sudo certbot certonly --apache -d web.example.com

# IdM ACME workflow (optional)
# This points at your IPA server's ACME directory, not Let's Encrypt.
sudo certbot certonly \
  --server https://ipa.example.com/acme/directory \
  -d host.example.com
```

**Important:** IdM ACME and Let's Encrypt are different CAs. `certmonger` remains the native RHEL tool for IPA, local CA, and tracked renewal workflows.

---

## 11.6 Trust Store Enhancements

### Advanced Trust Management

```bash
#============================================#
# RHEL 9 TRUST MANAGEMENT
#============================================#

# Add CA (same as RHEL 7/8)
sudo cp corporate-ca.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust

# NEW: Purpose-specific trust
trust anchor /path/to/ca.crt --purpose server-auth

# List trust with details
trust list --filter=ca-anchors

# Export specific CA
trust extract --format=pem-bundle --filter=ca-anchors \
  --purpose server-auth /tmp/server-cas.pem

# Remove specific trust
trust anchor --remove "pkcs11:id=%CERT_ID%"
```

---

## 11.7 Common RHEL 9 Issues and Solutions

### Issue 1: OpenSSL 3.x API Changes

**Problem:** Custom application fails with OpenSSL errors

**Symptoms:**
```
Error: EVP_PKEY_RSA no longer supported
Error: Provider not available
```

**Solution:**
```bash
# Check if application is using deprecated APIs
# Application needs recompilation against OpenSSL 3.x

# Temporary: Set compat environment variable (if available)
export OPENSSL_CONF=/etc/pki/tls/openssl-compat.cnf

# Long-term: Update application
```

### Issue 2: SHA-1 Certificates Rejected

**Problem:** Legacy certificates with SHA-1 signatures fail

**Symptoms:**
```bash
openssl verify cert.crt
# error 3: CA md too weak
```

**Solution:**
```bash
# Reissue certificate with SHA-256+
# No workaround - SHA-1 is blocked for security

# Check certificate signature
openssl x509 -in cert.crt -noout -text | grep "Signature Algorithm"
# Must show: sha256WithRSAEncryption or better
```

### Issue 3: Legacy Algorithm Not Available

**Problem:** Application needs MD5/RC4/etc.

**Symptoms:**
```bash
openssl md5 file.txt
# Error: unsupported
```

**Solution:**
```bash
# Use legacy provider explicitly
openssl md5 -provider legacy file.txt

# For applications: Update to use SHA-256+
# Or configure to load legacy provider
```

---

## 11.8 FIPS Mode on RHEL 9

### Improved FIPS Support

```bash
#============================================#
# FIPS MODE (RHEL 9)
#============================================#

# Enable FIPS mode
sudo fips-mode-setup --enable
sudo reboot

# Check FIPS status
fips-mode-setup --check
# FIPS mode is enabled.

# Check FIPS provider loaded
openssl list -providers | grep -A3 fips
#   fips
#     name: OpenSSL FIPS Provider
#     version: 3.5.5
#     status: active

# Generate FIPS-compliant certificate
openssl req -new -x509 -days 365 -newkey rsa:2048 \
  -keyout fips.key -out fips.crt \
  -subj "/CN=$(hostname)" -provider fips
```

**RHEL 9 FIPS:**
- Uses OpenSSL 3.x FIPS provider
- FIPS 140-2 validated modules
- Transition to FIPS 140-3 in progress

---

## 11.9 Migration from RHEL 8

### Certificate Impact

**Moderate Impact:**
- OpenSSL API changes (affects custom apps)
- Stricter validation (catches more issues)
- Legacy algorithms removed
- SHA-1 completely blocked

### Pre-Migration Checks

```bash
#============================================#
# RHEL 8 → 9 CERTIFICATE PRE-MIGRATION
#============================================#

# 1. Check for SHA-1 certificates (will fail on RHEL 9)
for cert in /etc/pki/tls/certs/*.crt; do
  SIG=$(openssl x509 -in "$cert" -noout -text | grep "Signature Algorithm" | head -2)
  echo "$cert: $SIG"
done | grep -i sha1
# ⚠️ Reissue any SHA-1 certs before migration!

# 2. Check custom applications using OpenSSL
rpm -qa | grep -E "custom|local"
# Test these applications in RHEL 9 environment

# 3. Verify crypto-policy compatibility
update-crypto-policies --show

# 4. Test certificate operations
openssl s_client -connect localhost:443

# 5. Backup everything
tar czf rhel8-certs-backup-$(date +%Y%m%d).tar.gz \
  /etc/pki/tls/ \
  /etc/pki/ca-trust/source/anchors/
```

---

## 11.10 Best Practices for RHEL 9

### Recommended Configuration

```bash
#============================================#
# RECOMMENDED SETUP (RHEL 9)
#============================================#

# 1. Use DEFAULT crypto-policy (unless specific need)
sudo update-crypto-policies --set DEFAULT

# 2. Use certmonger for native automation
sudo dnf install certmonger
sudo systemctl enable --now certmonger

# 3. For public sites: Use certbot for Let's Encrypt
sudo certbot certonly --apache -d web.example.com

# 4. For internal: Use FreeIPA with certmonger
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/internal.crt \
  -k /etc/pki/tls/private/internal.key \
  -K host/$(hostname -f)@REALM

# 5. Generate EC keys (smaller, faster)
openssl genpkey -algorithm EC -out ec.key \
  -pkeyopt ec_paramgen_curve:P-256

# 6. Always use SANs
openssl req -new -addext "subjectAltName=DNS:..."
```

---

## 11.11 New Features You Should Use

### Feature 1: Stronger certmonger + IPA Workflows

```bash
# Native RHEL automation for internal certificates
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/internal.crt \
  -k /etc/pki/tls/private/internal.key \
  -K HTTP/$(hostname -f)@REALM \
  -D $(hostname -f) \
  -C "systemctl reload httpd"

# Better status output on RHEL 9
sudo getcert list -v
```

### Feature 2: Enhanced Status Reporting

```bash
# More detailed status
sudo getcert list -v

# Better error messages
sudo getcert list -f /etc/pki/tls/certs/web.crt
# Shows exact error reason if renewal fails
```

### Feature 3: Crypto-Policy Subpolicies

```bash
# Fine-tune DEFAULT policy
sudo update-crypto-policies --set DEFAULT:NO-SHA1

# Multiple modifiers
sudo update-crypto-policies --set FUTURE:AD-SUPPORT
```

---

## 11.12 Breaking Changes from RHEL 8

### API Changes

**If you have custom applications:**

```c
// RHEL 8 (OpenSSL 1.1.1) - DEPRECATED on RHEL 9:
RSA *rsa = RSA_new();

// RHEL 9 (OpenSSL 3.x) - NEW API:
EVP_PKEY *pkey = EVP_PKEY_new();
```

**Impact:** Custom compiled applications may need updates

### Command Changes

```bash
# Most commands work the same, but some edge cases:

# RHEL 8: This works
openssl md5 file.txt

# RHEL 9: Requires provider
openssl md5 -provider legacy file.txt

# Solution: Use SHA-256 instead
openssl sha256 file.txt
```

---

## 11.13 Common RHEL 9 Scenarios

### Scenario 1: Fresh RHEL 9 Apache HTTPS Setup (Internal CA)

```bash
#============================================#
# COMPLETE APACHE HTTPS SETUP (RHEL 9)
#============================================#

# 1. Install Apache with mod_ssl
sudo dnf install httpd mod_ssl -y

# 2. Use certmonger + FreeIPA / IdM
sudo dnf install certmonger -y
sudo systemctl enable --now certmonger

# 3. Request certificate
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/web.crt \
  -k /etc/pki/tls/private/web.key \
  -K HTTP/$(hostname -f)@REALM \
  -D $(hostname -f) \
  -C "systemctl reload httpd"

# 4. Wait for certificate (check status)
sudo getcert list

# 5. Configure Apache to use certificate
# /etc/httpd/conf.d/ssl.conf already points to:
#   SSLCertificateFile /etc/pki/tls/certs/localhost.crt
# Update to:
#   SSLCertificateFile /etc/pki/tls/certs/web.crt
#   SSLCertificateKeyFile /etc/pki/tls/private/web.key

# 6. Crypto-policy handles TLS settings automatically!
# No need to set SSLProtocol or SSLCipherSuite

# 7. Open firewall
sudo firewall-cmd --add-service=https --permanent
sudo firewall-cmd --reload

# 8. Start Apache
sudo systemctl enable httpd
sudo systemctl start httpd

# 9. Test
curl -v https://$(hostname -f)/

# 10. Automatic renewal happens ~30 days before expiry!
```

**Result:** Fully automated internal HTTPS with FreeIPA and certmonger!

---

## 11.14 Troubleshooting RHEL 9 Certificates

### Diagnostic Commands

```bash
#============================================#
# RHEL 9 CERTIFICATE DIAGNOSTICS
#============================================#

# Check OpenSSL version
openssl version
# OpenSSL 3.5.5

# Check providers
openssl list -providers

# Check crypto-policy
update-crypto-policies --show

# Test connection with TLS 1.3
openssl s_client -connect server:443 -tls1_3

# Check certificate signature algorithm
openssl x509 -in cert.crt -noout -text | grep "Signature Algorithm"
# Must be SHA-256+ on RHEL 9

# Test with legacy provider (if needed)
openssl md5 -provider legacy file.txt

# Check certmonger tracking
sudo getcert list

# View certmonger logs
sudo journalctl -u certmonger -f
```

### Common RHEL 9 Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "CA md too weak" | SHA-1 signature | Reissue with SHA-256+ |
| "Provider not available" | Legacy algorithm used | Add `-provider legacy` or update to modern algorithm |
| "unsupported" on openssl command | Algorithm disabled | Use modern alternative or legacy provider |
| "no shared cipher" (migrated app) | Client uses old ciphers | Update client or use LEGACY policy temporarily |
| "certificate verify failed" | Stricter validation | Check cert chain, SANs, expiration |

---

## 11.15 When to Use RHEL 9

### Ideal For:

✅ **New deployments** - Start with modern security
✅ **Security-focused environments** - Stricter defaults
✅ **Modern applications** - Benefit from TLS 1.3
✅ **Long-term support** - 10 years maintenance
✅ **Compliance requirements** - Modern security standards

### Migration Timing:

**From RHEL 7:**
- ✅ Yes! RHEL 7 maintenance ended June 2024
- Plan carefully - big jump (test thoroughly)

**From RHEL 8:**
- Moderate - OpenSSL 3.x is main change
- Test custom applications first
- SHA-1 certificates must be reissued

---

## 11.16 Key Takeaways

1. **OpenSSL 3.5.5 provider architecture** - Understand providers
2. **Stricter validation** - Catches security issues (good!)
3. **SHA-1 completely blocked** - Reissue old certificates
4. **Crypto-policy subpolicies** - Fine-tune security
5. **certmonger stays valuable** for IPA and tracked renewal workflows
6. **TLS 1.3 mandatory support** - Faster, more secure
7. **Plan testing** - Custom apps may need updates

---

## Quick Reference

```
┌──────────────────────────────────────────────────────────────┐
│ RHEL 9 CERTIFICATE QUICK REFERENCE                           │
├──────────────────────────────────────────────────────────────┤
│ OpenSSL:        3.5.5 (provider architecture)                │
│ TLS:            1.2, 1.3 (1.0/1.1 removed completely)        │
│ Feature:        Subpolicies, stricter validation             │
│                                                              │
│ Providers:      openssl list -providers                      │
│ Policy:         update-crypto-policies --show                │
│ Subpolicy:      update-crypto-policies --set DEFAULT:NO-SHA1 │
│                                                              │
│ Generate key:   openssl genpkey -algorithm RSA -out key.pem  │
│ EC key:         openssl genpkey -algorithm EC -out ec.pem    │
│                 -pkeyopt ec_paramgen_curve:P-256             │
│                                                              │
│ Public ACME:    certbot certonly --apache -d example.com     │
│ certmonger:     ipa-getcert request ...                     │
│ Legacy algo:    openssl md5 -provider legacy file.txt        │
└──────────────────────────────────────────────────────────────┘

⚠️ SHA-1 is BLOCKED - reissue old certificates!
✅ Use certmonger for automation
✅ DEFAULT policy works for most cases
```
---

**Chapter Navigation**

| [← Previous: Chapter 10 - RHEL 8 & Crypto-Policies](10-rhel8-crypto-policies.md) | [Next: Chapter 12 - RHEL 10 Current Features →](12-rhel10-current.md) |
|:---|---:|
