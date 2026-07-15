# Lab 17: RHEL 7→8 Certificate Migration

## Learning Objectives

By completing this lab, you will:
- Understand certificate compatibility between RHEL 7 and 8
- Migrate certificates during OS upgrade
- Handle crypto-policies introduction
- Update certificate configurations
- Test certificates after migration
- Troubleshoot migration issues

## Prerequisites

- **Understanding of RHEL 7 and 8** differences
- **Labs 01-10** completed (certificate fundamentals)
- **Lab spans both systems** — run assessment/backup/preparation on RHEL 7, then run `configure-rhel8.sh` and `validate-migration.sh` on the upgraded RHEL 8 system
- **System Access:** Root/sudo required

## Time Estimate

**40-50 minutes**

## Lab Overview

RHEL 8 introduces significant changes to certificate management, primarily the crypto-policies system. Learn to migrate certificates from RHEL 7 to RHEL 8 while maintaining security and compatibility.

---

## Key Differences: RHEL 7 vs RHEL 8

### Crypto-Policies

**RHEL 7:**
- No system-wide crypto-policies
- Manual TLS configuration in each service
- Application-specific cipher configuration

**RHEL 8:**
- System-wide crypto-policies framework
- Centralized cryptographic standards
- Automatic configuration for services

### TLS Protocols

**RHEL 7:**
- TLS 1.0, 1.1, 1.2 supported by default
- Manual protocol selection
- Older ciphers allowed

**RHEL 8:**
- TLS 1.2+ by default (DEFAULT policy)
- TLS 1.0/1.1 disabled
- Stronger cipher requirements

### Certificate Validation

**RHEL 7:**
- More permissive validation
- SHA-1 signatures allowed
- Looser certificate requirements

**RHEL 8:**
- Stricter validation
- SHA-1 blocked in DEFAULT policy
- SANs preferred over CN

---

## Instructions

### Step 1: Pre-Migration Assessment

Assess current certificate state:

```bash
./assess-rhel7.sh
```

This checks:
- Current certificates
- TLS configurations
- Potential compatibility issues
- Services using certificates

---

### Step 2: Backup Certificates

Backup all certificates before migration:

```bash
sudo ./backup-certificates.sh
```

Creates comprehensive backup of:
- All certificate files
- Configuration files
- Trust store
- Service configurations

---

### Step 3: Migration Preparation

Prepare for migration:

```bash
./prepare-migration.sh
```

This:
- Identifies incompatible certificates
- Checks for SHA-1 signatures
- Reviews TLS configurations
- Creates migration checklist

---

### Step 4: Post-Upgrade Configuration (RHEL 8)

On the upgraded RHEL 8 system, configure crypto-policies:

```bash
sudo ./configure-rhel8.sh
```

This:
- Sets appropriate crypto-policy
- Updates service configurations
- Migrates TLS settings
- Tests connectivity

---

### Step 5: Validate Migration on RHEL 8

On the upgraded RHEL 8 system, verify everything works:

```bash
./validate-migration.sh
```

Tests:
- Certificate validity
- Service functionality
- TLS connections
- Crypto-policy application

---

## Validation

Verify successful migration on RHEL 8:

```bash
./validate-migration.sh
```

**Expected Results:**
- ✓ All services running on RHEL 8
- ✓ Certificates valid and accepted
- ✓ Crypto-policies active and enforced
- ✓ TLS connections working
- ✓ No compatibility errors in logs

**Manual Checks:**
1. Check crypto-policy: `update-crypto-policies --show`
2. Test service connections: `curl https://localhost`
3. Verify certificate validity: `openssl s_client -connect localhost:443`
4. Check service logs for errors

---

## Migration Checklist

### Before Migration (RHEL 7)

- [ ] Document all certificates in use
- [ ] Backup certificate files
- [ ] Backup service configurations
- [ ] Test current functionality
- [ ] Identify SHA-1 certificates
- [ ] Check certificate expiration dates
- [ ] Document custom TLS configurations

### During Migration

- [ ] Perform OS upgrade to RHEL 8
- [ ] Preserve `/etc/pki/` directory
- [ ] Note crypto-policy warnings
- [ ] Keep migration logs

### After Migration (RHEL 8)

- [ ] Verify certificates present
- [ ] Check crypto-policy setting
- [ ] Update service configs for crypto-policies
- [ ] Test all services
- [ ] Replace SHA-1 certificates if needed
- [ ] Update monitoring
- [ ] Document changes

---

## Common Issues

### Issue: TLS 1.0/1.1 Clients Fail

**Symptom:** Old clients cannot connect after migration

**Solution:**
```bash
# Temporarily use LEGACY policy
sudo update-crypto-policies --set LEGACY

# Or create custom policy allowing TLS 1.0/1.1
```

---

### Issue: SHA-1 Certificates Rejected

**Symptom:** Certificates with SHA-1 signatures fail

**Solution:**
```bash
# Replace with SHA-256 certificates
# Or temporarily use LEGACY policy
sudo update-crypto-policies --set LEGACY
```

---

### Issue: Service Won't Start

**Symptom:** Service fails after migration with SSL errors

**Solution:**
```bash
# Check service configuration
journalctl -xeu service-name

# Update to use crypto-policies
# Remove manual TLS protocol/cipher settings
```

---

## Best Practices

### Certificate Requirements for RHEL 8

1. **Use SHA-256 or stronger** - No SHA-1
2. **Include SANs** - Don't rely only on CN
3. **RSA 2048+ or ECC** - Strong key sizes
4. **Valid certificate chain** - Include intermediates
5. **Not expired** - Valid dates

### Configuration Migration

**Remove from service configs:**
- Manual `SSLProtocol` settings
- Manual `SSLCipherSuite` settings
- Hardcoded TLS versions
- Cipher lists

**Let crypto-policies handle:**
- TLS protocol versions
- Cipher suite selection
- Security levels

---

## Cleanup

```bash
sudo ./cleanup.sh
```

Removes migration artifacts and test files.

---

## Additional Resources

**Related Chapters:**
- Chapter 35: RHEL 7→8 Migration
- Chapter 10: RHEL 8 & Crypto-Policies

**Documentation:**
- RHEL 8 Upgrading Guide
- `man update-crypto-policies`
- `/usr/share/doc/crypto-policies/`

**Key Changes:**
- https://access.redhat.com/articles/3642912 (Crypto-policies)
- https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/

---

## Next Steps

Proceed to **Lab 18: RHEL 8→9 Migration** to learn about the next upgrade path.

---

**Difficulty Level:** Advanced
**Note:** Test migration in non-production environment first
