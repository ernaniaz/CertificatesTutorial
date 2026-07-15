# Chapter 12: RHEL 10 Current Features

> **Cutting Edge:** RHEL 10 GA was released May 20, 2025; RHEL 10.2 is the current minor release. Learn about the latest features and prepare for the future of certificate management on Red Hat Enterprise Linux.

---

## 12.1 RHEL 10 Overview

**GA Release:** May 20, 2025
**Current Version:** RHEL 10.2
**Support Until:** May 31, 2035
**Status:** ✅ Production Release

**Key Characteristics:**
- **OpenSSL Version:** 3.5.5-2 (package: `openssl-3.5.5-2.el10_2.x86_64`)
- **Same base as:** RHEL 9.8 (OpenSSL 3.5.5)
- **Focus:** Continued hardening, post-quantum prep, cloud-native
- **Philosophy:** Incremental improvement over RHEL 9

> **Important:** RHEL 10 features may evolve across minor versions (10.1, 10.2, etc.). Always consult official Red Hat documentation for your specific RHEL 10.x release.

---

## 12.2 What's New vs. RHEL 9?

### Key Differences

| Feature | RHEL 9 | RHEL 10 |
|---------|--------|---------|
| OpenSSL | 3.5.5 | 3.5.5 (same base) |
| Crypto-Policies | Subpolicies | Enhanced subpolicies |
| TLS Versions | 1.2, 1.3 | 1.3 preferred, 1.2 supported |
| FIPS | 140-2 modules | 140-3 transition |
| Security Defaults | Strict | **Stricter** |
| Container Support | Good | **Enhanced** |
| Post-Quantum | Foundation | **Active preparation** |

**Package:** `openssl-3.5.5-2.el10_2.x86_64`

### Not a Revolutionary Change

Unlike RHEL 7→8 (crypto-policies) or RHEL 8→9 (OpenSSL 3.x), RHEL 10 is an **incremental improvement**.

**Think of it as:**
- RHEL 7 → 8: 🚀 Revolutionary (crypto-policies)
- RHEL 8 → 9: 🔄 Major (OpenSSL 3.x)
- RHEL 9 → 10: ⬆️  Incremental (refinements)

---

## 12.3 Certificate Management on RHEL 10

### Same Foundation as RHEL 9

```bash
#============================================#
# RHEL 10 CERTIFICATE BASICS
#============================================#

# Same OpenSSL version as RHEL 9.8
openssl version
# OpenSSL 3.5.5 27 Jan 2026

# Same crypto-policies system
update-crypto-policies --show

# Same certmonger
getcert list

# Same directory structure
ls -la /etc/pki/tls/
```

**Bottom Line:** If you know RHEL 9, you know RHEL 10 certificates!

---

## 12.4 Enhanced Security Features

### Stricter Defaults

```bash
#============================================#
# RHEL 10 SECURITY ENHANCEMENTS
#============================================#

# 1. DEFAULT policy is stricter
# - Stronger cipher preferences
# - Additional weak algorithms removed
# - Enhanced validation

# 2. LEGACY policy more restricted
# - Fewer legacy algorithms allowed
# - Stronger minimums even in LEGACY

# 3. Container certificate management improved
# - Better integration with Podman
# - Simplified cert mounting
# - Enhanced secret management
```

### Post-Quantum Cryptography Preparation

**Foundation for Future:**

```bash
# RHEL 10 prepares for post-quantum algorithms
# (Not yet default, but infrastructure ready)

# Future capability (as standards finalize):
# - ML-KEM (Module-Lattice Key Encapsulation)
# - ML-DSA (Module-Lattice Digital Signatures)
# - Hybrid classical/quantum cryptography

# Current status: Monitoring NIST standards
# Expected: RHEL 10.x minor releases will add PQC support
```

> **Note:** Post-quantum cryptography is still evolving. RHEL 10 provides foundation, actual implementation will come as standards are finalized.

---

## 12.5 RHEL 10-Specific Features

### Feature 1: Enhanced Crypto-Policy Modules

