# Chapter 41: Compliance & Auditing

> **Meet Requirements:** Learn how to meet security compliance requirements (STIG, CIS, PCI-DSS) and audit certificate configurations on RHEL.

---

## 41.1 Compliance Frameworks

### Common Certificate-Related Requirements

| Framework | Focus | Certificate Requirements |
|-----------|-------|-------------------------|
| **STIG** | DoD Security | FIPS, strong algorithms, auditing |
| **CIS Benchmark** | Industry best practices | TLS 1.2+, strong ciphers, permissions |
| **PCI-DSS** | Payment card industry | Strong crypto, no weak TLS/ciphers |
| **HIPAA** | Healthcare | Encryption, access control, auditing |
| **NIST 800-53** | Federal systems | FIPS, approved algorithms, monitoring |

---

## 41.2 STIG Compliance

### DISA STIG Requirements for Certificates

**Key STIG Requirements:**

```markdown
## Certificate STIG Controls

### V-238200: SSH must use strong ciphers
- Requirement: Only FIPS-approved algorithms
- Check: /etc/ssh/sshd_config
- Fix: Use crypto-policies (RHEL 8+)

### V-238201: Web server must use strong TLS
- Requirement: TLS 1.2+ only
- Check: Apache/NGINX configuration
- Fix: Disable TLS 1.0/1.1

### V-238202: Certificates must be from DoD-approved CA
- Requirement: Use approved CA
- Check: Certificate issuer
- Fix: Obtain from approved source

### V-238203: Private keys must be protected
- Requirement: Mode 600 or stricter
- Check: ls -l /etc/pki/tls/private/
- Fix: chmod 600

### V-238204: Certificate expiration must be monitored
- Requirement: Automated monitoring
- Check: Monitoring system in place
- Fix: Implement (see Chapter 26)
```

### STIG Compliance Scanning

```bash
#============================================#
# STIG COMPLIANCE SCAN FOR CERTIFICATES
#============================================#

# Install SCAP Security Guide
sudo dnf install scap-security-guide openscap-scanner -y

# Run STIG scan
sudo oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_stig \
  --results stig-results.xml \
  --report stig-report.html \
  /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml

# View report
firefox stig-report.html

# Check certificate-specific findings
grep -i "cert\|tls\|ssl" stig-report.html
```

---

## 41.3 CIS Benchmark Compliance

### CIS Controls for Certificates

**CIS RHEL Benchmark Recommendations:**

```markdown
## CIS Certificate Controls

### 5.2.14: Ensure only strong ciphers are used
- Check: Crypto-policy DEFAULT or FUTURE
- Command: `update-crypto-policies --show`

### 5.2.15: Ensure only strong algorithms used
- Check: No MD5, SHA-1, weak keys
- Scan: Check all certificates

### 5.2.16: Ensure TLS 1.2 minimum
- Check: Crypto-policy or service config
- Test: `openssl s_client -tls1_2`

### 5.3.1: Ensure permissions on private keys
- Requirement: 600 or stricter
- Check: `ls -l /etc/pki/tls/private/`

### 5.3.2: Ensure certificate expiration monitoring
- Requirement: Automated checks
- Implementation: certmonger or monitoring script
```

### CIS Compliance Scan

```bash
#============================================#
# CIS BENCHMARK SCAN
#============================================#

# Run CIS scan
sudo oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis \
  --results cis-results.xml \
  --report cis-report.html \
  /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml

# Generate remediation script
sudo oscap xccdf generate fix \
  --profile xccdf_org.ssgproject.content_profile_cis \
  --fix-type bash \
  stig-results.xml > remediation.sh

# Review and run remediation
chmod +x remediation.sh
sudo ./remediation.sh
```

---

## 41.4 PCI-DSS Compliance

### PCI-DSS Certificate Requirements

**PCI-DSS v4.0 Requirements:**

