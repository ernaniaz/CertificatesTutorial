# Chapter 37: Migration Troubleshooting & Recovery

> **When Things Go Wrong:** Migrations don't always go smoothly. This chapter covers common migration problems and recovery procedures.

---

## 37.1 Common Migration Issues

### Top 10 Certificate Migration Problems

| Problem | Symptoms | Cause | Quick Fix |
|---------|----------|-------|-----------|
| 1. Services won't start | systemctl status fails | Config syntax changed | Restore config, update syntax |
| 2. SHA-1 rejection (RHEL 9) | "ca md too weak" | SHA-1 signature | Reissue certificate |
| 3. TLS version mismatch | Clients can't connect | TLS 1.0/1.1 blocked | LEGACY policy (temp) |
| 4. crypto-policy issues | Various errors | New policy system | Understand & configure |
| 5. certmonger lost tracking | getcert list empty | DB corruption | Restore from backup |
| 6. Missing CAs | Cert verify failed | Trust store reset | Re-add CAs |
| 7. Permission changes | Permission denied | Ownership changed | Fix permissions |
| 8. SELinux denials | Service blocked | Context changed | Relabel files |
| 9. Provider errors (RHEL 9) | Algorithm unsupported | OpenSSL 3.x change | Use -provider legacy |
| 10. Performance degradation | Slow connections | Stricter crypto | Expected, or tune |

---

## 37.2 Rollback Procedures

### When to Rollback

**Rollback if:**
- Critical services can't start
- Certificate issues can't be quickly fixed
- Business impact is severe
- Within rollback window (usually 24-48 hours)

### leapp Rollback

```bash
#============================================#
# ROLLBACK RHEL MIGRATION
#============================================#

# leapp creates snapshot during upgrade
# Rollback BEFORE rebooting into new version

# During upgrade (if issues detected):
# Don't reboot - investigate and fix

# After upgrade but issues found:
# Check if within rollback window

# leapp doesn't have automatic rollback
# Use snapshot/backup to restore

# With LVM snapshot (if created pre-migration):
# Boot from snapshot
# Or restore from backup
```

### Certificate-Specific Rollback

```bash
#============================================#
# RESTORE CERTIFICATES AFTER FAILED MIGRATION
#============================================#

# Scenario: Migrated, but certificate issues
# Need to restore certificate state

# Step 1: Stop services
sudo systemctl stop httpd nginx postfix slapd

# Step 2: Restore certificates
sudo tar xzf /var/backups/pre-migration-*/certificates.tar.gz -C /

# Step 3: Restore service configs
sudo tar xzf /var/backups/pre-migration-*/service-configs.tar.gz -C /

# Step 4: Restore certmonger
sudo systemctl stop certmonger
sudo tar xzf /var/backups/pre-migration-*/certmonger.tar.gz -C /
sudo systemctl start certmonger

# Step 5: Restore crypto-policy (if RHEL 8+)
POLICY=$(cat /var/backups/pre-migration-*/crypto-policy.txt)
sudo update-crypto-policies --set $POLICY

# Step 6: Start services
sudo systemctl start httpd nginx postfix slapd

# Step 7: Verify
curl -v https://localhost/
sudo getcert list
```

---

## 37.3 Service Won't Start After Migration

### Diagnosis

```bash
#============================================#
# SERVICE STARTUP TROUBLESHOOTING
#============================================#

# Check service status
systemctl status httpd

# View detailed errors
sudo journalctl -xe -u httpd

# Test configuration
# Apache:
sudo apachectl configtest

# NGINX:
sudo nginx -t

# Postfix:
sudo postfix check

# Common certificate-related errors:
# - File not found
# - Permission denied
# - Certificate format invalid
# - ca md too weak (SHA-1)
```

### Solutions

**Problem: Configuration Syntax Changed**
```bash
# Some directives changed between versions
# Check release notes for changes

# Temporarily restore old config
sudo cp /var/backups/pre-migration-*/ssl.conf /etc/httpd/conf.d/

# Update to new syntax
# Research correct syntax for new version
```

