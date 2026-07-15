# Appendix G: VPN Certificates

## VPN Certificates — OpenVPN, WireGuard & IPsec

Virtual Private Networks use certificates to authenticate endpoints and establish encrypted tunnels.

## 1. OpenVPN with PKI

### Setup Easy-RSA

```bash
git clone https://github.com/OpenVPN/easy-rsa.git
cd easy-rsa/easyrsa3
./easyrsa init-pki
./easyrsa build-ca nopass
./easyrsa gen-req server nopass
./easyrsa sign-req server server
./easyrsa gen-req client1 nopass
./easyrsa sign-req client client1
./easyrsa gen-dh
openvpn --genkey secret ta.key
```

### Server Configuration

`/etc/openvpn/server.conf`:

```ini
port 1194
proto udp
dev tun

ca /etc/openvpn/pki/ca.crt
cert /etc/openvpn/pki/issued/server.crt
key /etc/openvpn/pki/private/server.key
dh /etc/openvpn/pki/dh.pem
tls-auth /etc/openvpn/ta.key 0

server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"

cipher AES-256-GCM
auth SHA256
user nobody
group nobody
persist-key
persist-tun

status /var/log/openvpn-status.log
verb 3
```

Start:
```bash
sudo systemctl enable --now openvpn-server@server
```

### Client Configuration

`client1.ovpn`:

```ini
client
dev tun
proto udp
remote vpn.example.com 1194

ca ca.crt
cert client1.crt
key client1.key
tls-auth ta.key 1

cipher AES-256-GCM
auth SHA256
verb 3
```

Connect:
```bash
sudo openvpn --config client1.ovpn
```

## 2. WireGuard (Certificate-less but Key-based)

WireGuard uses Curve25519 public keys instead of X.509 certificates. However, you can *wrap* WireGuard keys in certificates for enterprise identity management.

### Generate Keys

```bash
wg genkey | tee privatekey | wg pubkey > publickey
```

### Server Config

`/etc/wireguard/wg0.conf`:

```ini
[Interface]
PrivateKey = <server-private-key>
Address = 10.9.0.1/24
ListenPort = 51820

[Peer]
PublicKey = <client-public-key>
AllowedIPs = 10.9.0.2/32
```

Enable:
```bash
sudo systemctl enable --now wg-quick@wg0
```

### Client Config

```ini
[Interface]
PrivateKey = <client-private-key>
Address = 10.9.0.2/24
DNS = 8.8.8.8

[Peer]
PublicKey = <server-public-key>
Endpoint = vpn.example.com:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

Connect:
```bash
sudo wg-quick up wg0
```

## 3. IPsec (strongSwan) with X.509

### Install strongSwan

```bash
sudo dnf install strongswan -y
```

### Generate Certificates

```bash
# CA
ipsec pki --gen --type rsa --size 4096 --outform pem > ca.key.pem
ipsec pki --self --ca --lifetime 3650 --in ca.key.pem --type rsa \
  --dn "CN=VPN CA" --outform pem > ca.crt.pem

# Server cert
ipsec pki --gen --type rsa --size 2048 --outform pem > server.key.pem
ipsec pki --req --type priv --in server.key.pem --dn "CN=vpn.example.com" \
  --san vpn.example.com --outform pem > server.req.pem
ipsec pki --issue --cacert ca.crt.pem --cakey ca.key.pem --type pkcs10 \
  --in server.req.pem --lifetime 365 --outform pem > server.crt.pem

# Client cert
ipsec pki --gen --type rsa --size 2048 --outform pem > client.key.pem
ipsec pki --req --type priv --in client.key.pem --dn "CN=client@example.com" \
  --outform pem > client.req.pem
ipsec pki --issue --cacert ca.crt.pem --cakey ca.key.pem --type pkcs10 \
  --in client.req.pem --lifetime 365 --outform pem > client.crt.pem
```

Copy to `/etc/ipsec.d/`:

```bash
sudo cp ca.crt.pem /etc/ipsec.d/cacerts/
sudo cp server.crt.pem /etc/ipsec.d/certs/
sudo cp server.key.pem /etc/ipsec.d/private/
```

### Server Configuration

`/etc/ipsec.conf`:

```ini
config setup
    charondebug="ike 2, knl 2, cfg 2"

conn %default
    ikelifetime=60m
    keylife=20m
    rekeymargin=3m
    keyingtries=1
    keyexchange=ikev2
    authby=pubkey

conn rw
    leftcert=server.crt.pem
    leftid=@vpn.example.com
    leftsubnet=0.0.0.0/0
    leftfirewall=yes
    right=%any
    rightid=%any
    rightsourceip=10.10.10.0/24
    auto=add
```

Start:
```bash
sudo systemctl enable --now strongswan
```

### Client Configuration

Install client cert/key, then connect via NetworkManager or command-line.

## 4. Certificate Revocation in VPNs

### OpenVPN CRL

```bash
./easyrsa revoke client1
./easyrsa gen-crl
```

Update `server.conf`:
```ini
crl-verify /etc/openvpn/pki/crl.pem
```

### strongSwan OCSP

In `/etc/ipsec.conf`:
```ini
conn rw
    leftcert=server.crt.pem
    leftsendcert=always
    rightca="CN=VPN CA"
    rightcert=*
    ocsp_uri=http://ocsp.example.com
```

## 5. Comparison

| VPN | Certificate Support | Key Management | Use Case |
|-----|---------------------|----------------|----------|
| OpenVPN | Full X.509 PKI | Easy-RSA, manual | Enterprise site-to-site & remote access |
| WireGuard | Public keys (no X.509 by default) | Simple key pairs | Modern, high-performance, IoT |
| IPsec (strongSwan) | Full X.509 PKI | ipsec pki tools | Standards-compliant, interop with Cisco/Juniper |

## 6. Best Practices

1. **Separate CA for VPN** – Isolate VPN certs from web TLS certs.
2. **Short Validity** – Issue VPN client certs with 30-90 day expiry.
3. **CRL/OCSP** – Enable revocation checking on the server.
4. **Hardware Tokens** – Store client keys in YubiKeys or smartcards for remote workers.

> **Real-world:** Many organisations migrate from OpenVPN to WireGuard for performance but wrap WireGuard keys in X.509 for integration with existing IAM systems.
