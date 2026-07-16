# Lab 08: Postfix TLS Configuration

## Learning Objectives

By completing this lab, you will:
- Install and configure Postfix mail server
- Configure SMTP with STARTTLS encryption
- Enable TLS on submission port (587)
- Test SMTP TLS connections
- Understand mail server certificate requirements
- Configure Postfix logging for TLS

## Prerequisites

- **Labs 01-05** completed
- **RHEL Version:** 7, 8, 9, or 10
- **System Access:** Root/sudo required
- **Ports:** 25 (SMTP), 587 (submission)

## Time Estimate

**30-40 minutes**

## Lab Overview

Postfix is the default mail transfer agent (MTA) on RHEL. Learn to configure it with TLS for secure mail transmission using STARTTLS on port 25 and mandatory TLS on the submission port (587).

---

## Instructions

### Step 1: Install Postfix

Install Postfix mail server:

```bash
sudo ./install-postfix.sh
```

This installs:
- `postfix` mail server
- Required dependencies
- Configures basic settings

---

### Step 2: Configure TLS

Configure Postfix with TLS certificates:

```bash
sudo ./configure-tls.sh
```

This:
- Copies certificates from Lab 04
- Configures TLS parameters in main.cf
- Enables STARTTLS on port 25
- Configures mandatory TLS on port 587
- Restarts Postfix

---

### Step 3: Test STARTTLS

Test STARTTLS on port 25:

```bash
./test-starttls.sh
```

This tests:
- Basic SMTP connection
- STARTTLS capability
- TLS handshake
- Certificate presentation

---

### Step 4: Test Submission Port

Test secure submission on port 587:

```bash
./test-submission.sh
```

This tests:
- Submission port connectivity
- Mandatory TLS enforcement
- Authentication requirements
- TLS encryption

---

### Step 5: Verify Configuration

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
- ✅ Postfix installed and running
- ✅ STARTTLS available on port 25
- ✅ TLS mandatory on port 587
- ✅ Certificates configured correctly
- ✅ Understanding of mail server TLS

---

## Key Concepts

### Postfix Configuration Files

```
/etc/postfix/
├── main.cf              # Main configuration
├── master.cf            # Service definitions
├── transport            # Transport maps
└── virtual              # Virtual aliases
```

### TLS Directives in main.cf

```conf
# TLS for incoming connections (server mode)
smtpd_tls_cert_file = /etc/pki/tls/certs/postfix.crt
smtpd_tls_key_file = /etc/pki/tls/private/postfix.key
smtpd_tls_security_level = may
smtpd_tls_loglevel = 1

# TLS for outgoing connections (client mode)
smtp_tls_security_level = may
smtp_tls_loglevel = 1

# TLS protocols and ciphers
smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtpd_tls_ciphers = high
smtpd_tls_exclude_ciphers = aNULL, MD5
```

### Port 25 vs Port 587

**Port 25 (SMTP):**
- Traditional mail transfer port
- Server-to-server communication
- TLS optional (STARTTLS)
- No authentication typically required

**Port 587 (Submission):**
- Mail submission from clients
- Requires authentication
- TLS should be mandatory
- Modern best practice for client mail submission

### STARTTLS Process

1. Client connects on plain text port
2. Server advertises STARTTLS capability
3. Client issues STARTTLS command
4. Negotiation upgrades to TLS
5. Encrypted communication continues

---

## Troubleshooting

### Issue: Postfix Won't Start

**Symptom:**
```
Job for postfix.service failed
```

**Solution:**
Check configuration and logs:
```bash
sudo postfix check
sudo journalctl -xeu postfix
sudo tail -f /var/log/maillog
```

---

### Issue: STARTTLS Not Advertised

**Symptom:**
EHLO doesn't show STARTTLS capability

**Solution:**
Verify TLS configuration:
```bash
postconf -n | grep tls
# Ensure smtpd_tls_cert_file and smtpd_tls_key_file are set
# Restart postfix: systemctl restart postfix
```

---

### Issue: Certificate Errors

**Symptom:**
```
warning: cannot get RSA private key
```

**Solution:**
Check certificate permissions:
```bash
ls -l /etc/pki/tls/certs/postfix.crt
ls -l /etc/pki/tls/private/postfix.key
# Private key should be readable by postfix
chmod 600 /etc/pki/tls/private/postfix.key
chown root:root /etc/pki/tls/private/postfix.key
```

---

### Issue: Port 25 Blocked

**Symptom:**
Cannot connect to port 25

**Solution:**
Many ISPs block port 25 outbound. This is normal. Use port 587 for client connections:
```bash
# Test locally
telnet localhost 25
# If that works, it's network/firewall blocking external access
```

---

## Version-Specific Notes

### RHEL 7
- Uses `yum` for installation
- Logs to `/var/log/maillog`
- Postfix 2.10.x typically

### RHEL 8
- Uses `dnf` for installation
- Postfix 3.3.x or 3.5.x
- Crypto-policies affect TLS
- Can reference `/etc/crypto-policies/back-ends/postfix.config`

### RHEL 9
- Postfix 3.5.x
- Stricter TLS defaults
- SHA-1 blocked
- Requires strong ciphers

---

## Cleanup

```bash
sudo ./cleanup.sh
```

This removes Postfix and restores system state.

---

## Additional Resources

**Related Chapters:**
- Chapter 16: Postfix Mail Server TLS

**Documentation:**
- `man 5 postconf`
- `man postfix`
- `/usr/share/doc/postfix/`
- http://www.postfix.org/TLS_README.html

**Testing Tools:**
- `openssl s_client -starttls smtp`
- `swaks` (Swiss Army Knife for SMTP)

---

## Next Steps

Proceed to **Lab 09: OpenLDAP LDAPS** to learn LDAP over TLS.

---

**Difficulty Level**: Intermediate
