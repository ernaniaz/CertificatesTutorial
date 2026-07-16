# Lab 11: certmonger Basics

## Learning Objectives

By completing this lab, you will:
- Install and configure certmonger
- Request self-signed certificates
- Request certificates from local CA
- Track certificate expiration
- Configure automatic renewal
- Set up post-save commands for service restarts
- Understand getcert command usage

## Prerequisites

- **Labs 01-05** completed
- **RHEL Version:** 7, 8, 9, or 10
- **System Access:** Root/sudo required
- **certmonger** package available

## Time Estimate

**40-50 minutes**

## Lab Overview

certmonger is a certificate tracking and renewal daemon for RHEL. Learn to use it for automatic certificate lifecycle management, including requesting, tracking, and renewing certificates without manual intervention.

---

## Instructions

### Step 1: Install certmonger

Install certmonger service:

```bash
sudo ./install-certmonger.sh
```

This installs:
- `certmonger` daemon
- Starts and enables service
- Configures basic settings

---

### Step 2: Request Self-Signed Certificate

Request a self-signed certificate:

```bash
sudo ./request-self-signed.sh
```

This:
- Uses `getcert request` command
- Creates certificate and key
- Tracks certificate status
- Shows certificate details

---

### Step 3: Request from Local CA

Request certificate from local CA:

```bash
sudo ./request-local-ca.sh
```

This:
- Sets up local CA with certmonger
- Requests CA-signed certificate
- Configures renewal settings
- Tests tracking

---

### Step 4: Check Certificate Status

Check certificate tracking status:

```bash
./check-status.sh
```

This shows:
- All tracked certificates
- Expiration dates
- Renewal status
- Tracking IDs

---

### Step 5: Test Renewal

Simulate certificate renewal:

```bash
sudo ./test-renewal.sh
```

This:
- Forces certificate renewal
- Tests automatic renewal process
- Verifies post-save commands
- Checks new certificate

---

### Step 6: Verify Configuration

Run comprehensive validation:

```bash
sudo ./verify.sh
```

---

## Validation

```bash
sudo ./test.sh
```

All checks should pass.

## Expected Outcome

After completing this lab:
- ✅ certmonger installed and running
- ✅ Self-signed certificate tracked
- ✅ Local CA certificate tracked
- ✅ Automatic renewal configured
- ✅ Understanding of certmonger workflow

---

## Key Concepts

### certmonger Architecture

```
certmonger daemon (certmonger.service)
    ↓
Certificate Tracking Database
    ↓
CAs (Certificate Authorities)
  - Self-signed
  - Local CA (certmonger-local)
  - IPA CA
  - ACME providers
```

### getcert Command

**Request Certificate:**
```bash
getcert request \
  -f /path/to/cert.crt \
  -k /path/to/key.key \
  -c IPA \
  -N CN=server.example.com
```

**List Certificates:**
```bash
getcert list
getcert list -i <request-id>
```

**Check Status:**
```bash
getcert status -i <request-id>
```

**Force Renewal:**
```bash
getcert resubmit -i <request-id>
getcert refresh -i <request-id>
```

**Stop Tracking:**
```bash
getcert stop-tracking -i <request-id>
# or
getcert stop-tracking -f /path/to/cert.crt
```

### Certificate States

| State | Description |
|-------|-------------|
| MONITORING | Cert tracked, will auto-renew |
| NEED_GUIDANCE | Manual intervention needed |
| SUBMITTING | Request being submitted |
| GENERATING_KEY | Generating key pair |
| ISSUED | Certificate successfully issued |

### Post-Save Commands

Execute commands after certificate renewal:

```bash
getcert request \
  -f /etc/httpd/cert.crt \
  -k /etc/httpd/key.key \
  -C "systemctl reload httpd"
```

### Renewal Timing

- certmonger checks certificates daily
- Default: renew when <30 days remain
- Configurable with `-T` option
- Can force immediate renewal

---

## Troubleshooting

### Issue: certmonger Not Running

**Symptom:**
```
Cannot connect to certmonger service
```

**Solution:**
Start the service:
```bash
systemctl start certmonger
systemctl enable certmonger
systemctl status certmonger
```

---

### Issue: Certificate Request Stuck

**Symptom:**
```
status: SUBMITTING
stuck: yes
```

**Solution:**
Check logs and resubmit:
```bash
journalctl -u certmonger | tail -50
getcert resubmit -i <request-id>
# Or stop and start fresh
getcert stop-tracking -i <request-id>
```

---

### Issue: CA Not Available

**Symptom:**
```
CA 'IPA' not available
```

**Solution:**
List available CAs:
```bash
getcert list-cas
# Use available CA (like 'local' for self-signed)
getcert request -c local ...
```

---

### Issue: Permission Denied

**Symptom:**
```
unable to write certificate file
```

**Solution:**
Check directory permissions:
```bash
# certmonger runs as root, but check:
ls -ld /path/to/cert/directory
# Ensure directory exists and is writable
mkdir -p /path/to/certs
chmod 755 /path/to/certs
```

---

## Version-Specific Notes

### RHEL 7
- Uses `yum` for installation
- certmonger 0.79.x typically
- Basic CA support
- Self-signed and local CA

### RHEL 8
- Uses `dnf` for installation
- certmonger 0.79.x
- Enhanced CA support
- Better IPA integration

### RHEL 9
- certmonger 0.79.x or newer
- Improved ACME support
- Better error handling
- Enhanced logging

---

## Cleanup

```bash
sudo ./cleanup.sh
```

This removes certmonger and tracked certificates.

---

## Additional Resources

**Related Chapters:**
- Chapter 22: certmonger Mastery

**Documentation:**
- `man getcert`
- `man getcert-request`
- `man getcert-list`
- `man certmonger`
- `/usr/share/doc/certmonger/`

**Useful Commands:**
```bash
# List all tracked certificates
getcert list

# Show detailed status
getcert list -i <ID>

# List available CAs
getcert list-cas

# Refresh all certificates
getcert refresh-ca -c <CA-name>

# View certmonger logs
journalctl -u certmonger -f
```

---

## Next Steps

Proceed to **Lab 12: Crypto-Policies** to learn system-wide cryptographic policy management.

---

**Difficulty Level**: Intermediate to Advanced
