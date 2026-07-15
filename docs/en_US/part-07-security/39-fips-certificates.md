# Chapter 39: FIPS-Compliant Certificates

> **Compliance Ready:** Learn how to generate, validate, and manage FIPS-compliant certificates on RHEL for federal and regulated environments.

---

## 39.1 FIPS Certificate Requirements

### Mandatory Requirements

**For FIPS 140-2/140-3 Compliance:**

```
✅ Key Algorithm: RSA 2048+ or ECC P-256/384/521
✅ Signature: SHA-256, SHA-384, or SHA-512
✅ TLS Protocols: 1.2 or 1.3 only
✅ Generated in FIPS mode (for new keys)
✅ Validated module used for operations

❌ NO MD5, SHA-1
❌ NO RSA < 2048 bits
❌ NO TLS 1.0/1.1
❌ NO 3DES, RC4, DES
❌ NO non-approved algorithms
```

---

## 39.2 Generating FIPS Certificates

### Complete FIPS Certificate Workflow

```bash
#============================================#
# COMPLETE FIPS CERTIFICATE GENERATION
#============================================#

# Prerequisites: FIPS mode must be enabled
fips-mode-setup --check
# FIPS mode is enabled.

# Step 1: Generate FIPS-compliant RSA key
openssl genpkey -algorithm RSA \
  -out /etc/pki/tls/private/fips-server.key \
  -pkeyopt rsa_keygen_bits:2048

# Or stronger (3072/4096)
openssl genpkey -algorithm RSA \
  -out /etc/pki/tls/private/fips-server.key \
  -pkeyopt rsa_keygen_bits:3072

# Step 2: Set permissions
sudo chmod 600 /etc/pki/tls/private/fips-server.key

# Step 3: Generate CSR with SHA-256
openssl req -new \
  -key /etc/pki/tls/private/fips-server.key \
  -out /tmp/fips-server.csr \
  -sha256 \
  -subj "/C=US/O=Federal Agency/OU=IT/CN=secure.example.gov" \
  -addext "subjectAltName=DNS:secure.example.gov,DNS:www.secure.example.gov"

# Step 4: Verify CSR
openssl req -in /tmp/fips-server.csr -noout -text | grep -E "(Signature Algorithm|Public-Key)"
# Signature Algorithm: sha256WithRSAEncryption  ← Must be SHA-256+
# Public-Key: (2048 bit)  ← Must be 2048+

# Step 5: Submit to FIPS-compliant CA
# Get certificate back

# Step 6: Verify certificate compliance
openssl x509 -in fips-server.crt -noout -text | grep "Signature Algorithm"
# Signature Algorithm: sha256WithRSAEncryption  ← Good!
```

### FIPS-Compliant EC Keys

```bash
#============================================#
# ELLIPTIC CURVE KEYS FOR FIPS
#============================================#

# P-256 (FIPS-approved)
openssl genpkey -algorithm EC \
  -out /etc/pki/tls/private/fips-ec.key \
  -pkeyopt ec_paramgen_curve:P-256

# P-384 (stronger, FIPS-approved)
openssl genpkey -algorithm EC \
  -out /etc/pki/tls/private/fips-ec.key \
  -pkeyopt ec_paramgen_curve:P-384

# Generate CSR
openssl req -new -key /etc/pki/tls/private/fips-ec.key \
  -out /tmp/fips-ec.csr \
  -sha256 \
  -subj "/CN=secure.example.gov"
```

---

## 39.3 Validating FIPS Compliance

### Certificate Compliance Check

