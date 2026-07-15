# Capítulo 20: Outros Serviços RHEL com Certificados

> **Além do Básico:** Muitos outros serviços RHEL usam certificados. Este capítulo cobre Cockpit, serviços VPN, registros container, e mais.

---

## 20.1 Serviços Cobertos

Este capítulo fornece guias de início rápido para:

- 🖥️ **Cockpit** (Console admin baseado em web)
- 🔒 **OpenVPN** (Serviço VPN)
- 🛡️ **strongSwan** (VPN IPsec)
- 📦 **Container Registry** (Registro Podman/Docker)
- 📡 **HAProxy** (Load balancer)
- 🔌 **Redis** com TLS (usando stunnel)
- ⚙️ **Ansible Tower/AWX** (Plataforma automatização)

---

## 20.2 Console Web Cockpit

### O Que é Cockpit?

**Cockpit** é a interface de administração baseada em web integrada do RHEL.

**Padrão:** Usa certificado autoassinado
**Objetivo:** Substituir com certificado apropriado

### Configurar Cockpit com Certificados

```bash
#============================================#
# COCKPIT COM CERTIFICADO APROPRIADO
#============================================#

# Instalar Cockpit
sudo dnf install cockpit -y
sudo systemctl enable --now cockpit.socket

# Abrir firewall
sudo firewall-cmd --add-service=cockpit --permanent
sudo firewall-cmd --reload

# Localização certificado Cockpit
ls -l /etc/cockpit/ws-certs.d/

# Método 1: Colocar certificado com nome específico
# Cockpit usa certificados em /etc/cockpit/ws-certs.d/
# Formato filename: NN-name.cert (onde NN = prioridade, menor = maior prioridade)

sudo cat server.crt server.key > /etc/cockpit/ws-certs.d/01-server.cert
sudo chmod 644 /etc/cockpit/ws-certs.d/01-server.cert

# Reiniciar Cockpit
sudo systemctl restart cockpit.socket

# Método 2: Usar certmonger
sudo ipa-getcert request \
  -f /etc/cockpit/ws-certs.d/01-cockpit.cert \
  -k /etc/cockpit/ws-certs.d/01-cockpit.cert \
  -K HTTP/$(hostname -f)@REALM \
  -D $(hostname -f) \
  -C "systemctl restart cockpit.socket" \
  -F /etc/cockpit/ws-certs.d/01-cockpit.cert  # Cert+chave combinados

# Acessar Cockpit
# https://server.example.com:9090/
```

**Nota:** Cockpit espera cert+chave combinados em arquivo único!

---

## 20.3 OpenVPN

### Configuração Servidor com Certificados

```bash
#============================================#
# SERVIDOR OPENVPN COM CERTIFICADOS
#============================================#

# Instalar OpenVPN (de EPEL no RHEL 7, repos no RHEL 8+)
sudo dnf install openvpn -y

# Gerar ou obter certificados:
# - Certificado CA
# - Certificado servidor + chave
# - Certificados cliente

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

# Iniciar OpenVPN
sudo systemctl enable --now openvpn-server@server

# Abrir firewall
sudo firewall-cmd --add-port=1194/udp --permanent
sudo firewall-cmd --reload
```

### Testar OpenVPN

```bash
# Verificar se rodando
systemctl status openvpn-server@server

# Testar do cliente
openvpn --config client.ovpn --verb 3
```

---

## 20.4 strongSwan IPsec VPN

### Configurar com Certificados

```bash
#============================================#
# STRONGSWAN COM CERTIFICADOS
#============================================#

# Instalar
sudo dnf install strongswan -y

# Localizações certificado
# CA: /etc/strongswan/ipsec.d/cacerts/
# Certs Servidor/Cliente: /etc/strongswan/ipsec.d/certs/
# Chaves privadas: /etc/strongswan/ipsec.d/private/

# Copiar certificados
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

# Iniciar strongSwan
sudo systemctl enable --now strongswan

# Verificar status
sudo swanctl --list-sas
```

---

## 20.5 Registro Container com TLS

### Registro Podman/Docker

```bash
#============================================#
# REGISTRO CONTAINER COM TLS
#============================================#

# Instalar registry
sudo dnf install -y podman
sudo podman pull docker.io/library/registry:2

# Criar certificado para registry
sudo mkdir -p /etc/registry/certs
sudo openssl genpkey -algorithm RSA \
  -out /etc/registry/certs/registry.key \
  -pkeyopt rsa_keygen_bits:2048

sudo openssl req -new -x509 -days 365 \
  -key /etc/registry/certs/registry.key \
  -out /etc/registry/certs/registry.crt \
  -subj "/CN=registry.example.com" \
  -addext "subjectAltName=DNS:registry.example.com"

# Executar registry com TLS
sudo podman run -d \
  --name registry \
  -p 5000:5000 \
  -v /etc/registry/certs:/certs:ro \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
  registry:2

# Testar
curl https://registry.example.com:5000/v2/_catalog
```

