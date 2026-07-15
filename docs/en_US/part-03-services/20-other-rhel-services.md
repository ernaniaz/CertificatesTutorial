# Chapter 20: Other RHEL Services with Certificates

> **Beyond the Basics:** Many other RHEL services use certificates. This chapter covers Cockpit, VPN services, container registries, and more.

---

## 20.1 Services Covered

This chapter provides quick-start guides for:

- 🖥️ **Cockpit** (Web-based admin console)
- 🔒 **OpenVPN** (VPN service)
- 🛡️ **strongSwan** (IPsec VPN)
- 📦 **Container Registry** (Podman/Docker registry)
- 📡 **HAProxy** (Load balancer)
- 🔌 **Redis** with TLS (using stunnel)
- ⚙️ **Ansible Tower/AWX** (Automation platform)

---

## 20.2 Cockpit Web Console

### What is Cockpit?

**Cockpit** is RHEL's built-in web-based administration interface.

**Default:** Uses self-signed certificate
**Goal:** Replace with proper certificate

### Configure Cockpit with Certificates

```bash
#============================================#
# COCKPIT WITH PROPER CERTIFICATE
#============================================#

# Install Cockpit
sudo dnf install cockpit -y
sudo systemctl enable --now cockpit.socket

# Open firewall
sudo firewall-cmd --add-service=cockpit --permanent
sudo firewall-cmd --reload

# Cockpit certificate location
ls -l /etc/cockpit/ws-certs.d/

# Method 1: Place certificate with specific name
# Cockpit uses certificates in /etc/cockpit/ws-certs.d/
# Filename format: NN-name.cert (where NN = priority, lower = higher priority)

sudo cat server.crt server.key > /etc/cockpit/ws-certs.d/01-server.cert
sudo chmod 644 /etc/cockpit/ws-certs.d/01-server.cert

# Restart Cockpit
sudo systemctl restart cockpit.socket

# Method 2: Use certmonger
sudo ipa-getcert request \
  -f /etc/cockpit/ws-certs.d/01-cockpit.cert \
  -k /etc/cockpit/ws-certs.d/01-cockpit.cert \
  -K HTTP/$(hostname -f)@REALM \
  -D $(hostname -f) \
  -C "systemctl restart cockpit.socket" \
  -F /etc/cockpit/ws-certs.d/01-cockpit.cert  # Combined cert+key

# Access Cockpit
# https://server.example.com:9090/
```

**Note:** Cockpit expects combined cert+key in single file!

---

## 20.3 OpenVPN

### Server Configuration with Certificates

```bash
#============================================#
# OPENVPN SERVER WITH CERTIFICATES
#============================================#

# Install OpenVPN (from EPEL on RHEL 7, repos on RHEL 8+)
sudo dnf install openvpn -y

# Generate or obtain certificates:
# - CA certificate
# - Server certificate + key
# - Client certificates

# /etc/openvpn/server/server.conf
port 1194
proto udp
dev tun

ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key /etc/openvpn/server/server.key
dh /etc/openvpn/server/dh2048.pem

tls-auth /etc/openvpn/server/ta.key 0
cipher AES-256-GCM
auth SHA256

server 10.8.0.0 255.255.255.0

# Start OpenVPN
sudo systemctl enable --now openvpn-server@server

# Open firewall
sudo firewall-cmd --add-port=1194/udp --permanent
sudo firewall-cmd --reload
```

### Test OpenVPN

```bash
# Check if running
systemctl status openvpn-server@server

# Test from client
openvpn --config client.ovpn --verb 3
```

---

## 20.4 strongSwan IPsec VPN

### Configure with Certificates