**Problem: Permission Changed During Migration**
```bash
# Fix permissions
sudo chmod 600 /etc/pki/tls/private/*.key
sudo chmod 644 /etc/pki/tls/certs/*.crt

# Fix ownership
sudo chown root:root /etc/pki/tls/private/*.key

# Fix SELinux contexts
sudo restorecon -Rv /etc/pki/tls/
```

---

## 37.4 Client Connection Failures Post-Migration

### TLS Version Incompatibility

**Symptom:** Clients can't connect after migration to RHEL 8/9

**Diagnosis:**
```bash
# Test from server
openssl s_client -connect localhost:443 -tls1_2
# Works

openssl s_client -connect localhost:443 -tls1
# Fails (expected on RHEL 8/9 DEFAULT)

# Check crypto-policy
update-crypto-policies --show
# DEFAULT  ← Blocks TLS 1.0/1.1
```

**Temporary Solution:**
```bash
# Allow TLS 1.0/1.1 temporarily
sudo update-crypto-policies --set LEGACY
sudo systemctl restart httpd nginx postfix

# Test clients
# Document which clients need TLS 1.0/1.1

# Plan to update those clients, then revert to DEFAULT
```

**Proper Solution:**
```bash
# Update clients to support TLS 1.2+
# Then use DEFAULT policy

sudo update-crypto-policies --set DEFAULT
```

---

## 37.5 certmonger Issues Post-Migration

### certmonger Tracking Lost

**Symptom:**
```bash
sudo getcert list
# (empty or missing certificates)
```

**Solution:**
```bash
# Restore certmonger database
sudo systemctl stop certmonger
sudo tar xzf /var/backups/pre-migration-*/certmonger.tar.gz -C /
sudo systemctl start certmonger

# Verify
sudo getcert list

# If still issues, re-add certificates manually
```

### certmonger CA_UNREACHABLE After Migration

**Common after RHEL upgrade**

**Solution:**
```bash
# Renew Kerberos ticket
sudo kinit -k host/$(hostname -f)@REALM

# Restart certmonger
sudo systemctl restart certmonger

# Resubmit requests
for cert in $(sudo getcert list | grep "certificate:" | sed -n "s/.*location='\\([^']*\\)'.*/\\1/p"); do
  sudo ipa-getcert resubmit -f "$cert"
done
```

---

## 37.6 Emergency Recovery Procedures

### Emergency: All Services Down

**Situation:** Migration complete but nothing works

**Quick Recovery:**
```bash
#!/bin/bash
# emergency-post-migration-recovery.sh

echo "=== EMERGENCY: Post-Migration Certificate Recovery ==="

# 1. Check RHEL version (confirm migration happened)
cat /etc/redhat-release

# 2. Emergency: Disable SSL temporarily
# Apache
sudo mv /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/ssl.conf.disabled
sudo systemctl start httpd
# Now Apache runs on HTTP only (port 80)

# 3. Identify certificate issues
sudo journalctl -xe | grep -i cert | tail -50

# 4. For RHEL 9: Check for SHA-1 rejections
grep "ca md too weak" /var/log/messages

# 5. Generate temporary self-signed certificates
/usr/local/bin/emergency-self-signed-cert.sh $(hostname -f) 90

# 6. Re-enable SSL with temp cert
sudo mv /etc/httpd/conf.d/ssl.conf.disabled /etc/httpd/conf.d/ssl.conf
# Update to use temp cert
sudo systemctl restart httpd

# 7. Services restored (with warnings)
# Plan proper certificate fixes

echo "✅ Emergency recovery complete"
echo "⚠️ Using temporary certificates - fix ASAP!"
```

---

## 37.7 Post-Migration Validation Script

### Comprehensive Validation

