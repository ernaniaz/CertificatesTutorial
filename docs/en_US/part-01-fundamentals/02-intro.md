# Chapter 2: Introduction to Certificates on RHEL

> **Welcome!** This tutorial will take you from knowing nothing about digital certificates to confidently troubleshooting certificate issues on Red Hat Enterprise Linux systems.

---

## 2.1 Why This Tutorial?

You're a RHEL administrator. One day, something breaks:

- Apache refuses to start: `SSL_CTX_use_certificate:ca md too weak`
- LDAP connections fail: `TLS: hostname does not match CN`
- certmonger shows: `CA_UNREACHABLE`
- curl returns: `SSL certificate problem: unable to get local issuer certificate`

**Sound familiar?** These are certificate issues, and they're everywhere in modern Linux systems.

This tutorial teaches you to:

- ✅ Understand what certificates are (RHEL perspective)
- ✅ Configure certificates for common RHEL services
- ✅ **Troubleshoot certificate problems** (primary goal!)
- ✅ Automate certificate lifecycle with RHEL tools
- ✅ Handle RHEL version differences (7, 8, 9, 10)
- ✅ Pass audits (FIPS, STIG, compliance)

---

## 2.2 Who Is This For?

**Primary Audience:**
- RHEL administrators and engineers
- Support engineers troubleshooting certificate issues
- Anyone managing RHEL systems with HTTPS, LDAPS, or TLS

**Prerequisites:**
- Basic Linux command line knowledge
- Access to RHEL systems (7, 8, 9, or 10)
- No prior certificate knowledge needed!

---

## 2.3 What Are Certificates? (In 60 Seconds)

Imagine you visit https://example.com. How does your browser know it's really talking to example.com and not an imposter?

**Answer: Digital certificates.**

A certificate is like a digital ID card that:
1. **Proves identity** ("I am example.com")
2. **Enables encryption** (secure communication)
3. **Is signed by a trusted authority** (like a CA)

### On RHEL Systems

Certificates are used everywhere:
- **Web servers** (Apache, NGINX) → HTTPS
- **Directory services** (OpenLDAP, FreeIPA) → LDAPS
- **Mail servers** (Postfix, Dovecot) → SMTPS/IMAPS
- **Databases** (PostgreSQL, MySQL) → TLS connections
- **APIs and services** (REST, microservices) → mTLS
- **VPN tunnels** → Secure connections
- **Container registries** → Secure images

**Bottom line:** If it's networked and secure on RHEL, it probably uses certificates.

---

## 2.4 Your First Certificate Inspection

Let's get hands-on immediately. On any RHEL system, run:

```bash
# Check a web server's TLS certificate (HTTPS, port 443)
echo | openssl s_client -connect access.redhat.com:443 2>/dev/null | openssl x509 -noout -text | head -20

# Alternative: inspect mail STARTTLS on port 25 (-starttls smtp matches SMTP, not SSH)
echo | openssl s_client -connect localhost:25 -starttls smtp 2>/dev/null | openssl x509 -noout -text | head -20
```

You'll see output like:

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            0a:5d:d2:48:fc:4e:2f:e2:99:81:09:74:2d:4c:d5:69
        Signature Algorithm: ecdsa-with-SHA384
        Issuer: C=US, O=DigiCert Inc, CN=DigiCert Global G3 TLS ECC SHA384 2020 CA1
        Validity
            Not Before: Oct 30 00:00:00 2025 GMT
            Not After : Oct 27 23:59:59 2026 GMT
        Subject: C=US, ST=North Carolina, L=Raleigh, O=Red Hat, Inc., CN=access.redhat.com
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub:
                    04:fc:08:bf:d2:d8:63:0c:84:a4:c8:dd:04:9c:8c:
                    99:4f:cb:93:31:7f:9e:64:27:ea:3d:a7:18:fd:3e:
                    4c:c2:58:8b:cb:f2:5c:6e:95:bf:f3:97:ba:b8:2b:
                    49:c6:51:30:f4:71:88:e3:fa:d4:f1:73:74:1d:e3:
                    2b:49:bc:9e:6e
```

**What you're seeing:**
- **Issuer:** Who signed this certificate
- **Subject:** Who this certificate belongs to
- **Validity:** When it's valid (Not Before / Not After dates)
- **Signature Algorithm:** How it's secured (for example, ECDSA with SHA-384)

**🎉 Congratulations!** You just inspected your first certificate.

---

## 2.5 How Certificates Work (RHEL Context)

### The Three Key Components

1. **Certificate** (`.crt`, `.pem`)
   - Public information: "I am server.example.com"
   - Contains the public key
   - Stored in `/etc/pki/tls/certs/` on RHEL

2. **Private Key** (`.key`, `.pem`)
   - Secret! Never share this
   - Used to prove you own the certificate
   - Stored in `/etc/pki/tls/private/` on RHEL (mode 600!)

3. **Certificate Authority (CA)**
   - Issues and signs certificates
   - Could be public (Let's Encrypt, DigiCert)
   - Or internal (FreeIPA, corporate CA)
   - Trusted CAs stored in `/etc/pki/ca-trust/` on RHEL

### The Trust Chain

```
Root CA (trusted by RHEL system)
  └─ Intermediate CA
      └─ Server Certificate (your web server)