```bash
#============================================#
# STRONGSWAN WITH CERTIFICATES
#============================================#

# Install
sudo dnf install strongswan -y

# Certificate locations
# CA: /etc/strongswan/ipsec.d/cacerts/
# Server/Client certs: /etc/strongswan/ipsec.d/certs/
# Private keys: /etc/strongswan/ipsec.d/private/

# Copy certificates
sudo cp ca.crt /etc/strongswan/ipsec.d/cacerts/
sudo cp server.crt /etc/strongswan/ipsec.d/certs/
sudo cp server.key /etc/strongswan/ipsec.d/private/
sudo chmod 600 /etc/strongswan/ipsec.d/private/server.key

# /etc/strongswan/ipsec.conf
config setup
    charondebug="ike 2, knl 2, cfg 2"

conn example-ipsec
    left=%any
    leftid=@server.example.com
    leftcert=server.crt
    leftsubnet=10.0.0.0/24

    right=%any
    rightid=@client.example.com
    rightcert=client.crt

    auto=add
    type=tunnel
    keyexchange=ikev2

# Start strongSwan
sudo systemctl enable --now strongswan

# Check status
sudo swanctl --list-sas
```

---

## 20.5 Container Registry with TLS

### Podman/Docker Registry

```bash
#============================================#
# CONTAINER REGISTRY WITH TLS
#============================================#

# Install registry
sudo dnf install -y podman
sudo podman pull docker.io/library/registry:2

# Create certificate for registry
sudo mkdir -p /etc/registry/certs
sudo openssl genpkey -algorithm RSA \
  -out /etc/registry/certs/registry.key \
  -pkeyopt rsa_keygen_bits:2048

sudo openssl req -new -x509 -days 365 \
  -key /etc/registry/certs/registry.key \
  -out /etc/registry/certs/registry.crt \
  -subj "/CN=registry.example.com" \
  -addext "subjectAltName=DNS:registry.example.com"

# Run registry with TLS
sudo podman run -d \
  --name registry \
  -p 5000:5000 \
  -v /etc/registry/certs:/certs:ro \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
  registry:2

# Test
curl https://registry.example.com:5000/v2/_catalog
```

### Client Configuration

```bash
# Add registry CA to system trust
sudo cp /etc/registry/certs/registry.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust

# Test pull
podman pull registry.example.com:5000/myimage:latest
```

---

## 20.6 HAProxy TLS Termination

### Load Balancer with TLS

```bash
#============================================#
# HAPROXY TLS TERMINATION
#============================================#

# Install HAProxy
sudo dnf install haproxy -y

# HAProxy requires combined cert+key+chain in ONE file
cat server.crt intermediate.crt server.key > /etc/haproxy/certs/bundle.pem
sudo chmod 600 /etc/haproxy/certs/bundle.pem

# /etc/haproxy/haproxy.cfg
frontend https-in
    bind *:443 ssl crt /etc/haproxy/certs/bundle.pem
    mode http
    default_backend web_servers

    # Force HTTPS
    http-request redirect scheme https unless { ssl_fc }

    # Security headers
    http-response set-header Strict-Transport-Security "max-age=31536000"

backend web_servers
    mode http
    balance roundrobin
    server web1 10.0.1.10:80 check
    server web2 10.0.1.11:80 check
    server web3 10.0.1.12:80 check

# Start HAProxy
sudo systemctl enable --now haproxy

# Test
curl -v https://loadbalancer.example.com/
```

---

## 20.7 Redis with TLS (via stunnel)

### Redis TLS Proxy

```bash
#============================================#
# REDIS WITH TLS USING STUNNEL
#============================================#

# Install Redis and stunnel
sudo dnf install redis stunnel -y

# Configure Redis (listen on localhost only)
# /etc/redis/redis.conf
bind 127.0.0.1

# Start Redis
sudo systemctl enable --now redis

# Configure stunnel
# /etc/stunnel/redis.conf
[redis-tls]
accept = 0.0.0.0:6380
connect = 127.0.0.1:6379
cert = /etc/pki/tls/certs/redis.crt
key = /etc/pki/tls/private/redis.key
CAfile = /etc/pki/tls/certs/ca-bundle.crt

# Optional: Require client certificates
verify = 2
CApath = /etc/pki/tls/certs/

# Start stunnel
sudo systemctl enable --now stunnel@redis

# Test
openssl s_client -connect localhost:6380
# Then type: PING
# Should respond: +PONG
```

