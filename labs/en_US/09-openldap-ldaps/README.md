# Lab 09: OpenLDAP LDAPS Configuration

## Learning Objectives

By completing this lab, you will:
- Install and configure OpenLDAP server
- Configure LDAP over TLS (LDAPS) on port 636
- Configure STARTTLS on port 389
- Set up LDAP client TLS configuration
- Test secure LDAP connections
- Understand cn=config vs slapd.conf

## Prerequisites

- **Labs 01-05** completed
- **RHEL Version:** 7, 8, 9, or 10
- **System Access:** Root/sudo required
- **Ports:** 389 (LDAP), 636 (LDAPS)

## Time Estimate

**40-50 minutes**

## Lab Overview

OpenLDAP is a directory service implementation. Learn to configure it with TLS for secure authentication and directory queries using both LDAPS (dedicated TLS port) and STARTTLS (upgrade plain connection).

---

## Instructions

### Step 1: Install OpenLDAP

Install OpenLDAP server:

```bash
sudo ./install-openldap.sh
```

This installs:
- `openldap-servers` (LDAP server)
- `openldap-clients` (client tools)
- Basic directory structure

> **Note:** On RHEL 9+, `openldap-servers` was removed from the base repositories. The script automatically enables EPEL to install it.

---

### Step 2: Configure LDAPS

Configure LDAP with TLS certificates:

```bash
sudo ./configure-ldaps.sh
```

This:
- Copies certificates from Lab 04
- Configures TLS in cn=config
- Enables LDAPS on port 636
- Sets up certificate paths
- Restarts slapd

---

### Step 3: Configure LDAP Client

Configure LDAP client for TLS:

```bash
sudo ./configure-client.sh
```

This:
- Configures `/etc/openldap/ldap.conf`
- Sets TLS certificate path
- Configures TLS options
- Enables certificate validation

---

### Step 4: Test Connections

Test LDAP and LDAPS connections:

```bash
./test-connection.sh
```

This tests:
- Plain LDAP (port 389)
- STARTTLS on port 389
- LDAPS on port 636
- Certificate validation

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
- ✅ OpenLDAP installed and running
- ✅ LDAPS working on port 636
- ✅ STARTTLS working on port 389
- ✅ Client configured for TLS
- ✅ Understanding of LDAP TLS configuration

---

## Key Concepts

### OpenLDAP Configuration

**RHEL 7:**
- Uses `/etc/openldap/slapd.conf` (traditional)
- Text-based configuration
- Requires restart to apply changes

**RHEL 8+:**
- Uses cn=config (dynamic configuration)
- LDIF-based in `/etc/openldap/slapd.d/`
- Changes applied without restart

### LDAP Ports

**Port 389 (LDAP):**
- Plain LDAP
- Supports STARTTLS upgrade
- Default LDAP port

**Port 636 (LDAPS):**
- LDAP over TLS from start
- Like HTTPS vs HTTP
- Dedicated secure port

### TLS Configuration Directives

**Server (cn=config):**
```ldif
olcTLSCertificateFile: /etc/pki/tls/certs/ldap.crt
olcTLSCertificateKeyFile: /etc/pki/tls/private/ldap.key
olcTLSCACertificateFile: /etc/pki/tls/certs/ca-bundle.crt
olcTLSProtocolMin: 3.3
olcTLSCipherSuite: HIGH:!aNULL:!MD5
```

**Client (/etc/openldap/ldap.conf):**
```conf
TLS_CACERTDIR /etc/openldap/certs
TLS_REQCERT allow
URI ldaps://localhost
```

### ldapsearch Commands

```bash
# Plain LDAP
ldapsearch -x -H ldap://localhost -b "" -s base

# LDAP with STARTTLS
ldapsearch -x -H ldap://localhost -b "" -s base -ZZ

# LDAPS
ldapsearch -x -H ldaps://localhost -b "" -s base
```

---

## Troubleshooting

### Issue: slapd Won't Start

**Symptom:**
```
Job for slapd.service failed
```

**Solution:**
Check logs and configuration:
```bash
journalctl -xeu slapd
slapd -d 1  # Debug mode
# Check file permissions on certificates
```

---

### Issue: TLS Handshake Failed

**Symptom:**
```
ldap_start_tls: Connect error (-11)
TLS: can't connect: TLS error
```

**Solution:**
Check certificate configuration:
```bash
# Verify certificates are readable by ldap user
ls -l /etc/openldap/certs/
# Check SELinux contexts
ls -Z /etc/openldap/certs/
# Restore contexts if needed
restorecon -Rv /etc/openldap/certs/
```

---

### Issue: Certificate Verification Failed

**Symptom:**
```
TLS certificate verification: Error, self signed certificate
```

**Solution:**
Configure client to trust certificate:
```bash
# Option 1: Use TLS_REQCERT allow (for lab/testing)
echo "TLS_REQCERT allow" >> /etc/openldap/ldap.conf

# Option 2: Add CA certificate (production)
cp /path/to/ca.crt /etc/openldap/certs/
echo "TLS_CACERT /etc/openldap/certs/ca.crt" >> /etc/openldap/ldap.conf
```

---

### Issue: Port 636 Not Listening

**Symptom:**
Cannot connect to ldaps://localhost:636

**Solution:**
Enable LDAPS in slapd configuration:
```bash
# Check slapd arguments
systemctl cat slapd | grep ExecStart

# RHEL 8+: Edit /etc/sysconfig/slapd
# Add: SLAPD_URLS="ldap:/// ldaps:/// ldapi:///"

systemctl restart slapd
ss -tlnp | grep 636
```

---

## Version-Specific Notes

### RHEL 7
- Uses `yum` for installation
- May use slapd.conf (traditional config)
- Manual TLS protocol configuration
- TLS support via OpenSSL

### RHEL 8
- Uses `dnf` for installation
- cn=config only (no slapd.conf)
- Crypto-policies affect TLS
- OpenLDAP 2.4.x

### RHEL 9
- **`openldap-servers` removed from base repos** — installed from EPEL
- OpenLDAP 2.4.x or 2.5.x
- Stricter TLS defaults
- SHA-1 blocked by default
- Enhanced security policies
- Better SELinux integration

---

## Cleanup

```bash
sudo ./cleanup.sh
```

This removes OpenLDAP and restores system state.

---

## Additional Resources

**Related Chapters:**
- Chapter 17: OpenLDAP LDAPS

**Documentation:**
- `man slapd`
- `man slapd.conf` (RHEL 7)
- `man slapd-config` (cn=config)
- `man ldap.conf`
- https://www.openldap.org/doc/admin24/tls.html

**Client Tools:**
- `ldapsearch` - search directory
- `ldapadd` - add entries
- `ldapmodify` - modify entries

---

## Next Steps

Proceed to **Lab 10: PostgreSQL TLS** to learn database TLS configuration.

---

**Difficulty Level**: Intermediate to Advanced
