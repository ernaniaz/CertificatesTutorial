# Chapter 31: Crypto-Policy Troubleshooting

> **RHEL 8/9/10 Only:** Crypto-policies are powerful but can cause compatibility issues. Learn how to diagnose and fix crypto-policy problems.

---

## 31.1 Crypto-Policy Overview

**Available:** RHEL 8, 9, 10 only (NOT RHEL 7)

**Quick Check:**
```bash
# Check if crypto-policies available
which update-crypto-policies

# If found: RHEL 8/9/10
# If not found: RHEL 7 (no crypto-policies)

# Current policy
update-crypto-policies --show
```

---

## 31.2 Common Crypto-Policy Issues

### Issue 1: Application Fails After Policy Change

**Symptom:** Service worked, then you changed crypto-policy, now it fails

**Scenario:**
```bash
# Before
update-crypto-policies --show
# DEFAULT

# You changed it
sudo update-crypto-policies --set FUTURE
sudo systemctl restart httpd

# Now httpd won't start or clients can't connect
```

**Diagnosis:**
```bash
#============================================#
# DIAGNOSE POLICY CHANGE IMPACT
#============================================#

# Step 1: Check what changed
cat /etc/crypto-policies/back-ends/opensslcnf.config

# Step 2: Check logs
sudo journalctl -xe -u httpd | grep -i cipher

# Step 3: Test connection
openssl s_client -connect localhost:443

# Step 4: Check if app overriding policy
grep -r "SSLProtocol\|SSLCipherSuite" /etc/httpd/
```

**Solution:**
```bash
# Solution 1: Revert policy
sudo update-crypto-policies --set DEFAULT
sudo systemctl restart httpd

# Solution 2: Fix application config
# Remove hard-coded cipher specifications
# Let crypto-policy handle it

# Solution 3: Create custom policy module (RHEL 9+)
# See Chapter 23 for details
```

---

### Issue 2: "no shared cipher"

**Symptom:** Clients can't connect after policy change

**Full Error:**
```
SSL routines:SSL23_GET_SERVER_HELLO:sslv3 alert handshake failure
no shared cipher
```

**Diagnosis:**
```bash
#============================================#
# DIAGNOSE CIPHER MISMATCH
#============================================#

# Step 1: Check current policy
update-crypto-policies --show
# FUTURE  ← Very strict!

# Step 2: What ciphers are available?
openssl ciphers -v | head -20

# Step 3: Test client capabilities
openssl s_client -connect server:443 -cipher 'ALL'

# Step 4: Is client too old?
# Old client might only support weak ciphers blocked by FUTURE policy
```

**Solutions:**
```bash
# Solution 1: Use less strict policy (temporary!)
sudo update-crypto-policies --set DEFAULT
sudo systemctl restart services

# Solution 2: Update client to support modern ciphers

# Solution 3: Create custom policy module
# Allow specific cipher for compatibility
```

---

### Issue 3: TLS 1.0/1.1 Client Can't Connect

**Symptom:** Old clients fail to connect to RHEL 8+ server

**Error:**
```
SSL routines:ssl3_read_bytes:tlsv1 alert protocol version
wrong version number
```

**Diagnosis:**
```bash
# Check policy
update-crypto-policies --show
# DEFAULT  ← Blocks TLS 1.0/1.1

# Test if TLS 1.0 works
openssl s_client -connect server:443 -tls1
# Should fail with DEFAULT policy

# Test if TLS 1.2 works
openssl s_client -connect server:443 -tls1_2
# Should work
```

**Solutions:**
```bash
# Solution 1: Temporary LEGACY policy (NOT recommended!)
sudo update-crypto-policies --set LEGACY
sudo systemctl restart services
# Now TLS 1.0/1.1 allowed

# Solution 2: Update client to support TLS 1.2+
# This is the PROPER fix

# Solution 3: Per-application override (last resort)
# Apache example:
# SSLProtocol all -SSLv3  # Re-enables TLS 1.0/1.1
```

---

### Issue 4: Service Overriding Crypto-Policy

**Symptom:** Policy changes don't affect service

**Diagnosis:**
```bash
#============================================#
# CHECK FOR POLICY OVERRIDES
#============================================#

# Apache
grep -r "SSLProtocol\|SSLCipherSuite" /etc/httpd/

# NGINX
grep -r "ssl_protocols\|ssl_ciphers" /etc/nginx/

# Postfix
sudo postconf | grep -E "smtp.*_tls_protocols|smtp.*_tls_ciphers"

# If found → Service is overriding policy!
```