---

## 20.8 Ansible Tower/AWX

### Tower/AWX with Custom Certificate

```bash
#============================================#
# ANSIBLE TOWER/AWX CUSTOM CERTIFICATE
#============================================#

# Tower certificate location
# /etc/tower/tower.cert
# /etc/tower/tower.key

# Replace with proper certificate
sudo cp tower.example.com.crt /etc/tower/tower.cert
sudo cp tower.example.com.key /etc/tower/tower.key
sudo chmod 600 /etc/tower/tower.key

# Restart Tower services
sudo ansible-tower-service restart

# Or for AWX (containerized)
# Update docker-compose.yml or k8s secrets

# Test
curl -v https://tower.example.com/
```

---

## 20.9 SSH with Certificates (Advanced)

### SSH Certificate Authentication

**Note:** Different from SSH keys! This uses X.509 certificates.

```bash
#============================================#
# SSH WITH X.509 CERTIFICATES (ADVANCED)
#============================================#

# Requires: openssh-server with X.509 patch or ssh-keysign

# Generate certificate for SSH user
openssl genpkey -algorithm RSA -out ssh-user.key -pkeyopt rsa_keygen_bits:2048
openssl req -new -key ssh-user.key -out ssh-user.csr -subj "/CN=user@example.com"
# Get signed by CA

# Configure sshd (experimental, not standard RHEL)
# /etc/ssh/sshd_config
# X509KeyAlgorithm x509v3-rsa2048-sha256
# X509TrustAnchor /etc/ssh/ca.crt

# Standard approach: Use SSH keys, not X.509
# X.509 SSH support is limited on RHEL
```

**Recommendation:** Use standard SSH key-based authentication for SSH, use X.509 for other services.

---

## 20.10 Monitoring Multiple Services

### Multi-Service Certificate Check

```bash
#!/bin/bash
# check-all-services.sh
# Check certificates for all services

echo "=== Multi-Service Certificate Check ==="

# Apache
echo "1. Apache (port 443):"
timeout 3 openssl s_client -connect localhost:443 </dev/null 2>&1 | grep -E "(subject=|issuer=)" | head -2

# NGINX (if installed)
echo "2. NGINX (port 8443 or custom):"
timeout 3 openssl s_client -connect localhost:8443 </dev/null 2>&1 | grep -E "(subject=|issuer=)" | head -2

# Postfix
echo "3. Postfix SMTPS (port 465):"
timeout 3 openssl s_client -connect localhost:465 </dev/null 2>&1 | grep -E "(subject=|issuer=)" | head -2

# LDAPS
echo "4. LDAP (port 636):"
timeout 3 openssl s_client -connect localhost:636 </dev/null 2>&1 | grep -E "(subject=|issuer=)" | head -2

# PostgreSQL
echo "5. PostgreSQL (port 5432):"
sudo -u postgres psql -c "SHOW ssl;" 2>/dev/null

# Cockpit
echo "6. Cockpit (port 9090):"
timeout 3 openssl s_client -connect localhost:9090 </dev/null 2>&1 | grep -E "(subject=|issuer=)" | head -2

# certmonger tracking
echo ""
echo "7. certmonger tracked certificates:"
sudo getcert list | grep -c "Request ID"
echo "total certificates tracked"

echo ""
echo "=== Check Complete ==="
```

---

## 20.11 Service-Specific Quick References

### Cockpit

```bash
# Install: dnf install cockpit
# Cert location: /etc/cockpit/ws-certs.d/
# Format: Combined cert+key
# Reload: systemctl restart cockpit.socket
# Test: https://server:9090/
```

### OpenVPN

```bash
# Install: dnf install openvpn (EPEL)
# Cert location: /etc/openvpn/server/
# Files: ca.crt, server.crt, server.key
# Start: systemctl start openvpn-server@server
# Test: openvpn --config client.ovpn
```