```bash
#============================================#
# RHEL 10 CRYPTO-POLICY IMPROVEMENTS
#============================================#

# More granular control
sudo update-crypto-policies --set DEFAULT:NO-SHA1

# Better validation
update-crypto-policies --check

# Improved error messages when policies conflict
```

### Feature 2: Improved Container Certificate Support

```bash
#============================================#
# CONTAINERS WITH CERTIFICATES (RHEL 10)
#============================================#

# Easier certificate mounting in Podman
podman run -d \
  -v /etc/pki/tls/certs/web.crt:/certs/web.crt:ro \
  -v /etc/pki/tls/private/web.key:/certs/web.key:ro \
  -p 443:443 \
  nginx

# Enhanced secret management
podman secret create web-cert /etc/pki/tls/certs/web.crt
podman secret create web-key /etc/pki/tls/private/web.key

# Use secrets in container
podman run -d --secret web-cert --secret web-key nginx
```

### Feature 3: Enhanced FIPS Mode

```bash
#============================================#
# FIPS ON RHEL 10
#============================================#

# FIPS mode with OpenSSL 3.x FIPS provider
sudo fips-mode-setup --enable
sudo reboot

# Check FIPS status
fips-mode-setup --check

# RHEL 10: Transition toward FIPS 140-3
# Current: Still FIPS 140-2 validated modules
# Future: FIPS 140-3 compliance as certification completes
```

---

## 12.6 Migration from RHEL 9

### Should You Upgrade?

**Upgrade Considerations:**

**Reasons to Upgrade:**
- ✅ Want 10+ years of support (until 2035)
- ✅ Need latest security enhancements
- ✅ Future-proofing (post-quantum prep)
- ✅ Enhanced container support
- ✅ Latest features and improvements

**Reasons to Wait:**
- ⏸️ RHEL 9 supported until 2032
- ⏸️ No urgent certificate-related features
- ⏸️ Let others test RHEL 10 in production first
- ⏸️ Want to wait for RHEL 10.3 or 10.4

**Certificate Impact: LOW**
- Same OpenSSL base (3.5.5)
- Same tools and commands
- Minimal breaking changes
- Mostly transparent

### Migration Process

```bash
#============================================#
# RHEL 9 → RHEL 10 CERTIFICATE MIGRATION
#============================================#

# 1. Pre-migration: Verify certificates
for cert in /etc/pki/tls/certs/*.crt; do
  openssl x509 -in "$cert" -noout -text | grep "Signature Algorithm"
done
# All should show SHA-256+ (no SHA-1 or MD5)

# 2. Backup
tar czf rhel9-certs-backup-$(date +%Y%m%d).tar.gz \
  /etc/pki/tls/ \
  /etc/pki/ca-trust/source/anchors/

# 3. Perform RHEL upgrade
sudo leapp upgrade

# 4. Verify crypto-policy
update-crypto-policies --show

# 5. Restart services
sudo systemctl restart httpd nginx postfix

# 6. Test certificates
curl -v https://localhost/
openssl s_client -connect localhost:443

# 7. Check certmonger
sudo getcert list
```

---

## 12.7 Best Practices for RHEL 10

### Recommended Setup

```bash
#============================================#
# RHEL 10 RECOMMENDED CONFIGURATION
#============================================#

# 1. Use DEFAULT crypto-policy (already optimal)
sudo update-crypto-policies --set DEFAULT

# 2. Prefer TLS 1.3
# (Automatically preferred by DEFAULT policy)

# 3. Use EC keys for new certificates
openssl genpkey -algorithm EC -out ec.key \
  -pkeyopt ec_paramgen_curve:P-256

# 4. Automate with the right tool
# Public Let's Encrypt certificate: use certbot
sudo certbot certonly --apache -d web.example.com

# Internal FreeIPA / IdM certificate: use certmonger
# sudo ipa-getcert request \
#   -f /etc/pki/tls/certs/web.crt \
#   -k /etc/pki/tls/private/web.key \
#   -K HTTP/web.example.com@REALM \
#   -D web.example.com \
#   -C "systemctl reload httpd"

# 5. Monitor certificates
# Use built-in monitoring or external tools

# 6. Plan for future PQC
# Keep up with RHEL 10.x minor releases
```

