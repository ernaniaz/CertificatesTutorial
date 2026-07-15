# Capítulo 9: Gerenciamento de Certificados no RHEL 7

> **Legado mas Importante:** RHEL 7 alcançou fim de manutenção em junho 2024, mas muitas empresas ainda executam. Aprenda como gerenciamento de certificados funciona no RHEL 7.

---

## 9.1 Visão Geral RHEL 7

**Lançamento:** 10 de junho de 2014
**Suporte Manutenção Terminou:** 30 de junho de 2024
**Extended Life Cycle Support:** Disponível até 2028

**Características Chave:**
- **Versão OpenSSL:** 1.0.2k-26 (pacote: `openssl-1.0.2k-26.el7_9.x86_64`)
- **TLS Padrão:** TLS 1.0, 1.1, 1.2 todos habilitados
- **Repositório de Confiança:** `/etc/pki/ca-trust/extracted/`
- **Abordagem Gerenciamento:** Primariamente manual
- **Crypto-Policies:** Não disponíveis (recurso RHEL 8+)

> **Nota:** Se você ainda está no RHEL 7, planeje migração para RHEL 8 ou 9. Atualizações segurança são limitadas.

---

## 9.2 Especificações OpenSSL 1.0.2k

### Verificação Versão

```bash
# Verificar versão OpenSSL no RHEL 7
openssl version
# OpenSSL 1.0.2k-fips  12 Jan 2017

# Verificar pacote
rpm -q openssl
# openssl-1.0.2k-26.el7_9.x86_64
```

### Recursos Chave e Limitações

**Recursos:**
- ✅ Suporte TLS 1.0, 1.1, 1.2
- ✅ Estável e bem testado
- ✅ Compatibilidade ampla
- ✅ Tipos chave RSA, ECC, DSA

**Limitações:**
- ❌ Sem suporte TLS 1.3
- ❌ Sintaxe comando antiga (genrsa vs genpkey)
- ❌ Cifras padrão mais fracas
- ❌ Suites cifra modernas limitadas

### Sintaxe Comando (Estilo RHEL 7)

```bash
#============================================#
# GERAR CHAVE RSA (RHEL 7)
#============================================#

# Estilo antigo (comum no RHEL 7)
openssl genrsa -out server.key 2048

# Com proteção passphrase
openssl genrsa -aes256 -out server.key 2048

# Remover passphrase da chave
openssl rsa -in server.key -out server-nopass.key


#============================================#
# GERAR CSR (RHEL 7)
#============================================#

# CSR básico
openssl req -new -key server.key -out server.csr

# Com subject especificado
openssl req -new -key server.key -out server.csr \
  -subj "/C=US/ST=State/L=City/O=Company/CN=server.example.com"

# ⚠️ Nota: SANs são mais difíceis de adicionar com OpenSSL RHEL 7
# Necessita arquivo config para SANs


#============================================#
# VER CERTIFICADO
#============================================#

# Detalhes completos
openssl x509 -in server.crt -noout -text

# Apenas expiração
openssl x509 -in server.crt -noout -dates

# Apenas subject
openssl x509 -in server.crt -noout -subject
```

---

## 9.3 Gerenciamento Repositório de Confiança no RHEL 7

### Adicionando CAs Customizadas

```bash
#============================================#
# ADICIONAR CA CUSTOMIZADA (RHEL 7)
#============================================#

# Passo 1: Copiar certificado CA para diretório anchors
sudo cp corporate-ca.crt /etc/pki/ca-trust/source/anchors/

# Passo 2: Atualizar repositório de confiança
sudo update-ca-trust extract

# Passo 3: Verificar
trust list | grep -i "corporate"

# Verificar aplicações usam
openssl verify -CAfile /etc/pki/tls/certs/ca-bundle.crt test-cert.crt
```

### Localizações Repositório de Confiança (RHEL 7)

```bash
/etc/pki/ca-trust/
├── source/
│   └── anchors/                   ← Adicionar CAs customizadas aqui
│
└── extracted/
    ├── pem/
    │   └── tls-ca-bundle.pem      ← OpenSSL, Python, Ruby
    ├── openssl/
    │   └── ca-bundle.trust.crt    ← OpenSSL específico
    └── java/
        └── cacerts                ← Aplicações Java
```

---

## 9.4 Configuração Serviço (Abordagem RHEL 7)

### Apache HTTPS no RHEL 7