### Configuração Cliente

```bash
# Adicionar CA registry ao trust sistema
sudo cp /etc/registry/certs/registry.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust

# Testar pull
podman pull registry.example.com:5000/myimage:latest
```

---

## 20.6 Terminação TLS HAProxy

### Load Balancer com TLS

```bash
#============================================#
# TERMINAÇÃO TLS HAPROXY
#============================================#

# Instalar HAProxy
sudo dnf install haproxy -y

# HAProxy requer cert+chave+cadeia combinados em UM arquivo
cat server.crt intermediate.crt server.key > /etc/haproxy/certs/bundle.pem
sudo chmod 600 /etc/haproxy/certs/bundle.pem

# /etc/haproxy/haproxy.cfg
frontend https-in
    bind *:443 ssl crt /etc/haproxy/certs/bundle.pem
    mode http
    default_backend web_servers

    # Forçar HTTPS
    http-request redirect scheme https unless { ssl_fc }

    # Headers segurança
    http-response set-header Strict-Transport-Security "max-age=31536000"

backend web_servers
    mode http
    balance roundrobin
    server web1 10.0.1.10:80 check
    server web2 10.0.1.11:80 check
    server web3 10.0.1.12:80 check

# Iniciar HAProxy
sudo systemctl enable --now haproxy

# Testar
curl -v https://loadbalancer.example.com/
```

---

## 20.7 Redis com TLS (via stunnel)

### Proxy TLS Redis

```bash
#============================================#
# REDIS COM TLS USANDO STUNNEL
#============================================#

# Instalar Redis e stunnel
sudo dnf install redis stunnel -y

# Configurar Redis (escutar apenas em localhost)
# /etc/redis/redis.conf
bind 127.0.0.1

# Iniciar Redis
sudo systemctl enable --now redis

# Configurar stunnel
# /etc/stunnel/redis.conf
[redis-tls]
accept = 0.0.0.0:6380
connect = 127.0.0.1:6379
cert = /etc/pki/tls/certs/redis.crt
key = /etc/pki/tls/private/redis.key
CAfile = /etc/pki/tls/certs/ca-bundle.crt

# Opcional: Requerer certificados cliente
verify = 2
CApath = /etc/pki/tls/certs/

# Iniciar stunnel
sudo systemctl enable --now stunnel@redis

# Testar
openssl s_client -connect localhost:6380
# Então digitar: PING
# Deveria responder: +PONG
```

---

## 20.8 Ansible Tower/AWX

### Tower/AWX com Certificado Customizado

```bash
#============================================#
# ANSIBLE TOWER/AWX CERTIFICADO CUSTOMIZADO
#============================================#

# Localização certificado Tower
# /etc/tower/tower.cert
# /etc/tower/tower.key

# Substituir com certificado apropriado
sudo cp tower.example.com.crt /etc/tower/tower.cert
sudo cp tower.example.com.key /etc/tower/tower.key
sudo chmod 600 /etc/tower/tower.key

# Reiniciar serviços Tower
sudo ansible-tower-service restart

# Ou para AWX (containerizado)
# Atualizar docker-compose.yml ou secrets k8s

# Testar
curl -v https://tower.example.com/
```

---

## 20.9 SSH com Certificados (Avançado)

### Autenticação Certificado SSH

**Nota:** Diferente de chaves SSH! Isto usa certificados X.509.

```bash
#============================================#
# SSH COM CERTIFICADOS X.509 (AVANÇADO)
#============================================#

# Requer: openssh-server com patch X.509 ou ssh-keysign

# Gerar certificado para usuário SSH
openssl genpkey -algorithm RSA -out ssh-user.key -pkeyopt rsa_keygen_bits:2048
openssl req -new -key ssh-user.key -out ssh-user.csr -subj "/CN=user@example.com"
# Obter assinado por CA

# Configurar sshd (experimental, não padrão RHEL)
# /etc/ssh/sshd_config
# X509KeyAlgorithm x509v3-rsa2048-sha256
# X509TrustAnchor /etc/ssh/ca.crt

# Abordagem padrão: Usar chaves SSH, não X.509
# Suporte X.509 SSH é limitado no RHEL
```

**Recomendação:** Usar autenticação SSH baseada em chave padrão para SSH, usar X.509 para outros serviços.

---

## 20.10 Monitorando Múltiplos Serviços

### Verificação Certificado Multi-Serviço

