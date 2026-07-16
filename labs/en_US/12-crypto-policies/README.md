# Lab 12: Crypto-Policies

## Learning Objectives

By completing this lab, you will:
- Understand RHEL crypto-policies system
- Check current cryptographic policy
- Switch between policy levels (DEFAULT, FUTURE, LEGACY)
- Test service compatibility with policies
- Create custom policy modules
- Understand impact on TLS/SSL services

## Prerequisites

- **RHEL Version:** 8, 9, or 10 (crypto-policies introduced in RHEL 8)
- **System Access:** Root/sudo required
- **Previous labs:** Understanding of TLS services helpful

## Time Estimate

**30-40 minutes**

## Lab Overview

Crypto-policies is a system-wide cryptographic policy framework in RHEL 8+. Learn to manage security levels across all system services uniformly, understanding the trade-offs between security and compatibility.

---

## Instructions

### Step 1: Check Current Policy

Check the current crypto-policy:

```bash
./check-policy.sh
```

This shows:
- Current active policy
- Policy configuration files
- Affected services

---

### Step 2: Switch to LEGACY Policy

Test LEGACY policy for maximum compatibility:

```bash
sudo ./switch-legacy.sh
```

This:
- Switches to LEGACY policy
- Updates all service configurations
- Tests compatibility

---

### Step 3: Switch to FUTURE Policy

Test FUTURE policy for maximum security:

```bash
sudo ./switch-future.sh
```

This:
- Switches to FUTURE policy
- Shows stricter requirements
- Tests service compatibility

---

### Step 4: Test Compatibility

Test how services behave under different policies:

```bash
./test-compatibility.sh
```

This tests:
- TLS versions allowed
- Cipher suites available
- SSH algorithms supported
- Service functionality

---

### Step 5: Restore Default Policy

Return to DEFAULT policy:

```bash
sudo ./restore-default.sh
```

This:
- Restores DEFAULT policy
- Resets all services
- Verifies restoration

---

### Step 6: Verify Configuration

Run comprehensive validation:

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
- ✅ Understanding of crypto-policies
- ✅ Ability to switch policies
- ✅ Knowledge of policy impacts
- ✅ Tested multiple policy levels
- ✅ Restored system to DEFAULT

---

## Key Concepts

### Crypto-Policies Overview

**Purpose:**
- System-wide cryptographic standards
- Consistent security across services
- Easy policy management
- Balance security vs compatibility

**Supported Services:**
- OpenSSL
- GnuTLS
- NSS
- OpenSSH
- Kerberos
- BIND
- Apache
- NGINX

### Policy Levels

| Policy | Description | Use Case |
|--------|-------------|----------|
| **DEFAULT** | Balanced security | Normal operations |
| **LEGACY** | Weak algorithms allowed | Old systems/compatibility |
| **FUTURE** | Strong algorithms only | High security needs |
| **FIPS** | FIPS 140-2 compliant | Government/compliance |

### Policy Characteristics

**DEFAULT:**
- TLS 1.2+
- SHA-1 signatures in DNSSec
- SSH RSA 2048+
- Balanced for most environments

**LEGACY:**
- TLS 1.0+
- Weak ciphers allowed
- SHA-1 signatures allowed
- Maximum compatibility

**FUTURE:**
- TLS 1.3 preferred
- Strong ciphers only
- Larger key sizes
- Forward-looking security

**FIPS:**
- FIPS 140-2 approved algorithms
- No MD5, SHA-1 signatures
- Specific cipher suites
- Compliance requirement

### Commands

```bash
# Check current policy
update-crypto-policies --show

# Set policy
update-crypto-policies --set LEGACY
update-crypto-policies --set DEFAULT
update-crypto-policies --set FUTURE

# List available policies
ls /usr/share/crypto-policies/policies/

# View policy details
cat /usr/share/crypto-policies/policies/DEFAULT.pol

# Apply custom module
update-crypto-policies --set DEFAULT:module-name
```

### Configuration Files

```
/etc/crypto-policies/
├── config                           # Active policy
├── back-ends/                       # Service-specific configs
│   ├── openssh.config
│   ├── openssl.config
│   ├── gnutls.config
│   └── nss.config
└── state/
    └── current                      # Symlink to current policy
```

---

## Troubleshooting

### Issue: Services Fail After Policy Change

**Symptom:**
```
SSL handshake failed
Connection refused
```

**Solution:**
Switch back to DEFAULT or LEGACY:
```bash
update-crypto-policies --set DEFAULT
systemctl restart <service>
```

---

### Issue: Cannot Switch Policy

**Symptom:**
```
Setting system policy failed
```

**Solution:**
Check logs and permissions:
```bash
journalctl -xe
# Ensure you're root
sudo update-crypto-policies --set DEFAULT
```

---

### Issue: Legacy Clients Cannot Connect

**Symptom:**
Old clients fail with FUTURE/DEFAULT policy

**Solution:**
Temporarily use LEGACY or create custom module:
```bash
# Option 1: Use LEGACY
update-crypto-policies --set LEGACY

# Option 2: Create custom module allowing specific algorithms
```

---

## Version-Specific Notes

### RHEL 8
- Crypto-policies introduced
- DEFAULT policy is balanced
- Most services supported
- Manual restart required after policy change

### RHEL 9
- Enhanced crypto-policies
- Stricter DEFAULT policy
- SHA-1 blocked by default
- Better automatic service restart

### RHEL 10 (Beta/Preview)
- Further hardened defaults
- More granular control
- Extended service support

---

## Cleanup

```bash
sudo ./cleanup.sh
```

This restores DEFAULT policy.

---

## Additional Resources

**Related Chapters:**
- Chapter 23: Crypto-Policies Deep Dive

**Documentation:**
- `man update-crypto-policies`
- `man crypto-policies`
- `/usr/share/doc/crypto-policies/`
- https://access.redhat.com/articles/3642912

**Policy Files:**
- `/usr/share/crypto-policies/policies/`
- `/etc/crypto-policies/config`

---

## Next Steps

Proceed to **Lab 13: Let's Encrypt/Certbot** to learn ACME certificate automation.

---

**Difficulty Level**: Intermediate  
**Note**: This lab requires RHEL 8+ (crypto-policies not available in RHEL 7)