---

## 12.8 Looking Ahead: Post-Quantum Readiness

### What is Post-Quantum Cryptography?

**Problem:** Future quantum computers could break current encryption (RSA, ECC)
**Solution:** New quantum-resistant algorithms

**NIST Standards (Finalized 2024):**
- **ML-KEM-768** (Key Encapsulation)
- **ML-DSA-65** (Digital Signatures)
- **SLH-DSA** (Stateless signatures)

**RHEL 10 Role:**
- Provides foundation for PQC
- OpenSSL 3.x architecture supports new algorithms
- Future RHEL 10.x releases will add PQC support

### Hybrid Cryptography (Future)

```bash
# Future capability in RHEL 10.x:
# Use both classical AND quantum-resistant crypto

# Example (conceptual - not yet in RHEL 10.2):
openssl genpkey -algorithm hybrid-rsa-mlkem768 -out hybrid.key

# Provides:
# - Security against classical attacks (RSA)
# - Security against quantum attacks (ML-KEM)
```

> **Note:** PQC support is coming in future RHEL 10.x minor versions as standards are finalized and tested.

---

## 12.9 What Stays the Same

### No Major Breaking Changes

```bash
#============================================#
# FAMILIAR COMMANDS STILL WORK
#============================================#

# Generate key (same as RHEL 9)
openssl genpkey -algorithm RSA -out server.key \
  -pkeyopt rsa_keygen_bits:2048

# Generate CSR (same as RHEL 9)
openssl req -new -key server.key -out server.csr \
  -subj "/CN=server.example.com" \
  -addext "subjectAltName=DNS:server.example.com"

# View certificate (same)
openssl x509 -in cert.crt -noout -text

# Test connection (same)
openssl s_client -connect server:443

# Trust management (same)
sudo cp ca.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust

# certmonger (same)
sudo getcert list

# crypto-policies (same)
update-crypto-policies --show
```

**If you know RHEL 9, you're ready for RHEL 10!**

---

## 12.10 When to Adopt RHEL 10

### Adoption Timeline Recommendations

**Early Adopters (2025-2026):**
- Testing environments
- Non-critical workloads
- Want latest features
- Security research

**Mainstream (2026-2027):**
- New deployments
- Refreshed infrastructure
- After RHEL 10.3/10.4 release
- When major apps certified

**Conservative (2027-2028):**
- Critical production systems
- Stable workloads
- After extensive community testing
- When migration from RHEL 9 necessary

**Current Recommendation (Late 2025):**
- ✅ **New projects:** Consider RHEL 10
- ⏸️ **Existing RHEL 9:** No urgency to upgrade
- ✅ **RHEL 8 or older:** Evaluate RHEL 9 or 10
- ❌ **RHEL 7:** Upgrade required (support ended)

---

## 12.11 Monitoring RHEL 10 Evolution

### Stay Updated

```bash
# Check RHEL 10 minor version
cat /etc/redhat-release
# Red Hat Enterprise Linux release 10.2 (Coughlan)

# Check for updates
sudo dnf check-update

# Monitor Red Hat announcements
# - https://access.redhat.com/articles/3078
# - RHEL 10 release notes
# - Red Hat security advisories

# Subscribe to Red Hat newsletters
# Follow release notes for 10.3, 10.4, etc.
```

### Features to Watch For

**Expected in RHEL 10.x minor releases:**
- Post-quantum cryptography support
- Additional crypto-policy enhancements
- Further container integration
- Enhanced automation tools
- Additional FIPS 140-3 modules

---

## 12.12 Practical RHEL 10 Certificate Setup

### Complete Example: Modern HTTPS Setup