```bash
#!/bin/bash
# check-all-services.sh
# Verificar certificados para todos serviços

echo "=== Verificação Certificado Multi-Serviço ==="

# Apache
echo "1. Apache (porta 443):"
timeout 3 openssl s_client -connect localhost:443 </dev/null 2>&1 | grep -E "(subject=|issuer=)" | head -2

# NGINX (se instalado)
echo "2. NGINX (porta 8443 ou customizada):"
timeout 3 openssl s_client -connect localhost:8443 </dev/null 2>&1 | grep -E "(subject=|issuer=)" | head -2

# Postfix
echo "3. Postfix SMTPS (porta 465):"
timeout 3 openssl s_client -connect localhost:465 </dev/null 2>&1 | grep -E "(subject=|issuer=)" | head -2

# LDAPS
echo "4. LDAP (porta 636):"
timeout 3 openssl s_client -connect localhost:636 </dev/null 2>&1 | grep -E "(subject=|issuer=)" | head -2

# PostgreSQL
echo "5. PostgreSQL (porta 5432):"
sudo -u postgres psql -c "SHOW ssl;" 2>/dev/null

# Cockpit
echo "6. Cockpit (porta 9090):"
timeout 3 openssl s_client -connect localhost:9090 </dev/null 2>&1 | grep -E "(subject=|issuer=)" | head -2

# Rastreamento certmonger
echo ""
echo "7. Certificados rastreados certmonger:"
sudo getcert list | grep -c "Request ID"
echo "total certificados rastreados"

echo ""
echo "=== Verificação Completa ==="
```

---

## 20.11 Referências Rápidas Específicas por Serviço

### Cockpit

```bash
# Instalar: dnf install cockpit
# Localização cert: /etc/cockpit/ws-certs.d/
# Formato: Cert+chave combinados
# Recarregar: systemctl restart cockpit.socket
# Testar: https://server:9090/
```

### OpenVPN

```bash
# Instalar: dnf install openvpn (EPEL)
# Localização cert: /etc/openvpn/server/
# Arquivos: ca.crt, server.crt, server.key
# Iniciar: systemctl start openvpn-server@server
# Testar: openvpn --config client.ovpn
```

### strongSwan

```bash
# Instalar: dnf install strongswan
# Localização cert: /etc/strongswan/ipsec.d/
# Subdirs: cacerts/, certs/, private/
# Iniciar: systemctl start strongswan
# Testar: swanctl --list-sas
```

### HAProxy

```bash
# Instalar: dnf install haproxy
# Formato cert: PEM Combinado (cert+chave+cadeia)
# Localização: /etc/haproxy/certs/
# Config: bind *:443 ssl crt /path/to/bundle.pem
# Testar: curl -v https://loadbalancer/
```

### Registro Container

```bash
# Executar: podman run -d -p 5000:5000 registry:2
# Certs: Montar como volumes (-v)
# Env vars: REGISTRY_HTTP_TLS_CERTIFICATE
#           REGISTRY_HTTP_TLS_KEY
# Testar: curl https://registry:5000/v2/_catalog
```

---

## 20.12 Certificados Wildcard para Múltiplos Serviços

### Quando Usar Wildcards

**Cenário:** Múltiplos subdomínios no mesmo servidor

```
web.example.com    → Apache
api.example.com    → NGINX
admin.example.com  → Cockpit
mail.example.com   → Postfix
```

**Solução:** Usar certificado wildcard `*.example.com`

### Gerar Certificado Wildcard

```bash
#============================================#
# CERTIFICADO WILDCARD
#============================================#

# Gerar chave
openssl genpkey -algorithm RSA -out wildcard.key -pkeyopt rsa_keygen_bits:2048

# Gerar CSR
openssl req -new -key wildcard.key -out wildcard.csr \
  -subj "/CN=*.example.com" \
  -addext "subjectAltName=DNS:*.example.com,DNS:example.com"

# Submeter para CA, receber wildcard.crt

# Usar para múltiplos serviços
sudo cp wildcard.crt /etc/pki/tls/certs/
sudo cp wildcard.key /etc/pki/tls/private/
sudo chmod 600 /etc/pki/tls/private/wildcard.key

# Configurar cada serviço para usá-lo
# Apache: SSLCertificateFile /etc/pki/tls/certs/wildcard.crt
# NGINX: ssl_certificate /etc/pki/tls/certs/wildcard.crt
# Postfix: smtpd_tls_cert_file = /etc/pki/tls/certs/wildcard.crt
```

**Prós:**
- ✅ Um certificado para múltiplos subdomínios
- ✅ Gerenciamento mais fácil
- ✅ Cost-effective (se comprando)

**Contras:**
- ⚠️ Se comprometido, afeta todos subdomínios
- ⚠️ Não funciona para multi-nível (*.*.example.com)
- ⚠️ Algumas políticas segurança proíbem wildcards

---

## 20.13 Matriz Certificados Serviço

### Requisitos Certificado por Serviço

