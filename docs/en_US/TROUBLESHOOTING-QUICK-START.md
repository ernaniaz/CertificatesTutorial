# Troubleshooting Quick-Start Guide

**When you have a certificate problem, start here!**

---

## 🚨 Emergency? Jump to Chapter 33!

If production is down, go immediately to [Chapter 33: Emergency Procedures](part-05-troubleshooting/33-emergency-procedures.md)

---

## 📋 The 7-Step Method (Chapter 27)

```
1. Identify: RHEL version, OpenSSL, crypto-policy
2. Verify: Expiry, hostname, key match, algorithm
3. Trust: CA validation, chain, intermediates
4. Config: Service files, paths, permissions
5. System: Crypto-policy, FIPS, SELinux, firewall
6. Test: Live connections, curl, openssl s_client
7. Logs: Service logs, journal, SELinux audit
```

**Full methodology:** [Chapter 27](part-05-troubleshooting/27-troubleshooting-methodology.md)

---

## ⚡ Quick Diagnostics

### First 60 Seconds

```bash
# What RHEL version?
cat /etc/redhat-release

# Certificate expired?
openssl x509 -in /etc/pki/tls/certs/server.crt -noout -checkend 0

# Service running?
systemctl status httpd

# Recent errors?
journalctl -xe | grep -i cert | tail -20

# Crypto-policy? (RHEL 8+)
update-crypto-policies --show
```

---

## 🔍 Common Problems

### Certificate Expired
```bash
# Check
openssl x509 -in cert.crt -noout -dates

# Fix
sudo getcert resubmit -f cert.crt  # If using certmonger tracking
# Or renew manually, or use Chapter 33 emergency procedures
```

### Trust Chain Broken
```bash
# Check
openssl verify cert.crt

# Fix
sudo cp ca.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust
```

### Permission Denied
```bash
# Check
ls -l /etc/pki/tls/private/server.key

# Fix
sudo chmod 600 /etc/pki/tls/private/server.key
sudo chown root:root /etc/pki/tls/private/server.key
```

### Hostname Mismatch
```bash
# Check
openssl x509 -in cert.crt -noout -ext subjectAltName

# Fix
# Reissue certificate with correct SANs
```

### No Shared Cipher (RHEL 8+)
```bash
# Check
update-crypto-policies --show

# Temporary fix
sudo update-crypto-policies --set LEGACY
sudo systemctl restart httpd

# Proper fix: Update client to support TLS 1.2+
```

### SHA-1 Rejected (RHEL 9+)
```bash
# Check
openssl x509 -in cert.crt -noout -text | grep "Signature Algorithm"

# Fix
# Must reissue with SHA-256+ (no workaround)
```

---

## 📖 Where to Look

| Problem Type | Go To Chapter |
|--------------|---------------|
| **General troubleshooting** | Chapter 27 |
| **Common errors** | Chapter 28 |
| **Apache/NGINX/Postfix issues** | Chapter 29 |
| **certmonger problems** | Chapter 30 |
| **crypto-policy issues** | Chapter 31 |
| **SOS report analysis** | Chapter 32 |
| **Production emergency** | Chapter 33 |
| **RHEL 7 specific** | Chapter 9 |
| **RHEL 8 specific** | Chapter 10 |
| **RHEL 9 specific** | Chapter 11 |
| **RHEL 10 specific** | Chapter 12 |
| **After migration** | Chapters 35-36 |

---

## ⚙️ Service-Specific Commands

```bash
# Apache
apachectl configtest
tail -f /var/log/httpd/ssl_error_log

# NGINX
nginx -t
tail -f /var/log/nginx/error.log

# Postfix
postfix check
tail -f /var/log/maillog | grep TLS

# OpenLDAP
slapcat -b "cn=config" | grep TLS
# Note: Keys must be owned by ldap:ldap!

# PostgreSQL
sudo -u postgres psql -c "SHOW ssl;"
# Note: Keys must be owned by postgres:postgres!

# certmonger
getcert list
journalctl -u certmonger -f
```

---

## 🎯 Quick Reference

**Most Common Issues:**
1. Certificate expired → Renew
2. Missing CA → Add to trust store
3. Wrong permissions → chmod 600
4. Cert/key mismatch → Regenerate CSR
5. Hostname mismatch → Reissue with SANs
6. TLS version → Check crypto-policy
7. SELinux denying → restorecon
8. certmonger CA_UNREACHABLE → Check IPA/Kerberos

**Emergency:** [Chapter 33](part-05-troubleshooting/33-emergency-procedures.md)

**Methodology:** [Chapter 27](part-05-troubleshooting/27-troubleshooting-methodology.md)
