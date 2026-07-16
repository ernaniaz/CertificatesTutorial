# Lab 06: Apache HTTPS Setup

## Learning Objectives

By completing this lab, you will:
- Install Apache (httpd) with mod_ssl
- Configure Apache for HTTPS with certificates
- Understand RHEL version-specific SSL configuration
- Work with crypto-policies (RHEL 8+)
- Test HTTPS connections
- Configure virtual hosts with TLS

## Prerequisites

- **Labs 01-05** completed
- **RHEL Version:** 7, 8, 9, or 10
- **System Access:** Root/sudo required
- **Firewall:** Ports 80 and 443 access

## Time Estimate

**30-40 minutes**

## Lab Overview

Apache is the most common web server on RHEL. Learn to configure it with TLS certificates across all RHEL versions, handling version-specific differences.

---

## Instructions

### Step 1: Install Apache

Install Apache with SSL support:

```bash
sudo ./install-apache.sh
```

This installs:
- `httpd` (Apache web server)
- `mod_ssl` (SSL/TLS module)
- Opens firewall ports 80, 443

---

### Step 2: Configure SSL (Version-Specific)

Run the configuration script:

```bash
sudo ./configure-ssl.sh
```

This:
- Copies certificates from Lab 04
- Creates SSL VirtualHost configuration
- Applies version-specific TLS settings
- Restarts Apache

---

### Step 3: Test HTTPS Connection

Test your Apache HTTPS setup:

```bash
./test-connection.sh
```

This tests:
- HTTP connection (port 80)
- HTTPS connection (port 443)
- Certificate validity
- TLS version and ciphers

---

### Step 4: Verify Configuration

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
- ✅ Apache installed and running
- ✅ HTTPS configured with certificates
- ✅ Port 443 accessible
- ✅ Certificate served correctly
- ✅ Understanding of version-specific differences

---

## Key Concepts

### Apache SSL Configuration Files

```
/etc/httpd/
├── conf/
│   └── httpd.conf          # Main config
├── conf.d/
│   └── ssl.conf            # SSL config (mod_ssl)
└── conf.modules.d/
    └── 00-ssl.conf         # Module loading
```

### Basic SSL Directives

```apache
SSLEngine on
SSLCertificateFile /path/to/cert.crt
SSLCertificateKeyFile /path/to/key.key
SSLCertificateChainFile /path/to/chain.crt
```

### Version Differences

**RHEL 7:**
- Manual TLS protocol configuration
- Manual cipher suite configuration
- `SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1`
- `SSLCipherSuite` explicit configuration

**RHEL 8+:**
- Crypto-policies handle TLS/ciphers automatically
- Minimal SSL directives needed
- System-wide policy enforcement
- `SSLEngine on` + certificate paths sufficient

---

## Troubleshooting

### Issue: Apache Won't Start

**Symptom:**
```
Job for httpd.service failed
```

**Solution:**
Check syntax and logs:
```bash
sudo apachectl configtest
sudo journalctl -xeu httpd
```

---

### Issue: Certificate Error

**Symptom:**
```
SSL_CTX_use_PrivateKey_file: error
```

**Solution:**
Check file paths and permissions:
```bash
ls -l /etc/pki/tls/certs/server.crt
ls -l /etc/pki/tls/private/server.key
# Private key should be mode 600
```

---

### Issue: Firewall Blocking

**Symptom:**
Cannot connect to https://localhost

**Solution** (only if firewalld is running):
```bash
systemctl is-active firewalld && sudo firewall-cmd --list-services
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

> **Note**: On RHEL 7, firewalld may not be running. If so, use `iptables` or simply skip this step.

---

## Version-Specific Notes

### RHEL 7
- Uses `yum` for installation
- Requires explicit cipher configuration
- Manual TLS version control

### RHEL 8+
- Uses `dnf` for installation
- Crypto-policies introduced
- Reduced SSL configuration needed

### RHEL 9+
- SHA-1 blocked by default
- Stricter certificate validation
- SANs required

---

## Cleanup

```bash
sudo ./cleanup.sh
```

This removes Apache and restores system state.

---

## Additional Resources

**Related Chapters:**
- Chapter 14: Apache httpd on RHEL

**Documentation:**
- `man httpd`
- `man apachectl`
- `/usr/share/doc/httpd/`

---

## Next Steps

Proceed to **Lab 07: NGINX HTTPS Setup** to learn NGINX configuration.

---

**Difficulty Level**: Intermediate
