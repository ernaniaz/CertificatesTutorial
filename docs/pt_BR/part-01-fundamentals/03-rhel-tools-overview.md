# Capítulo 3: Visão Geral das Ferramentas de Certificados do RHEL

> **Objetivo de Aprendizagem:** Familiarize-se com as ferramentas essenciais para gerenciar certificados no RHEL para que você saiba qual ferramenta usar para cada tarefa.

---

## 3.1 Sua Caixa de Ferramentas de Certificados

Ao trabalhar com certificados no RHEL, você usará estas ferramentas principais:

| Ferramenta | Uso Principal | Versões RHEL | Quando Usar |
|------------|---------------|--------------|-------------|
| **openssl** | Operações de certificados, testes | Todas | Gerar chaves/CSRs, inspecionar certs, testar conexões |
| **certutil** | Gerenciamento de base de dados NSS | Todas | BDs de cert estilo Firefox/Mozilla |
| **update-ca-trust** | Gerenciamento de repositório de confiança | Todas | Adicionar/remover CAs confiáveis |
| **certmonger** | Renovação automática | Todas | Rastrear e renovar certificados automaticamente |
| **crypto-policies** | Segurança em todo o sistema | RHEL 8+ | Controlar versões TLS e cifras |
| **getcert** | CLI do certmonger | Todas | Solicitar e gerenciar certs rastreados |
| **trust** | Gerenciamento de confiança P11-kit | Todas (aprimorado RHEL 8+) | Operações avançadas de confiança |

---

## 3.2 OpenSSL - O Canivete Suíço

**Disponível:** Todas as versões RHEL
**Pacote:** `openssl`

### Diferenças de Versão

```bash
# Verificar sua versão
openssl version

# RHEL 7: OpenSSL 1.0.2k-26
# RHEL 8: OpenSSL 1.1.1k-14
# RHEL 9: OpenSSL 3.5.5-2
# RHEL 10: OpenSSL 3.5.5-2
```

### Usos Comuns

```bash
#============================================#
# INSPECIONAR CERTIFICADOS
#============================================#

# Ver detalhes do certificado
openssl x509 -in cert.crt -noout -text

# Verificar expiração
openssl x509 -in cert.crt -noout -dates
openssl x509 -in cert.crt -noout -checkend 86400  # Verificar se expira em 24h

# Ver assunto do certificado
openssl x509 -in cert.crt -noout -subject -issuer


#============================================#
# GERAR CHAVES
#============================================#

# Estilo RHEL 7 (ainda funciona em todas as versões)
openssl genrsa -out server.key 2048

# Estilo moderno RHEL 8+ (recomendado)
openssl genpkey -algorithm RSA -out server.key -pkeyopt rsa_keygen_bits:2048

# Chave EC RHEL 9+ (curva elíptica)
openssl genpkey -algorithm EC -out ec.key -pkeyopt ec_paramgen_curve:P-256


#============================================#
# CRIAR CSR (Solicitação de Assinatura de Certificado)
#============================================#

# CSR básico
openssl req -new -key server.key -out server.csr \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=server.example.com"

# CSR com SANs (requerido para navegadores modernos!)
openssl req -new -key server.key -out server.csr \
  -subj "/CN=server.example.com" \
  -addext "subjectAltName=DNS:server.example.com,DNS:www.example.com"


#============================================#
# TESTAR CONEXÕES
#============================================#

# Testar HTTPS
openssl s_client -connect server.example.com:443 -servername server.example.com

# Testar versão TLS específica
openssl s_client -connect server.example.com:443 -tls1_2
openssl s_client -connect server.example.com:443 -tls1_3

# Testar LDAPS
openssl s_client -connect ldap.example.com:636

# Testar SMTP com STARTTLS
openssl s_client -connect mail.example.com:25 -starttls smtp
```

### Diferenças Específicas por Versão

**RHEL 7 (OpenSSL 1.0.2k):**
- ✅ Estável e bem testado
- ❌ Sem suporte TLS 1.3
- ❌ Sintaxe de comando mais antiga

**RHEL 8 (OpenSSL 1.1.1k):**
- ✅ Suporte TLS 1.3
- ✅ Sintaxe de comando moderna
- ✅ Melhores padrões

**RHEL 9/10 (OpenSSL 3.5.5):**
- ✅ Arquitetura de provedores
- ✅ Suporte FIPS aprimorado
- ⚠️ Mudanças na API (afeta apps personalizadas)
- ⚠️ Algoritmos legados requerem `-provider legacy`

---

## 3.3 certutil - Ferramenta de Base de Dados NSS

**Disponível:** Todas as versões RHEL
**Pacote:** `nss-tools`