```bash
#============================================#
# SETUP APACHE SSL/TLS (RHEL 7)
#============================================#

# Instalar Apache com SSL
sudo yum install httpd mod_ssl -y

# Gerar certificado e chave
sudo openssl genrsa -out /etc/pki/tls/private/server.key 2048
sudo openssl req -new -key /etc/pki/tls/private/server.key \
  -out /tmp/server.csr \
  -subj "/CN=$(hostname -f)"

# Obter certificado da CA (ou autoassinado para teste)
sudo openssl x509 -req -days 365 -in /tmp/server.csr \
  -signkey /etc/pki/tls/private/server.key \
  -out /etc/pki/tls/certs/server.crt

# Configurar Apache (/etc/httpd/conf.d/ssl.conf)
sudo vi /etc/httpd/conf.d/ssl.conf
# Definir:
#   SSLCertificateFile /etc/pki/tls/certs/server.crt
#   SSLCertificateKeyFile /etc/pki/tls/private/server.key
#
#   # Recomendado: Desabilitar versões TLS fracas
#   SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
#
#   # Recomendado: Apenas cifras fortes
#   SSLCipherSuite HIGH:!aNULL:!MD5:!3DES:!RC4

# Iniciar Apache
sudo systemctl enable httpd
sudo systemctl start httpd

# Testar
curl -vk https://localhost/
```

### NGINX no RHEL 7

```bash
#============================================#
# SETUP NGINX SSL/TLS (RHEL 7)
#============================================#

# Instalar NGINX (de EPEL)
sudo yum install epel-release -y
sudo yum install nginx -y

# Gerar certificado
sudo openssl genrsa -out /etc/pki/tls/private/nginx.key 2048
sudo openssl req -new -x509 -days 365 \
  -key /etc/pki/tls/private/nginx.key \
  -out /etc/pki/tls/certs/nginx.crt \
  -subj "/CN=$(hostname -f)"

# Configurar NGINX (/etc/nginx/nginx.conf)
# Adicionar ao bloco server:
#   listen 443 ssl;
#   ssl_certificate /etc/pki/tls/certs/nginx.crt;
#   ssl_certificate_key /etc/pki/tls/private/nginx.key;
#
#   # Recomendado
#   ssl_protocols TLSv1.2;
#   ssl_ciphers HIGH:!aNULL:!MD5;

# Iniciar NGINX
sudo systemctl enable nginx
sudo systemctl start nginx
```

---

## 9.5 Renovação Manual Certificado (RHEL 7)

**Sem crypto-policies, sem ferramentas automáticas - tudo é manual!**

### Processo Renovação

```bash
#============================================#
# PROCESSO RENOVAÇÃO MANUAL (RHEL 7)
#============================================#

# Passo 1: Verificar expiração (definir lembrete calendário)
openssl x509 -in /etc/pki/tls/certs/server.crt -noout -dates

# Passo 2: Gerar novo CSR (reusar chave existente)
openssl req -new -key /etc/pki/tls/private/server.key \
  -out /tmp/server-renewal.csr \
  -subj "/CN=server.example.com"

# Passo 3: Submeter CSR para CA

# Passo 4: Receber novo certificado da CA

# Passo 5: Backup certificado antigo
sudo cp /etc/pki/tls/certs/server.crt \
     /etc/pki/tls/certs/server.crt.$(date +%Y%m%d).old

# Passo 6: Instalar novo certificado
sudo cp new-server.crt /etc/pki/tls/certs/server.crt
sudo chmod 644 /etc/pki/tls/certs/server.crt

# Passo 7: Recarregar serviço
sudo systemctl reload httpd

# Passo 8: Testar
curl -v https://localhost/
openssl s_client -connect localhost:443
```

### Rastreamento Renovações Certificado

```bash
#============================================#
# CRIAR RASTREAMENTO RENOVAÇÃO (RHEL 7)
#============================================#

# Job cron para verificar expiração
cat > /etc/cron.weekly/check-cert-expiration << 'EOF'
#!/bin/bash
# Verificar certificados expirando em 60 dias

for cert in /etc/pki/tls/certs/*.crt; do
  [ -f "$cert" ] || continue

  if ! openssl x509 -in "$cert" -noout -checkend $((86400*60)); then
    echo "⚠️ $cert expira dentro de 60 dias!"
    echo "$cert" | mail -s "Certificado Expirando Em Breve" admin@example.com
  fi
done
EOF

chmod +x /etc/cron.weekly/check-cert-expiration
```

---

## 9.6 Problemas Comuns Certificado RHEL 7

