# Capítulo 11: Segurança Moderna no RHEL 9

> **Padrão Moderno:** RHEL 9 representa o estado da arte atual em gerenciamento de certificados Linux com OpenSSL 3.x, crypto-policies aprimoradas, e padrões segurança mais rigorosos.

---

## 11.1 Visão Geral RHEL 9

**Lançamento:** 17 de maio de 2022
**Suporte Até:** 31 de maio de 2032
**Versão Atual:** RHEL 9.8

**Mudanças Principais do RHEL 8:**

| Recurso | RHEL 8 | RHEL 9 |
|---------|--------|--------|
| OpenSSL | 1.1.1k | **3.5.5** |
| Arquitetura | Tradicional | **Baseada em Provider** |
| TLS 1.0/1.1 | Política LEGACY | ❌ **Completamente removido** |
| Crypto-Policies | Básica | **Subpolíticas** |
| Validação | Padrão | **Mais Rigorosa** |
| SHA-1 | Depreciado | **Bloqueado** |
| certmonger | Aprimorado | **Fluxos nativos de IPA e rastreamento** |

**Pacote:** `openssl-3.5.5-2.el9_8.x86_64`

---

## 11.2 OpenSSL 3.5.5 - Mudanças Principais

### Arquitetura Provider (Novo!)

**O Que Mudou:**
OpenSSL 3.x introduziu sistema "provider" para diferentes implementações crypto.

```bash
#============================================#
# LISTAR PROVIDERS (RHEL 9)
#============================================#

openssl list -providers

# Saída:
# Providers:
#   default
#     name: OpenSSL Default Provider
#     version: 3.5.5
#     status: active
#
#   fips
#     name: OpenSSL FIPS Provider
#     version: 3.5.5
#     status: inactive (a menos que modo FIPS habilitado)
#
#   legacy
#     name: OpenSSL Legacy Provider
#     version: 3.5.5
#     status: inactive
#
#   base
#     name: OpenSSL Base Provider
#     version: 3.5.5
#     status: active
```

### Algoritmos Legados Requerem Provider Explícito

**Mudança Disruptiva:** MD5, Blowfish, CAST5 necessitam `-provider legacy`

```bash
#============================================#
# USANDO ALGORITMOS LEGADOS (RHEL 9)
#============================================#

# Isto FALHA no RHEL 9:
openssl md5 file.txt
# Erro: unsupported

# Isto FUNCIONA (provider explícito):
openssl md5 -provider legacy file.txt

# Por quê: Algoritmos legados desabilitados por padrão para segurança
```

### Geração Chave Moderna (RHEL 9)

```bash
#============================================#
# GERAR CHAVES (RHEL 9)
#============================================#

# RSA 2048 (padrão)
openssl genpkey -algorithm RSA -out server.key \
  -pkeyopt rsa_keygen_bits:2048

# RSA 4096 (mais forte)
openssl genpkey -algorithm RSA -out server.key \
  -pkeyopt rsa_keygen_bits:4096

# EC P-256 (elliptic curve, recomendado)
openssl genpkey -algorithm EC -out ec.key \
  -pkeyopt ec_paramgen_curve:P-256

# EC P-384 (mais forte)
openssl genpkey -algorithm EC -out ec.key \
  -pkeyopt ec_paramgen_curve:P-384


#============================================#
# GERAR CSR COM SANS (RHEL 9)
#============================================#

openssl req -new -key server.key -out server.csr \
  -subj "/C=US/ST=State/O=Company/CN=server.example.com" \
  -addext "subjectAltName=DNS:server.example.com,DNS:www.example.com,IP:10.0.0.100" \
  -addext "keyUsage=digitalSignature,keyEncipherment" \
  -addext "extendedKeyUsage=serverAuth,clientAuth"

# Verificar
openssl req -in server.csr -noout -text | grep -A5 "Subject Alternative Name"
```

---

## 11.3 Crypto-Policies Aprimoradas (RHEL 9)

### Subpolíticas (Novo Recurso!)

**RHEL 9 introduz modificadores política:**

