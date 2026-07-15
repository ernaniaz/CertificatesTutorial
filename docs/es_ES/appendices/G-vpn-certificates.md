# Apéndice G: Certificados VPN

## Certificados VPN — OpenVPN, WireGuard e IPsec

Las Redes Privadas Virtuales usan certificados para autenticar endpoints y establecer túneles cifrados.

## 1. OpenVPN con PKI

### Configurar Easy-RSA

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

### Configuración de Servidor

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

Iniciar:
```bash
sudo systemctl enable --now openvpn-server@server
```

### Configuración de Cliente

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

Conectar:
```bash
sudo openvpn --config client1.ovpn
```

## 2. WireGuard (Sin Certificados pero Basado en Claves)

WireGuard usa claves públicas Curve25519 en lugar de certificados X.509. Sin embargo, puedes *envolver* claves WireGuard en certificados para gestión de identidad empresarial.

### Generar Claves

```bash
wg genkey | tee privatekey | wg pubkey > publickey
```

### Configuración de Servidor

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

Habilitar:
```bash
sudo systemctl enable --now wg-quick@wg0
```

### Configuración de Cliente

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

Conectar:
```bash
sudo wg-quick up wg0
```

## 3. IPsec (strongSwan) con X.509

### Instalar strongSwan

```bash
sudo dnf install strongswan -y
```

### Generar Certificados

```bash
# CA
ipsec pki --gen --type rsa --size 4096 --outform pem > ca.key.pem
ipsec pki --self --ca --lifetime 3650 --in ca.key.pem --type rsa \
  --dn "CN=VPN CA" --outform pem > ca.crt.pem

# Cert de servidor
ipsec pki --gen --type rsa --size 2048 --outform pem > server.key.pem
ipsec pki --req --type priv --in server.key.pem --dn "CN=vpn.example.com" \
  --san vpn.example.com --outform pem > server.req.pem
ipsec pki --issue --cacert ca.crt.pem --cakey ca.key.pem --type pkcs10 \
  --in server.req.pem --lifetime 365 --outform pem > server.crt.pem

# Cert de cliente
ipsec pki --gen --type rsa --size 2048 --outform pem > client.key.pem
ipsec pki --req --type priv --in client.key.pem --dn "CN=client@example.com" \
  --outform pem > client.req.pem
ipsec pki --issue --cacert ca.crt.pem --cakey ca.key.pem --type pkcs10 \
  --in client.req.pem --lifetime 365 --outform pem > client.crt.pem
```

Copiar a `/etc/ipsec.d/`:

```bash
sudo cp ca.crt.pem /etc/ipsec.d/cacerts/
sudo cp server.crt.pem /etc/ipsec.d/certs/
sudo cp server.key.pem /etc/ipsec.d/private/
```

### Configuración de Servidor

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

Iniciar:
```bash
sudo systemctl enable --now strongswan
```

### Configuración de Cliente

Instalar cert/clave de cliente, luego conectar vía NetworkManager o línea de comandos.

## 4. Revocación de Certificados en VPNs

### CRL de OpenVPN

```bash
./easyrsa revoke client1
./easyrsa gen-crl
```

Actualizar `server.conf`:
```ini
crl-verify /etc/openvpn/pki/crl.pem
```

### OCSP de strongSwan

En `/etc/ipsec.conf`:
```ini
conn rw
    leftcert=server.crt.pem
    leftsendcert=always
    rightca="CN=VPN CA"
    rightcert=*
    ocsp_uri=http://ocsp.example.com
```

## 5. Comparación

| VPN | Soporte Certificado | Gestión de Claves | Caso de Uso |
|-----|---------------------|-------------------|-------------|
| OpenVPN | PKI X.509 completa | Easy-RSA, manual | Sitio-a-sitio empresarial y acceso remoto |
| WireGuard | Claves públicas (no X.509 por defecto) | Pares de claves simples | Moderno, alto rendimiento, IoT |
| IPsec (strongSwan) | PKI X.509 completa | Herramientas ipsec pki | Conforme a estándares, interop con Cisco/Juniper |

## 6. Mejores Prácticas

1. **CA Separada para VPN** – Aislar certs VPN de certs TLS web.
2. **Validez Corta** – Emitir certs de cliente VPN con expiración 30-90 días.
3. **CRL/OCSP** – Habilitar verificación de revocación en el servidor.
4. **Tokens de Hardware** – Almacenar claves de cliente en YubiKeys o smartcards para trabajadores remotos.

> **Mundo real:** Muchas organizaciones migran de OpenVPN a WireGuard por rendimiento pero envuelven claves WireGuard en X.509 para integración con sistemas IAM existentes.
