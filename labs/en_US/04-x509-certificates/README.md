# Lab 04: X.509 Certificates

## Learning Objectives

By completing this lab, you will:
- Create self-signed X.509 certificates
- Generate Certificate Signing Requests (CSRs)
- Inspect certificate fields (subject, issuer, dates, SANs)
- Understand Subject Alternative Names (SANs)
- Convert between PEM and DER formats
- Verify certificate validity

## Prerequisites

- **Lab 02** completed (key generation)
- **RHEL Version:** 7, 8, 9, or 10

## Time Estimate

**25-30 minutes**

## Lab Overview

X.509 is the standard certificate format used everywhere on RHEL. Learn to create, inspect, and validate X.509 certificates.

---

## Instructions

### Step 1: Create a Self-Signed Certificate

Generate a self-signed certificate:

```bash
./create-self-signed.sh
```

This creates:
- `output/server.crt` - Self-signed certificate
- Uses RSA-2048 key from Lab 02
- Includes Subject Alternative Names (SANs)

**Inspect the certificate:**
```bash
openssl x509 -in output/server.crt -text -noout | head -40
```

---

### Step 2: Create a Certificate Signing Request (CSR)

Generate a CSR (for submitting to a CA):

```bash
./create-csr.sh
```

Creates `output/server.csr` with:
- Subject: /CN=server.example.com/O=Lab/C=US
- SANs: server.example.com, www.example.com

**Inspect the CSR:**
```bash
openssl req -in output/server.csr -text -noout
```

---

### Step 3: Inspect Certificate Fields

Run the inspection script:

```bash
./inspect-cert.sh
```

This displays:
- Subject (who the certificate identifies)
- Issuer (who signed it - same for self-signed)
- Validity dates (Not Before / Not After)
- Subject Alternative Names (SANs) - REQUIRED on RHEL 9+
- Public key algorithm and size
- Signature algorithm

---

### Step 4: Convert Formats

Convert between PEM and DER:

```bash
./convert-formats.sh
```

Creates:
- `output/server.der` - Binary DER format
- `output/server-from-der.pem` - Converted back to PEM

**Compare file sizes:**
```bash
ls -lh output/server.{crt,der}
```

DER is binary (smaller), PEM is Base64 (human-readable).

---

## Validation

```bash
./test.sh
```

All checks should pass.

## Expected Outcome

After completing this lab:
- ✅ Self-signed certificate created
- ✅ CSR created successfully
- ✅ Understanding of certificate structure
- ✅ Can inspect certificate fields
- ✅ Can convert between PEM and DER

---

## Key Concepts

### X.509 Certificate Structure

| Field | Purpose |
|-------|---------|
| Version | v3 (includes extensions) |
| Serial Number | Unique identifier |
| Signature Algorithm | How certificate is signed (e.g., sha256WithRSAEncryption) |
| Issuer | Who signed the certificate (CA) |
| Validity | Not Before / Not After dates |
| Subject | Who the certificate identifies |
| Public Key | Subject's public key |
| Extensions | SANs, Key Usage, etc. |
| Signature | CA's digital signature |

### Subject Alternative Names (SANs)

**Critical for RHEL 9+**: Certificates MUST include SANs for hostname validation.

Example:
```
X509v3 Subject Alternative Name:
    DNS:server.example.com, DNS:www.example.com, IP:192.168.1.10
```

### PEM vs DER

- **PEM**: Base64-encoded, `-----BEGIN CERTIFICATE-----` headers
- **DER**: Binary ASN.1, used by some applications and devices

---

## Troubleshooting

### Issue: SANs Not Included

**Symptom:**
Certificate doesn't include Subject Alternative Names

**Solution:**
RHEL 9+ requires explicit SAN configuration. The scripts include SANs automatically.

---

### Issue: Certificate Already Expired

**Symptom:**
```
notAfter=... (certificate has expired)
```

**Solution:**
Self-signed certificates created with 365-day validity. Regenerate if expired:
```bash
./create-self-signed.sh
```

---

## Version-Specific Notes

### RHEL 7-8
- SANs recommended but not strictly required
- Browser warnings without SANs

### RHEL 9+
- SANs **REQUIRED** for validation
- SHA-1 signatures blocked
- Use SHA-256 or better

---

## Cleanup

```bash
./cleanup.sh
```

---

## Additional Resources

**Related Chapters:**
- Chapter 5: X.509 Certificates on RHEL

**Documentation:**
- `man x509`
- `man req`

---

## Next Steps

Proceed to **Lab 05: Trust Store Management** to learn about system-wide CA trust.

---

**Difficulty Level:** Beginner
