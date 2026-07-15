# Lab 13: Let's Encrypt with Certbot

## Learning Objectives

By completing this lab, you will:
- Install Certbot for ACME protocol
- Obtain certificates from Let's Encrypt
- Configure automatic renewal
- Integrate with Apache and NGINX
- Test renewal process
- Set up systemd timers for automation
- Understand ACME challenge types

## Prerequisites

- **Labs 01-06** completed (Apache or NGINX knowledge)
- **RHEL Version:** 8, 9, or 10 (RHEL 7 is not supported)
- **System Access:** Root/sudo required
- **Internet connection** required
- **Public domain** (or use staging for testing)

## Time Estimate

**40-50 minutes**

## Lab Overview

Let's Encrypt is a free, automated Certificate Authority. Learn to use Certbot to obtain and automatically renew trusted certificates using the ACME protocol, eliminating manual certificate management.

---

## Instructions

### Step 1: Install Certbot

Install Certbot:

```bash
sudo ./install-certbot.sh
```

This installs:
- `certbot` command-line tool
- Web server plugins (if available)
- Dependencies

---

### Step 2: Obtain Certificate (Standalone)

Obtain certificate using standalone mode:

```bash
sudo ./obtain-standalone.sh
```

This:
- Stops web servers temporarily
- Runs built-in web server
- Completes HTTP-01 challenge
- Obtains certificate

---

### Step 3: Obtain Certificate (Apache/NGINX)

Obtain certificate with web server integration:

```bash
sudo ./obtain-webserver.sh
```

This:
- Integrates with running web server
- Auto-configures HTTPS
- No downtime required
- Tests configuration

---

### Step 4: Test Renewal

Test certificate renewal process:

```bash
sudo ./test-renewal.sh
```

This tests:
- Dry-run renewal
- Renewal hooks
- Configuration validation
- Error handling

---

### Step 5: Setup Auto-Renewal

Configure automatic renewal:

```bash
sudo ./setup-autorenewal.sh
```

This sets up:
- systemd timer
- Renewal hooks
- Email notifications

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
- ✅ Certbot installed
- ✅ Let's Encrypt certificate obtained
- ✅ Automatic renewal configured
- ✅ Web server configured
- ✅ Understanding of ACME protocol

---

## Key Concepts

### Let's Encrypt Overview

**What it is:**
- Free, automated Certificate Authority
- Uses ACME protocol
- Trusted by all major browsers
- 90-day certificate lifetime
- Automatic renewal recommended

**Rate Limits:**
- 50 certificates per domain per week
- 5 duplicate certificates per week
- Use staging environment for testing

### ACME Challenge Types

**HTTP-01 Challenge:**
- Places file in `.well-known/acme-challenge/`
- Requires port 80 accessible
- Can't use with wildcard certificates
- Most common method

**DNS-01 Challenge:**
- Creates DNS TXT record
- Works with wildcards
- No need for port 80
- Requires DNS API access

**TLS-ALPN-01 Challenge:**
- Uses port 443
- Less common
- Specific use cases

### Certbot Commands

**Obtain Certificate:**
```bash
# Standalone (stops web server)
certbot certonly --standalone -d example.com

# Webroot (no downtime)
certbot certonly --webroot -w /var/www/html -d example.com

# Apache plugin
certbot --apache -d example.com

# NGINX plugin
certbot --nginx -d example.com

# Manual DNS
certbot certonly --manual --preferred-challenges dns -d example.com
```

**Manage Certificates:**
```bash
# List certificates
certbot certificates

# Renew all
certbot renew

# Renew specific
certbot renew --cert-name example.com

# Test renewal (dry-run)
certbot renew --dry-run

# Revoke certificate
certbot revoke --cert-path /etc/letsencrypt/live/example.com/cert.pem
```

**Delete Certificate:**
```bash
certbot delete --cert-name example.com
```

### Certificate Locations

```
/etc/letsencrypt/
├── live/
│   └── example.com/
│       ├── cert.pem         # Certificate
│       ├── chain.pem        # Intermediate chain
│       ├── fullchain.pem    # cert.pem + chain.pem
│       └── privkey.pem      # Private key
├── archive/                 # All versions
├── renewal/                 # Renewal configs
└── accounts/                # ACME account info
```

### Renewal Automation

**Systemd Timer (RHEL 8+):**
```bash
systemctl list-timers certbot
systemctl status certbot-renew.timer
```

### Renewal Hooks

```bash
# Pre-hook (before renewal)
certbot renew --pre-hook "systemctl stop nginx"

# Post-hook (after renewal)
certbot renew --post-hook "systemctl reload nginx"

# Deploy-hook (only if renewed)
certbot renew --deploy-hook "systemctl reload httpd"
```

---

## Troubleshooting

### Issue: HTTP Challenge Fails

**Symptom:**
```
Failed authorization procedure
Connection refused
```

**Solution:**
```bash
# Ensure port 80 is accessible
sudo firewall-cmd --add-service=http
sudo firewall-cmd --reload

# Check web server
sudo systemctl status httpd
```

---

### Issue: Rate Limit Exceeded

**Symptom:**
```
too many certificates already issued
```

**Solution:**
Use staging environment for testing:
```bash
certbot --staging -d example.com
```

---

### Issue: Domain Validation Fails

**Symptom:**
```
DNS problem: NXDOMAIN
```

**Solution:**
Verify DNS:
```bash
dig example.com
nslookup example.com
# Ensure domain points to your server
```

---

### Issue: Renewal Fails

**Symptom:**
Certificate not renewed automatically

**Solution:**
```bash
# Test renewal
certbot renew --dry-run

# Check logs
journalctl -u certbot-renew

# Manual renewal
certbot renew --force-renewal
```

---

## Version-Specific Notes

### RHEL 8
- Available in AppStream
- Uses systemd timers
- Better plugin integration

### RHEL 9
- certbot 1.x or 2.x
- Enhanced security
- Improved automation

---

## Cleanup

```bash
sudo ./cleanup.sh
```

This removes Certbot and certificates.

---

## Additional Resources

**Related Chapters:**
- Chapter 24: Let's Encrypt with Certbot

**Documentation:**
- `man certbot`
- https://letsencrypt.org/docs/
- https://certbot.eff.org/
- https://community.letsencrypt.org/

**Rate Limits:**
- https://letsencrypt.org/docs/rate-limits/

**Staging Environment:**
```bash
certbot --staging ...
# Staging URL: https://acme-staging-v02.api.letsencrypt.org/directory
```

---

## Next Steps

Proceed to **Lab 14: Ansible Automation** to learn certificate deployment at scale.

---

**Difficulty Level:** Intermediate
**Note:** Requires internet connection and ideally a real domain for production certificates
