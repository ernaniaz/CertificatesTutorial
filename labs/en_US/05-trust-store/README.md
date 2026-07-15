# Lab 05: Trust Store Management

## Learning Objectives

By completing this lab, you will:
- Create a custom Certificate Authority (CA)
- Add custom CA to system trust store
- Use update-ca-trust to update the system
- Verify CA trust operations
- Remove custom CAs from trust
- Understand /etc/pki/ca-trust/ structure

## Prerequisites

- **Lab 04** completed (X.509 certificates)
- **RHEL Version:** 7, 8, 9, or 10
- **System Access:** Root/sudo required

## Time Estimate

**25 minutes**

## Lab Overview

Learn to manage system-wide certificate trust on RHEL. This is essential for working with internal CAs, self-signed certificates, and custom PKI infrastructure.

---

## Instructions

### Step 1: Create a Test CA Certificate

Generate a custom CA certificate:

```bash
./create-test-ca.sh
```

Creates:
- `output/test-ca.key` - CA private key
- `output/test-ca.crt` - CA certificate

---

### Step 2: Add CA to System Trust

Add the CA to the system trust store:

```bash
sudo ./add-custom-ca.sh
```

This copies the CA certificate to:
```
/etc/pki/ca-trust/source/anchors/lab-test-ca.crt
```

---

### Step 3: Update System Trust

Run update-ca-trust to rebuild the system bundle:

```bash
sudo ./update-trust.sh
```

This regenerates `/etc/pki/tls/certs/ca-bundle.crt` to include your custom CA.

---

### Step 4: Verify Trust

Test that your CA is now trusted:

```bash
./verify-trust.sh
```

This:
1. Creates a certificate signed by your CA
2. Verifies it with system trust (should succeed)
3. Demonstrates the CA is trusted system-wide

---

### Step 5: Remove Custom CA

Clean up by removing the CA from trust:

```bash
sudo ./remove-ca.sh
```

---

## Validation

```bash
sudo ./test.sh
```

All tests should pass.

## Expected Outcome

After completing this lab:
- ✅ Custom CA created
- ✅ CA added to system trust
- ✅ System trust updated successfully
- ✅ Certificates signed by CA verify correctly
- ✅ CA removed from trust
- ✅ Understanding of RHEL trust store management

---

## Key Concepts

### RHEL Trust Store Structure

```
/etc/pki/ca-trust/
├── source/
│   └── anchors/          ← Add custom CAs here
├── extracted/
│   ├── openssl/          ← Generated bundles
│   ├── pem/
│   └── java/
└── ca-bundle.trust.p11-kit
```

### update-ca-trust Command

Rebuilds system trust bundles from:
1. System CAs (`/usr/share/pki/ca-trust-source/`)
2. Custom CAs (`/etc/pki/ca-trust/source/anchors/`)

After running:
- `/etc/pki/tls/certs/ca-bundle.crt` updated
- All applications using system trust pick up changes

### Use Cases

**Add custom CA when:**
- Using internal/corporate CA
- Working with self-signed certificates
- Testing with private PKI
- Integrating with enterprise services

---

## Troubleshooting

### Issue: Permission Denied

**Symptom:**
```
Permission denied: /etc/pki/ca-trust/source/anchors/
```

**Solution:**
All trust operations require root:
```bash
sudo ./add-custom-ca.sh
```

---

### Issue: CA Not Trusted After Adding

**Symptom:**
Certificate still doesn't verify

**Solution:**
Did you run update-ca-trust?
```bash
sudo update-ca-trust extract
```

---

## Version-Specific Notes

### All RHEL Versions (7, 8, 9, 10)
- Same trust store structure
- Same update-ca-trust command
- CAs added to `/etc/pki/ca-trust/source/anchors/`

### Best Practices
- Use descriptive names for CA files
- Document why each CA is trusted
- Remove CAs when no longer needed
- Test after adding CAs

---

## Cleanup

```bash
sudo ./cleanup.sh
```

This removes:
- Custom CA from system trust
- Generated certificates and keys
- Updates system trust store

---

## Additional Resources

**Related Chapters:**
- Chapter 6: RHEL Trust Store Deep Dive

**Documentation:**
- `man update-ca-trust`
- `/usr/share/doc/ca-certificates/`

---

## Next Steps

**Foundation Labs Complete!** You can now:
- Proceed to **Lab 06: Apache HTTPS Setup** for service configuration
- Or explore automation with **Lab 11: certmonger Basics**
- Or jump to **Lab 15: Troubleshooting Scenarios** for hands-on problem-solving

---

**Difficulty Level:** Beginner