Usado para bases de dados de certificados estilo Mozilla/Firefox.

### Usos Comuns

```bash
#============================================#
# GERENCIAR BASE DE DADOS NSS
#============================================#

# Criar nova base de dados
certutil -N -d /etc/pki/nssdb

# Listar certificados
certutil -L -d /etc/pki/nssdb

# Adicionar certificado CA
certutil -A -n "My CA" -t "CT,C,C" -d /etc/pki/nssdb -i ca.crt

# Deletar certificado
certutil -D -n "Certificate Name" -d /etc/pki/nssdb

# Exportar certificado
certutil -L -n "Certificate Name" -d /etc/pki/nssdb -a > exported.crt
```

### Quando Usar certutil

- Gerenciar certificados Firefox/Thunderbird
- Trabalhar com aplicações que usam NSS (muitos serviços Red Hat)
- Quando você vê arquivos `.db` em `/etc/pki/nssdb/`

---

## 3.4 update-ca-trust - Gerenciamento de Repositório de Confiança

**Disponível:** Todas as versões RHEL
**Pacote:** `ca-certificates` (instalado por padrão)

Gerencia quais Autoridades Certificadoras (CAs) seu sistema confia.

### Como Funciona

```
Suas CAs Personalizadas
  ↓
/etc/pki/ca-trust/source/anchors/
  ↓
update-ca-trust extract
  ↓
/etc/pki/ca-trust/extracted/
  ├── pem/tls-ca-bundle.pem       (OpenSSL/Python/Ruby)
  ├── openssl/ca-bundle.trust.crt (Específico OpenSSL)
  └── java/cacerts                (Aplicações Java)
```

### Usos Comuns

```bash
#============================================#
# ADICIONAR CA PERSONALIZADA
#============================================#

# Passo 1: Copiar certificado CA
sudo cp corporate-ca.crt /etc/pki/ca-trust/source/anchors/

# Passo 2: Atualizar repositório de confiança
sudo update-ca-trust extract

# É isso! Agora todas as aplicações confiam nesta CA


#============================================#
# REMOVER/BLOQUEAR CA (RHEL 8+)
#============================================#

# Bloquear uma CA comprometida
sudo cp compromised-ca.crt /etc/pki/ca-trust/source/blacklist/
sudo update-ca-trust extract


#============================================#
# VERIFICAR CONFIANÇA
#============================================#

# Verificar se certificado é confiável
openssl verify /path/to/cert.crt

# Listar todas as CAs confiáveis
trust list | grep "certificate-authority"

# Procurar CA específica
trust list | grep -i "Let's Encrypt"
```

### Diretórios Chave

```
/etc/pki/ca-trust/
├── source/
│   ├── anchors/          ← Adicione suas CAs confiáveis aqui
│   └── blacklist/        ← CAs na lista negra (RHEL 8+)
└── extracted/
    ├── pem/              ← Usado pela maioria das apps
    ├── openssl/          ← Específico OpenSSL
    └── java/             ← Aplicações Java
```

---

## 3.5 certmonger - Renovação Automática de Certificados

**Disponível:** Todas as versões RHEL
**Pacote:** `certmonger`

A ferramenta "configure e esqueça" para certificados.

### O Que Faz