### strongSwan

```bash
# Install: dnf install strongswan
# Cert location: /etc/strongswan/ipsec.d/
# Subdirs: cacerts/, certs/, private/
# Start: systemctl start strongswan
# Test: swanctl --list-sas
```

### HAProxy

```bash
# Install: dnf install haproxy
# Cert format: Combined PEM (cert+key+chain)
# Location: /etc/haproxy/certs/
# Config: bind *:443 ssl crt /path/to/bundle.pem
# Test: curl -v https://loadbalancer/
```

### Container Registry

```bash
# Run: podman run -d -p 5000:5000 registry:2
# Certs: Mount as volumes (-v)
# Env vars: REGISTRY_HTTP_TLS_CERTIFICATE
#           REGISTRY_HTTP_TLS_KEY
# Test: curl https://registry:5000/v2/_catalog
```

---

## 20.12 Wildcard Certificates for Multiple Services

### When to Use Wildcards

**Scenario:** Multiple subdomains on same server

```
web.example.com    → Apache
api.example.com    → NGINX
admin.example.com  → Cockpit
mail.example.com   → Postfix
```

**Solution:** Use wildcard certificate `*.example.com`

### Generate Wildcard Certificate

```bash
#============================================#
# WILDCARD CERTIFICATE
#============================================#

# Generate key
openssl genpkey -algorithm RSA -out wildcard.key -pkeyopt rsa_keygen_bits:2048

# Generate CSR
openssl req -new -key wildcard.key -out wildcard.csr \
  -subj "/CN=*.example.com" \
  -addext "subjectAltName=DNS:*.example.com,DNS:example.com"

# Submit to CA, receive wildcard.crt

# Use for multiple services
sudo cp wildcard.crt /etc/pki/tls/certs/
sudo cp wildcard.key /etc/pki/tls/private/
sudo chmod 600 /etc/pki/tls/private/wildcard.key

# Configure each service to use it
# Apache: SSLCertificateFile /etc/pki/tls/certs/wildcard.crt
# NGINX: ssl_certificate /etc/pki/tls/certs/wildcard.crt
# Postfix: smtpd_tls_cert_file = /etc/pki/tls/certs/wildcard.crt
```

**Pros:**
- ✅ One certificate for multiple subdomains
- ✅ Easier management
- ✅ Cost-effective (if purchasing)

**Cons:**
- ⚠️ If compromised, affects all subdomains
- ⚠️ Doesn't work for multi-level (*.*.example.com)
- ⚠️ Some security policies prohibit wildcards

---

## 20.13 Service Certificate Matrix

### Certificate Requirements by Service

| Service | CN/SAN | Client Cert | Auto-Renew | Special Notes |
|---------|--------|-------------|------------|---------------|
| **Apache** | Required | Optional (mTLS) | certmonger | Most common |
| **NGINX** | Required | Optional (mTLS) | certmonger | High performance |
| **Postfix** | Required | Optional | certmonger | SMTP/SMTPS |
| **OpenLDAP** | Required | Optional | certmonger | Must be ldap user readable |
| **PostgreSQL** | Required | Optional | Manual or script | postgres user ownership |
| **MySQL** | Required | Optional | Manual or script | mysql user ownership |
| **FreeIPA** | Automatic | N/A | Automatic | Self-managing |
| **Cockpit** | Required | No | certmonger | Combined cert+key file |
| **OpenVPN** | Required | Required | Manual | Complex PKI |
| **strongSwan** | Required | Required | Manual | IPsec specific |
| **HAProxy** | Required | No | certmonger | Combined PEM format |
| **Registry** | Required | Optional | Manual | Container specific |

---

## 20.14 Troubleshooting Quick Guide

### Generic Service TLS Troubleshooting