```

When someone connects to your RHEL server:
1. Server sends its certificate
2. Client verifies signature chain back to a trusted root CA
3. If chain is valid → connection proceeds
4. If chain breaks → error (and you get the support call!)

---

## 2.6 RHEL's Certificate Architecture

### Key Directories

```
/etc/pki/
├── ca-trust/
│   ├── source/anchors/      ← Put custom CA certs here
│   └── extracted/           ← System-wide trust store
│       ├── pem/             ← PEM format CAs
│       ├── openssl/         ← OpenSSL trust
│       └── java/            ← Java trust (cacerts)
├── tls/
│   ├── certs/               ← Server certificates
│   ├── private/             ← Private keys (mode 700!)
│   └── cert.pem             ← Default certificate symlink
└── nssdb/                   ← NSS database (Firefox, etc.)
```

### Key Tools

```bash
# OpenSSL - Swiss army knife of certificates
openssl version  # Check your version

# NSS Tools - For NSS databases
certutil -L -d /etc/pki/nssdb

# Trust Management - Add/remove CAs
update-ca-trust  # RHEL's trust store updater

# Certificate Manager - Automatic renewal (RHEL 7+)
getcert list  # Show tracked certificates

# Crypto-Policies - System-wide security (RHEL 8+)
update-crypto-policies --show  # Check current policy
```

---

## 2.7 A Day in the Life: Certificate Scenarios

### Scenario 1: Adding a Custom CA

```bash
# You have a corporate CA that signed your internal servers
sudo cp corporate-ca.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust extract

# Now RHEL trusts certificates signed by your corporate CA!
```

### Scenario 2: Setting Up Apache HTTPS

```bash
# Install Apache with SSL/TLS
sudo dnf install httpd mod_ssl

# Generate a private key
sudo openssl genpkey -algorithm RSA -out /etc/pki/tls/private/server.key \
  -pkeyopt rsa_keygen_bits:2048

# Generate a certificate signing request (CSR)
sudo openssl req -new -key /etc/pki/tls/private/server.key \
  -out /tmp/server.csr \
  -subj "/CN=web.example.com"

# Send CSR to CA, get certificate back, install it
sudo cp server.crt /etc/pki/tls/certs/

# Configure Apache, restart
sudo systemctl restart httpd
```

### Scenario 3: Troubleshooting an Expired Certificate

```bash
# Service fails with: "certificate has expired"
# Check certificate expiration
sudo openssl x509 -in /etc/pki/tls/certs/server.crt -noout -dates

# Output shows:
# notAfter=Jan 15 23:59:59 2024 GMT  ← Oops, expired!

