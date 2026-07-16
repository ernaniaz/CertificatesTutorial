# Lab 02: Key Generation

## Learning Objectives

By completing this lab, you will:
- Generate RSA key pairs (2048-bit and 4096-bit)
- Generate Elliptic Curve (ECC) key pairs (P-256 and P-384)
- Extract public keys from private keys
- Understand key file formats and permissions
- Compare different key sizes and algorithms

## Prerequisites

- **Lab 01** completed (environment setup)
- **RHEL Version:** 7, 8, 9, or 10
- **System Access:** Regular user (root not required)

## Time Estimate

**20-25 minutes**

## Lab Overview

Learn to generate cryptographic key pairs using OpenSSL. Keys are the foundation of certificate operations - understanding how to create and manage them is essential.

---

## Instructions

### Step 1: Generate RSA Keys

Run the RSA key generation script:

```bash
./generate-rsa-keys.sh
```

This creates:
- `output/rsa-2048.key` - 2048-bit RSA private key (minimum for production)
- `output/rsa-2048.pub` - Corresponding public key
- `output/rsa-4096.key` - 4096-bit RSA private key (recommended for high security)
- `output/rsa-4096.pub` - Corresponding public key

**View a key:**
```bash
openssl pkey -in output/rsa-2048.key -text -noout | head -20
```

---

### Step 2: Generate ECC Keys

Run the ECC key generation script:

```bash
./generate-ecc-keys.sh
```

This creates:
- `output/ecc-p256.key` - P-256 (secp256r1) private key
- `output/ecc-p256.pub` - Corresponding public key
- `output/ecc-p384.key` - P-384 (secp384r1) private key
- `output/ecc-p384.pub` - Corresponding public key

**View an ECC key:**
```bash
openssl pkey -in output/ecc-p256.key -text -noout
```

---

### Step 3: Verify Keys

Run the verification script:

```bash
./verify-keys.sh
```

This validates:
- All keys were generated successfully
- Private keys have correct permissions (600)
- Public keys have correct permissions (644)
- Keys are valid OpenSSL format

---

### Step 4: Compare Key Sizes

View file sizes:

```bash
ls -lh output/
```

**Observation:**
- RSA keys are larger files
- ECC keys are much smaller for equivalent security
- P-256 ECC ≈ 3072-bit RSA security
- P-384 ECC ≈ 7680-bit RSA security

---

## Validation

Run the test script:

```bash
./test.sh
```

All checks should pass.

## Expected Outcome

After completing this lab, you should have:
- ✅ RSA 2048 and 4096-bit key pairs generated
- ✅ ECC P-256 and P-384 key pairs generated
- ✅ All keys with correct permissions
- ✅ Understanding of RSA vs ECC differences

---

## Troubleshooting

### Issue: Permission Denied

**Symptom:**
```
Permission denied: output/
```

**Solution:**
```bash
mkdir -p output
chmod 755 output
```

---

### Issue: OpenSSL Command Not Found

**Symptom:**
```
bash: openssl: command not found
```

**Solution:**
Return to Lab 01 and run setup script.

---

## Key Concepts

### RSA Key Sizes
- **2048-bit:** Minimum for RHEL 8+ crypto-policies DEFAULT
- **4096-bit:** Recommended for long-term security

### ECC Curves
- **P-256 (prime256v1):** Minimum, equivalent to 3072-bit RSA
- **P-384 (secp384r1):** Stronger, equivalent to 7680-bit RSA

### File Permissions
- **Private keys:** Mode 600 (read/write owner only)
- **Public keys:** Mode 644 (readable by all)

---

## Cleanup

```bash
./cleanup.sh
```

This removes the `output/` directory and all generated keys.

---

## Additional Resources

**Related Chapters:**
- Chapter 4: Basic Cryptography for RHEL Admins

**Documentation:**
- `man genpkey`
- `man pkey`
- `man ecparam`

---

## Next Steps

Proceed to **Lab 03: Digital Signatures** to learn how to sign and verify files using these keys.

---

**Difficulty Level**: Beginner
