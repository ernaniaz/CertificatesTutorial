# RHEL Version Cheat Sheet for Certificates

Quick reference for certificate differences across RHEL versions.

---

## Version Overview

| RHEL | Released | OpenSSL | TLS Support | Crypto-Policies | Key Feature |
|------|----------|---------|-------------|-----------------|-------------|
| **7** | 2014 | 1.0.2k-26 | 1.0/1.1/1.2 | ❌ No | Manual config |
| **8** | 2019 | 1.1.1k-14 | 1.2/1.3 | ✅ **NEW!** | System-wide policies |
| **9** | May 2022 | 3.5.5-2 | 1.2/1.3 | ✅ Enhanced | OpenSSL 3.x, strict |
| **10** | May 2025 | 3.5.5-2 | 1.3 pref | ✅ Enhanced | PQC prep, modern |

---

## Quick Detection

```bash
# Check RHEL version
cat /etc/redhat-release

# Check OpenSSL (indirect version check)
openssl version
# 1.0.2k = RHEL 7
# 1.1.1k = RHEL 8
# 3.5.5  = RHEL 9 or 10

# Check crypto-policies (RHEL 8+ only)
update-crypto-policies --show 2>/dev/null || echo "RHEL 7 (no crypto-policies)"
```

---

## TLS Configuration by Version

### RHEL 7
```apache
# Manual configuration required everywhere
SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
SSLCipherSuite HIGH:!aNULL:!MD5:!3DES
```

### RHEL 8/9/10
```apache
# crypto-policies handle it automatically!
# No SSLProtocol or SSLCipherSuite needed
# Just include certificate paths
```

---

## Common Commands by Version

| Task | RHEL 7 | RHEL 8/9/10 |
|------|--------|-------------|
| **Generate Key** | `openssl genrsa -out key 2048` | `openssl genpkey -algorithm RSA -out key` |
| **Check Policy** | N/A | `update-crypto-policies --show` |
| **TLS Config** | Manual per service | Automatic via crypto-policies |
| **certmonger** | Basic | Enhanced (IPA/tracking workflows) |

---

## Troubleshooting by Version

### RHEL 7
- Check for TLS 1.0/1.1 issues
- Manual cipher configurations
- No crypto-policies

### RHEL 8
- Check crypto-policy first!
- TLS 1.0/1.1 disabled in DEFAULT
- LEGACY policy for compatibility

### RHEL 9
- OpenSSL 3.x provider issues
- SHA-1 BLOCKED
- Use `-provider legacy` for old algorithms

### RHEL 10
- Same as RHEL 9
- Even stricter defaults
- Check minor version docs

---

## Migration Impact

| Migration | Certificate Impact | Key Changes |
|-----------|-------------------|-------------|
| **7→8** | Moderate-High | crypto-policies, TLS 1.0/1.1 blocked |
| **8→9** | High | OpenSSL 3.x, SHA-1 blocked, stricter |
| **9→10** | Low | Same OpenSSL, incremental hardening |

---

## Quick Fixes by Version

### "no shared cipher" Error
- **RHEL 7:** Update cipher config manually
- **RHEL 8/9/10:** `sudo update-crypto-policies --set LEGACY` (temp!)

### SHA-1 Certificate
- **RHEL 7/8:** Works (deprecated)
- **RHEL 9/10:** BLOCKED - must reissue

### TLS 1.0 Client
- **RHEL 7:** Works by default
- **RHEL 8/9/10:** Blocked in DEFAULT, use LEGACY (temp!)

---

**Full Details:** See Chapters 9-12