```bash
#!/bin/bash
# post-migration-cert-validation.sh

echo "=== Post-Migration Certificate Validation ==="

ISSUES=0

# Check RHEL version
echo "1. RHEL Version:"
cat /etc/redhat-release

# Check OpenSSL
echo ""
echo "2. OpenSSL Version:"
openssl version

# Check crypto-policy (RHEL 8+)
if command -v update-crypto-policies &>/dev/null; then
  echo ""
  echo "3. Crypto-Policy:"
  update-crypto-policies --show
fi

# Check certificates
echo ""
echo "4. Certificate Status:"
CERT_COUNT=0
EXPIRED=0
for cert in /etc/pki/tls/certs/*.crt; do
  [ -f "$cert" ] || continue
  ((CERT_COUNT++))

  if ! openssl x509 -in "$cert" -noout -checkend 0 2>/dev/null; then
    echo "  ❌ EXPIRED: $cert"
    ((EXPIRED++))
    ((ISSUES++))
  fi

  # Check for SHA-1 (RHEL 9)
  if [ "$(cat /etc/redhat-release)" =~ "release 9" ]; then
    if openssl x509 -in "$cert" -noout -text | grep -qi "sha1.*Signature"; then
      echo "  ❌ SHA-1: $cert"
      ((ISSUES++))
    fi
  fi
done

echo "  Total certificates: $CERT_COUNT"
echo "  Expired: $EXPIRED"

# Check certmonger
echo ""
echo "5. certmonger Status:"
if command -v getcert &>/dev/null; then
  sudo getcert list | grep "status:" | sort | uniq -c

  UNREACHABLE=$(sudo getcert list | grep -c "CA_UNREACHABLE")
  if [ $UNREACHABLE -gt 0 ]; then
    echo "  ⚠️ $UNREACHABLE certificates CA_UNREACHABLE"
    ((ISSUES++))
  fi
else
  echo "  certmonger not installed"
fi

# Check services
echo ""
echo "6. Service Status:"
for svc in httpd nginx postfix slapd; do
  if systemctl is-active --quiet $svc 2>/dev/null; then
    echo "  ✅ $svc: running"
  elif systemctl is-enabled --quiet $svc 2>/dev/null; then
    echo "  ❌ $svc: not running (should be)"
    ((ISSUES++))
  fi
done

# Test connections
echo ""
echo "7. Connection Tests:"
timeout 3 curl -ks https://localhost/ &>/dev/null && \
  echo "  ✅ HTTPS: OK" || echo "  ❌ HTTPS: FAILED"

# Summary
echo ""
echo "==================================="
if [ $ISSUES -eq 0 ]; then
  echo "✅ Migration validation PASSED!"
  exit 0
else
  echo "⚠️ $ISSUES issues found - review above"
  exit 1
fi
```

---

## 37.8 Key Takeaways

1. **Have rollback plan ready** before migration
2. **Most issues are fixable** without rollback
3. **Crypto-policy changes** cause most compatibility issues
4. **SHA-1 rejection** is non-negotiable on RHEL 9
5. **Test, test, test** before production migration
6. **Document everything** during troubleshooting
7. **Emergency procedures** (Ch 33) apply during migration too

---

## Quick Reference Card

```
┌──────────────────────────────────────────────────────────────┐
│ MIGRATION TROUBLESHOOTING QUICK REFERENCE                    │
├──────────────────────────────────────────────────────────────┤
│ Service fails:  Check: journalctl -xe -u <service>           │
│                 Try: Restore config from backup              │
│                                                              │
│ Cert rejected:  Check: Signature algorithm (SHA-1?)          │
│                 Fix: Reissue with SHA-256+                   │
│                                                              │
│ Client fails:   Check: TLS version support                   │
│                 Temp: update-crypto-policies --set LEGACY    │
│                 Fix: Update client                           │
│                                                              │
│ certmonger:     Check: getcert list                          │
│                 Fix: Restore /var/lib/certmonger/            │
│                                                              │
│ Emergency:      Disable SSL temporarily                      │
│                 Generate temp self-signed                    │
│                 Restore from backup                          │
│                                                              │
│ Rollback:       Use snapshot/backup                          │
│                 Restore certificates                         │
│                 Restore configs                              │
└──────────────────────────────────────────────────────────────┘

✅ Most issues are fixable without full rollback
⚠️ Have backups ready
⚠️ Test in non-production first
```
---

**Chapter Navigation**

| [← Previous: Chapter 36 - RHEL 8→9 Migration](36-rhel8-to-9.md) | [Next: Chapter 38 - FIPS Mode Complete Guide →](../part-07-security/38-fips-mode-guide.md) |
|:---|---:|