```bash
#============================================#
# SUBPOLÍTICAS CRYPTO-POLICY (RHEL 9)
#============================================#

# Política base com módulo NO-SHA1
sudo update-crypto-policies --set DEFAULT:NO-SHA1

# Múltiplos módulos
sudo update-crypto-policies --set DEFAULT:NO-SHA1:GOST

# Subpolíticas comuns:
# - NO-SHA1: Desabilitar completamente SHA-1 (mesmo em assinaturas)
# - NO-ENFORCE-EMS: Desabilitar Extended Master Secret
# - GOST: Habilitar algoritmos GOST
# - NO-CAMELLIA: Desabilitar cifra Camellia

# Ver módulos disponíveis
ls /usr/share/crypto-policies/policies/modules/
```

### Módulos Crypto-Policy Customizados (RHEL 9)

```bash
#============================================#
# CRIAR MÓDULO POLÍTICA CUSTOMIZADO
#============================================#

# Criar módulo customizado
sudo vi /etc/crypto-policies/policies/modules/CUSTOM.pmod

# Conteúdo exemplo:
min_rsa_size = 3072
min_dh_size = 3072
min_dsa_size = 3072

# Aplicar
sudo update-crypto-policies --set DEFAULT:CUSTOM

# Testar
openssl ciphers -v | head
```

---

## 11.4 Validação Certificado Mais Rigorosa

### O Que É Mais Rigoroso no RHEL 9?

```bash
#============================================#
# EXEMPLOS VALIDAÇÃO MAIS RIGOROSA
#============================================#

# 1. Assinaturas SHA-1 completamente rejeitadas
openssl verify sha1-signed-cert.crt
# Erro: CA md too weak

# 2. Autoassinado sem trust CA apropriado rejeitado
curl https://self-signed.example.com/
# Erro: certificate verify failed

# 3. Cadeia certificado deve estar completa
# Intermediário faltando → conexão falha

# 4. Hostname deve coincidir (CN ou SAN)
openssl s_client -connect server.example.com:443 -servername different.example.com
# Erro verificação: hostname mismatch

# 5. Chaves < 2048 bits rejeitadas
# (mesmo em política LEGACY, < 1024 rejeitado)
```

### Impacto em Aplicações

**Aplicações compiladas contra OpenSSL 3.x:**
- Podem necessitar mudanças código se usando APIs depreciadas
- Tratamento erro pode ser diferente
- Código crypto customizado necessita teste

**Administradores sistema:**
- ✅ Maioria mudanças transparentes
- ✅ Comandos maioria iguais
- ⚠️ Validação mais rigorosa captura mais problemas (isto é bom!)

---

## 11.5 Automação no RHEL 9: certmonger, certbot e IdM ACME

### Use o cliente certo para a CA certa

```bash
#============================================#
# OPÇÕES DE AUTOMAÇÃO NO RHEL 9
#============================================#

# Fluxo nativo do certmonger para FreeIPA / IdM
sudo dnf install certmonger -y
sudo systemctl enable --now certmonger
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/internal.crt \
  -k /etc/pki/tls/private/internal.key \
  -K HTTP/$(hostname -f)@REALM \
  -D $(hostname -f) \
  -C "systemctl reload httpd"

# Fluxo público do Let's Encrypt
# Use certbot, não uma definição falsa de CA Let's Encrypt no certmonger.
sudo certbot certonly --apache -d web.example.com

# Fluxo IdM ACME (opcional)
# Isto aponta para o diretório ACME do seu servidor IPA, não para o Let's Encrypt.
sudo certbot certonly \
  --server https://ipa.example.com/acme/directory \
  -d host.example.com
```

**Importante:** IdM ACME e Let's Encrypt são CAs diferentes. `certmonger` continua sendo a ferramenta nativa do RHEL para IPA, CA local e fluxos de renovação com rastreamento.

---

## 11.6 Aprimoramentos Repositório de Confiança

### Gerenciamento Trust Avançado

```bash
#============================================#
# GERENCIAMENTO TRUST RHEL 9
#============================================#

# Adicionar CA (mesmo que RHEL 7/8)
sudo cp corporate-ca.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust

# NOVO: Trust específica por propósito
trust anchor /path/to/ca.crt --purpose server-auth

# Listar trust com detalhes
trust list --filter=ca-anchors

# Exportar CA específica
trust extract --format=pem-bundle --filter=ca-anchors \
  --purpose server-auth /tmp/server-cas.pem

# Remover trust específica
trust anchor --remove "pkcs11:id=%CERT_ID%"
```

---

## 11.7 Problemas Comuns RHEL 9 e Soluções