# Renew certificate, replace file, restart service
```

---

## 2.8 RHEL Version Differences (Preview)

Certificate management has evolved significantly across RHEL versions:

| RHEL Version | Key Feature | Troubleshooting Focus |
|--------------|-------------|----------------------|
| **RHEL 7** | Traditional approach | Manual configuration, legacy TLS issues |
| **RHEL 8** | **Crypto-policies** | Policy conflicts, certmonger integration |
| **RHEL 9** | OpenSSL 3.x | Provider issues, stricter validation |
| **RHEL 10** | Hardened defaults | Modern-only, enhanced tooling |

> **Don't worry!** Chapter 8 covers these version differences in detail.

---

## 2.9 Common Certificate Problems (Preview)

You'll learn to troubleshoot:

**Configuration Issues:**
- Certificate/key mismatch
- Wrong file permissions
- Incorrect paths in config files

**Trust Issues:**
- Self-signed certificates rejected
- Unknown CA errors
- Chain validation failures

**Expiration Issues:**
- Expired certificates
- Clock skew problems
- Renewal failures

**Version Issues:**
- TLS version mismatches
- Cipher suite problems
- Crypto-policy conflicts (RHEL 8+)
- OpenSSL 3.x compatibility (RHEL 9+)

**Service-Specific:**
- Apache: `SSLCertificateFile` errors
- NGINX: `ssl_certificate` problems
- Postfix: TLS handshake failures
- LDAP: `TLS: hostname does not match`

---

## 2.10 Learning Path Overview

This tutorial is organized for RHEL administrators:

### Part 1: Foundations (Chapters 1-7)
Start here. Learn certificate basics in RHEL context.

### Part 2: Version-Specific (Chapters 8-13)
Deep dive into RHEL 7, 8, 9, 10 differences.

### Part 3: Services (Chapters 14-21)
Configure certificates for Apache, NGINX, Postfix, LDAP, etc.

### Part 4: Automation (Chapters 22-26)
Master certmonger, crypto-policies, Let's Encrypt, Ansible.

### Part 5: Troubleshooting (Chapters 27-33) ⭐
**This is where you become an expert!**
Systematic troubleshooting, common errors, emergency procedures.

### Part 6: Migration (Chapters 34-37)
RHEL version upgrades and certificate migration.

### Part 7: Security (Chapters 38-41)
FIPS mode, compliance, hardening, auditing.

### Appendices
Optional advanced topics (Kubernetes, Vault, Zero Trust, etc.)

---

## 2.11 How to Use This Tutorial

### For New Users
📖 Read chapters in order. Each builds on previous knowledge.

### For Experienced Users
🎯 Jump to troubleshooting (Part 5) or specific services (Part 3).

### For Support Engineers
🚨 Start with Chapter 27 (Troubleshooting Methodology), then dive into specifics.

### Hands-On Labs
Every chapter includes practical examples. You'll need:
- A RHEL system (VM or container is fine)
- Root or sudo access
- Internet connectivity (for package installs)

---

## 2.12 Key Concepts to Master

By the end of this tutorial, you'll understand:

- ✅ **What certificates are** and why RHEL uses them
- ✅ **How trust works** on RHEL systems
- ✅ **Where certificates live** (`/etc/pki/`)
- ✅ **Which tools to use** (openssl, certutil, certmonger)
- ✅ **Version differences** (RHEL 7 vs 8 vs 9 vs 10)
- ✅ **How to troubleshoot** any certificate issue
- ✅ **How to automate** certificate lifecycle
- ✅ **How to secure** systems (FIPS, compliance)

---

## 2.13 Real-World Impact

Certificate issues cause:
- ❌ Service outages (expired certs)
- ❌ Security vulnerabilities (weak ciphers)
- ❌ Failed migrations (RHEL upgrades)
- ❌ Compliance failures (audit rejections)
- ❌ Lost productivity (troubleshooting time)

**After this tutorial:**
- ✅ Prevent issues before they happen
- ✅ Troubleshoot problems in minutes, not hours
- ✅ Automate certificate management
- ✅ Pass security audits
- ✅ Confidently migrate RHEL versions

---

## 2.14 Your First Exercise

Let's verify your RHEL system is ready:

```bash
# Check RHEL version
cat /etc/redhat-release

# Check OpenSSL
openssl version

# Check if certmonger is installed
rpm -q certmonger

# Check if you can use sudo
sudo whoami

# Check internet connectivity (for package installs)
ping -c 3 access.redhat.com

# List current trusted CAs (sample)
trust list | head -20
```

✅ If all commands work, you're ready to proceed!

---

## 2.15 Let's Begin!

You now understand:
- What certificates are
- Why they matter on RHEL
- Where they live on the filesystem
- Which tools you'll use
- What you'll learn in this tutorial

**Ready to dive deeper?**

---

## Quick Reference

```
┌────────────────────────────────────────────────────────────┐
│ CERTIFICATE QUICK START (RHEL)                             │
├────────────────────────────────────────────────────────────┤
│ View cert:     openssl x509 -in cert.crt -noout -text      │
│ Check expiry:  openssl x509 -in cert.crt -noout -dates     │
│ Add CA:        cp ca.crt /etc/pki/ca-trust/source/anchors/ │
│                sudo update-ca-trust                        │
│ List tracked:  getcert list                                │
│ Check policy:  update-crypto-policies --show  (RHEL 8+)    │
└────────────────────────────────────────────────────────────┘

Cert location:  /etc/pki/tls/certs/
Key location:   /etc/pki/tls/private/  (mode 600!)
CA trust:       /etc/pki/ca-trust/
```

---

## 🧪 Hands-On Lab

**Lab 01: Environment Setup**

Validate your RHEL environment and install essential certificate management tools

- 📁 **Location:** `labs/en_US/01-environment-setup/`
- ⏱️ **Time:** 15-20 minutes
- 🎯 **Level:** Beginner

---

**Chapter Navigation**

| [← Previous: Chapter 1 - Cryptography, PKI Structure & Fundamentals](01-cryptography-pki-basics.md) | [Next: Chapter 3 - RHEL Certificate Tools Overview →](03-rhel-tools-overview.md) |
|:---|---:|
