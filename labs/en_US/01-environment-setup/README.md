# Lab 01: Environment Setup

## Learning Objectives

By completing this lab, you will:
- Verify your RHEL system is properly configured
- Install essential certificate management tools
- Understand the /etc/pki/ directory structure
- Validate OpenSSL installation and version
- Prepare your system for subsequent certificate labs

## Prerequisites

- **RHEL Version:** RHEL 7, 8, 9, or 10
- **System Access:** Root or sudo privileges required
- **Network:** Internet connectivity for package installation

## Time Estimate

**15-20 minutes**

## Lab Overview

This lab validates and prepares your RHEL system for certificate management exercises. You'll install necessary tools and verify the certificate infrastructure is in place.

---

## Instructions

### Step 1: Identify Your RHEL Version

First, let's identify which RHEL version you're running:

```bash
cat /etc/redhat-release
```

**Expected Output:**
```
Red Hat Enterprise Linux release 8.x (Ootpa)
# or similar for RHEL 7, 9, or 10
```

Check OpenSSL version:
```bash
openssl version
```

**Version by RHEL:**
- RHEL 7: OpenSSL 1.0.2k
- RHEL 8: OpenSSL 1.1.1k
- RHEL 9: OpenSSL 3.5.5
- RHEL 10: OpenSSL 3.5.5

---

### Step 2: Run the Setup Script

Execute the setup script:

```bash
sudo ./setup.sh
```

The script will install:
- OpenSSL (certificate operations)
- NSS tools / certutil (NSS database management)
- certmonger (automatic certificate renewal)
- ca-certificates (system trust store)

---

### Step 3: Verify Installation

After installation, run the verification script:

```bash
./verify-environment.sh
```

**Expected Result:**
```
=== Environment Verification ===
RHEL Version: 8
✓ OpenSSL: OpenSSL 1.1.1k FIPS  25 Mar 2021
✓ certutil available
✓ certmonger available
✓ /etc/pki/tls/certs
✓ /etc/pki/tls/private
✓ /etc/pki/ca-trust
✓ CA bundle: 140 lines

=== Environment Ready ===
Proceed to Lab 02: Key Generation
```

---

### Step 4: Explore Certificate Directory Structure

View the certificate directory structure:

```bash
tree -L 2 /etc/pki/
```

**Key Directories:**
- `/etc/pki/tls/certs/` - Server certificates (public)
- `/etc/pki/tls/private/` - Private keys (mode 600!)
- `/etc/pki/ca-trust/` - Trusted CA certificates
- `/etc/pki/nssdb/` - NSS database

Check the system CA bundle:
```bash
ls -lh /etc/pki/tls/certs/ca-bundle.crt
wc -l /etc/pki/tls/certs/ca-bundle.crt
```

---

## Validation

To verify your lab is complete, run:

```bash
./verify-environment.sh
```

All checks should pass with ✓ symbols.

## Expected Outcome

After completing this lab, you should have:
- ✅ RHEL version identified
- ✅ OpenSSL installed and version verified
- ✅ Certificate tools installed (certutil, certmonger)
- ✅ /etc/pki/ directory structure validated
- ✅ System CA bundle accessible

---

## Troubleshooting

### Issue 1: Package Installation Fails

**Symptom:**
```
Error: Unable to find a match: certmonger
```

**Cause:**
Repository not configured or RHEL subscription not active

**Solution:**
```bash
# Check RHEL subscription status
sudo subscription-manager status

# If not registered, register system
sudo subscription-manager register

# Enable required repositories
sudo subscription-manager repos --enable=rhel-8-for-x86_64-baseos-rpms
```

---

### Issue 2: Permission Denied

**Symptom:**
```
Permission denied when accessing /etc/pki/
```

**Cause:**
Script not run with sudo/root

**Solution:**
Run setup scripts with sudo:
```bash
sudo ./setup.sh
```

---

## Version-Specific Notes

### RHEL 7
- Uses YUM package manager
- OpenSSL 1.0.2k (older, but functional)
- Manual SSL/TLS configuration required for services

### RHEL 8+
- Uses DNF package manager
- Crypto-policies system introduced
- Automatic TLS version and cipher management

### RHEL 9+
- OpenSSL 3.x (major version change)
- SHA-1 signatures blocked by default
- Stricter certificate validation

---

## Cleanup

This lab doesn't require cleanup as it only installs system packages. If you want to remove packages:

```bash
sudo ./cleanup.sh
```

**Warning:** Only run cleanup if you're sure you won't need these tools.

---

## Additional Resources

**Related Chapters:**
- Chapter 1: Cryptography, PKI Structure & Fundamentals
- Chapter 2: Introduction to Certificates on RHEL
- Chapter 3: RHEL Certificate Tools Overview

**Documentation:**
- `man openssl`
- `man certutil`
- `man getcert` (certmonger)

---

## Next Steps

After completing this lab, proceed to:

**Lab 02: Key Generation** - Learn to generate RSA and ECC key pairs

---

**RHEL Versions Tested**: 7, 8, 9, 10  
**Difficulty Level**: Beginner