### Problema 1: Mudanças API OpenSSL 3.x

**Problema:** Aplicação customizada falha com erros OpenSSL

**Sintomas:**
```
Error: EVP_PKEY_RSA no longer supported
Error: Provider not available
```

**Solução:**
```bash
# Verificar se aplicação está usando APIs depreciadas
# Aplicação necessita recompilação contra OpenSSL 3.x

# Temporário: Definir variável ambiente compat (se disponível)
export OPENSSL_CONF=/etc/pki/tls/openssl-compat.cnf

# Longo prazo: Atualizar aplicação
```

### Problema 2: Certificados SHA-1 Rejeitados

**Problema:** Certificados legados com assinaturas SHA-1 falham

**Sintomas:**
```bash
openssl verify cert.crt
# error 3: CA md too weak
```

**Solução:**
```bash
# Reemitir certificado com SHA-256+
# Sem workaround - SHA-1 é bloqueado para segurança

# Verificar assinatura certificado
openssl x509 -in cert.crt -noout -text | grep "Signature Algorithm"
# Deve mostrar: sha256WithRSAEncryption ou melhor
```

### Problema 3: Algoritmo Legado Não Disponível

**Problema:** Aplicação necessita MD5/RC4/etc.

**Sintomas:**
```bash
openssl md5 file.txt
# Erro: unsupported
```

**Solução:**
```bash
# Usar provider legado explicitamente
openssl md5 -provider legacy file.txt

# Para aplicações: Atualizar para usar SHA-256+
# Ou configurar para carregar provider legado
```

---

## 11.8 Modo FIPS no RHEL 9

### Suporte FIPS Melhorado

```bash
#============================================#
# MODO FIPS (RHEL 9)
#============================================#

# Habilitar modo FIPS
sudo fips-mode-setup --enable
sudo reboot

# Verificar status FIPS
fips-mode-setup --check
# FIPS mode is enabled.

# Verificar provider FIPS carregado
openssl list -providers | grep -A3 fips
#   fips
#     name: OpenSSL FIPS Provider
#     version: 3.5.5
#     status: active

# Gerar certificado conforme FIPS
openssl req -new -x509 -days 365 -newkey rsa:2048 \
  -keyout fips.key -out fips.crt \
  -subj "/CN=$(hostname)" -provider fips
```

**FIPS RHEL 9:**
- Usa provider FIPS OpenSSL 3.x
- Módulos validados FIPS 140-2
- Transição para FIPS 140-3 em progresso

---

## 11.9 Migração do RHEL 8

### Impacto Certificado

**Impacto Moderado:**
- Mudanças API OpenSSL (afeta apps customizadas)
- Validação mais rigorosa (captura mais problemas)
- Algoritmos legados removidos
- SHA-1 completamente bloqueado

### Verificações Pré-Migração

```bash
#============================================#
# PRÉ-MIGRAÇÃO CERTIFICADO RHEL 8 → 9
#============================================#

# 1. Verificar por certificados SHA-1 (falharão no RHEL 9)
for cert in /etc/pki/tls/certs/*.crt; do
  SIG=$(openssl x509 -in "$cert" -noout -text | grep "Signature Algorithm" | head -2)
  echo "$cert: $SIG"
done | grep -i sha1
# ⚠️ Reemitir quaisquer certs SHA-1 antes migração!

# 2. Verificar aplicações customizadas usando OpenSSL
rpm -qa | grep -E "custom|local"
# Testar estas aplicações em ambiente RHEL 9

# 3. Verificar compatibilidade crypto-policy
update-crypto-policies --show

# 4. Testar operações certificado
openssl s_client -connect localhost:443

# 5. Backup de tudo
tar czf rhel8-certs-backup-$(date +%Y%m%d).tar.gz \
  /etc/pki/tls/ \
  /etc/pki/ca-trust/source/anchors/
```

---

## 11.10 Melhores Práticas para RHEL 9

### Configuração Recomendada

