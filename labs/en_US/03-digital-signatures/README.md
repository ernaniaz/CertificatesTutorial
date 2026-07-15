# Lab 03: Digital Signatures

## Learning Objectives

By completing this lab, you will:
- Sign files using private keys
- Verify signatures using public keys
- Understand hash algorithms (SHA-256)
- Demonstrate tampering detection
- Practice signature validation workflows

## Prerequisites

- **Lab 02** completed (key generation)
- **RHEL Version:** 7, 8, 9, or 10

## Time Estimate

**20 minutes**

## Lab Overview

Digital signatures prove authenticity and integrity. Learn how to sign files and verify that signatures detect any tampering.

---

## Instructions

### Step 1: Sign a File

Sign the sample file:

```bash
./sign-file.sh
```

This creates `sample-data.sig` - a digital signature of `sample-data.txt`.

**View signature (hex):**
```bash
hexdump -C sample-data.sig | head -5
```

---

### Step 2: Verify the Signature

Verify the signature:

```bash
./verify-signature.sh
```

**Expected output:**
```
Verified OK
```

---

### Step 3: Tamper Detection Test

Demonstrate that signatures detect tampering:

```bash
./tamper-test.sh
```

The script:
1. Modifies the file
2. Attempts to verify with original signature
3. **Should fail** - proving tampering detected

---

## Validation

```bash
./test.sh
```

All tests should pass.

## Expected Outcome

After completing this lab:
- ✅ File signed successfully
- ✅ Signature verifies correctly
- ✅ Tampered file fails verification
- ✅ Understanding of digital signature workflow

---

## Key Concepts

### Digital Signature Process

1. **Hash** the message (SHA-256)
2. **Encrypt** hash with private key = signature
3. **Send** message + signature
4. **Decrypt** signature with public key = original hash
5. **Hash** the received message
6. **Compare** hashes - match = valid

### Why This Works

- Only the private key holder can create valid signatures
- Anyone with the public key can verify
- Any change to the message changes the hash
- Signature won't match if message was altered

---

## Troubleshooting

### Issue: Keys Not Found

**Symptom:**
```
Error: ../02-key-generation/output/rsa-2048.key not found
```

**Solution:**
Complete Lab 02 first:
```bash
cd ../02-key-generation
./generate-rsa-keys.sh
cd ../03-digital-signatures
```

---

## Cleanup

```bash
./cleanup.sh
```

---

## Additional Resources

**Related Chapters:**
- Chapter 7: Digital Signatures & Verification on RHEL

---

## Next Steps

Proceed to **Lab 04: X.509 Certificates** to create actual certificates.

---

**Difficulty Level:** Beginner
