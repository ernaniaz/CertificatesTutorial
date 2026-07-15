# Lab 15: Troubleshooting Scenarios

## Learning Objectives

By completing this lab, you will:
- Diagnose an expired certificate problem
- Use troubleshooting tools effectively
- Fix expired certificates
- Follow a structured troubleshooting methodology

## Prerequisites

- **Labs 01-10** completed (understanding of certificates and services)
- **RHEL Version:** 7, 8, 9, or 10
- **System Access:** Root/sudo required
- **Troubleshooting mindset** required

## Time Estimate

**15-20 minutes**

## Lab Overview

Real-world troubleshooting scenario! This lab creates a specific certificate problem, then guides you through diagnosis and resolution. This is one of the most common issues you'll encounter in production.

---

## Lab Structure

This lab currently contains **one implemented scenario**:

```
15-troubleshooting-scenarios/
├── scenario-01-expired-cert/
├── run-all.sh
└── cleanup-all.sh
```

Each scenario includes:
- **create-problem.sh** - Sets up the issue
- **diagnose.sh** - Diagnostic steps to find the problem
- **fix.sh** - Solution to fix the issue
- **verify-fix.sh** - Validates the fix worked
- **README.md** - Scenario description and learning notes

---

## Instructions

### Run the Scenario

```bash
cd scenario-01-expired-cert
sudo ./create-problem.sh
./diagnose.sh
sudo ./fix.sh
sudo ./verify-fix.sh
```

Or use the helper script from the lab directory:

```bash
sudo ./run-all.sh
```

---

## Scenarios

### Scenario 01: Expired Certificate

**Problem:** Certificate has expired, causing connection failures

**Symptoms:**
- "certificate has expired"
- SSL handshake failures
- Browser security warnings

**Tools:** `openssl x509 -dates`, certificate inspection

**Learning:** Certificate lifecycle management, renewal importance

See `scenario-01-expired-cert/README.md` for full scenario details.

---

## Validation

To verify you've completed this lab successfully:

```bash
cd scenario-01-expired-cert
sudo ./verify-fix.sh
```

**Expected Results:**
- `verify-fix.sh` reports all checks passed
- Certificate file exists at `/etc/pki/tls/certs/expired.crt`
- Certificate is valid and not expired
- Certificate is valid for at least 30 days
- Certificate subject matches `expired.example.com`

---

## Troubleshooting Methodology

Each scenario follows this methodology:

1. **Observe** - Identify symptoms
2. **Gather** - Collect logs and diagnostic data
3. **Analyze** - Determine root cause
4. **Fix** - Implement solution
5. **Verify** - Confirm resolution
6. **Document** - Record for future reference

---

## Key Troubleshooting Commands

### Certificate Inspection
```bash
# View certificate
openssl x509 -in cert.pem -text -noout

# Check expiration
openssl x509 -in cert.pem -noout -dates

# Verify certificate chain
openssl verify -CAfile ca.pem cert.pem

# Check certificate matches key
openssl x509 -noout -modulus -in cert.pem | openssl md5
openssl rsa -noout -modulus -in key.pem | openssl md5
```

### Connection Testing
```bash
# Test TLS connection
openssl s_client -connect host:443 -servername host

# Show certificate chain
openssl s_client -connect host:443 -showcerts

# Test specific TLS version
openssl s_client -connect host:443 -tls1_2

# Check available ciphers
openssl s_client -connect host:443 -cipher 'HIGH'
```

### Service Debugging
```bash
# Check service logs
journalctl -xeu httpd
journalctl -xeu nginx

# Test configuration
apachectl configtest
nginx -t

# Check SELinux denials
ausearch -m avc -ts recent
sealert -a /var/log/audit/audit.log
```

---

## Cleanup

Each scenario has its own cleanup, or use the master cleanup:

```bash
sudo ./cleanup-all.sh
```

---

## Additional Resources

**Related Chapters:**
- Chapter 27: RHEL Certificate Troubleshooting Methodology
- Chapter 28: Common RHEL Certificate Errors
- Chapter 29: Service-Specific Troubleshooting

**Useful Tools:**
- `openssl` - Swiss army knife for certificates
- `curl` - HTTP/HTTPS testing
- `journalctl` - System logs
- `ausearch` - SELinux audit logs
- `tcpdump` - Network packet capture

---

## Next Steps

Proceed to **Lab 16: Emergency Procedures** to learn rapid recovery techniques.

---

**Difficulty Level:** Advanced
**Note:** These scenarios simulate real production issues