```markdown
## PCI-DSS Certificate Controls

### Requirement 4.2.1: Strong cryptography
- TLS 1.2 minimum (1.3 recommended)
- Strong cipher suites only
- Check: crypto-policy DEFAULT or FUTURE

### Requirement 4.2.1.1: Insecure protocols disabled
- NO SSL, TLS 1.0, TLS 1.1
- Check: `openssl s_client -tls1`
- Should fail on compliant system

### Requirement 4.2.1.2: Strong encryption algorithms
- AES-128 minimum
- NO 3DES, DES, RC4
- Check: `openssl ciphers -v`

### Requirement 8.3.2: Certificate-based authentication
- For administrative access
- Implementation: Client certificates, smart cards

### Requirement 10: Audit certificate access
- Log all private key access
- Implementation: auditd rules
```

### PCI-DSS Validation Script

```bash
#!/bin/bash
# pci-dss-cert-check.sh

echo "=== PCI-DSS Certificate Compliance Check ==="

# Check 1: TLS 1.2+ only
echo "1. TLS Version Check:"
if openssl s_client -connect localhost:443 -tls1 &>/dev/null; then
  echo "  ❌ FAIL: TLS 1.0 is enabled"
else
  echo "  ✅ PASS: TLS 1.0 disabled"
fi

# Check 2: Strong ciphers
echo ""
echo "2. Cipher Strength:"
WEAK=$(openssl ciphers -v | grep -Ei "3des|rc4|des-cbc" | wc -l)
if [ $WEAK -gt 0 ]; then
  echo "  ❌ FAIL: Weak ciphers available"
else
  echo "  ✅ PASS: No weak ciphers"
fi

# Check 3: Certificate expiration monitoring
echo ""
echo "3. Expiration Monitoring:"
if systemctl is-active --quiet certmonger || \
   systemctl list-timers | grep -q cert-monitor; then
  echo "  ✅ PASS: Monitoring enabled"
else
  echo "  ⚠️ WARNING: No automated monitoring detected"
fi

# Check 4: Private key permissions
echo ""
echo "4. Private Key Permissions:"
BAD_PERMS=$(find /etc/pki/tls/private/ -name "*.key" -not -perm 600 2>/dev/null | wc -l)
if [ $BAD_PERMS -gt 0 ]; then
  echo "  ❌ FAIL: $BAD_PERMS keys with wrong permissions"
else
  echo "  ✅ PASS: All keys properly protected"
fi

echo ""
echo "=== Check Complete ==="
```

---

## 41.5 Audit Procedures

### Certificate Audit Checklist

```markdown
## Quarterly Certificate Audit Checklist

### Inventory Review
- [ ] All certificates documented
- [ ] Certificate inventory current
- [ ] Ownership documented
- [ ] Purpose documented

### Expiration Review
- [ ] No expired certificates
- [ ] No certificates expiring < 30 days
- [ ] Renewal process documented
- [ ] Monitoring alerts working

### Security Review
- [ ] SHA-256+ signatures only (no SHA-1 or MD5)
- [ ] RSA 2048+ or ECC P-256+ keys
- [ ] TLS 1.2+ only (no 1.0/1.1)
- [ ] Private key permissions correct (600)
- [ ] SELinux contexts correct
- [ ] No unnecessary certificates

### Configuration Review
- [ ] Service configurations reviewed
- [ ] Crypto-policy appropriate
- [ ] No weak cipher overrides
- [ ] HSTS enabled (web servers)
- [ ] Certificate pinning documented

### Access Review
- [ ] Audit logs reviewed
- [ ] Unauthorized access investigated
- [ ] Key access limited to authorized personnel
- [ ] Backup access controlled

### Compliance Review
- [ ] STIG/CIS/PCI compliance verified
- [ ] Security scans passing
- [ ] Remediation complete
- [ ] Documentation updated
```

---

## 41.6 Automated Compliance Reporting

### Generate Compliance Report

