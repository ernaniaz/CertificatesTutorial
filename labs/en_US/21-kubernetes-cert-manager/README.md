# Lab 21: Kubernetes cert-manager

## Learning Objectives

By completing this lab, you will:
- Understand cert-manager architecture and components
- Install and configure minikube for local Kubernetes testing
- Deploy cert-manager to a Kubernetes cluster
- Create multiple issuer types (self-signed, CA, ACME)
- Request and manage certificates using cert-manager
- Configure TLS for Kubernetes Ingress
- Understand automatic certificate renewal

## Prerequisites

- **Lab Dependencies:** Labs 01-05 completed (certificate basics)
- **RHEL Version:** RHEL 8, 9, or 10
- **System Access:** Root or sudo privileges required
- **Additional Requirements:**
  - 2 CPU cores minimum (for minikube)
  - 2GB RAM available
  - 20GB disk space
  - Internet connectivity for downloads
  - Docker or podman installed (for minikube driver)

## Time Estimate

**40-50 minutes** (includes minikube setup and cert-manager deployment)

## Lab Overview

cert-manager is a Cloud Native Computing Foundation (CNCF) project that automates certificate management in Kubernetes clusters. It acts as a certificate controller, requesting certificates from various sources and ensuring they are valid and up-to-date.

---

## cert-manager Architecture

### Core Components

**Issuer / ClusterIssuer:**
- Defines the certificate authority (CA) or ACME server
- Issuer: namespace-scoped
- ClusterIssuer: cluster-wide

**Certificate:**
- Kubernetes Custom Resource defining desired certificate
- Specifies DNS names, duration, renewal settings
- Results in a Kubernetes Secret containing the certificate

**Controller:**
- Watches Certificate resources
- Requests certificates from configured Issuers
- Stores certificates in Kubernetes Secrets
- Handles automatic renewal

---

## Instructions

### Step 1: Install Minikube

Install and start minikube for local Kubernetes testing:

```bash
./install-minikube.sh
```

**What this does:**
- Downloads and installs minikube binary
- Installs kubectl if not present
- Starts a local Kubernetes cluster
- Configures kubectl context

**Expected Output:**
```
========================================
Lab 21: Install Minikube
========================================

✓ Minikube binary downloaded
✓ Minikube started with docker driver
✓ kubectl context configured
✓ Cluster is running

Minikube status:
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

**Verification:**
```bash
kubectl cluster-info
kubectl get nodes
```

---

### Step 2: Install cert-manager

Deploy cert-manager to the Kubernetes cluster:

```bash
./install-cert-manager.sh
```

**What this does:**
- Applies cert-manager CRDs (Custom Resource Definitions)
- Deploys cert-manager components
- Waits for pods to be ready
- Verifies installation

**Expected Output:**
```
========================================
Lab 21: Install cert-manager
========================================

✓ cert-manager namespace created
✓ CRDs applied
✓ cert-manager deployed
✓ Waiting for pods to be ready...
✓ cert-manager-webhook is ready
✓ cert-manager-cainjector is ready
✓ cert-manager controller is ready

cert-manager installation complete!
```

**Verification:**
```bash
kubectl get pods -n cert-manager
```

---

### Step 3: Create Self-Signed Issuer

Create a self-signed certificate issuer:

```bash
./create-selfsigned-issuer.sh
```

**What this does:**
- Creates a ClusterIssuer for self-signed certificates
- Useful for testing and development
- Certificates signed by their own private key

**Expected Output:**
```
✓ Self-signed ClusterIssuer created
✓ Issuer is ready