```bash
#!/bin/bash
# check-fips-compliance.sh
# Verify certificate is FIPS-compliant

CERT=$1

if [ -z "$CERT" ] || [ ! -f "$CERT" ]; then
  echo "Usage: $0 /path/to/certificate.crt"
  exit 1
fi

echo "=== FIPS Compliance Check ==="
echo "Certificate: $CERT"
echo ""

COMPLIANT=true

# Check signature algorithm
SIG_ALG=$(openssl x509 -in "$CERT" -noout -text | grep "Signature Algorithm" | head -2)
echo "Signature Algorithm: $SIG_ALG"

if echo "$SIG_ALG" | grep -Eqi "md5|sha1"; then
  echo "  ❌ FAIL: MD5/SHA-1 not FIPS-approved"
  COMPLIANT=false
else
  echo "  ✅ PASS: FIPS-approved signature"
fi

# Check key size
KEY_SIZE=$(openssl x509 -in "$CERT" -noout -text | grep "Public-Key" | grep -oP '\d+')
echo ""
echo "Key Size: $KEY_SIZE bits"

if [ "$KEY_SIZE" -lt 2048 ]; then
  echo "  ❌ FAIL: Key size < 2048 bits"
  COMPLIANT=false
else
  echo "  ✅ PASS: Key size adequate"
fi

# Check key algorithm
KEY_ALG=$(openssl x509 -in "$CERT" -noout -text | grep "Public Key Algorithm")
echo ""
echo "Key Algorithm: $KEY_ALG"

if echo "$KEY_ALG" | grep -qi "dsa"; then
  echo "  ❌ FAIL: DSA not FIPS-approved"
  COMPLIANT=false
fi

# Final result
echo ""
echo "================================"
if [ "$COMPLIANT" = true ]; then
  echo "✅ Certificate is FIPS-COMPLIANT"
  exit 0
else
  echo "❌ Certificate is NOT FIPS-compliant"
  echo "   Reissue with FIPS-approved parameters"
  exit 1
fi
```

---

## 39.4 FIPS CA Selection

### CA Must Be FIPS-Validated

**Internal CA:**
- Use FreeIPA in FIPS mode
- Dogtag PKI (FreeIPA's CA) has FIPS validation

**External CA:**
- Verify CA is FIPS 140-2/140-3 validated
- Request FIPS compliance documentation
- Common FIPS CAs: DigiCert Federal, Entrust, IdenTrust

---

## 39.5 Service Configuration for FIPS

### Services Automatically FIPS-Compliant

When FIPS mode enabled, all services automatically use FIPS crypto-policy:

```bash
# Apache - no special config needed
# Just ensure certificate is FIPS-compliant

# NGINX - automatically uses FIPS policy

# Postfix - FIPS-compliant automatically

# Verify each service
openssl s_client -connect localhost:443
# Check cipher used - should be FIPS-approved
```

---

## 39.6 Key Takeaways

1. **FIPS 140-2 is current** validated standard on RHEL
2. **FIPS 140-3 transition** is in progress
3. **Enable at installation** for best results
4. **RSA 2048+ or ECC P-256/384** only
5. **SHA-256+ signatures** required
6. **Services automatically comply** with FIPS policy
7. **Test applications** before enabling FIPS

---

## Quick Reference Card

```
┌───────────────────────────────────────────────────────────────┐
│ FIPS-COMPLIANT CERTIFICATES QUICK REFERENCE                   │
├───────────────────────────────────────────────────────────────┤
│ Standard:   FIPS 140-2 (current validated)                    │
│             FIPS 140-3 (transition in progress)               │
│                                                               │
│ Keys:       RSA 2048/3072/4096                                │
│             ECC P-256/384/521                                 │
│                                                               │
│ Signature:  SHA-256, SHA-384, SHA-512                         │
│             (NO MD5, NO SHA-1)                                │
│                                                               │
│ Generate:   openssl genpkey -algorithm RSA ... (in FIPS mode) │
│ CSR:        openssl req -new -sha256 ...                      │
│ Verify:     Check signature alg, key size                     │
│                                                               │
│ Test:       echo test | openssl md5                           │
│             (should fail if FIPS working)                     │
└───────────────────────────────────────────────────────────────┘

✅ FIPS mode must be enabled for compliance
✅ All operations use validated cryptographic modules
⚠️ Check current 140-2/140-3 status for your needs
```
---

**Chapter Navigation**

| [← Previous: Chapter 38 - FIPS Mode Complete Guide](38-fips-mode-guide.md) | [Next: Chapter 40 - RHEL Security Hardening for Certificates →](40-security-hardening.md) |
|:---|---:|