```bash
#!/bin/bash
# Complete modern HTTPS setup on RHEL 10

echo "=== RHEL 10 Modern HTTPS Setup ==="

# 1. Install packages
sudo dnf install -y httpd mod_ssl epel-release certbot python3-certbot-apache

# 2. Enable services
sudo systemctl enable --now httpd

# 3. Request Let's Encrypt certificate with certbot
sudo certbot --apache -d $(hostname -f)

# 4. Verify the certificate
sudo certbot certificates

# 5. Update Apache configuration
# certbot usually updates Apache automatically; adjust manually only if needed
sudo sed -i "s|SSLCertificateFile.*|SSLCertificateFile /etc/letsencrypt/live/$(hostname -f)/fullchain.pem|" \
  /etc/httpd/conf.d/ssl.conf
sudo sed -i "s|SSLCertificateKeyFile.*|SSLCertificateKeyFile /etc/letsencrypt/live/$(hostname -f)/privkey.pem|" \
  /etc/httpd/conf.d/ssl.conf

# 6. Crypto-policy already optimal (DEFAULT)
update-crypto-policies --show

# 7. Open firewall
sudo firewall-cmd --add-service=https --permanent
sudo firewall-cmd --reload

# 8. Reload Apache
sudo systemctl reload httpd

# 9. Test
curl -v https://$(hostname -f)/

echo "✅ RHEL 10 modern HTTPS setup complete!"
echo "   - TLS 1.3 supported"
echo "   - Let's Encrypt certificate"
echo "   - Automatic renewal enabled"
echo "   - Optimal security (DEFAULT policy)"
```

---

## 12.13 Future-Proofing Strategies

### Preparing for RHEL 10.x Evolution

```bash
#============================================#
# FUTURE-PROOF CERTIFICATE MANAGEMENT
#============================================#

# 1. Use modern algorithms (ready for PQC transition)
# Prefer EC over RSA
openssl genpkey -algorithm EC -out ec.key -pkeyopt ec_paramgen_curve:P-256

# 2. Keep certificates short-lived (90 days or less)
# Easier to rotate when algorithms change

# 3. Automate everything
# Use certbot for public ACME and certmonger for IPA/internal workflows

# 4. Monitor Red Hat announcements
# Subscribe to security and release notifications

# 5. Test PQC when available
# Be early tester of new features in RHEL 10.x

# 6. Document your setup
# Makes future transitions easier
```

---

## 12.14 Known Issues and Workarounds

### Issue 1: Same as RHEL 9 (OpenSSL 3.x)

**Most RHEL 9 issues apply to RHEL 10:**
- Legacy algorithms need `-provider legacy`
- SHA-1 blocked
- Custom apps may need OpenSSL 3.x updates

**Reference:** See Chapter 11 for OpenSSL 3.x issues

### Issue 2: Even Stricter Validation

**RHEL 10 may catch issues RHEL 9 allowed:**

```bash
# Example: Marginal certificate that worked on RHEL 9
# might fail on RHEL 10

# Solution: Always use best practices
# - SHA-256+ signatures
# - 2048+ bit keys (4096 recommended)
# - Proper SANs
# - Valid trust chains
```

---

## 12.15 When to Choose RHEL 10

### Decision Matrix

| Scenario | RHEL 9 | RHEL 10 | Recommendation |
|----------|--------|---------|----------------|
| **New deployment 2025+** | ✅ Good | ✅ Better | RHEL 10 |
| **Existing RHEL 9** | ✅ Keep | ⏸️ Wait | Stay on 9 for now |
| **Migrating from RHEL 8** | ✅ Yes | ✅ Consider | Either (9 is safer) |
| **Migrating from RHEL 7** | ✅ Yes | ⚠️ Big jump | Go to 9 first |
| **10+ year horizon** | ⏸️ 2032 support | ✅ 2035 support | RHEL 10 |
| **Cutting edge security** | ✅ Good | ✅ Better | RHEL 10 |
| **Production critical** | ✅ Proven | ⏸️ Newer | RHEL 9 (safer) |

---

## 12.16 Key Takeaways

