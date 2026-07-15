# Chapter 40: RHEL Security Hardening for Certificates

> **Defense in Depth:** Beyond FIPS, learn how to harden certificate security on RHEL using SELinux, TPM, smart cards, and security scanning tools.

---

## 40.1 Security Hardening Overview

**Layers of Certificate Security:**

1. **File Permissions** - Protect private keys
2. **SELinux** - Mandatory access control
3. **Firewall** - Limit exposure
4. **Auditing** - Track access
5. **TPM** - Hardware key protection
6. **Smart Cards** - Physical tokens
7. **Monitoring** - Detect issues
8. **Compliance Scanning** - Verify configuration

---

## 40.2 SELinux for Certificates

### Proper SELinux Contexts

```bash
#============================================#
# SELINUX CERTIFICATE CONTEXTS
#============================================#

# Check current contexts
ls -Z /etc/pki/tls/certs/*.crt
ls -Z /etc/pki/tls/private/*.key

# Correct contexts:
# Certificates: system_u:object_r:cert_t:s0
# Private keys: system_u:object_r:cert_t:s0

# Fix contexts if wrong
sudo restorecon -Rv /etc/pki/tls/

# Verify
ls -Z /etc/pki/tls/certs/server.crt
# system_u:object_r:cert_t:s0  ← Correct
```

### SELinux Certificate Policy

```bash
#============================================#
# SELINUX CERTIFICATE HARDENING
#============================================#

# Ensure SELinux enforcing
getenforce
# Enforcing  ← Good

# If permissive, enable enforcing
sudo setenforce 1

# Make permanent
sudo sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config

# Check for certificate-related denials
sudo ausearch -m avc -ts recent | grep cert

# If denials found, generate policy
sudo ausearch -m avc -ts recent | audit2allow -M mycert-policy
sudo semodule -i mycert-policy.pp
```

---

## 40.3 File Permissions Hardening

### Strict Permission Model

```bash
#============================================#
# HARDENED FILE PERMISSIONS
#============================================#

# Certificates (public) - minimal access
sudo chmod 444 /etc/pki/tls/certs/*.crt
sudo chown root:root /etc/pki/tls/certs/*.crt

# Private keys (secret!) - owner only
sudo chmod 400 /etc/pki/tls/private/*.key
sudo chown root:root /etc/pki/tls/private/*.key

# Even stricter: Immutable (can't be modified even by root without removing flag)
sudo chattr +i /etc/pki/tls/certs/critical.crt
sudo chattr +i /etc/pki/tls/private/critical.key

# Remove immutable when need to update
# sudo chattr -i /etc/pki/tls/private/critical.key

# Verify
ls -l /etc/pki/tls/private/
# -r--------. 1 root root  ← 400, very restrictive
```

---

## 40.4 TPM (Trusted Platform Module)

### Using TPM for Key Storage

**TPM Benefits:**
- ✅ Hardware-protected keys
- ✅ Keys never leave TPM
- ✅ Tamper-resistant
- ✅ Platform attestation

```bash
#============================================#
# TPM FOR CERTIFICATE KEYS (ADVANCED)
#============================================#

# Check if TPM available
ls /dev/tpm*

# Install TPM tools
sudo dnf install tpm2-tools -y

# Generate key in TPM
tpm2_createprimary -C o -g sha256 -G rsa -c primary.ctx
tpm2_create -G rsa -u rsa.pub -r rsa.priv -C primary.ctx

# Use TPM key with OpenSSL requires additional setup
# (Complex, enterprise use case)

# For certmonger with TPM:
# Experimental/advanced - check Red Hat docs
```

---

## 40.5 Smart Cards and PIV

### Using Smart Cards for Authentication

```bash
#============================================#
# SMART CARD SETUP (PIV/CAC)
#============================================#

# Install smart card support
sudo dnf install opensc pcsc-lite -y

# Start PC/SC daemon
sudo systemctl enable --now pcscd

# Check if card readable
pkcs11-tool --list-slots

# List certificates on card
pkcs11-tool --list-objects

# Use smart card with SSH
# /etc/ssh/sshd_config:
# PubkeyAuthentication yes

# Extract public key from card
ssh-keygen -D /usr/lib64/opensc-pkcs11.so > ~/.ssh/authorized_keys
```

---

## 40.6 Audit and Monitoring

### auditd for Certificate Access