certmonger:
- Rastreia datas de expiração de certificados
- Renova automaticamente antes de expirar
- Funciona com múltiplas CAs (IPA, Let's Encrypt, externa)
- Executa comandos pós-renovação (ex: reiniciar serviços)

### Fluxo de Trabalho Básico

```bash
#============================================#
# INSTALAÇÃO
#============================================#

sudo dnf install certmonger
sudo systemctl enable --now certmonger


#============================================#
# SOLICITAR CERTIFICADO
#============================================#

# De FreeIPA
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/web.crt \
  -k /etc/pki/tls/private/web.key \
  -D web.example.com \
  -K host/web.example.com@REALM

# Autoassinado (para testes)
sudo getcert request \
  -f /etc/pki/tls/certs/test.crt \
  -k /etc/pki/tls/private/test.key


#============================================#
# MONITORAR CERTIFICADOS
#============================================#

# Listar todos os certificados rastreados
sudo getcert list

# Verificar certificado específico
sudo getcert list -f /etc/pki/tls/certs/web.crt

# Observar renovação
sudo journalctl -u certmonger -f
```

### Recursos Chave por Versão

**RHEL 7:**
- Rastreamento e renovação básicos
- Integração IPA
- Configuração manual

**RHEL 8:**
- Integração IPA aprimorada
- Melhor relatório de erros
- Comandos pós-salvamento

**RHEL 9:**
- Suporte ACME (Let's Encrypt!)
- Monitoramento aprimorado
- Melhor relatório de status

```bash
# RHEL 9 - Integração Let's Encrypt
sudo getcert request \
  -f /etc/pki/tls/certs/acme.crt \
  -k /etc/pki/tls/private/acme.key \
  -D example.com \
  -c acme-letsencrypt \
  -C "systemctl reload httpd"
```

---

## 3.6 crypto-policies - Segurança em Todo o Sistema (RHEL 8+)

**Disponível:** Apenas RHEL 8, 9, 10
**Pacote:** `crypto-policies` (instalado por padrão)

**MUDANÇA DE JOGO:** Controle versões TLS, cifras e tamanhos de chave em todo o sistema!

### A Grande Ideia

Em vez de configurar cada aplicação individualmente:

```
❌ FORMA ANTIGA (RHEL 7):
- Configurar cifras SSL do Apache
- Configurar cifras SSL do NGINX
- Configurar ajustes TLS do Postfix
- Configurar ajustes TLS do OpenLDAP
- Configurar cada aplicação...

✅ FORMA NOVA (RHEL 8+):
- Definir UMA política do sistema
- Todas as aplicações seguem automaticamente!
```

### Políticas Disponíveis

```bash
# Verificar política atual
update-crypto-policies --show

# Políticas:
# DEFAULT  - Segurança equilibrada (TLS 1.2+, RSA 2048+)
# LEGACY   - Modo de compatibilidade (permite TLS 1.0/1.1)
# FUTURE   - Segurança mais rigorosa (TLS 1.2+, RSA 3072+)
# FIPS     - Modo de conformidade federal
```

### Comparação de Políticas

| Característica | LEGACY | DEFAULT | FUTURE | FIPS |
|----------------|--------|---------|--------|------|
| TLS 1.0/1.1 | ✅ Permitido | ❌ Bloqueado | ❌ Bloqueado | ❌ Bloqueado |
| TLS 1.2 | ✅ Sim | ✅ Sim | ✅ Sim | ✅ Sim |
| TLS 1.3 | ✅ Sim | ✅ Sim | ✅ Sim | ✅ Sim |
| RSA Mín | 1024 bits | 2048 bits | 3072 bits | 2048 bits |
| Assinaturas SHA-1 | ⚠️ Permitido | ❌ Bloqueado | ❌ Bloqueado | ❌ Bloqueado |
| Cifra 3DES | ⚠️ Permitido | ❌ Bloqueado | ❌ Bloqueado | ❌ Bloqueado |

### Usos Comuns

```bash
#============================================#
# MUDAR POLÍTICA
#============================================#

# Definir política FUTURE (mais rigorosa)
sudo update-crypto-policies --set FUTURE
# Reiniciar ou reiniciar serviços

# Usar temporariamente LEGACY (para sistemas antigos)
sudo update-crypto-policies --set LEGACY
# Nota: LEGACY deve ser temporário!


#============================================#
# POLÍTICAS PERSONALIZADAS (RHEL 9+)
#============================================#

# Subpolíticas - modificar política existente
sudo update-crypto-policies --set DEFAULT:NO-SHA1
sudo update-crypto-policies --set FUTURE:AD-SUPPORT


#============================================#
# RESOLVER PROBLEMAS DE POLÍTICA
#============================================#

# Se serviço falha após mudança de política:
# 1. Verificar política atual
update-crypto-policies --show

# 2. Verificar configuração de aplicação
cat /etc/crypto-policies/back-ends/opensslcnf.config

# 3. Testar com LEGACY temporariamente
sudo update-crypto-policies --set LEGACY
sudo systemctl restart <service>
```

### O Que crypto-policies Controla

Configura automaticamente:
- OpenSSL
- GnuTLS
- NSS
- OpenJDK/Java
- BIND
- Kerberos
- OpenSSH
- E mais!

**Resumo:** Mude uma configuração, atualize a segurança de todo o sistema. Brilhante!

---

## 3.7 Guia de Seleção de Ferramenta

### "Qual ferramenta devo usar?"

```
┌─────────────────────────────────────────────────────────────┐
│ ÁRVORE DE DECISÃO DE FERRAMENTA DE CERTIFICADO              │
└─────────────────────────────────────────────────────────────┘

Eu preciso...
│
├─ Inspecionar um certificado
│  └─ Usar: openssl x509 -in cert.crt -noout -text
│
├─ Gerar uma chave/CSR
│  └─ Usar: openssl genpkey / openssl req
│
├─ Testar uma conexão TLS
│  └─ Usar: openssl s_client -connect host:port
│
├─ Adicionar uma CA confiável em todo o sistema
│  └─ Usar: copiar para /etc/pki/ca-trust/source/anchors/
│           depois: update-ca-trust
│
├─ Renovar certificados automaticamente
│  └─ Usar: certmonger (getcert/ipa-getcert)
│
├─ Mudar política TLS do sistema (RHEL 8+)
│  └─ Usar: update-crypto-policies --set <POLICY>
│
├─ Trabalhar com bases de dados Firefox/NSS
│  └─ Usar: certutil
│
└─ Resolver problemas de certificados
   └─ Usar: Metodologia do Capítulo 27!
```

---

## 3.8 Matriz de Disponibilidade de Ferramentas

| Ferramenta | RHEL 7 | RHEL 8 | RHEL 9 | RHEL 10 | Notas |
|------------|--------|--------|--------|---------|-------|
| openssl | 1.0.2k | 1.1.1k | 3.5.5 | 3.5.5 | Ferramenta principal |
| certutil | ✅ | ✅ | ✅ | ✅ | Ferramenta NSS |
| update-ca-trust | ✅ | ✅ Aprimorado | ✅ Aprimorado | ✅ Aprimorado | Gestão confiança |
| certmonger | ✅ | ✅ Aprimorado | ✅ ACME | ✅ ACME | Renovação auto |
| crypto-policies | ❌ | ✅ | ✅ Subpolíticas | ✅ Aprimorado | Política sistema |
| getcert | ✅ | ✅ | ✅ | ✅ | CLI certmonger |
| trust | ✅ Básico | ✅ | ✅ | ✅ | Ferramenta p11-kit |

---

## 3.9 Verificação de Instalação

Verifique que você tem as ferramentas essenciais:

```bash
#============================================#
# VERIFICAR FERRAMENTAS INSTALADAS
#============================================#

# OpenSSL (deve estar instalado por padrão)
openssl version

# Ferramentas NSS
rpm -q nss-tools || echo "Instalar com: sudo dnf install nss-tools"

# certmonger
rpm -q certmonger || echo "Instalar com: sudo dnf install certmonger"

# Verificar crypto-policies (apenas RHEL 8+)
which update-crypto-policies &>/dev/null && \
  echo "Crypto-policies disponível: $(update-crypto-policies --show)" || \
  echo "Crypto-policies não disponível (RHEL 7 ou anterior)"
```

---

## 3.10 Comandos de Referência Rápida

```bash
# === OpenSSL ===
openssl version                          # Verificar versão
openssl x509 -in cert.crt -noout -text   # Inspecionar certificado
openssl s_client -connect host:443       # Testar HTTPS

# === Repositório de Confiança ===
sudo cp ca.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust                     # Adicionar CA confiável

# === certmonger ===
sudo getcert list                        # Listar certs rastreados
sudo getcert list -f /path/to/cert.crt   # Verificar cert específico
sudo journalctl -u certmonger -f         # Ver logs

# === Crypto-Policies (RHEL 8+) ===
update-crypto-policies --show            # Política atual
sudo update-crypto-policies --set <POL>  # Mudar política

# === NSS ===
certutil -L -d /etc/pki/nssdb            # Listar certs NSS
```

---

## 3.11 O Que Vem a Seguir?

Agora que você conhece as ferramentas, você aprenderá:
- **Capítulo 4:** Conceitos básicos de criptografia
- **Capítulo 5:** Entendendo certificados X.509
- **Capítulo 6:** Mergulho profundo em repositório de confiança RHEL
- **Capítulo 22:** Domínio de certmonger (detalhado)
- **Capítulo 23:** Mergulho profundo em Crypto-policies (detalhado)

---

## Cartão de Referência Rápida

```
┌────────────────────────────────────────────────────────────┐
│ FOLHA DE DICAS DE FERRAMENTAS DE CERTIFICADOS RHEL         │
├────────────────────────────────────────────────────────────┤
│ Inspecionar:   openssl x509 -in cert.crt -noout -text      │
│ Testar:        openssl s_client -connect host:443          │
│ Adicionar CA:  cp ca.crt /etc/pki/ca-trust/source/anchors/ │
│                sudo update-ca-trust                        │
│ Renovar auto:  sudo getcert list                           │
│ Política:      update-crypto-policies --show  (RHEL 8+)    │
│ NSS:           certutil -L -d /etc/pki/nssdb               │
└────────────────────────────────────────────────────────────┘
```
---

**Navegação do Capítulo**

| [← Anterior: Capítulo 2 - Introdução aos Certificados no RHEL](02-intro.md) | [Próximo: Capítulo 4 - Criptografia Básica para Administradores RHEL →](04-basic-cryptography.md) |
|:---|---:|
