# Lab 22: HashiCorp Vault PKI

## Learning Objectives

By completing this lab, you will:
- Understand Vault's dynamic PKI secrets engine
- Install and configure HashiCorp Vault in dev mode
- Enable and configure the PKI secrets engine
- Create a root and intermediate CA hierarchy
- Configure PKI roles for certificate issuance
- Issue certificates dynamically via API/CLI
- Understand short-lived certificate benefits
- Revoke certificates and manage CRLs

## Prerequisites

- **Lab Dependencies:** Labs 01-05 completed (certificate basics)
- **RHEL Version:** RHEL 8, 9, or 10
- **System Access:** Root or sudo privileges required
- **Additional Requirements:**
  - curl installed
  - jq installed (for JSON parsing)
  - Internet connectivity for Vault download
  - 1GB RAM available

## Time Estimate

**35-45 minutes** (includes Vault installation and PKI configuration)

## Lab Overview

HashiCorp Vault provides a dynamic PKI system where certificates are issued on-demand with short time-to-live (TTL) values. This approach reduces the need for certificate revocation and simplifies certificate lifecycle management. Vault centralizes policy enforcement and provides API-driven certificate management.

---

## Why Use Vault for PKI?

### Benefits

**Dynamic Certificate Issuance:**
- Certificates created on-demand
- Short TTL (minutes to hours) reduces revocation needs
- Automatic renewal via Vault agents

**Centralized Policy:**
- Role-based access control
- Consistent certificate policies
- Audit logging of all operations

**API-Driven:**
- REST API for automation
- CLI for manual operations
- Easy integration with CI/CD

**Security:**
- Private keys never leave Vault
- Automatic rotation
- Secure secret storage

---

## Vault PKI Architecture

```
┌─────────────────────────────────────┐
│         Root CA (Internal)           │
│     Long-lived (10 years)            │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│      Intermediate CA                 │
│     Medium-lived (5 years)           │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│    Leaf Certificates (Dynamic)       │
│    Short-lived (hours to days)       │
│    Issued via Roles                  │
└─────────────────────────────────────┘
```

---

## Instructions

### Step 1: Install Vault

Download and install HashiCorp Vault:

```bash
./install-vault.sh
```

**What this does:**
- Downloads Vault binary from HashiCorp
- Installs to /usr/local/bin/
- Verifies installation
- Checks version

**Expected Output:**
```
========================================
Lab 22: Install Vault
========================================

✓ Vault binary downloaded
✓ Vault installed to /usr/local/bin/vault
✓ Vault version: 1.15.x

Vault is ready to use!
```

**Verification:**
```bash
vault version
vault --help
```

---

### Step 2: Start Vault in Dev Mode

Start Vault server in development mode:

```bash
./start-vault-dev.sh
```

**Important Notes:**
- ⚠️ **Dev mode is NOT for production** - all data stored in memory
- ⚠️ Vault runs unsealed and with a root token
- ⚠️ Data is lost when Vault stops
- 💡 Perfect for learning and testing

**Expected Output:**
```
========================================
Lab 22: Start Vault (Dev Mode)
========================================

✓ Vault started with PID: <pid>
✓ Vault is ready
✓ Configuration saved to vault-env.sh
✓ Vault is running and unsealed

IMPORTANT: Save these credentials!
  Root Token: root
  Vault Address: http://127.0.0.1:8200
  Process PID: <pid>

Environment configured:
  source vault-env.sh
```

**Verification:**
```bash
source vault-env.sh
vault status
```

---

### Step 3: Enable PKI Secrets Engine

Enable the PKI secrets engine:

```bash
./enable-pki.sh
```

**What this does:**
- Enables PKI secrets engine at path `pki/`
- Configures maximum lease TTL
- Sets up PKI backend

**Expected Output:**
```
========================================
Lab 22: Enable PKI Secrets Engine
========================================

✓ PKI secrets engine enabled at: pki/
✓ Max lease TTL set to: 87600h (10 years)
✓ PKI backend ready

PKI engine is ready for CA configuration
```

**Verification:**
```bash
vault secrets list
```

---

### Step 4: Configure Root CA

Generate internal root CA:

```bash
./configure-root-ca.sh
```

**What this does:**
- Generates root CA certificate internally
- Sets common name and TTL
- Configures issuing certificate URLs
- Configures CRL distribution points

**Expected Output:**
```
========================================
Lab 22: Configure Root CA
========================================

✓ Root CA generated
✓ CA URLs configured
✓ CRL distribution configured

Root CA Details:
  Common Name: Lab Root CA
  TTL: 87600h (10 years)
  Issuing CA: http://127.0.0.1:8200/v1/pki/ca
  CRL: http://127.0.0.1:8200/v1/pki/crl
```

**Verification:**
```bash
vault read pki/cert/ca
```

---

### Step 5: Configure Intermediate CA

Set up intermediate CA for issuing leaf certificates:

```bash
./configure-intermediate-ca.sh
```

**What this does:**
- Enables PKI secrets engine at `pki_int/`
- Generates intermediate CA CSR
- Signs intermediate CSR with root CA
- Sets intermediate certificate
- Configures intermediate CA URLs

**Expected Output:**
```
========================================
Lab 22: Configure Intermediate CA
========================================

✓ Intermediate PKI engine enabled: pki_int/
✓ Intermediate CSR generated
✓ Intermediate CSR signed by root CA
✓ Intermediate certificate set
✓ Intermediate URLs configured

Intermediate CA ready for certificate issuance
```

**Verification:**
```bash
vault read pki_int/cert/ca
```

---

### Step 6: Create PKI Role

Create a role for certificate issuance:

```bash
./create-role.sh
```

**What this does:**
- Creates PKI role named "web-server"
- Defines allowed domains
- Sets default and maximum TTL
- Configures certificate policies

**Expected Output:**
```
========================================
Lab 22: Create PKI Role
========================================

✓ PKI role 'web-server' created

Role Configuration:
  Allowed Domains: example.com, lab.local
  Allow Subdomains: true
  Max TTL: 72h (3 days)
  Default TTL: 24h (1 day)
  Key Type: RSA-2048

Use this role to issue certificates
```

**Verification:**
```bash
vault read pki_int/roles/web-server
```

---

### Step 7: Issue Certificates

Issue certificates using the configured role:

```bash
./issue-certificate.sh
```

**What this does:**
- Issues multiple test certificates
- Demonstrates different common names
- Shows certificate details
- Saves certificates to files

**Expected Output:**
```
========================================
Lab 22: Issue Certificates
========================================

ℹ Issuing certificate: server01.lab.local (TTL: 24h)...
✓ Certificate issued: server01.lab.local
ℹ   Certificate: certs/server01.lab.local.crt
ℹ   Private key: certs/server01.lab.local.key
ℹ   Serial: xx:xx:xx:xx

ℹ Issuing certificate: server02.lab.local (TTL: 24h)...
✓ Certificate issued: server02.lab.local
ℹ   Certificate: certs/server02.lab.local.crt
ℹ   Private key: certs/server02.lab.local.key
ℹ   Serial: xx:xx:xx:xx

✓ All test certificates issued
```

**Verification:**
```bash
openssl x509 -in certs/server01.lab.local.crt -noout -text
openssl verify -CAfile certs/server01.lab.local-ca.crt certs/server01.lab.local.crt
```

---

### Step 8: Revoke Certificate (Optional)

Demonstrate certificate revocation:

```bash
./revoke-certificate.sh
```

**What this does:**
- Revokes a test certificate
- Updates CRL
- Verifies revocation

**Expected Output:**
```
========================================
Lab 22: Revoke Certificate
========================================

✓ Certificate revoked
✓ Serial number: xx:xx:xx:xx
✓ CRL updated

Certificate successfully revoked and added to CRL
```

**Verification:**
```bash
vault write pki_int/revoke serial_number="xx:xx:xx:xx"
vault read pki_int/cert/crl
```

---

## Validation

To verify your lab is complete, run the validation script:

```bash
./verify.sh
```

**Expected Result:**
```
========================================
Lab 22: Validation
========================================

✓ Vault is running
✓ Vault is accessible and unsealed
✓ PKI secrets engine enabled
✓ Root CA exists
✓ Intermediate CA exists
✓ PKI role exists
✓ Certificates were issued

========================================
✓ All validations passed!
Lab 22 completed successfully.
========================================
```

---

## Expected Outcome

After completing this lab, you should have:
- ✅ Vault installed and running in dev mode
- ✅ PKI secrets engine configured
- ✅ Root and intermediate CA hierarchy
- ✅ PKI role configured for certificate issuance
- ✅ Dynamically issued certificates
- ✅ Understanding of certificate revocation

You can verify this by:
- Running `vault status` (should show unsealed)
- Running `vault secrets list` (should show pki/ and pki_int/)
- Listing issued certificates in the `certs/` directory

---

## Troubleshooting

### Issue 1: Vault not starting

**Symptom:**
```
Error: Failed to start Vault server
```

**Cause:**
- Port 8200 already in use
- Vault already running

**Solution:**
```bash
# Check if Vault is running
ps aux | grep vault

# Kill existing Vault processes
pkill vault

# Check port availability
ss -tulpn | grep 8200

# Restart Vault
./start-vault-dev.sh
```

---

### Issue 2: Connection refused

**Symptom:**
```
Error: Get "http://127.0.0.1:8200/v1/sys/health": dial tcp 127.0.0.1:8200: connect: connection refused
```

**Cause:**
- Vault not running
- VAULT_ADDR not set

**Solution:**
```bash
# Check Vault status
vault status

# Ensure environment variables are set
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

# Or source the environment file
source vault-env.sh
```

---