**Solution:**
```bash
# Remove overrides from config files
# Let crypto-policy handle TLS settings

# Apache: Remove or comment out
# #SSLProtocol all -SSLv3
# #SSLCipherSuite ...

# NGINX: Remove
# #ssl_protocols ...
# #ssl_ciphers ...

# Restart service
sudo systemctl restart httpd
```

---

## 31.3 Crypto-Policy Not Applied

### Policy Set But Not Taking Effect

**Symptoms:**
- Changed policy but services still use old settings
- Weak ciphers still accepted

**Diagnosis:**
```bash
#============================================#
# VERIFY POLICY IS ACTIVE
#============================================#

# Step 1: Confirm policy set
update-crypto-policies --show

# Step 2: Check when policy was last updated
ls -l /etc/crypto-policies/back-ends/

# Step 3: Check if services restarted
systemctl status httpd nginx postfix | grep "Active:"
# Services MUST be restarted after policy change!

# Step 4: Test actual ciphers in use
openssl s_client -connect localhost:443 | grep "Cipher"
```

**Solution:**
```bash
# Restart ALL services
sudo systemctl restart httpd nginx postfix slapd

# Or reboot (ensures everything picks up changes)
sudo reboot

# Verify after restart
openssl s_client -connect localhost:443
```

---

## 31.4 FIPS Policy Issues

### FIPS Policy Failures

**Symptom:** Services fail in FIPS mode

**Diagnosis:**
```bash
#============================================#
# DIAGNOSE FIPS ISSUES
#============================================#

# Step 1: Verify FIPS mode enabled
fips-mode-setup --check

# Step 2: Check crypto-policy
update-crypto-policies --show
# Should show: FIPS

# Step 3: Check for non-FIPS algorithms
# Common culprits: MD5, SHA-1, weak ciphers

# Step 4: Test with FIPS provider
openssl list -providers | grep fips
```

**Common FIPS Issues:**
```bash
# Issue: Application uses MD5 (not FIPS-approved)
# Error: "digital envelope routines:EVP_DigestInit_ex:disabled for fips"

# Solution: Update application to use SHA-256

# Issue: Certificate has SHA-1 signature
# Error: "ca md too weak"

# Solution: Reissue certificate with SHA-256 or better
```

---

## 31.5 Policy Compatibility Testing

### Before Changing Policy

```bash
#!/bin/bash
# test-crypto-policy-change.sh
# Test crypto-policy change before production

NEW_POLICY=$1  # DEFAULT, LEGACY, FUTURE, or FIPS

if [ -z "$NEW_POLICY" ]; then
  echo "Usage: $0 <policy>"
  exit 1
fi

echo "=== Testing Crypto-Policy Change to $NEW_POLICY ==="

# Save current policy
CURRENT=$(update-crypto-policies --show)
echo "Current policy: $CURRENT"

# Change policy
echo "Changing to $NEW_POLICY..."
sudo update-crypto-policies --set "$NEW_POLICY"

# Restart services
echo "Restarting services..."
sudo systemctl restart httpd nginx postfix 2>/dev/null

# Wait for services to start
sleep 3

# Test each service
echo ""
echo "Testing services:"

# Apache
if systemctl is-active --quiet httpd; then
  curl -ks https://localhost/ >/dev/null && \
    echo "✅ Apache: OK" || echo "❌ Apache: FAILED"
else
  echo "❌ Apache: Not running"
fi

# NGINX
if systemctl is-active --quiet nginx; then
  curl -ks https://localhost:8443/ >/dev/null && \
    echo "✅ NGINX: OK" || echo "❌ NGINX: FAILED"
else
  echo "⚠️ NGINX: Not installed"
fi

# Postfix
if systemctl is-active --quiet postfix; then
  timeout 3 openssl s_client -starttls smtp -connect localhost:25 </dev/null &>/dev/null && \
    echo "✅ Postfix: OK" || echo "❌ Postfix: FAILED"
else
  echo "⚠️ Postfix: Not installed"
fi

# Ask to keep or revert
echo ""
read -p "Keep $NEW_POLICY policy? (y/n): " KEEP

if [ "$KEEP" != "y" ]; then
  echo "Reverting to $CURRENT..."
  sudo update-crypto-policies --set "$CURRENT"
  sudo systemctl restart httpd nginx postfix 2>/dev/null
  echo "✅ Reverted"
else
  echo "✅ Keeping $NEW_POLICY policy"
fi
```

---

## 31.6 Troubleshooting Workflow

### Systematic Approach