1. **RHEL 10 = RHEL 9 + incremental improvements**
2. **Same OpenSSL 3.5.5 base** - No major API changes
3. **Stricter security defaults** - Good for security
4. **Post-quantum preparation** - Future-ready infrastructure
5. **No urgent certificate changes** - Transition is smooth
6. **RHEL 9 knowledge transfers** - Same tools and commands
7. **Watch for minor releases** - 10.3, 10.4 may add features

---

## 12.17 Troubleshooting RHEL 10

### Diagnostic Approach

```bash
#============================================#
# RHEL 10 CERTIFICATE TROUBLESHOOTING
#============================================#

# Use troubleshooting methodology (Chapter 27) and RHEL 9 patterns (Chapter 11)

# 1. Verify RHEL 10 version
cat /etc/redhat-release
# Red Hat Enterprise Linux release 10.2 (Coughlan)

# 2. Check OpenSSL
openssl version
# OpenSSL 3.5.5

# 3. Check crypto-policy
update-crypto-policies --show

# 4. Test certificate
openssl x509 -in cert.crt -noout -text

# 5. Test connection
openssl s_client -connect server:443 -tls1_3

# 6. Check providers (if issues)
openssl list -providers

# 7. Check logs
sudo journalctl -xe | grep -i cert
```

**No new troubleshooting techniques needed - same as RHEL 9!**

---

## 12.18 Recommended Migration Path

### From RHEL 9 to RHEL 10

```bash
#============================================#
# CERTIFICATE-SAFE RHEL 9→10 MIGRATION
#============================================#

# Phase 1: Preparation
# - Backup all certificates
# - Document current configuration
# - Test in lab environment

# Phase 2: Migration
# - Use standard RHEL upgrade process
# - Certificates should transfer seamlessly

# Phase 3: Verification
# - Verify crypto-policy unchanged
# - Test all certificate operations
# - Confirm certmonger tracking maintained
# - Test services using certificates

# Phase 4: Optimization
# - Consider EC keys for new certificates
# - Review and update crypto-policy if needed
# - Monitor for RHEL 10.x enhancements
```

---

## 12.19 Documentation and Resources

### Official Resources

```markdown
## RHEL 10 Certificate Resources

### Official Documentation
- RHEL 10 Release Notes (check for your specific 10.x version)
- https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/10

### Security Updates
- https://access.redhat.com/security/
- Subscribe to RHEL security announcements

### Crypto-Policies
- https://access.redhat.com/articles/3642912
- Check for RHEL 10-specific updates

### Support
- Red Hat Customer Portal
- Red Hat Support Cases
- RHEL community forums
```

---

## 12.20 Quick Reference

```
┌──────────────────────────────────────────────────────────────┐
│ RHEL 10 CERTIFICATE QUICK REFERENCE                          │
├──────────────────────────────────────────────────────────────┤
│ OpenSSL:      3.5.5-2 (same as RHEL 9.8)                     │
│ TLS:          1.3 preferred, 1.2 supported                   │
│ GA Release:   May 20, 2025 (RHEL 10.0)                       │
│ Status:       Production ready                               │
│                                                              │
│ Key Change:   Incremental security improvements              │
│ Migration:    Low impact from RHEL 9                         │
│ Commands:     Same as RHEL 9                                 │
│ Tools:        Same as RHEL 9                                 │
│                                                              │
│ Future:       Post-quantum crypto preparation                │
│               Watch for features in 10.3, 10.4+              │
│                                                              │
│ Verify:       cat /etc/redhat-release                        │
│               openssl version                                │
│               update-crypto-policies --show                  │
└──────────────────────────────────────────────────────────────┘

✅ If you know RHEL 9 certificates, you know RHEL 10!
⚠️ Always check official docs for your specific 10.x minor version
```
---

**Chapter Navigation**

| [← Previous: Chapter 11 - RHEL 9 Modern Security](11-rhel9-modern-security.md) | [Next: Chapter 13 - Cross-Version Compatibility →](13-cross-version-compatibility.md) |
|:---|---:|