```bash
#============================================#
# AUDIT CERTIFICATE ACCESS
#============================================#

# Add audit rules for private key access
sudo auditctl -w /etc/pki/tls/private/ -p war -k certificate-access

# Make permanent
echo "-w /etc/pki/tls/private/ -p war -k certificate-access" | \
  sudo tee -a /etc/audit/rules.d/certificate.rules

# Reload rules
sudo augenrules --load

# Monitor access
sudo ausearch -k certificate-access

# Real-time monitoring
sudo ausearch -k certificate-access -ts recent -i
```

---

## 40.7 OpenSCAP Scanning

### Security Compliance Scanning

```bash
#============================================#
# OPENSCAP CERTIFICATE SCANNING
#============================================#

# Install OpenSCAP
sudo dnf install openscap-scanner scap-security-guide -y

# Scan for certificate issues
sudo oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_pci-dss \
  --results scan-results.xml \
  --report scan-report.html \
  /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml

# View report
firefox scan-report.html

# Certificate-related checks:
# - File permissions
# - SELinux contexts
# - Weak algorithms
# - Expiration
```

---

## 40.8 Security Hardening Checklist

```markdown
## Certificate Security Hardening Checklist

### File Security
- [ ] Private keys mode 400 or 600 (never 644!)
- [ ] Certificates mode 444 or 644
- [ ] Ownership: root:root or service user
- [ ] SELinux contexts: cert_t
- [ ] Consider immutable flag (+i) for critical certs

### Access Control
- [ ] SELinux enforcing
- [ ] Audit rules for private key access
- [ ] Firewall limiting TLS ports
- [ ] Principle of least privilege applied

### Algorithm Security
- [ ] SHA-256+ signatures only
- [ ] RSA 2048+ or ECC P-256+ keys
- [ ] TLS 1.2+ only (no 1.0/1.1)
- [ ] Strong ciphers (via crypto-policy)
- [ ] FIPS mode if required

### Operational Security
- [ ] Certificates monitored for expiration
- [ ] Automatic renewal enabled (certmonger)
- [ ] Backups encrypted
- [ ] Keys never emailed or in tickets
- [ ] Access logged and reviewed
- [ ] Regular security scans

### Network Security
- [ ] Firewall rules restrictive
- [ ] Only necessary ports open
- [ ] Certificate pinning (where applicable)
- [ ] HSTS enabled for web servers
- [ ] OCSP stapling enabled

### Compliance
- [ ] OpenSCAP scans passing
- [ ] STIG compliance verified
- [ ] CIS benchmarks met
- [ ] Documentation current
- [ ] Audit trail maintained
```

---

## 40.9 Key Takeaways

1. **Defense in depth** - Multiple security layers
2. **SELinux enforcing** - Mandatory for production
3. **File permissions critical** - 400/600 for keys
4. **Audit everything** - Track key access
5. **TPM for high security** - Hardware protection
6. **OpenSCAP for compliance** - Automated scanning
7. **Monitor continuously** - Security is ongoing

---

## Quick Reference Card

```
┌──────────────────────────────────────────────────────────────┐
│ CERTIFICATE SECURITY HARDENING                               │
├──────────────────────────────────────────────────────────────┤
│ Permissions:  chmod 400 /etc/pki/tls/private/*.key           │
│               chmod 444 /etc/pki/tls/certs/*.crt             │
│                                                              │
│ SELinux:      getenforce (must be Enforcing)                 │
│               restorecon -Rv /etc/pki/tls/                   │
│               ls -Z (check contexts)                         │
│                                                              │
│ Audit:        auditctl -w /etc/pki/tls/private/ -p war       │
│               ausearch -k certificate-access                 │
│                                                              │
│ Scan:         oscap xccdf eval --profile pci-dss ...         │
│                                                              │
│ Immutable:    chattr +i /etc/pki/tls/private/key.key         │
│               chattr -i (to modify)                          │
└──────────────────────────────────────────────────────────────┘

✅ SELinux enforcing is mandatory
✅ Audit private key access
✅ Use 400 (not 600) for maximum security
```

---

## 🧪 Hands-On Lab

**Lab 20: Security Hardening**

Apply security best practices to certificate configurations

- 📁 **Location:** `labs/en_US/20-security-hardening/`
- ⏱️ **Time:** 30-40 minutes
- 🎯 **Level:** Advanced

---

**Chapter Navigation**

| [← Previous: Chapter 39 - FIPS-Compliant Certificates](39-fips-certificates.md) | [Next: Chapter 41 - Compliance & Auditing →](41-compliance-auditing.md) |
|:---|---:|
