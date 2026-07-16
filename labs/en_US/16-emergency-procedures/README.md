# Lab 16: Emergency Certificate Procedures

## Learning Objectives

By completing this lab, you will:
- Perform emergency certificate replacement
- Create temporary self-signed certificates
- Temporarily bypass SSL verification (for testing)
- Restore from backups quickly
- Rollback certificate changes
- Implement disaster recovery procedures

## Prerequisites

- **Labs 01-15** completed
- **RHEL Version:** 7, 8, 9, or 10
- **System Access:** Root/sudo required
- **Calm under pressure** required

## Time Estimate

**30-40 minutes**

## Lab Overview

When certificates fail in production, you need fast solutions. This lab teaches emergency procedures to restore service quickly, then implement proper fixes later.

---

## Emergency Scenarios

### When to Use Emergency Procedures

- Production service down due to certificate
- Certificate expired overnight
- Wrong certificate deployed
- Lost private key
- CA unreachable for renewal
- Immediate service restoration required

### Emergency Response Priority

1. **Restore Service** - Get it working (may use temporary cert)
2. **Assess Impact** - Understand what happened
3. **Implement Proper Fix** - Replace temporary solution
4. **Prevent Recurrence** - Fix root cause

---

## Instructions

### Emergency Replacement

Quickly replace a failed certificate:

```bash
sudo ./emergency-replacement.sh
```

Creates and deploys new certificate immediately.

---

### Create Temporary Self-Signed

Generate temporary self-signed certificate:

```bash
sudo ./self-signed-temp.sh
```

Use when:
- CA is unreachable
- Need immediate certificate
- Buying time for proper solution

---

### Bypass SSL Verification (Testing Only)

Test connectivity without validating the certificate (troubleshooting only):

```bash
# curl: skip certificate validation
curl -k https://localhost/

# openssl: connect without verifying the chain
openssl s_client -connect localhost:443 </dev/null
```

**WARNING:** Only for troubleshooting! Never in production!

---

### Restore from Backup

Restore certificates from backup:

```bash
sudo ./restore-backup.sh
```

Restores known-good certificates.

---

### Rollback Changes

Rollback recent certificate changes:

```bash
sudo ./rollback.sh
```

Returns to previous working state.

---

## Key Scripts

### emergency-replacement.sh

**Purpose:** Fast certificate replacement
**Use when:** Certificate failed, need immediate fix
**Time:** <5 minutes
**Result:** Service restored with new certificate

### self-signed-temp.sh

**Purpose:** Create temporary certificate
**Use when:** CA unavailable, need quick solution
**Time:** <2 minutes
**Result:** Temporary self-signed certificate deployed

### restore-backup.sh

**Purpose:** Restore from backup
**Use when:** Have good backup, need to revert
**Time:** <3 minutes
**Result:** Known-good certificates restored

### rollback.sh

**Purpose:** Undo recent changes
**Use when:** New certificate causing issues
**Time:** <3 minutes
**Result:** Previous configuration restored

---

## Emergency Checklist

When certificate emergency occurs:

### Immediate Actions (0-5 minutes)

- [ ] Confirm service is down
- [ ] Check certificate expiration
- [ ] Verify certificate/key files exist
- [ ] Check service logs
- [ ] Assess impact (how many services/users)

### Quick Fix (5-15 minutes)

- [ ] Run emergency replacement
- [ ] OR deploy temporary self-signed
- [ ] Restart affected services
- [ ] Test basic functionality
- [ ] Notify stakeholders

### Proper Fix (15-60 minutes)

- [ ] Obtain proper certificate from CA
- [ ] Test certificate before deployment
- [ ] Deploy proper certificate
- [ ] Verify all functionality
- [ ] Remove temporary solutions

### Post-Incident (After service restored)

- [ ] Document what happened
- [ ] Analyze root cause
- [ ] Implement monitoring
- [ ] Update procedures
- [ ] Conduct post-mortem

---

## Validation

To verify your emergency procedures knowledge:

```bash
./verify.sh
```

**Expected Results:**
- ✓ `emergency-replacement.sh`, `self-signed-temp.sh`, `restore-backup.sh`, and `rollback.sh` exist and are executable
- ✓ `/etc/pki/tls/certs` and `/etc/pki/tls/private` exist on the system
- ✓ Existing emergency backup directories under `/root/cert-backup-*` are counted and reported
- ✓ Any `emergency.crt` or `temp-*.crt` files found under `/etc/pki/tls/certs` are listed with subject and validity details

**Manual Verification:**
1. Can you generate a temporary cert in < 2 minutes?
2. Do you understand when to use each procedure?
3. Do you have at least one known-good backup to restore from?
4. Is the rollback plan documented and ready to test manually?

---

## Best Practices

### Always Have Backups

```bash
# Backup before changes
cp /etc/pki/tls/certs/server.crt /etc/pki/tls/certs/server.crt.backup
cp /etc/pki/tls/private/server.key /etc/pki/tls/private/server.key.backup

# With timestamp
DATE=$(date +%Y%m%d-%H%M%S)
cp /etc/pki/tls/certs/server.crt /etc/pki/tls/certs/server.crt.$DATE
```

### Test Before Deploying

```bash
# Test certificate matches key
diff <(openssl x509 -noout -modulus -in cert.pem | openssl md5) \
     <(openssl rsa -noout -modulus -in key.pem | openssl md5)

# Test certificate validity
openssl x509 -in cert.pem -noout -checkend 0

# Test with service
# Deploy to test system first
```

### Document Everything

- What broke
- When it broke
- What you did
- What worked
- What didn't work
- How to prevent it

---

## Common Emergency Scenarios

### Scenario: Cert Expired Overnight

```bash
# Quick fix
sudo ./self-signed-temp.sh
sudo systemctl restart httpd

# Then get proper cert
sudo certbot renew --force-renewal
```

### Scenario: Wrong Cert Deployed

```bash
# Rollback
sudo ./rollback.sh
sudo systemctl restart nginx

# Verify
curl -v https://localhost/
```

### Scenario: Lost Private Key

```bash
# Generate new pair
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout new.key -out new.crt -days 90

# Deploy
sudo cp new.crt /etc/pki/tls/certs/
sudo cp new.key /etc/pki/tls/private/
sudo systemctl restart httpd
```

---

## Cleanup

```bash
sudo ./cleanup.sh
```

Removes emergency certificates and restores normal state.

---

## Additional Resources

**Related Chapters:**
- Chapter 33: Emergency Procedures
- Chapter 27: RHEL Certificate Troubleshooting Methodology

**Emergency Contacts:**
- Certificate Authority support
- System administrators
- Application owners
- Management escalation

**Tools:**
- `openssl` - Certificate generation
- `systemctl` - Service management
- `journalctl` - Log analysis

---

## Next Steps

You've completed the troubleshooting labs! Next:
- **Lab 17-18:** Migration procedures
- **Lab 19-20:** Security and FIPS
- **Lab 21-22:** Advanced topics (Kubernetes, Vault)

---

**Difficulty Level**: Advanced  
**Note**: Practice these procedures before you need them!
