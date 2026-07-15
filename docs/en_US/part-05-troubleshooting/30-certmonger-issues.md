# Chapter 30: certmonger Troubleshooting

> **Automation Issues:** certmonger is RHEL's certificate automation tool. When it fails, certificates don't renew. This chapter teaches you to diagnose and fix certmonger problems quickly.

---

## 30.1 certmonger Status Values

### Understanding Status Messages

| Status | Meaning | Action Required |
|--------|---------|-----------------|
| `MONITORING` | ✅ All good - cert issued, tracking expiry | None |
| `SUBMITTING` | 🔄 Requesting cert from CA | Wait (usually seconds) |
| `CA_UNREACHABLE` | ❌ Can't contact CA server | Fix connectivity |
| `CA_REJECTED` | ❌ CA refused request | Fix principal/permissions |
| `NEED_KEY_GEN_PIN` | ⏸️ Waiting for PIN (HSM) | Provide PIN |
| `NEED_GUIDANCE` | ⚠️ Needs manual intervention | Check request details |
| `PRE_SAVE_COMMAND` | 🔄 Running pre-save script | Wait |
| `POST_SAVE_COMMAND` | 🔄 Running post-save script | Wait |
| `NEWLY_ADDED` | 🆕 Just added, not yet processed | Wait |

---

## 30.2 CA_UNREACHABLE Troubleshooting

### Most Common certmonger Issue!

**Symptom:**
```bash
sudo getcert list
# status: CA_UNREACHABLE
```

### Diagnosis Steps

```bash
#============================================#
# DIAGNOSE CA_UNREACHABLE
#============================================#

# Step 1: Which CA are we trying to reach?
sudo getcert list -v | grep "CA:"
# CA: IPA

# Step 2: Can we reach IPA?
ipa ping
# Pong!  ← Good
# ipa: ERROR: cannot connect to 'https://ipa.example.com/ipa/xml'  ← Bad!

# Step 3: Check Kerberos ticket
klist
# Ticket cache: FILE:/tmp/krb5cc_0
# Valid starting     Expires            Service principal
# ...

# Step 4: Check if ticket expired
klist | grep "host/"
# If no host ticket or expired → Problem!

# Step 5: Check IPA server status
ssh ipa.example.com "sudo ipactl status"

# Step 6: Check network
ping ipa.example.com
curl -k https://ipa.example.com/ipa/config/ca.crt

# Step 7: Check DNS
nslookup ipa.example.com
```

### Solutions for CA_UNREACHABLE

**Solution 1: Renew Kerberos Ticket**
```bash
# Get new host ticket
sudo kinit -k host/$(hostname -f)@REALM

# Verify
klist

# Retry cert request
sudo ipa-getcert resubmit -f /etc/pki/tls/certs/web.crt
```

**Solution 2: Check IPA Server**
```bash
# On IPA server
sudo ipactl status

# If services down
sudo ipactl restart

# Check specific service
sudo systemctl status pki-tomcatd@pki-tomcat  # CA service
```

**Solution 3: Network/Firewall**
```bash
# Test IPA connectivity
curl -vk https://ipa.example.com/ipa/xml

# Check firewall on IPA server
ssh ipa.example.com "sudo firewall-cmd --list-services | grep https"

# Check routes
traceroute ipa.example.com
```

**Solution 4: Restart certmonger**
```bash
sudo systemctl restart certmonger

# Wait a moment
sleep 10

# Check status
sudo getcert list
```

---

## 30.3 CA_REJECTED Troubleshooting

### When CA Refuses the Request

**Symptom:**
```bash
sudo getcert list -v
# status: CA_REJECTED
# ca-error: Server at https://ipa.example.com/ipa/xml unwilling to issue certificate
```

### Diagnosis Steps

```bash
#============================================#
# DIAGNOSE CA_REJECTED
#============================================#

# Step 1: Check error details
sudo getcert list -v -f /etc/pki/tls/certs/web.crt
# Look at 'ca-error' field

# Step 2: Does service principal exist?
ipa service-show HTTP/$(hostname -f)
# If error: Service not found

# Step 3: Is host enrolled?
ipa host-show $(hostname -f)

# Step 4: Check certificate profile exists
sudo getcert list -v | grep "profile:"
ipa certprofile-show caIPAserviceCert

# Step 5: Check request details
sudo getcert list -v | grep -A30 "Request ID"
```

### Solutions for CA_REJECTED

**Solution 1: Create Service Principal**
```bash
# Add missing service principal
ipa service-add HTTP/$(hostname -f)

# Add SAN (if needed)
ipa service-mod HTTP/$(hostname -f) --addattr=cn=web.example.com

# Retry
sudo ipa-getcert resubmit -f /etc/pki/tls/certs/web.crt
```

