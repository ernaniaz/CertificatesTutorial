# Lab 07: NGINX HTTPS Setup

## Learning Objectives

By completing this lab, you will:
- Install NGINX web server
- Configure NGINX for HTTPS with certificates
- Understand NGINX SSL configuration syntax
- Work with NGINX server blocks
- Test HTTPS connections with NGINX
- Understand RHEL version-specific differences

## Prerequisites

- **Labs 01-05** completed
- **RHEL Version:** 7, 8, 9, or 10
- **System Access:** Root/sudo required
- **Firewall:** Ports 80 and 443 access

## Time Estimate

**30-40 minutes**

## Lab Overview

NGINX is a high-performance web server and reverse proxy. Learn to configure it with TLS certificates across all RHEL versions, understanding how it differs from Apache.

---

## Instructions

### Step 1: Install NGINX

Install NGINX:

```bash
sudo ./install-nginx.sh
```

This installs:
- `nginx` web server
- Opens firewall ports 80, 443
- Creates basic configuration

**Notes**:
- RHEL 7 does not include NGINX in its base repositories. The script installs EPEL (`epel-release` from archives.fedoraproject.org, since EPEL 7 is archived) to provide the `nginx` package;
- The service name is `nginx` on all supported RHEL versions.

---

### Step 2: Configure SSL (Version-Specific)

Run the configuration script:

```bash
sudo ./configure-ssl.sh
```

This:
- Copies certificates from Lab 04
- Creates SSL server block configuration
- Applies version-specific TLS settings
- Restarts NGINX

---

### Step 3: Test HTTPS Connection

Test your NGINX HTTPS setup:

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
- ✅ NGINX installed and running
- ✅ HTTPS configured with certificates
- ✅ Port 443 accessible
- ✅ Certificate served correctly
- ✅ Understanding of NGINX vs Apache differences

---

## Key Concepts

### NGINX Configuration Structure

```
/etc/nginx/
├── nginx.conf               # Main configuration
├── conf.d/                  # Custom configurations
│   └── default.conf         # Default server block
└── default.d/               # Additional configs
```

### Basic SSL Directives

```nginx
server {
    listen 443 ssl;
    server_name example.com;

    ssl_certificate /path/to/cert.crt;
    ssl_certificate_key /path/to/key.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
}
```

### NGINX vs Apache

**NGINX:**
- Event-driven architecture
- Configuration in `nginx.conf` and `/etc/nginx/conf.d/`
- Test config: `nginx -t`
- Reload: `nginx -s reload`
- Server blocks instead of VirtualHosts

**Apache:**
- Process/thread-driven
- Configuration in `/etc/httpd/conf.d/`
- Test config: `apachectl configtest`
- Reload: `systemctl reload httpd`
- VirtualHosts

### Version Differences

**RHEL 7:**
- Manual TLS protocol configuration
- Explicit cipher suite configuration
- `ssl_protocols TLSv1.2 TLSv1.3;`
- `ssl_ciphers` explicit configuration

**RHEL 8+:**
- Crypto-policies can be used
- But NGINX requires more explicit config than Apache
- Still specify protocols and ciphers
- System-wide policy affects available options

---

## Troubleshooting

### Issue: NGINX Won't Start

**Symptom:**
```
Job for nginx.service failed
```

**Solution:**
Check syntax and logs:
```bash
sudo nginx -t
sudo journalctl -xeu nginx
```

---

### Issue: Configuration Syntax Error

**Symptom:**
```
nginx: [emerg] unexpected "}" in /etc/nginx/...
```

**Solution:**
Check for missing semicolons and braces:
```bash
nginx -t
# Each directive needs semicolon
# server blocks need { }
```

---

### Issue: Certificate Error

**Symptom:**
```
nginx: [emerg] cannot load certificate
```

**Solution:**
Check file paths and permissions:
```bash
ls -l /etc/pki/nginx/server.crt
ls -l /etc/pki/nginx/private/server.key
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

### Issue: SELinux Blocking Certificate Access

**Symptom:**
```
nginx: [emerg] BIO_new_file(...) failed
```

**Solution:**
Check SELinux contexts:
```bash
sudo setenforce 0  # Temporary test
# If that fixes it, fix SELinux contexts:
sudo restorecon -Rv /etc/pki/nginx/
sudo setenforce 1
```

---

## Version-Specific Notes

### RHEL 7
- Uses `yum` for installation
- NGINX version 1.20.x typically
- Requires explicit cipher configuration
- Manual TLS version control

### RHEL 8+
- Uses `dnf` for installation
- NGINX version 1.20.x typically
- Crypto-policies exist but NGINX needs explicit config
- Can reference system policy

### RHEL 9+
- NGINX version 1.20.x or newer
- SHA-1 blocked by default
- Stricter certificate validation
- SANs required
- TLSv1.3 preferred

---

## Cleanup

```bash
sudo ./cleanup.sh
```

This removes NGINX and restores system state.

---

## Additional Resources

**Related Chapters:**
- Chapter 15: NGINX on RHEL

**Documentation:**
- `man nginx`
- `/usr/share/doc/nginx/`
- https://nginx.org/en/docs/

**NGINX SSL Module:**
- http://nginx.org/en/docs/http/ngx_http_ssl_module.html

---

## Next Steps

Proceed to **Lab 08: Postfix TLS** to learn mail server TLS configuration.

---

**Difficulty Level:** Intermediate
