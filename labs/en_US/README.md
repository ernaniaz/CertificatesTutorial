# 🧪 Laboratory Exercises

Complete hands-on labs to practice what you've learned. Each lab includes working scripts, step-by-step instructions, and validation procedures.

---

## Labs by Category

### 📚 Foundation Labs (1-5)

| Lab | Title | Time | Level | Chapter |
|-----|-------|------|-------|---------|
| [01](01-environment-setup/) | Environment Setup | 15-20 min | Beginner | Ch 1-3 |
| [02](02-key-generation/) | Key Generation | 20-25 min | Beginner | Ch 4 |
| [03](03-digital-signatures/) | Digital Signatures | 20 min | Beginner | Ch 7 |
| [04](04-x509-certificates/) | X.509 Certificates | 25-30 min | Beginner | Ch 5 |
| [05](05-trust-store/) | Trust Store Management | 25 min | Beginner | Ch 6 |

### 🌐 Service Configuration Labs (6-10)

| Lab | Title | Time | Level | Chapter |
|-----|-------|------|-------|---------|
| [06](06-apache-https/) | Apache HTTPS Setup | 30-40 min | Intermediate | Ch 14 |
| [07](07-nginx-https/) | NGINX HTTPS Setup | 30-35 min | Intermediate | Ch 15 |
| [08](08-postfix-tls/) | Postfix TLS | 30-40 min | Intermediate | Ch 16 |
| [09](09-openldap-ldaps/) | OpenLDAP LDAPS | 40-50 min | Intermediate | Ch 17 |
| [10](10-postgresql-tls/) | PostgreSQL TLS | 30-40 min | Intermediate | Ch 18 |

### ⚙️ Automation Labs (11-14)

| Lab | Title | Time | Level | Chapter |
|-----|-------|------|-------|---------|
| [11](11-certmonger-basics/) | certmonger Basics | 40-50 min | Intermediate | Ch 22 |
| [12](12-crypto-policies/) | Crypto-Policies | 30-40 min | Intermediate | Ch 23 |
| [13](13-letsencrypt-certbot/) | Let's Encrypt & Certbot | 40-50 min | Intermediate | Ch 24 |
| [14](14-ansible-automation/) | Ansible Automation | 50-60 min | Advanced | Ch 25 |

### 🔧 Troubleshooting Labs (15-16) - CRITICAL

| Lab | Title | Time | Level | Chapter |
|-----|-------|------|-------|---------|
| [15](15-troubleshooting-scenarios/) | Troubleshooting Scenarios (expired certificate) | 15-20 min | Advanced | Ch 27-29 |
| [16](16-emergency-procedures/) | Emergency Procedures | 30-40 min | Advanced | Ch 33 |

### 🔄 Migration Labs (17-18)

| Lab | Title | Time | Level | Chapter |
|-----|-------|------|-------|---------|
| [17](17-rhel7to8-migration/) | RHEL 7→8 Migration | 40-50 min | Advanced | Ch 35 |
| [18](18-rhel8to9-migration/) | RHEL 8→9 Migration | 40-50 min | Advanced | Ch 36 |

### 🔒 Security Labs (19-20)

| Lab | Title | Time | Level | Chapter |
|-----|-------|------|-------|---------|
| [19](19-fips-mode/) | FIPS Mode Configuration | 40-50 min | Advanced | Ch 38-39 |
| [20](20-security-hardening/) | Security Hardening | 30-40 min | Advanced | Ch 40 |

### 🚀 Advanced/Appendix Labs (21-22)

| Lab | Title | Time | Level | Chapter |
|-----|-------|------|-------|---------|
| [21](21-kubernetes-cert-manager/) | Kubernetes cert-manager | 40-50 min | Advanced | Appendix A |
| [22](22-vault-pki/) | HashiCorp Vault PKI | 35-45 min | Advanced | Appendix B |

---

## Lab Features

Labs generally include:
- ✅ **README.md** - Complete instructions and learning objectives
- ✅ **Shell scripts** - Working, tested automation scripts
- ✅ **Validation** - A documented validation command or procedure
- ✅ **Cleanup** - Cleanup procedures where the lab provides them
- ✅ **Error handling** - Colored output and helpful error messages
- ✅ **RHEL version notes** - Check each lab README for the supported RHEL versions

---

## Learning Paths

### Beginner Path (Start Here!)
1. Lab 01: Environment Setup
2. Lab 02: Key Generation
3. Lab 03: Digital Signatures
4. Lab 04: X.509 Certificates
5. Lab 05: Trust Store

### Service Administrator Path
1. Complete Foundation Labs (1-5)
2. Lab 06: Apache HTTPS
3. Lab 07: NGINX HTTPS
4. Lab 08-10: Additional Services

### Automation Engineer Path
1. Complete Foundation Labs (1-5)
2. Lab 11: certmonger Basics
3. Lab 12: Crypto-Policies
4. Lab 13: Let's Encrypt
5. Lab 14: Ansible Automation

### Production Support Path (Most Important!)
1. Complete Foundation Labs (1-5)
2. Lab 15: Troubleshooting Scenarios ⭐
3. Lab 16: Emergency Procedures ⭐
4. Labs 17-18: Migration Labs
5. Labs 19-20: Security Labs

---

## Quick Start

```bash
# Navigate to labs directory
cd labs/en_US

# Start with Lab 01
cd 01-environment-setup
./setup.sh
./verify-environment.sh

# Each lab follows the validation flow documented in its README:
cd ../XX-lab-name/
./script-name.sh
./verify*.sh or ./test*.sh
./cleanup*.sh
```

---

## Prerequisites

- **RHEL System:** Version 7, 8, 9, or 10
- **Access:** Root or sudo privileges
- **Skills:** Basic Linux command-line knowledge
- **Time:** Allow 15-90 minutes per lab

---

## Support

- **Issues?** Check each lab's Troubleshooting section in README.md
- **Questions?** Refer back to relevant tutorial chapters
- **Errors?** Labs include detailed error messages and hints

---

**Total Lab Time:** ~15-20 hours for all 22 labs
**Difficulty:** Beginner → Advanced progression
