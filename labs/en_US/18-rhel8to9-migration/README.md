# Lab 18: RHEL 8→9 Certificate Migration

## Learning Objectives

By completing this lab, you will:
- Understand certificate changes in RHEL 9
- Handle OpenSSL 3.x migration
- Deal with stricter security defaults
- Update deprecated algorithms
- Test certificates after upgrade
- Troubleshoot RHEL 9-specific issues

## Prerequisites

- **Understanding of RHEL 8 and 9** differences
- **Labs 01-17** completed
- **Lab spans both systems** — run assessment/backup/compatibility checks on RHEL 8, then run `configure-rhel9.sh` and `validate-migration.sh` on the upgraded RHEL 9 system
- **System Access:** Root/sudo required

## Time Estimate

**40-50 minutes**

## Lab Overview

RHEL 9 introduces OpenSSL 3.x with stricter security defaults. Learn to migrate certificates while adapting to enhanced security requirements and deprecated algorithm handling.

---

## Key Differences: RHEL 8 vs RHEL 9

### OpenSSL Version

**RHEL 8:**
- OpenSSL 1.1.1
- More permissive defaults
- Legacy algorithm support

**RHEL 9:**
- OpenSSL 3.0+
- Stricter security defaults
- Legacy algorithms in separate provider
- Enhanced deprecation warnings

### Security Defaults

**RHEL 8:**
- DEFAULT policy allows some older options
- SHA-1 signatures allowed in LEGACY
- More lenient certificate validation

**RHEL 9:**
- Stricter DEFAULT policy
- SHA-1 completely blocked
- SANs required (CN-only deprecated)
- Minimum key sizes enforced

### Crypto-Policies

**RHEL 8:**
- DEFAULT, LEGACY, FUTURE, FIPS
- System-wide but with exceptions

**RHEL 9:**
- Same policy levels
- Stricter enforcement
- Better integration with OpenSSL 3
- Legacy provider for compatibility

---

## Instructions

### Step 1: Pre-Migration Assessment

Assess RHEL 8 certificate state:

```bash
./assess-rhel8.sh
```

Checks:
- Current certificates compatibility
- OpenSSL 1.1.1 usage
- Deprecated algorithms
- Service configurations

---

### Step 2: Backup Everything

Back up certificates on the current RHEL 8 host before upgrading:

```bash
sudo ./backup-certificates.sh
```

Backs up:
- All certificates and keys under `/etc/pki/`
- Service configurations (Apache, NGINX, Postfix, OpenLDAP when present)
- Crypto-policies configuration and current policy
- Compressed archive for off-system storage

---

### Step 3: Identify Compatibility Issues

Find potential problems:

```bash
./check-compatibility.sh
```

Identifies:
- Certificates without SANs
- Weak key sizes
- Deprecated algorithms
- Configuration issues

---

### Step 4: Post-Upgrade Configuration (RHEL 9)

On the upgraded RHEL 9 system:

```bash
sudo ./configure-rhel9.sh
```

Configures:
- OpenSSL 3.x settings
- Updated crypto-policies
- Service adaptations
- Legacy provider if needed

---

### Step 5: Validate Migration on RHEL 9

On the upgraded RHEL 9 system, run comprehensive validation:

```bash
./validate-migration.sh
```

Tests:
- OpenSSL 3.x functionality
- Certificate validity
- Service operations
- TLS connections

---

## Migration Checklist

### Before Migration (RHEL 8)

- [ ] Backup all certificates
- [ ] Document crypto-policy
- [ ] Check for CN-only certificates
- [ ] Verify key sizes (RSA 2048+)
- [ ] Test certificate chains
- [ ] Document custom OpenSSL configs
- [ ] Check for legacy algorithms

### During Migration

- [ ] Perform OS upgrade to RHEL 9
- [ ] Note OpenSSL 3.x warnings
- [ ] Preserve configurations
- [ ] Keep upgrade logs

### After Migration (RHEL 9)

- [ ] Verify OpenSSL 3.x active
- [ ] Check crypto-policy
- [ ] Test all services
- [ ] Update certificates if needed
- [ ] Enable legacy provider if required
- [ ] Validate TLS connections
- [ ] Update monitoring