### Issue 3: Permission denied

**Symptom:**
```
Error: permission denied
```

**Cause:**
- Invalid or expired token
- Wrong token used

**Solution:**
```bash
# Use the root token from start-vault-dev.sh
export VAULT_TOKEN='root'

# Or login again
vault login root
```

---

### Issue 4: PKI engine not found

**Symptom:**
```
Error: namespace not found
```

**Cause:**
- PKI engine not enabled
- Wrong path

**Solution:**
```bash
# List enabled secrets engines
vault secrets list

# Re-enable PKI if needed
./enable-pki.sh
```

---

## Version-Specific Notes

### RHEL 8
- All features supported
- Use dnf to install dependencies
- SELinux may affect local Vault files

### RHEL 9
- All features supported
- OpenSSL 3.x compatible
- Full compatibility with Vault

### RHEL 10
- Latest Vault version supported
- All modern features available
- Optimal performance

---

## Cleanup

To reset your system and stop Vault:

```bash
./cleanup.sh
```

**Warning:** This will:
- Stop Vault server
- Delete all PKI data (dev mode only)
- Remove generated certificates
- Clean up temporary files

**Manual Cleanup:**
```bash
# Stop Vault
pkill vault

# Remove certificates
rm -rf certs/

# Remove environment file
rm -f vault-env.sh
```

---

## Advanced Topics

### Production Deployment

**Key Differences:**
- Use storage backend (Consul, etcd, etc.)
- Enable TLS for Vault API
- Use initialization and unseal process
- Implement HA clustering
- Use auth methods (not root token)
- Enable audit logging

**Example Production Start:**
```bash
vault server -config=/etc/vault/config.hcl
```

### Short-Lived Certificates

**Benefits:**
- Reduces need for revocation
- Limits exposure window
- Simplifies certificate management

**Example 1-hour TTL:**
```bash
vault write pki_int/issue/web-server \
    common_name="temp.example.com" \
    ttl="1h"
```

### Vault Agent Auto-Renewal

Vault Agent can automatically renew certificates:

```hcl
# vault-agent.hcl
auto_auth {
  method "approle" {
    config = {
      role_id_file_path = "roleid"
      secret_id_file_path = "secretid"
    }
  }
}

template {
  source      = "cert.tpl"
  destination = "/etc/tls/server.pem"
  command     = "systemctl reload nginx"
}
```

### API Usage

**Issue Certificate via API:**
```bash
curl -X POST \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -d '{"common_name":"api.example.com","ttl":"24h"}' \
  http://127.0.0.1:8200/v1/pki_int/issue/web-server
```

**Revoke via API:**
```bash
curl -X POST \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -d '{"serial_number":"xx:xx:xx:xx"}' \
  http://127.0.0.1:8200/v1/pki_int/revoke
```

---

## Additional Resources

**Related Chapters:**
- Appendix B: HashiCorp Vault (detailed theory)
- Lab 21: Kubernetes cert-manager (similar automation)
- Chapter 22: certmonger Mastery (RHEL-native automation)

**Documentation:**
- Vault PKI Secrets Engine: https://developer.hashicorp.com/vault/docs/secrets/pki
- Vault API Documentation: https://developer.hashicorp.com/vault/api-docs
- Production Hardening: https://developer.hashicorp.com/vault/tutorials/operations/production-hardening

**Further Reading:**
- Dynamic Secrets whitepaper
- Zero Trust Architecture with Vault
- Certificate lifecycle automation

---

## Next Steps

After completing this lab, you can:
1. **Review:** All 22 labs completed! 🎉
2. **Practice:** Deploy Vault in a more production-like environment
3. **Integrate:** Connect Vault with your applications
4. **Explore:** Vault auth methods and policies
5. **Advanced:** Set up Vault HA cluster

---

## Real-World Use Cases

**Microservices:**
- Each service gets short-lived certificates
- Automatic renewal via Vault agent
- Consistent certificate policies

**CI/CD Pipelines:**
- Dynamic certificates for build agents
- Temporary credentials for deployments
- Automated certificate provisioning

**Database TLS:**
- Dynamic database certificates
- Automatic rotation
- Centralized management

**Service Mesh:**
- Integration with Consul Connect
- Automatic mTLS certificates
- Service-to-service authentication

---

## Comparison: Vault vs cert-manager vs certmonger

| Feature | Vault PKI | cert-manager | certmonger |
|---------|-----------|--------------|------------|
| Platform | Any | Kubernetes | RHEL |
| Certificates | Dynamic | Declarative | Tracked |
| Default TTL | Hours-Days | Days-Months | Months |
| CA Integration | Built-in | External | External |
| API | REST | Kubernetes | D-Bus |
| Best For | Microservices | K8s workloads | RHEL services |

---

**RHEL Versions Tested**: 8, 9, 10  
**Difficulty Level**: Advanced  
**Congratulations on completing all 22 labs!** 🎉