```bash
#============================================#
# UNIVERSAL TLS TROUBLESHOOTING
#============================================#

# 1. Identify service and port
ss -tlnp | grep <service>

# 2. Check if TLS is enabled
# (service-specific command)

# 3. Test TLS connection
openssl s_client -connect localhost:<port>
# Or with STARTTLS:
openssl s_client -connect localhost:<port> -starttls <protocol>

# 4. Check certificate files
ls -lZ /path/to/certs/

# 5. Verify ownership/permissions
# - Certificate: 644, owned by service user
# - Key: 600, owned by service user

# 6. Check configuration
# (service-specific config file)

# 7. Check logs
sudo journalctl -u <service> | grep -i tls
sudo tail -f /var/log/<service>/ | grep -i tls

# 8. Test from remote client
openssl s_client -connect server.example.com:<port>
```

---

## 20.15 Centralized Certificate Management

### Using certmonger for All Services

```bash
#============================================#
# CENTRAL CERTIFICATE MANAGEMENT STRATEGY
#============================================#

# Track all service certificates with certmonger

# Apache
sudo ipa-getcert request -f /etc/pki/tls/certs/apache.crt \
  -k /etc/pki/tls/private/apache.key \
  -K HTTP/$(hostname -f)@REALM \
  -C "systemctl reload httpd"

# NGINX
sudo ipa-getcert request -f /etc/pki/tls/certs/nginx.crt \
  -k /etc/pki/tls/private/nginx.key \
  -K HTTP/$(hostname -f)@REALM \
  -C "systemctl reload nginx"

# Postfix
sudo ipa-getcert request -f /etc/pki/tls/certs/postfix.crt \
  -k /etc/pki/tls/private/postfix.key \
  -K smtp/$(hostname -f)@REALM \
  -C "postfix reload"

# OpenLDAP
sudo ipa-getcert request -f /etc/openldap/certs/ldap.crt \
  -k /etc/openldap/certs/ldap.key \
  -K ldap/$(hostname -f)@REALM \
  -o ldap:ldap \
  -m 600 \
  -C "systemctl restart slapd"

# Monitor all
sudo getcert list
```

**Benefits:**
- ✅ Single tool for all services
- ✅ Automatic renewal
- ✅ Centralized monitoring
- ✅ Consistent approach

---

## 20.16 Key Takeaways

1. **Many services use certificates** beyond just web servers
2. **Each service has unique requirements** - Check ownership, permissions
3. **certmonger works with most** services for automation
4. **Wildcard certificates** can simplify multi-service setups
5. **Test each service** independently
6. **Centralized tracking** with certmonger recommended
7. **Document service-specific** configurations

---

## Quick Reference Card

```
┌───────────────────────────────────────────────────────────────┐
│ OTHER SERVICES CERTIFICATE QUICK REFERENCE                    │
├───────────────────────────────────────────────────────────────┤
│ Cockpit:     /etc/cockpit/ws-certs.d/NN-name.cert             │
│              (combined cert+key)                              │
│                                                               │
│ OpenVPN:     /etc/openvpn/server/{ca,server}.{crt,key}        │
│              Complex PKI with client certs                    │
│                                                               │
│ strongSwan:  /etc/strongswan/ipsec.d/{cacerts,certs,private}/ │
│              IPsec-specific configuration                     │
│                                                               │
│ HAProxy:     Combined PEM (cert+key+chain in one file)        │
│              /etc/haproxy/certs/bundle.pem                    │
│                                                               │
│ Registry:    Environment variables for container              │
│              REGISTRY_HTTP_TLS_CERTIFICATE/KEY                │
│                                                               │
│ Generic:     Check ownership, permissions, SELinux            │
│              Test with: openssl s_client -connect :port       │
└───────────────────────────────────────────────────────────────┘

✅ Use certmonger for automation where possible
✅ Each service has unique file format/location requirements
```
---

**Chapter Navigation**

| [← Previous: Chapter 19 - FreeIPA Certificate Services](19-freeipa-services.md) | [Next: Chapter 21 - Service Certificate Best Practices →](21-service-best-practices.md) |
|:---|---:|