**Solution 2: Fix Host Entry**
```bash
# Re-enroll to IPA if needed
sudo ipa-client-install --force-join

# Verify
ipa host-show $(hostname -f)
```

**Solution 3: Check Permissions**
```bash
# Check if you have permission to request certs
ipa permission-find --name="Request Certificate"

# Check ACLs
ipa aci-find --name="*cert*"

# May need IPA admin to grant permissions
```

---

## 30.4 Renewal Failures

### Certificate Not Renewing

**Symptom:** Certificate approaching expiry but not renewing

**Diagnosis:**
```bash
#============================================#
# DIAGNOSE RENEWAL FAILURE
#============================================#

# Step 1: Check current status
sudo getcert list -f /etc/pki/tls/certs/web.crt

# Step 2: When should it renew?
# certmonger renews at 2/3 of cert lifetime
# 365-day cert → renews at day 243 (122 days before expiry)

# Step 3: Check certmonger logs
sudo journalctl -u certmonger --since "7 days ago" | grep -i renew

# Step 4: Force renewal attempt
sudo ipa-getcert resubmit -f /etc/pki/tls/certs/web.crt

# Step 5: Watch logs in real-time
sudo journalctl -u certmonger -f
```

### Common Renewal Issues

**Issue 1: Post-save command fails**
```bash
# Check post-save command
sudo getcert list -f /etc/pki/tls/certs/web.crt | grep "post-save"
# post-save command: systemctl reload httpd

# Test command manually
sudo systemctl reload httpd
# If fails → fix the command

# Update command (re-create tracking entry; do not use getcert rekey)
sudo getcert stop-tracking -f /etc/pki/tls/certs/web.crt
sudo getcert start-tracking \
  -f /etc/pki/tls/certs/web.crt \
  -k /etc/pki/tls/private/web.key \
  -C "systemctl reload httpd"
```

**Issue 2: IPA server down during renewal window**
```bash
# certmonger will retry
# Check retry schedule in logs
sudo journalctl -u certmonger | grep "will try again"

# Manual retry
sudo ipa-getcert resubmit -f /etc/pki/tls/certs/web.crt
```

---

## 30.5 Tracking Issues

### Certificate Not Being Tracked

**Symptom:** Certificate expires because certmonger wasn't tracking it

**Solution:**
```bash
#============================================#
# START TRACKING EXISTING CERTIFICATE
#============================================#

sudo getcert start-tracking \
  -f /etc/pki/tls/certs/existing.crt \
  -k /etc/pki/tls/private/existing.key \
  -c IPA \
  -K HTTP/$(hostname -f)@REALM
```

### Duplicate Tracking

**Symptom:** Same certificate tracked multiple times

**Diagnosis:**
```bash
# List all tracked certs
sudo getcert list | grep -E "(Request ID|certificate:)" | \
  awk -F"'" '/certificate:/{cert=$2} /Request ID/{print cert, $2}'

# Look for duplicates
```

**Solution:**
```bash
# Remove duplicate tracking
sudo getcert stop-tracking -i <duplicate-request-id>

# Keep only one tracking entry per certificate
```

---

## 30.6 Configuration Issues

### Wrong CA Configured

**Symptom:** certmonger trying to reach wrong CA

**Diagnosis:**
```bash
# Check configured CA
sudo getcert list -v | grep "CA:"

# List available CAs
sudo getcert list-cas
```

**Solution:**
```bash
# Stop tracking with wrong CA
sudo getcert stop-tracking -f /etc/pki/tls/certs/web.crt

# Re-request with correct CA
sudo ipa-getcert request \
  -c IPA \  # Specify correct CA
  -f /etc/pki/tls/certs/web.crt \
  -k /etc/pki/tls/private/web.key \
  -K HTTP/$(hostname -f)@REALM
```

---

## 30.7 certmonger Database Corruption

### Rare but Serious Issue

**Symptom:** certmonger completely broken, all certs show errors

**Diagnosis:**
```bash
# Check database
ls -l /var/lib/certmonger/

# Check for corruption
sudo journalctl -u certmonger | grep -i corrupt
```

**Solution (Nuclear Option):**
```bash
# CAUTION: This removes all tracking!

# Step 1: Backup current state
sudo tar czf certmonger-backup-$(date +%Y%m%d).tar.gz \
  /var/lib/certmonger/ \
  /etc/pki/tls/

# Step 2: Document current tracking
sudo getcert list > /tmp/certmonger-list-backup.txt

# Step 3: Stop certmonger
sudo systemctl stop certmonger

# Step 4: Remove database
sudo rm -rf /var/lib/certmonger/cas/*
sudo rm -rf /var/lib/certmonger/requests/*

# Step 5: Start certmonger
sudo systemctl start certmonger

# Step 6: Re-add certificates (from backup documentation)
# Manually re-request each certificate
```