Use: kubectl describe clusterissuer selfsigned-issuer
```

---

### Step 4: Create CA Issuer

Create a CA-based issuer using a custom CA:

```bash
./create-ca-issuer.sh
```

**What this does:**
- Generates a custom CA certificate and key
- Stores CA in a Kubernetes Secret
- Creates a ClusterIssuer that uses the CA
- Allows issuing certificates signed by your CA

**Expected Output:**
```
✓ CA certificate generated
✓ CA secret created
✓ CA ClusterIssuer created
✓ Issuer is ready
```

---

### Step 5: Create Let's Encrypt Issuer

Create an ACME issuer for Let's Encrypt certificates:

```bash
./create-letsencrypt-issuer.sh
```

**Important Notes:**
- ⚠️ Uses Let's Encrypt **staging** environment (safe for testing)
- ⚠️ Requires a valid domain name for production use
- ⚠️ Requires external access for HTTP-01 challenge
- 💡 For this lab, create the issuer so `./verify.sh` can confirm the `letsencrypt-staging` ClusterIssuer exists and is Ready, but you will not issue real ACME certificates

**Expected Output:**
```
✓ Let's Encrypt staging issuer created
ℹ Note: Configured for staging environment
ℹ For production, change to: https://acme-v02.api.letsencrypt.org/directory
```

---

### Step 6: Request Certificates

> **Required:** Steps 3 and 4 must be completed first. This script requires both
> the self-signed issuer and the CA issuer to exist, and will exit with an error
> if either is missing.

Request certificates using different issuers:

```bash
./request-certificate.sh
```

**What this does:**
- Verifies both issuers exist (exits if not)
- Creates Certificate resources
- Requests self-signed certificate
- Requests CA-signed certificate
- Waits for certificates to be issued
- Verifies certificates are stored in Secrets

**Expected Output:**
```
========================================
Lab 21: Request Certificates
========================================

✓ Self-signed certificate requested
✓ CA-signed certificate requested
✓ Waiting for certificates to be issued...
✓ Certificate 'selfsigned-cert' is ready
✓ Certificate 'ca-signed-cert' is ready
✓ Secrets created successfully

Certificates:
  - selfsigned-cert-tls (self-signed)
  - ca-signed-cert-tls (CA signed)
```

**Verification:**
```bash
kubectl get certificates
kubectl get secrets | grep tls
kubectl describe certificate selfsigned-cert
```

---

### Step 7: Test Ingress TLS

Deploy a test application with Ingress TLS:

```bash
./test-ingress-tls.sh
```

**What this does:**
- Deploys a simple nginx application
- Creates a Service
- Creates an Ingress with TLS annotation
- cert-manager automatically creates certificate
- Configures Ingress to use the certificate

**Expected Output:**
```
========================================
Lab 21: Test Ingress TLS
========================================

✓ Test application deployed
✓ Service created
✓ Ingress created with TLS
✓ cert-manager issued certificate automatically
✓ Certificate is ready

Access the application:
  minikube service test-app-ingress --url
```

**Verification:**
```bash
kubectl get ingress
kubectl describe ingress test-app-ingress
kubectl get certificate test-app-tls
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
Lab 21: Validation
========================================

✓ Minikube is running
✓ kubectl is configured
✓ cert-manager pods are running
✓ Self-signed issuer exists
✓ CA issuer exists
✓ Certificates are ready
✓ Test application is running
✓ Ingress TLS is configured

========================================
✓ All validations passed!
Lab 21 completed successfully.
========================================
```

---

## Expected Outcome

After completing this lab, you should have:
- ✅ Working minikube Kubernetes cluster
- ✅ cert-manager deployed and operational
- ✅ Multiple certificate issuers configured
- ✅ Certificates issued and stored in Secrets
- ✅ Test application with TLS-enabled Ingress
- ✅ Understanding of automatic certificate management

You can verify this by:
- Running `kubectl get clusterissuers` (should show 3 issuers)
- Running `kubectl get certificates` (should show multiple certificates)
- Running `kubectl get secrets | grep tls` (should show certificate secrets)

---

## Troubleshooting

### Issue 1: Minikube fails to start

**Symptom:**
```
Error: Failed to start minikube
```

**Cause:**
- Docker/podman not installed or not running
- Insufficient system resources
- VT-x/AMD-v virtualization not enabled

**Solution:**
```bash
# Check docker is running
sudo systemctl status docker

# Check system resources
free -h
df -h

# Try with podman driver instead
minikube start --driver=podman

# Or specify resources
minikube start --cpus=2 --memory=2048
```

---

### Issue 2: cert-manager pods not ready

**Symptom:**
```
cert-manager pods in CrashLoopBackOff or Pending state
```

**Cause:**
- Insufficient cluster resources
- CRDs not properly installed
- Network issues

**Solution:**
```bash
# Check pod status
kubectl get pods -n cert-manager
kubectl describe pod -n cert-manager <pod-name>