---

## Validation

Verify successful RHEL 9 migration:

```bash
./validate-migration.sh
```

**Expected Results:**
- ✓ OpenSSL 3.x active
- ✓ All certificates use SHA-256+ signatures
- ✓ Certificates include SANs
- ✓ Services running without errors
- ✓ Crypto-policies enforced
- ✓ No deprecated algorithm warnings

**Manual Verification:**
1. Check OpenSSL version: `openssl version`
2. Verify certificates: `openssl x509 -in cert.pem -noout -text`
3. Test connections: `curl -v https://localhost`
4. Check for SANs in all certificates
5. Review logs for deprecation warnings

---

## Common Issues

### Issue: Certificate Without SAN

**Symptom:** Certificate rejected, "no SAN" error

**Solution:**
```bash
# Regenerate with SANs or use legacy provider temporarily
# To enable legacy provider:
sudo update-crypto-policies --set DEFAULT:FEDORA32
```

---

### Issue: Weak Key Size Rejected

**Symptom:** RSA keys <2048 bits rejected

**Solution:**
```bash
# Regenerate with larger key
openssl genrsa -out new.key 2048
# Or enable legacy provider (not recommended)
```

---

### Issue: Service Won't Start

**Symptom:** SSL/TLS init errors in OpenSSL 3.x

**Solution:**
```bash
# Check for deprecated API usage
journalctl -xeu service-name

# Update application or enable legacy provider
# Edit /etc/pki/tls/openssl.cnf:
# openssl_conf = openssl_init
# [openssl_init]
# providers = provider_sect
# [provider_sect]
# default = default_sect
# legacy = legacy_sect
# [default_sect]
# activate = 1
# [legacy_sect]
# activate = 1
```

---

## OpenSSL 3.x Changes

### Provider Architecture

OpenSSL 3.x uses providers:
- **default** - Standard algorithms
- **legacy** - Deprecated algorithms (MD5, DES, etc.)
- **fips** - FIPS approved algorithms

### Enable Legacy Provider

```bash
# System-wide (not recommended)
sudo tee -a /etc/pki/tls/openssl.cnf << 'EOF'
openssl_conf = openssl_init

[openssl_init]
providers = provider_sect

[provider_sect]
default = default_sect
legacy = legacy_sect

[default_sect]
activate = 1

[legacy_sect]
activate = 1
EOF
```

### Certificate Requirements

**RHEL 9 Requirements:**
1. **SANs required** - Don't rely on CN only
2. **RSA 2048+ bits** - Minimum key size
3. **SHA-256+ signatures** - No SHA-1
4. **Valid chain** - Complete certificate chain
5. **Proper extensions** - Key usage, extended key usage

---

## Best Practices

### Certificate Generation for RHEL 9

```bash
# Generate with SANs
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout server.key -out server.crt -days 365 \
  -subj "/CN=server.example.com" \
  -addext "subjectAltName=DNS:server.example.com,DNS:www.example.com"
```

### Testing Compatibility

```bash
# Test with OpenSSL 3.x
openssl version
openssl s_client -connect localhost:443

# Check certificate SANs
openssl x509 -in cert.pem -noout -ext subjectAltName

# Verify with strict settings
openssl verify -CAfile ca.pem cert.pem
```

---

## Cleanup

```bash
sudo ./cleanup.sh
```

Removes migration artifacts.

---

## Additional Resources

**Related Chapters:**
- Chapter 36: RHEL 8→9 Migration
- Chapter 11: RHEL 9 Modern Security

**Documentation:**
- RHEL 9 Release Notes
- OpenSSL 3.x Migration Guide
- `man openssl-providers`

**Key Changes:**
- https://www.openssl.org/docs/man3.0/man7/migration_guide.html
- https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/

---

## Next Steps

You've completed migration labs! Next:
- **Lab 19-20:** Security labs (FIPS, Hardening)
- **Lab 21-22:** Advanced topics (Kubernetes, Vault)

---

**Difficulty Level:** Advanced
**Note:** OpenSSL 3.x requires careful testing