| Serviço | CN/SAN | Cert Cliente | Auto-Renov | Notas Especiais |
|---------|--------|--------------|------------|-----------------|
| **Apache** | Requerido | Opcional (mTLS) | certmonger | Mais comum |
| **NGINX** | Requerido | Opcional (mTLS) | certmonger | Alto desempenho |
| **Postfix** | Requerido | Opcional | certmonger | SMTP/SMTPS |
| **OpenLDAP** | Requerido | Opcional | certmonger | Deve ser legível usuário ldap |
| **PostgreSQL** | Requerido | Opcional | Manual ou script | Propriedade usuário postgres |
| **MySQL** | Requerido | Opcional | Manual ou script | Propriedade usuário mysql |
| **FreeIPA** | Automático | N/A | Automático | Auto-gerenciado |
| **Cockpit** | Requerido | Não | certmonger | Arquivo cert+chave combinado |
| **OpenVPN** | Requerido | Requerido | Manual | PKI complexa |
| **strongSwan** | Requerido | Requerido | Manual | IPsec específico |
| **HAProxy** | Requerido | Não | certmonger | Formato PEM combinado |
| **Registry** | Requerido | Opcional | Manual | Container específico |

---

## 20.14 Guia Rápido Solução de Problemas

### Solução de Problemas TLS Serviço Genérico

```bash
#============================================#
# SOLUÇÃO DE PROBLEMAS TLS UNIVERSAL
#============================================#

# 1. Identificar serviço e porta
ss -tlnp | grep <serviço>

# 2. Verificar se TLS está habilitado
# (comando específico serviço)

# 3. Testar conexão TLS
openssl s_client -connect localhost:<porta>
# Ou com STARTTLS:
openssl s_client -connect localhost:<porta> -starttls <protocolo>

# 4. Verificar arquivos certificado
ls -lZ /path/to/certs/

# 5. Verificar propriedade/permissões
# - Certificado: 644, propriedade usuário serviço
# - Chave: 600, propriedade usuário serviço

# 6. Verificar configuração
# (arquivo config específico serviço)

# 7. Verificar logs
sudo journalctl -u <serviço> | grep -i tls
sudo tail -f /var/log/<serviço>/ | grep -i tls

# 8. Testar de cliente remoto
openssl s_client -connect server.example.com:<porta>
```

---

## 20.15 Gerenciamento Certificado Centralizado

### Usando certmonger para Todos Serviços

```bash
#============================================#
# ESTRATÉGIA GERENCIAMENTO CERTIFICADO CENTRAL
#============================================#

# Rastrear todos certificados serviço com certmonger

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

# Monitorar todos
sudo getcert list
```

**Benefícios:**
- ✅ Ferramenta única para todos serviços
- ✅ Renovação automática
- ✅ Monitoramento centralizado
- ✅ Abordagem consistente

---

## 20.16 Conclusões Chave

1. **Muitos serviços usam certificados** além de apenas servidores web
2. **Cada serviço tem requisitos únicos** - Verificar propriedade, permissões
3. **certmonger funciona com maioria** serviços para automatização
4. **Certificados wildcard** podem simplificar setups multi-serviço
5. **Testar cada serviço** independentemente
6. **Rastreamento centralizado** com certmonger recomendado
7. **Documentar configurações** específicas serviço

---

## Cartão de Referência Rápida

```
┌───────────────────────────────────────────────────────────────┐
│ REFERÊNCIA RÁPIDA CERTIFICADOS OUTROS SERVIÇOS                │
├───────────────────────────────────────────────────────────────┤
│ Cockpit:     /etc/cockpit/ws-certs.d/NN-name.cert             │
│              (cert+chave combinados)                          │
│                                                               │
│ OpenVPN:     /etc/openvpn/server/{ca,server}.{crt,key}        │
│              PKI complexa com certs cliente                   │
│                                                               │
│ strongSwan:  /etc/strongswan/ipsec.d/{cacerts,certs,private}/ │
│              Configuração IPsec-específica                    │
│                                                               │
│ HAProxy:     PEM Combinado (cert+chave+cadeia em um arquivo)  │
│              /etc/haproxy/certs/bundle.pem                    │
│                                                               │
│ Registry:    Variáveis ambiente para container                │
│              REGISTRY_HTTP_TLS_CERTIFICATE/KEY                │
│                                                               │
│ Genérico:    Verificar propriedade, permissões, SELinux       │
│              Testar com: openssl s_client -connect :porta     │
└───────────────────────────────────────────────────────────────┘

✅ Usar certmonger para automatização onde possível
✅ Cada serviço tem requisitos únicos formato/localização arquivo
```
---

**Navegação do Capítulo**

| [← Anterior: Capítulo 19 - Serviços de Certificados do FreeIPA](19-freeipa-services.md) | [Próximo: Capítulo 21 - Melhores Práticas de Certificados de Serviço →](21-service-best-practices.md) |
|:---|---:|