```bash
#!/bin/bash
# generate-compliance-report.sh

REPORT_FILE="compliance-report-$(date +%Y%m%d).txt"

cat > "$REPORT_FILE" << EOF
=== Certificate Compliance Report ===
Generated: $(date)
System: $(hostname)
RHEL Version: $(cat /etc/redhat-release)

=== Configuration ===
OpenSSL Version: $(openssl version)
Crypto-Policy: $(update-crypto-policies --show 2>/dev/null || echo "N/A (RHEL 7)")
FIPS Mode: $(fips-mode-setup --check 2>/dev/null || echo "N/A")
SELinux: $(getenforce)

=== Certificate Inventory ===
EOF

# Count certificates
TOTAL=$(find /etc/pki/tls/certs/ -name "*.crt" -type f 2>/dev/null | wc -l)
echo "Total Certificates: $TOTAL" >> "$REPORT_FILE"

# Check expirations
echo "" >> "$REPORT_FILE"
echo "Expiration Status:" >> "$REPORT_FILE"
EXPIRING=0
for cert in /etc/pki/tls/certs/*.crt; do
  [ -f "$cert" ] || continue
  if ! openssl x509 -in "$cert" -noout -checkend $((86400*30)) 2>/dev/null; then
    echo "  ⚠️ Expires within 30 days: $cert" >> "$REPORT_FILE"
    ((EXPIRING++))
  fi
done
echo "Certificates expiring < 30 days: $EXPIRING" >> "$REPORT_FILE"

# Check algorithms
echo "" >> "$REPORT_FILE"
echo "Algorithm Compliance:" >> "$REPORT_FILE"
SHA1_COUNT=0
for cert in /etc/pki/tls/certs/*.crt; do
  [ -f "$cert" ] || continue
  if openssl x509 -in "$cert" -noout -text 2>/dev/null | grep -qi "sha1.*signature"; then
    echo "  ❌ SHA-1 signature: $cert" >> "$REPORT_FILE"
    ((SHA1_COUNT++))
  fi
done
echo "SHA-1 certificates: $SHA1_COUNT (should be 0)" >> "$REPORT_FILE"

# Check permissions
echo "" >> "$REPORT_FILE"
echo "Permission Compliance:" >> "$REPORT_FILE"
BAD_PERMS=$(find /etc/pki/tls/private/ -name "*.key" -not -perm 600 2>/dev/null | wc -l)
echo "Keys with incorrect permissions: $BAD_PERMS (should be 0)" >> "$REPORT_FILE"

# certmonger status
if command -v getcert &>/dev/null; then
  echo "" >> "$REPORT_FILE"
  echo "certmonger Status:" >> "$REPORT_FILE"
  sudo getcert list | grep "status:" | sort | uniq -c >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"
echo "=== Report Complete ===" >> "$REPORT_FILE"

cat "$REPORT_FILE"
echo ""
echo "Report saved to: $REPORT_FILE"
```

---

## 41.7 Key Takeaways

1. **Compliance is ongoing** - Not one-time
2. **Multiple frameworks exist** - STIG, CIS, PCI, HIPAA
3. **OpenSCAP automates scanning** on RHEL
4. **Document everything** - Required for audits
5. **Regular audits essential** - Quarterly minimum
6. **Remediation must be tracked** - Fix and verify
7. **Monitoring is compliance** - Continuous validation

---

## Quick Reference Card

```
┌──────────────────────────────────────────────────────────────┐
│ COMPLIANCE & AUDITING QUICK REFERENCE                        │
├──────────────────────────────────────────────────────────────┤
│ STIG:         oscap ... --profile stig                       │
│ CIS:          oscap ... --profile cis                        │
│ PCI-DSS:      oscap ... --profile pci-dss                    │
│                                                              │
│ Common Requirements:                                         │
│   - TLS 1.2+ only                                            │
│   - Strong algorithms (SHA-256+, RSA 2048+)                  │
│   - No weak ciphers (3DES, RC4)                              │
│   - Private keys protected (mode 600)                        │
│   - Expiration monitoring                                    │
│   - Audit logging enabled                                    │
│   - FIPS mode (for federal)                                  │
│                                                              │
│ Tools:        OpenSCAP, aide, auditd                         │
│ Scan:         oscap xccdf eval --profile <profile> ...       │
│ Remediate:    oscap xccdf generate fix ...                   │
└──────────────────────────────────────────────────────────────┘

✅ Compliance is continuous, not one-time
✅ Automate scanning with OpenSCAP
✅ Document all configurations and exceptions
```
---

**Chapter Navigation**

| [← Previous: Chapter 40 - RHEL Security Hardening for Certificates](40-security-hardening.md) | End of Part 7 |
|:---|---:|
