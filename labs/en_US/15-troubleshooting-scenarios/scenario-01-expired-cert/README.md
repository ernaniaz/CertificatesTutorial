# Scenario 01: Expired Certificate

## Problem Description

A certificate has expired, causing SSL/TLS connection failures. This is one of the most common certificate issues in production.

## Symptoms

- "certificate has expired" errors
- SSL handshake failures
- Browser security warnings
- Applications refusing to connect

## Learning Objectives

- Detect expired certificates
- Understand certificate validity periods
- Implement proper certificate renewal procedures
- Set up expiration monitoring

## Files

- `create-problem.sh` - Creates expired certificate
- `diagnose.sh` - Shows diagnostic steps
- `fix.sh` - Renews the certificate
- `verify-fix.sh` - Confirms fix

## Quick Start

```bash
sudo ./create-problem.sh
./diagnose.sh
sudo ./fix.sh
sudo ./verify-fix.sh
```

## Diagnostic Commands

```bash
# Check certificate expiration
openssl x509 -in /etc/pki/tls/certs/expired.crt -noout -dates

# Check if expired
openssl x509 -in /etc/pki/tls/certs/expired.crt -noout -checkend 0

# Inspect the certificate file (this lab does not bind it to port 443)
openssl x509 -in /etc/pki/tls/certs/expired.crt -noout -text
```

## Root Cause

Certificate's "Not After" date has passed. Common causes:
- Forgotten renewal
- Monitoring not configured
- Manual process broke down
- Certificate manager failed

## Solution

1. Generate new certificate with future expiration
2. Replace expired certificate
3. Restart affected services
4. Implement monitoring to prevent recurrence

## Prevention

- Use certmonger or certbot for auto-renewal
- Set up expiration monitoring
- Renew 30 days before expiration
- Test renewal process regularly