```bash
#============================================#
# SETUP RECOMENDADO (RHEL 9)
#============================================#

# 1. Usar crypto-policy DEFAULT (a menos que necessidade específica)
sudo update-crypto-policies --set DEFAULT

# 2. Usar certmonger para automação nativa
sudo dnf install certmonger
sudo systemctl enable --now certmonger

# 3. Para sites públicos: usar certbot com Let's Encrypt
sudo certbot certonly --apache -d web.example.com

# 4. Para interno: usar FreeIPA com certmonger
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/internal.crt \
  -k /etc/pki/tls/private/internal.key \
  -K host/$(hostname -f)@REALM

# 5. Gerar chaves EC (menores, mais rápidas)
openssl genpkey -algorithm EC -out ec.key \
  -pkeyopt ec_paramgen_curve:P-256

# 6. Sempre usar SANs
openssl req -new -addext "subjectAltName=DNS:..."
```

---

## 11.11 Novos Recursos Que Você Deveria Usar

### Recurso 1: Fluxos mais fortes de certmonger + IPA

```bash
# Automação nativa do RHEL para certificados internos
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/internal.crt \
  -k /etc/pki/tls/private/internal.key \
  -K HTTP/$(hostname -f)@REALM \
  -D $(hostname -f) \
  -C "systemctl reload httpd"

# Melhor saída de status no RHEL 9
sudo getcert list -v
```

### Recurso 2: Relatório Status Aprimorado

```bash
# Status mais detalhado
sudo getcert list -v

# Melhores mensagens erro
sudo getcert list -f /etc/pki/tls/certs/web.crt
# Mostra razão erro exata se renovação falha
```

### Recurso 3: Subpolíticas Crypto-Policy

```bash
# Ajuste fino política DEFAULT
sudo update-crypto-policies --set DEFAULT:NO-SHA1

# Múltiplos modificadores
sudo update-crypto-policies --set FUTURE:AD-SUPPORT
```

---

## 11.12 Mudanças Disruptivas do RHEL 8

### Mudanças API

**Se você tem aplicações customizadas:**

```c
// RHEL 8 (OpenSSL 1.1.1) - DEPRECIADO no RHEL 9:
RSA *rsa = RSA_new();

// RHEL 9 (OpenSSL 3.x) - NOVA API:
EVP_PKEY *pkey = EVP_PKEY_new();
```

**Impacto:** Aplicações compiladas customizadas podem necessitar atualizações

### Mudanças Comando

```bash
# Maioria comandos funcionam iguais, mas alguns casos extremos:

# RHEL 8: Isto funciona
openssl md5 file.txt

# RHEL 9: Requer provider
openssl md5 -provider legacy file.txt

# Solução: Usar SHA-256 ao invés
openssl sha256 file.txt
```

---

## 11.13 Cenários Comuns RHEL 9

### Cenário 1: Configuração Fresh Apache HTTPS RHEL 9

```bash
#============================================#
# SETUP COMPLETO APACHE HTTPS (RHEL 9)
#============================================#

# 1. Instalar Apache com mod_ssl
sudo dnf install httpd mod_ssl -y

# 2. Usar certmonger + FreeIPA / IdM
sudo dnf install certmonger -y
sudo systemctl enable --now certmonger

# 3. Solicitar certificado
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/web.crt \
  -k /etc/pki/tls/private/web.key \
  -K HTTP/$(hostname -f)@REALM \
  -D $(hostname -f) \
  -C "systemctl reload httpd"

# 4. Aguardar certificado (verificar status)
sudo getcert list

# 5. Configurar Apache para usar certificado
# /etc/httpd/conf.d/ssl.conf já aponta para:
#   SSLCertificateFile /etc/pki/tls/certs/localhost.crt
# Atualizar para:
#   SSLCertificateFile /etc/pki/tls/certs/web.crt
#   SSLCertificateKeyFile /etc/pki/tls/private/web.key

# 6. Crypto-policy lida com configurações TLS automaticamente!
# Sem necessidade definir SSLProtocol ou SSLCipherSuite

# 7. Abrir firewall
sudo firewall-cmd --add-service=https --permanent
sudo firewall-cmd --reload

# 8. Iniciar Apache
sudo systemctl enable httpd
sudo systemctl start httpd

# 9. Testar
curl -v https://$(hostname -f)/

# 10. Renovação automática acontece bem antes da expiração!
```

**Resultado:** HTTPS interno totalmente automatizado com FreeIPA e certmonger!

---

## 11.14 Solução de Problemas Certificados RHEL 9

### Comandos Diagnóstico