---

## 30.8 Debugging certmonger

### Enable Debug Logging

```bash
#============================================#
# CERTMONGER DEBUG MODE
#============================================#

# Edit service file
sudo systemctl edit certmonger

# Add:
[Service]
Environment="G_MESSAGES_DEBUG=all"

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart certmonger

# Watch detailed logs
sudo journalctl -u certmonger -f

# Disable debug after troubleshooting
sudo systemctl revert certmonger
sudo systemctl restart certmonger
```

### Manual Cert Request Test

```bash
#============================================#
# TEST CERTIFICATE REQUEST MANUALLY
#============================================#

# Submit request and watch
sudo ipa-getcert request \
  -f /tmp/test.crt \
  -k /tmp/test.key \
  -K HTTP/$(hostname -f)@REALM \
  -v  # Verbose

# Watch in another terminal
sudo journalctl -u certmonger -f

# If successful, remove test
sudo getcert stop-tracking -f /tmp/test.crt -r
rm -f /tmp/test.{crt,key}
```

---

## 30.9 Common Scenarios

### Scenario 1: All Certificates Show CA_UNREACHABLE

**Likely Cause:** IPA server down or network issue

**Quick Fix:**
```bash
# Check IPA
ipa ping

# If down, fix IPA first
ssh ipa-server "sudo ipactl start"

# If network issue, fix network

# Restart certmonger
sudo systemctl restart certmonger
```

### Scenario 2: One Certificate Stuck

**Diagnosis:**
```bash
# Check specific certificate
sudo getcert list -f /etc/pki/tls/certs/problem.crt

# Try resubmitting
sudo ipa-getcert resubmit -f /etc/pki/tls/certs/problem.crt

# If still stuck, recreate request
sudo getcert stop-tracking -f /etc/pki/tls/certs/problem.crt
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/problem.crt \
  -k /etc/pki/tls/private/problem.key \
  -K HTTP/$(hostname -f)@REALM \
  -D $(hostname -f)
```

### Scenario 3: Certificate Renewed but Service Not Reloaded

**Symptom:** New cert exists but service still uses old one

**Cause:** Post-save command failed or not configured

**Solution:**
```bash
# Check post-save command
sudo getcert list -f /etc/pki/tls/certs/web.crt | grep "post-save"

# If missing, add it (re-create tracking entry; do not use getcert rekey)
sudo getcert stop-tracking -f /etc/pki/tls/certs/web.crt
sudo getcert start-tracking \
  -f /etc/pki/tls/certs/web.crt \
  -k /etc/pki/tls/private/web.key \
  -C "systemctl reload httpd"

# Test post-save command works
sudo systemctl reload httpd

# Force renewal to test
sudo ipa-getcert resubmit -f /etc/pki/tls/certs/web.crt
```

---

## 30.10 Key Takeaways

1. **CA_UNREACHABLE** is most common issue - Check IPA connectivity
2. **CA_REJECTED** means principal problem - Create service principal
3. **MONITORING status** means all is well
4. **Post-save commands critical** - Test them independently
5. **certmonger logs** in journal - Use `journalctl -u certmonger`
6. **Retry with resubmit** - Often fixes transient issues
7. **Check Kerberos tickets** - Expired tickets cause issues

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────────┐
│ CERTMONGER TROUBLESHOOTING QUICK REFERENCE                  │
├─────────────────────────────────────────────────────────────┤
│ Status:          getcert list                               │
│ Verbose:         getcert list -v                            │
│ Specific:        getcert list -f /path/to/cert.crt          │
│ Logs:            journalctl -u certmonger -f                │
│                                                             │
│ Resubmit:        ipa-getcert resubmit -f /path/to/cert.crt  │
│ Stop track:      getcert stop-tracking -f /path/to/cert.crt │
│ Start track:     getcert start-tracking -f cert -k key      │
│                                                             │
│ CA_UNREACHABLE:  Check: ipa ping, klist                     │
│                  Fix: kinit -k host/$(hostname -f)@REALM    │
│                                                             │
│ CA_REJECTED:     Check: ipa service-show SERVICE/host       │
│                  Fix: ipa service-add SERVICE/host          │
│                                                             │
│ Debug:           systemctl edit certmonger                  │
│                  Environment="G_MESSAGES_DEBUG=all"         │
└─────────────────────────────────────────────────────────────┘

✅ MONITORING = All good!
❌ CA_UNREACHABLE = Check IPA connectivity
❌ CA_REJECTED = Check service principal
```
---

**Chapter Navigation**

| [← Previous: Chapter 29 - Service-Specific Troubleshooting](29-service-troubleshooting.md) | [Next: Chapter 31 - Crypto-Policy Troubleshooting →](31-crypto-policy-issues.md) |
|:---|---:|