```
Crypto-Policy Issue?
    │
    ├─ Step 1: Identify current policy
    │   └─ update-crypto-policies --show
    │
    ├─ Step 2: Check if policy changed recently
    │   └─ Check /var/log/messages for "crypto-policies"
    │
    ├─ Step 3: Test with different policy
    │   └─ sudo update-crypto-policies --set LEGACY
    │   └─ If works → policy was too strict
    │
    ├─ Step 4: Identify incompatibility
    │   └─ openssl s_client -cipher 'ALL' -tls1
    │   └─ Find what client/server needs
    │
    ├─ Step 5: Choose fix
    │   ├─ A) Update client (best)
    │   ├─ B) Create custom module (good)
    │   ├─ C) Use less strict policy (acceptable)
    │   └─ D) Per-app override (last resort)
    │
    └─ Step 6: Test and document
        └─ Verify fix works
        └─ Document why change needed
```

---

## 31.7 Debugging Crypto-Policy Application

### Verify Policy Is Applied

```bash
#============================================#
# VERIFY CRYPTO-POLICY APPLICATION
#============================================#

# Step 1: Check policy
update-crypto-policies --show

# Step 2: Check back-end files were updated
ls -l /etc/crypto-policies/back-ends/
# Files should be recently modified

# Step 3: View OpenSSL configuration
cat /etc/crypto-policies/back-ends/opensslcnf.config

# Step 4: Test actual cipher availability
openssl ciphers -v | grep -E "TLS|SSL"

# Step 5: Test connection
openssl s_client -connect localhost:443
# Look for: Protocol version, Cipher

# Step 6: Check if service restarted since policy change
systemctl status httpd | grep "Active:"
# Should show recent activation time
```

---

## 31.8 Common Scenarios

### Scenario 1: Legacy Application After RHEL 8 Upgrade

**Problem:** App worked on RHEL 7, fails on RHEL 8

**Root Cause:** RHEL 7 had no crypto-policies, RHEL 8 DEFAULT blocks TLS 1.0/1.1

**Solution:**
```bash
# Quick fix (temporary!):
sudo update-crypto-policies --set LEGACY

# Proper fix:
# Update application to support TLS 1.2+

# Document exception
echo "Application X requires LEGACY policy due to TLS 1.0 requirement" > \
  /etc/crypto-policies/POLICY-EXCEPTION.txt
```

### Scenario 2: Can't Connect to Windows Server 2008

**Problem:** RHEL 9 can't connect to old Windows server

**Cause:** Windows Server 2008 only supports TLS 1.0

**Solutions:**
```bash
# Option 1: Upgrade Windows (best)

# Option 2: LEGACY policy (temporary)
sudo update-crypto-policies --set LEGACY

# Option 3: Custom policy module for this specific case
# See Chapter 23
```

---

## 31.9 Key Takeaways

1. **Crypto-policies are RHEL 8+ only** (not RHEL 7)
2. **Services MUST restart** after policy change
3. **Policy changes are system-wide** - Affect everything
4. **DEFAULT is recommended** for most environments
5. **LEGACY should be temporary** only
6. **Test before deploying** new policies
7. **Update clients** rather than weaken policy

---

## Quick Reference Card

```
┌───────────────────────────────────────────────────────────────┐
│ CRYPTO-POLICY TROUBLESHOOTING                                 │
├───────────────────────────────────────────────────────────────┤
│ Check:         update-crypto-policies --show                  │
│ Set:           sudo update-crypto-policies --set <POLICY>     │
│ Revert:        sudo update-crypto-policies --set DEFAULT      │
│                                                               │
│ Back-ends:     /etc/crypto-policies/back-ends/                │
│ OpenSSL:       cat .../back-ends/opensslcnf.config            │
│                                                               │
│ Test:          openssl ciphers -v                             │
│                openssl s_client -connect :443                 │
│                                                               │
│ After change:  sudo systemctl restart <all-services>          │
│                OR: sudo reboot                                │
│                                                               │
│ Debug:         grep -r "SSLProtocol\|ssl_protocols" /etc/     │
│                (look for overrides)                           │
└───────────────────────────────────────────────────────────────┘

⚠️ RHEL 7 doesn't have crypto-policies
✅ Always restart services after policy change
✅ DEFAULT works for 95% of cases
```
---

**Chapter Navigation**

| [← Previous: Chapter 30 - certmonger Troubleshooting](30-certmonger-issues.md) | [Next: Chapter 32 - SOS Report Analysis →](32-sos-report-analysis.md) |
|:---|---:|