### Problema 1: TLS 1.0/1.1 Depreciados

**Problema:** Clientes modernos rejeitam TLS 1.0/1.1

**Sintomas:**
```bash
curl: (35) error:14094410:SSL routines:ssl3_read_bytes:sslv3 alert handshake failure
```

**Correção:**
```bash
# Atualizar Apache para desabilitar versões TLS antigas
# /etc/httpd/conf.d/ssl.conf
SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1

# Reiniciar Apache
sudo systemctl restart httpd
```

### Problema 2: Cifras Fracas

**Problema:** Scans PCI/Segurança marcam cifras fracas

**Correção:**
```bash
# Apache: Usar apenas cifras fortes
# /etc/httpd/conf.d/ssl.conf
SSLCipherSuite HIGH:!aNULL:!MD5:!3DES:!RC4:!EXPORT
SSLHonorCipherOrder on

# Testar
openssl s_client -connect localhost:443 -cipher '3DES'
# Deveria falhar se 3DES está desabilitado
```

### Problema 3: SANs Faltando

**Problema:** Navegadores modernos requerem Subject Alternative Names

**Desafio RHEL 7:** SANs são mais difíceis de adicionar com OpenSSL 1.0.2

**Solução: Usar arquivo config**
```bash
# Criar config OpenSSL
cat > /tmp/san.cnf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]
CN = server.example.com

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = server.example.com
DNS.2 = www.example.com
IP.1 = 10.0.0.100
EOF

# Gerar CSR com SANs
openssl req -new -key server.key -out server.csr -config /tmp/san.cnf

# Verificar SANs no CSR
openssl req -in server.csr -noout -text | grep -A3 "Subject Alternative Name"
```

---

## 9.7 certmonger no RHEL 7

**Disponível:** Sim (versão básica)

```bash
#============================================#
# CERTMONGER NO RHEL 7
#============================================#

# Instalar
sudo yum install certmonger -y
sudo systemctl enable certmonger
sudo systemctl start certmonger

# Solicitar certificado do FreeIPA
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/web.crt \
  -k /etc/pki/tls/private/web.key \
  -K host/$(hostname -f)@REALM

# Listar certificados rastreados
sudo getcert list

# Verificar status certificado específico
sudo getcert list -f /etc/pki/tls/certs/web.crt

# Monitorar logs certmonger
sudo tail -f /var/log/messages | grep certmonger
```