# Check logs
kubectl logs -n cert-manager deployment/cert-manager

# Reinstall cert-manager
kubectl delete namespace cert-manager
./install-cert-manager.sh
```

---

### Issue 3: Certificate not ready

**Symptom:**
```
Certificate status: Issuing (stuck)
```

**Cause:**
- Issuer not configured correctly
- ACME challenge failing
- DNS issues

**Solution:**
```bash
# Check certificate details
kubectl describe certificate <cert-name>

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check issuer status
kubectl describe clusterissuer <issuer-name>

# For self-signed issues, recreate issuer
kubectl delete clusterissuer selfsigned-issuer
./create-selfsigned-issuer.sh
```

---

### Issue 4: kubectl command not found

**Symptom:**
```
bash: kubectl: command not found
```

**Cause:**
- kubectl not installed
- Not in PATH

**Solution:**
```bash
# Install kubectl manually
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Or run install-minikube.sh again
./install-minikube.sh
```

---

## Version-Specific Notes

### RHEL 8
- Docker/podman available from standard repos
- May need to enable container-tools module
- `sudo dnf module enable container-tools`

### RHEL 9
- Podman recommended over Docker
- Built-in container tools
- May need to configure cgroup v2 for minikube

### RHEL 10
- Latest podman version
- Full container runtime support
- No special configuration needed

---

## Cleanup

To reset your system and remove all Kubernetes resources:

```bash
./cleanup.sh
```

**Warning:** This will:
- Delete all cert-manager resources
- Stop and delete the minikube cluster
- Remove minikube and kubectl binaries (optional)

**Partial Cleanup:**
```bash
# Just delete cert-manager
kubectl delete namespace cert-manager

# Just stop minikube (keep for later)
minikube stop

# Completely remove minikube
minikube delete
```

---

## Advanced Topics

### Certificate Renewal

cert-manager automatically renews certificates:
- Default: renews at 2/3 of certificate lifetime
- Configurable via `renewBefore` in Certificate spec
- Monitor renewal: `kubectl describe certificate <name>`

### Multiple Namespaces

- Use `Issuer` for namespace-scoped issuers
- Use `ClusterIssuer` for cluster-wide issuers
- Certificates can reference either type

### Production Considerations

**Let's Encrypt Production:**
- Change to production ACME endpoint
- Implement rate limiting awareness
- Use DNS-01 challenge for wildcards
- Monitor certificate expiration

**High Availability:**
- Run multiple cert-manager replicas
- Use distributed storage for ACME accounts
- Implement monitoring and alerting

---

## Additional Resources

**Related Chapters:**
- Appendix A: Kubernetes cert-manager (detailed theory)
- Chapter 24: Let's Encrypt with Certbot (ACME protocol)
- Chapter 25: Ansible Automation for Certificates (automation concepts)

**Documentation:**
- cert-manager docs: https://cert-manager.io/docs/
- Kubernetes docs: https://kubernetes.io/docs/
- minikube docs: https://minikube.sigs.k8s.io/docs/

**Further Reading:**
- ACME protocol RFC 8555
- Kubernetes Ingress TLS
- Certificate lifecycle management

---

## Next Steps

After completing this lab, you can:
1. **Continue to Lab 22:** HashiCorp Vault PKI - Dynamic certificate management
2. **Review:** Appendix A for deeper cert-manager architecture
3. **Practice:** Deploy your own applications with TLS
4. **Explore:** DNS-01 challenges for wildcard certificates
5. **Integrate:** Connect cert-manager with external CAs

---

## Real-World Use Cases

**Development Environments:**
- Local TLS testing with self-signed certificates
- Staging environments with Let's Encrypt staging
- Team development with shared CA

**Production Environments:**
- Automatic Let's Encrypt certificates for public services
- Integration with enterprise PKI via ACME
- Multi-tenant certificate management
- Microservices TLS automation

---

**RHEL Versions Tested**: 8, 9, 10  
**Difficulty Level**: Intermediate/Advanced