```bash
#============================================#
# DIAGNÓSTICO CERTIFICADO RHEL 9
#============================================#

# Verificar versão OpenSSL
openssl version
# OpenSSL 3.5.5

# Verificar providers
openssl list -providers

# Verificar crypto-policy
update-crypto-policies --show

# Testar conexão com TLS 1.3
openssl s_client -connect server:443 -tls1_3

# Verificar algoritmo assinatura certificado
openssl x509 -in cert.crt -noout -text | grep "Signature Algorithm"
# Deve ser SHA-256+ no RHEL 9

# Testar com provider legado (se necessário)
openssl md5 -provider legacy file.txt

# Verificar rastreamento certmonger
sudo getcert list

# Ver logs certmonger
sudo journalctl -u certmonger -f
```

### Erros Comuns RHEL 9

| Erro | Causa | Solução |
|------|-------|---------|
| "CA md too weak" | Assinatura SHA-1 | Reemitir com SHA-256+ |
| "Provider not available" | Algoritmo legado usado | Adicionar `-provider legacy` ou atualizar para algoritmo moderno |
| "unsupported" em comando openssl | Algoritmo desabilitado | Usar alternativa moderna ou provider legado |
| "no shared cipher" (app migrada) | Cliente usa cifras antigas | Atualizar cliente ou usar política LEGACY temporariamente |
| "certificate verify failed" | Validação mais rigorosa | Verificar cadeia cert, SANs, expiração |

---

## 11.15 Quando Usar RHEL 9

### Ideal Para:

✅ **Novas implantações** - Começar com segurança moderna
✅ **Ambientes focados segurança** - Padrões mais rigorosos
✅ **Aplicações modernas** - Beneficiar de TLS 1.3
✅ **Suporte longo prazo** - 10 anos manutenção
✅ **Requisitos conformidade** - Padrões segurança modernos

### Timing Migração:

**Do RHEL 7:**
- ✅ Sim! Manutenção RHEL 7 terminou junho 2024
- Planejar cuidadosamente - grande salto (testar completamente)

**Do RHEL 8:**
- Moderado - OpenSSL 3.x é mudança principal
- Testar aplicações customizadas primeiro
- Certificados SHA-1 devem ser reemitidos

---

## 11.16 Conclusões Chave

1. **Arquitetura provider OpenSSL 3.5.5** - Entender providers
2. **Validação mais rigorosa** - Captura problemas segurança (bom!)
3. **SHA-1 completamente bloqueado** - Reemitir certificados antigos
4. **Subpolíticas crypto-policy** - Ajustar fino segurança
5. **certmonger continua valioso** para IPA e fluxos de renovação com rastreamento
6. **Suporte TLS 1.3 obrigatório** - Mais rápido, mais seguro
7. **Planejar teste** - Apps customizadas podem necessitar atualizações

---

## Referência Rápida

```
┌──────────────────────────────────────────────────────────────┐
│ REFERÊNCIA RÁPIDA CERTIFICADO RHEL 9                         │
├──────────────────────────────────────────────────────────────┤
│ OpenSSL:        3.5.5 (arquitetura provider)                 │
│ TLS:            1.2, 1.3 (1.0/1.1 removidos completamente)   │
│ Recurso:        Subpolíticas, validação mais rigorosa        │
│                                                              │
│ Providers:      openssl list -providers                      │
│ Política:       update-crypto-policies --show                │
│ Subpolítica:    update-crypto-policies --set DEFAULT:NO-SHA1 │
│                                                              │
│ Gerar chave:    openssl genpkey -algorithm RSA -out key.pem  │
│ Chave EC:       openssl genpkey -algorithm EC -out ec.pem    │
│                 -pkeyopt ec_paramgen_curve:P-256             │
│                                                              │
│ ACME público:   certbot certonly --apache -d example.com     │
│ certmonger:     ipa-getcert request ...                      │
│ Algo legado:    openssl md5 -provider legacy file.txt        │
└──────────────────────────────────────────────────────────────┘

⚠️ SHA-1 está BLOQUEADO - reemitir certificados antigos!
✅ Usar certmonger para IPA e automação com rastreamento
✅ Política DEFAULT funciona para maioria casos
```
---

**Navegação do Capítulo**

| [← Anterior: Capítulo 10 - RHEL 8 e Crypto-Policies](10-rhel8-crypto-policies.md) | [Próximo: Capítulo 12 - Recursos Atuais do RHEL 10 →](12-rhel10-current.md) |
|:---|---:|