**Limitações RHEL 7:**
- Sem suporte ACME (Let's Encrypt requer certbot manual)
- Saída status menos detalhada
- Menos opções comando post-save

---

## 9.8 Considerações Migração

### Quando Migrar do RHEL 7

**Você deveria migrar se:**
- ✅ Suporte terminou (junho 2024) e você necessita atualizações
- ✅ Necessita suporte TLS 1.3
- ✅ Quer crypto-policies para gerenciamento mais fácil
- ✅ Requer recursos segurança modernos
- ✅ Conformidade requer SO suportado

### Tarefas Certificado Pré-Migração

```bash
#============================================#
# AUDITORIA CERTIFICADO PRÉ-MIGRAÇÃO RHEL 7
#============================================#

# 1. Listar todos certificados
find /etc/pki/tls/ -name "*.crt" -o -name "*.key"

# 2. Verificar expirações
for cert in /etc/pki/tls/certs/*.crt; do
  echo "=== $cert ==="
  openssl x509 -in "$cert" -noout -subject -dates
  echo ""
done

# 3. Verificar algoritmos assinatura (SHA-1 não funcionará no RHEL 8+)
for cert in /etc/pki/tls/certs/*.crt; do
  SIG=$(openssl x509 -in "$cert" -noout -text | grep "Signature Algorithm" | head -2)
  echo "$cert: $SIG"
done | grep -i sha1
# Se algum encontrado, reemitir antes migração!

# 4. Documentar CAs customizadas
ls -l /etc/pki/ca-trust/source/anchors/

# 5. Exportar certificados e chaves
tar czf rhel7-certificates-backup-$(date +%Y%m%d).tar.gz \
  /etc/pki/tls/certs/*.crt \
  /etc/pki/tls/private/*.key \
  /etc/pki/ca-trust/source/anchors/*
```

---

## 9.9 Fluxos de Trabalho Comuns RHEL 7

### Fluxo de Trabalho 1: Configuração Manual Apache HTTPS

```bash
# Workflow completo do zero

# 1. Instalar Apache com SSL
sudo yum install httpd mod_ssl -y

# 2. Gerar chave privada
sudo openssl genrsa -out /etc/pki/tls/private/$(hostname -s).key 2048

# 3. Definir permissões chave
sudo chmod 600 /etc/pki/tls/private/$(hostname -s).key

# 4. Criar CSR
sudo openssl req -new \
  -key /etc/pki/tls/private/$(hostname -s).key \
  -out /tmp/$(hostname -s).csr \
  -subj "/C=US/O=Company/CN=$(hostname -f)"

# 5. Submeter CSR para CA, aguardar certificado

# 6. Instalar certificado
sudo cp $(hostname -s).crt /etc/pki/tls/certs/

# 7. Configurar Apache
sudo vi /etc/httpd/conf.d/ssl.conf
# Editar:
#   SSLCertificateFile /etc/pki/tls/certs/$(hostname -s).crt
#   SSLCertificateKeyFile /etc/pki/tls/private/$(hostname -s).key
#   SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
#   SSLCipherSuite HIGH:!aNULL:!MD5:!3DES

# 8. Testar configuração
sudo apachectl configtest

# 9. Abrir firewall
sudo firewall-cmd --add-service=https --permanent
sudo firewall-cmd --reload

# 10. Iniciar Apache
sudo systemctl enable httpd
sudo systemctl start httpd

# 11. Testar
curl -vk https://$(hostname -f)/
```

### Fluxo de Trabalho 2: Integração FreeIPA

```bash
#============================================#
# WORKFLOW CERTIFICADO FREEIPA (RHEL 7)
#============================================#

# Pré-requisitos: Sistema deve estar registrado IPA
ipa-client-install

# Instalar certmonger
sudo yum install certmonger -y
sudo systemctl enable certmonger
sudo systemctl start certmonger

# Solicitar certificado para Apache
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/$(hostname -s).crt \
  -k /etc/pki/tls/private/$(hostname -s).key \
  -K host/$(hostname -f)@REALM.EXAMPLE.COM \
  -D $(hostname -f)

# Verificar status
sudo getcert list

# Aguardar status MONITORING (certificado emitido)

# Configurar Apache para usar cert
# /etc/httpd/conf.d/ssl.conf

# Recarregar Apache quando cert renova
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/$(hostname -s).crt \
  -k /etc/pki/tls/private/$(hostname -s).key \
  -K host/$(hostname -f)@REALM \
  -C "systemctl reload httpd"
```

---

## 9.10 Solução de Problemas Certificados RHEL 7

### Comandos Diagnóstico

```bash
#============================================#
# DIAGNÓSTICO CERTIFICADO RHEL 7
#============================================#

# Verificar versão OpenSSL
openssl version

# Testar HTTPS localmente
openssl s_client -connect localhost:443

# Verificar configuração SSL Apache
sudo apachectl -t -D DUMP_VHOSTS | grep 443

# Ver erros SSL Apache
sudo tail -f /var/log/httpd/ssl_error_log

# Verificar negações SELinux
sudo grep AVC /var/log/audit/audit.log | grep cert

# Verificar permissões arquivo
ls -lZ /etc/pki/tls/certs/*.crt
ls -lZ /etc/pki/tls/private/*.key

# Verificar par certificado/chave
openssl x509 -noout -modulus -in /etc/pki/tls/certs/server.crt | openssl md5
openssl rsa -noout -modulus -in /etc/pki/tls/private/server.key | openssl md5
# Hashes MD5 deveriam coincidir
```

### Erros Comuns RHEL 7

| Erro | Causa | Solução |
|------|-------|---------|
| "certificate verify failed" | CA faltando em repositório de confiança | Adicionar CA a /etc/pki/ca-trust/source/anchors/ |
| "permission denied" na chave | Permissões erradas | chmod 600 em arquivo .key |
| "certificate has expired" | Cert expirado | Renovar certificado manualmente |
| "no shared cipher" | Desajuste cipher cliente/servidor | Atualizar SSLCipherSuite |
| "wrong version number" | Desajuste versão TLS | Atualizar SSLProtocol |

---

## 9.11 Fortalecimento Segurança no RHEL 7

### Configuração Recomendada

```bash
#============================================#
# FORTALECIMENTO APACHE SSL/TLS (RHEL 7)
#============================================#

# /etc/httpd/conf.d/ssl.conf

# Desabilitar protocolos antigos
SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1

# Apenas cifras fortes
SSLCipherSuite ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!3DES:!DES

# Honrar preferência cipher servidor
SSLHonorCipherOrder on

# Habilitar HSTS (HTTP Strict Transport Security)
Header always set Strict-Transport-Security "max-age=31536000"

# OCSP Stapling (não disponível no OpenSSL 1.0.2 RHEL 7 por padrão)
# Disponível em alguns backports

# Perfect Forward Secrecy
SSLCipherSuite ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256
```

---

## 9.12 Caminho Migração para RHEL 8+

### Passos Migração Específicos Certificado

```bash
#============================================#
# PREPARAR CERTIFICADOS PARA MIGRAÇÃO
#============================================#

# 1. Verificar todos certificados usam SHA-256+ (sem SHA-1 nem MD5)
for cert in /etc/pki/tls/certs/*.crt; do
  openssl x509 -in "$cert" -noout -text | grep "Signature Algorithm"
done | grep -i sha1 && echo "⚠️ Certificados SHA-1 encontrados! Reemitir antes migração!"

# 2. Verificar tamanhos chave (2048+ bits)
for cert in /etc/pki/tls/certs/*.crt; do
  SIZE=$(openssl x509 -in "$cert" -noout -text | grep "Public-Key" | grep -oP '\d+')
  if [ "$SIZE" -lt 2048 ]; then
    echo "⚠️ $cert: Chave muito pequena ($SIZE bits)"
  fi
done

# 3. Backup de tudo
tar czf rhel7-certs-$(hostname)-$(date +%Y%m%d).tar.gz \
  /etc/pki/tls/ \
  /etc/pki/ca-trust/source/anchors/ \
  /etc/httpd/conf.d/ssl.conf \
  /etc/nginx/nginx.conf

# 4. Documentar inventário certificado
./generate-cert-inventory.sh > cert-inventory-pre-migration.csv

# 5. Testar compatibilidade TLS 1.2
# Garantir que todos serviços funcionam apenas com TLS 1.2
```

---

## 9.13 Quando RHEL 7 Faz Sentido

### Ainda Usando RHEL 7? Considere:

**Razões para Ficar (Temporariamente):**
- Contrato Extended Life Cycle Support ativo
- Aplicações legadas críticas requerendo TLS 1.0/1.1
- Migração planejada para futuro próximo
- Testando RHEL 8/9 em paralelo

**Razões para Migrar:**
- ✅ Manutenção estendida terminou junho 2024
- ✅ Sem crypto-policies (mais difícil gerenciar)
- ✅ Sem TLS 1.3
- ✅ Atualizações segurança limitadas
- ✅ Aplicações modernas abandonando suporte TLS 1.0/1.1

---

## 9.14 Conclusões Chave

1. **RHEL 7 é manual** - Sem crypto-policies, configuração cuidadosa necessária
2. **OpenSSL 1.0.2k** - Sintaxe antiga, sem TLS 1.3
3. **TLS 1.0/1.1 habilitados por padrão** - Desabilitá-los manualmente
4. **SHA-1 ainda funciona** - Mas não após migração para RHEL 8+
5. **certmonger disponível** - Mas básico comparado a RHEL 8+
6. **Planejar migração** - Suporte RHEL 7 está terminando
7. **Documentar tudo** - Torna migração mais fácil

---

## Referência Rápida

```
┌─────────────────────────────────────────────────────────┐
│ REFERÊNCIA RÁPIDA CERTIFICADO RHEL 7                    │
├─────────────────────────────────────────────────────────┤
│ OpenSSL:     1.0.2k-26                                  │
│ TLS:         1.0, 1.1, 1.2 (sem 1.3)                    │
│ Política:    Configuração manual (sem crypto-policies)  │
│                                                         │
│ Gerar:       openssl genrsa -out key.pem 2048           │
│ CSR:         openssl req -new -key key.pem -out req.csr │
│ Ver:         openssl x509 -in cert.crt -noout -text     │
│ Testar:      openssl s_client -connect host:443         │
│                                                         │
│ Fortalecer:  SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1     │
│              SSLCipherSuite HIGH:!aNULL:!MD5:!3DES      │
└─────────────────────────────────────────────────────────┘
```
---

**Navegação do Capítulo**

| [← Anterior: Capítulo 8 - Versões RHEL e Evolução dos Certificados](08-rhel-versions-overview.md) | [Próximo: Capítulo 10 - RHEL 8 e Crypto-Policies →](10-rhel8-crypto-policies.md) |
|:---|---:|
