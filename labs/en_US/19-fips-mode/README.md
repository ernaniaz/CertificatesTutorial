# Lab 19: FIPS Mode Configuration

## Learning Objectives

By completing this lab, you will:
- Understand FIPS 140-2 compliance requirements
- Enable FIPS mode on RHEL
- Configure certificates for FIPS
- Test FIPS compliance
- Troubleshoot FIPS issues
- Understand FIPS limitations

## Prerequisites

- **RHEL 8 or 9** (FIPS mode enable/disable support)
- **Labs 01-10** completed
- **System Access:** Root/sudo required
- **Reboot capability** required

> **RHEL 10 Note:** RHEL 10 does not support enabling or disabling FIPS mode
> after installation. FIPS must be configured during OS installation by adding
> `fips=1` to the kernel boot parameters or selecting FIPS in the Anaconda
> installer security policy. The verification and testing scripts in this lab
> still work on RHEL 10, but `enable-fips.sh` and `disable-fips.sh` do not.

## Time Estimate

**40-50 minutes** (includes reboot)

## Lab Overview

FIPS 140-2 is a US government security standard for cryptographic modules. Learn to enable and configure FIPS mode for compliance requirements.

---

## FIPS Mode Overview

### What is FIPS?

**FIPS 140-2:** Federal Information Processing Standard Publication 140-2
- Cryptographic module validation program
- Required for government systems
- Specifies approved algorithms
- Validates implementations

### FIPS Approved Algorithms

**Allowed:**
- AES (128, 192, 256-bit)
- RSA (2048+ bits)
- SHA-256, SHA-384, SHA-512
- ECDSA with approved curves
- HMAC with SHA-2

**Blocked:**
- MD5
- SHA-1 (signatures)
- DES, 3DES
- RC4
- RSA <2048 bits

---

## Instructions

### Step 1: Pre-FIPS Assessment

Check current system state:

```bash
./check-fips-readiness.sh
```

### Step 2: Enable FIPS Mode

Enable FIPS (requires reboot):

```bash
sudo ./enable-fips.sh
# System will reboot
```

### Step 3: Verify FIPS Mode

After reboot, verify:

```bash
./verify-fips.sh
```

### Step 4: Test Certificates

Test certificate compatibility:

```bash
./test-fips-certificates.sh
```

### Step 5: Configure Services

Update services for FIPS:

```bash
sudo ./configure-services-fips.sh
```

---

## Key Commands

```bash
# Check FIPS status
fips-mode-setup --check

# Enable FIPS (requires reboot) — RHEL 8 and 9 only
fips-mode-setup --enable

# Disable FIPS (requires reboot) — RHEL 8 and 9 only
fips-mode-setup --disable

# Check kernel FIPS flag
cat /proc/sys/crypto/fips_enabled
```

> **RHEL 10:** `fips-mode-setup --enable` and `--disable` are not supported.
> FIPS is set at installation time only.

---

## Validation

Verify FIPS mode is properly configured:

```bash
./verify-fips.sh
```

**Expected Results:**
- ✓ FIPS mode enabled: `/proc/sys/crypto/fips_enabled` shows `1`
- ✓ `fips-mode-setup --check` reports FIPS is enabled
- ✓ `openssl md5 /dev/null` fails because MD5 is disabled in FIPS mode

**Additional Manual Checks:**
```bash
# Check FIPS kernel parameter
cat /proc/sys/crypto/fips_enabled  # Should show 1

# Verify crypto-policy
update-crypto-policies --show  # Should show FIPS

# Test OpenSSL FIPS
openssl md5 /etc/hosts  # Should fail with FIPS error

# Check service configurations
systemctl status httpd
journalctl -u httpd | grep -i fips
```

---

## Common Issues

### Issue: Service Won't Start

**Symptom:** Service fails with "FIPS mode" error

**Solution:** Use FIPS-approved algorithms only

### Issue: Weak Key Rejected

**Symptom:** RSA <2048 bits rejected

**Solution:** Regenerate with 2048+ bits

### Issue: SHA-1 Certificate Fails

**Symptom:** Certificate with SHA-1 signature rejected

**Solution:** Use SHA-256+ certificates

---

## Cleanup

```bash
sudo ./cleanup.sh
```

**Note:** Disabling FIPS requires another reboot.

---

**Difficulty Level:** Advanced
**Note:** FIPS mode has significant compatibility implications
