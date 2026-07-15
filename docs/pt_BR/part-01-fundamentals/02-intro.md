# Capítulo 2: Introdução aos Certificados no RHEL

> **Bem-vindo!** Este tutorial levará você de não saber nada sobre certificados digitais a resolver problemas de certificados com confiança em sistemas Red Hat Enterprise Linux.

---

## 2.1 Por Que Este Tutorial?

Você é um administrador RHEL. Um dia, algo quebra:

- Apache se recusa a iniciar: `SSL_CTX_use_certificate:ca md too weak`
- Conexões LDAP falham: `TLS: hostname does not match CN`
- certmonger mostra: `CA_UNREACHABLE`
- curl retorna: `SSL certificate problem: unable to get local issuer certificate`

**Parece familiar?** Estes são problemas de certificados, e estão em todos os lugares em sistemas Linux modernos.

Este tutorial ensina você a:

- ✅ Entender o que são certificados (perspectiva RHEL)
- ✅ Configurar certificados para serviços comuns RHEL
- ✅ **Resolver problemas de certificados** (objetivo principal!)
- ✅ Automatizar ciclo de vida de certificados com ferramentas RHEL
- ✅ Lidar com diferenças de versões RHEL (7, 8, 9, 10)
- ✅ Passar auditorias (FIPS, STIG, conformidade)

---

## 2.2 Para Quem é Este Tutorial?

**Público Principal:**
- Administradores e engenheiros RHEL
- Engenheiros de suporte resolvendo problemas de certificados
- Qualquer pessoa gerenciando sistemas RHEL com HTTPS, LDAPS ou TLS

**Pré-requisitos:**
- Conhecimento básico de linha de comando Linux
- Acesso a sistemas RHEL (7, 8, 9 ou 10)
- Não é necessário conhecimento prévio de certificados!

---

## 2.3 O Que São Certificados? (Em 60 Segundos)

Imagine que você visita https://example.com. Como seu navegador sabe que está realmente falando com example.com e não com um impostor?

**Resposta: Certificados digitais.**

Um certificado é como uma carteira de identidade digital que:
1. **Prova identidade** ("Eu sou example.com")
2. **Habilita criptografia** (comunicação segura)
3. **É assinado por autoridade confiável** (como uma CA)

### Em Sistemas RHEL

Certificados são usados em todos os lugares:
- **Servidores web** (Apache, NGINX) → HTTPS
- **Serviços de diretório** (OpenLDAP, FreeIPA) → LDAPS
- **Servidores de email** (Postfix, Dovecot) → SMTPS/IMAPS
- **Bancos de dados** (PostgreSQL, MySQL) → Conexões TLS
- **APIs e serviços** (REST, microserviços) → mTLS
- **Túneis VPN** → Conexões seguras
- **Registros de contêiner** → Imagens seguras

**Resumo:** Se está em rede e é seguro no RHEL, provavelmente usa certificados.

---

## 2.4 Sua Primeira Inspeção de Certificado

Vamos ser práticos imediatamente. SSH em qualquer sistema RHEL e execute:

```bash
# Ver certificado do servidor SSH do seu sistema
sudo openssl s_client -connect localhost:22 -starttls smtp 2>/dev/null | openssl x509 -noout -text

# Exemplo melhor: Verificar um certificado web
echo | openssl s_client -connect access.redhat.com:443 2>/dev/null | openssl x509 -noout -text | head -20
```

Você verá uma saída como:

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            0a:5d:d2:48:fc:4e:2f:e2:99:81:09:74:2d:4c:d5:69
        Signature Algorithm: ecdsa-with-SHA384
        Issuer: C=US, O=DigiCert Inc, CN=DigiCert Global G3 TLS ECC SHA384 2020 CA1
        Validity
            Not Before: Oct 30 00:00:00 2025 GMT
            Not After : Oct 27 23:59:59 2026 GMT
        Subject: C=US, ST=North Carolina, L=Raleigh, O=Red Hat, Inc., CN=access.redhat.com
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub:
                    04:fc:08:bf:d2:d8:63:0c:84:a4:c8:dd:04:9c:8c:
                    99:4f:cb:93:31:7f:9e:64:27:ea:3d:a7:18:fd:3e:
                    4c:c2:58:8b:cb:f2:5c:6e:95:bf:f3:97:ba:b8:2b:
                    49:c6:51:30:f4:71:88:e3:fa:d4:f1:73:74:1d:e3:
                    2b:49:bc:9e:6e
```

**O que você está vendo:**
- **Issuer:** Quem assinou este certificado
- **Subject:** A quem este certificado pertence
- **Validity:** Quando é válido (expira 15 de março de 2025)
- **Signature Algorithm:** Como está protegido (SHA-256 com RSA)

**🎉 Parabéns!** Você acabou de inspecionar seu primeiro certificado.

---

## 2.5 Como Funcionam os Certificados (Contexto RHEL)

### Os Três Componentes Chave

1. **Certificado** (`.crt`, `.pem`)
   - Informação pública: "Eu sou server.example.com"
   - Contém a chave pública
   - Armazenado em `/etc/pki/tls/certs/` no RHEL

2. **Chave Privada** (`.key`, `.pem`)
   - Segredo! Nunca compartilhe isso
   - Usado para provar que você possui o certificado
   - Armazenado em `/etc/pki/tls/private/` no RHEL (modo 600!)

3. **Autoridade Certificadora (CA)**
   - Emite e assina certificados
   - Pode ser pública (Let's Encrypt, DigiCert)
   - Ou interna (FreeIPA, CA corporativa)
   - CAs confiáveis armazenadas em `/etc/pki/ca-trust/` no RHEL

### A Cadeia de Confiança

```
CA Raiz (confiável pelo sistema RHEL)
  └─ CA Intermediária
      └─ Certificado do Servidor (seu servidor web)
```

Quando alguém se conecta ao seu servidor RHEL:
1. Servidor envia seu certificado
2. Cliente verifica cadeia de assinatura até CA raiz confiável
3. Se cadeia é válida → conexão prossegue
4. Se cadeia quebra → erro (e você recebe a chamada de suporte!)

---

## 2.6 Arquitetura de Certificados do RHEL

### Diretórios Chave

```
/etc/pki/
├── ca-trust/
│   ├── source/anchors/      ← Coloque CAs personalizadas aqui
│   └── extracted/           ← Repositório de confiança do sistema
│       ├── pem/             ← CAs em formato PEM
│       ├── openssl/         ← Confiança OpenSSL
│       └── java/            ← Confiança Java (cacerts)
├── tls/
│   ├── certs/               ← Certificados de servidor
│   ├── private/             ← Chaves privadas (modo 700!)
│   └── cert.pem             ← Link simbólico de certificado padrão
└── nssdb/                   ← Base de dados NSS (Firefox, etc.)
```

### Ferramentas Chave

```bash
# OpenSSL - Canivete suíço de certificados
openssl version  # Verificar sua versão

# Ferramentas NSS - Para bases de dados NSS
certutil -L -d /etc/pki/nssdb

# Gestão de Confiança - Adicionar/remover CAs
update-ca-trust  # Atualizador de repositório de confiança do RHEL

# Gerenciador de Certificados - Renovação automática (RHEL 7+)
getcert list  # Mostrar certificados rastreados

# Crypto-Policies - Segurança em todo o sistema (RHEL 8+)
update-crypto-policies --show  # Verificar política atual
```

---

## 2.7 Um Dia na Vida: Cenários de Certificados

### Cenário 1: Adicionar uma CA Personalizada

```bash
# Você tem uma CA corporativa que assinou seus servidores internos
sudo cp corporate-ca.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust extract

# Agora RHEL confia em certificados assinados por sua CA corporativa!
```

### Cenário 2: Configurar Apache HTTPS

```bash
# Instalar Apache com SSL/TLS
sudo dnf install httpd mod_ssl

# Gerar uma chave privada
sudo openssl genpkey -algorithm RSA -out /etc/pki/tls/private/server.key \
  -pkeyopt rsa_keygen_bits:2048

# Gerar uma solicitação de assinatura de certificado (CSR)
sudo openssl req -new -key /etc/pki/tls/private/server.key \
  -out /tmp/server.csr \
  -subj "/CN=web.example.com"

# Enviar CSR para CA, obter certificado de volta, instalá-lo
sudo cp server.crt /etc/pki/tls/certs/

# Configurar Apache, reiniciar
sudo systemctl restart httpd
```

### Cenário 3: Resolver um Certificado Expirado

```bash
# Serviço falha com: "certificate has expired"
# Verificar expiração do certificado
sudo openssl x509 -in /etc/pki/tls/certs/server.crt -noout -dates

# Saída mostra:
# notAfter=Jan 15 23:59:59 2024 GMT  ← Ops, expirado!

# Renovar certificado, substituir arquivo, reiniciar serviço
```

---

## 2.8 Diferenças de Versão RHEL (Prévia)

A gestão de certificados evoluiu significativamente entre versões RHEL:

| Versão RHEL | Característica Chave | Foco de Solução de Problemas |
|-------------|----------------------|-------------------------|
| **RHEL 7** | Abordagem tradicional | Configuração manual, problemas TLS legados |
| **RHEL 8** | **Crypto-policies** | Conflitos de política, integração certmonger |
| **RHEL 9** | OpenSSL 3.x | Problemas de provedor, validação mais rigorosa |
| **RHEL 10** | Padrões fortalecidos | Somente moderno, ferramentas aprimoradas |

> **Não se preocupe!** O Capítulo 8 cobre essas diferenças de versão em detalhes.

---

## 2.9 Problemas Comuns de Certificados (Prévia)

Você aprenderá a resolver:

**Problemas de Configuração:**
- Desajuste de certificado/chave
- Permissões de arquivo incorretas
- Caminhos incorretos em arquivos de configuração

**Problemas de Confiança:**
- Certificados autoassinados rejeitados
- Erros de CA desconhecida
- Falhas de validação de cadeia

**Problemas de Expiração:**
- Certificados expirados
- Problemas de desvio de relógio
- Falhas de renovação

**Problemas de Versão:**
- Desajustes de versão TLS
- Problemas de suite de cifra
- Conflitos de crypto-policy (RHEL 8+)
- Compatibilidade OpenSSL 3.x (RHEL 9+)

**Específicos de Serviço:**
- Apache: Erros `SSLCertificateFile`
- NGINX: Problemas `ssl_certificate`
- Postfix: Falhas de handshake TLS
- LDAP: `TLS: hostname does not match`

---

## 2.10 Visão Geral do Caminho de Aprendizagem

Este tutorial está organizado para administradores RHEL:

### Parte 1: Fundamentos (Capítulos 1-7)
Comece aqui. Aprenda básicos de certificados em contexto RHEL.

### Parte 2: Específico por Versão (Capítulos 8-13)
Mergulho profundo nas diferenças RHEL 7, 8, 9, 10.

### Parte 3: Serviços (Capítulos 14-21)
Configure certificados para Apache, NGINX, Postfix, LDAP, etc.

### Parte 4: Automatização (Capítulos 22-26)
Domine certmonger, crypto-policies, Let's Encrypt, Ansible.

### Parte 5: Solução de Problemas (Capítulos 27-33) ⭐
**É aqui que você se torna um especialista!**
Solução sistemática de problemas, erros comuns, procedimentos de emergência.

### Parte 6: Migração (Capítulos 34-37)
Atualizações de versão RHEL e migração de certificados.

### Parte 7: Segurança (Capítulos 38-41)
Modo FIPS, conformidade, fortalecimento, auditoria.

### Apêndices
Tópicos avançados opcionais (Kubernetes, Vault, Zero Trust, etc.)

---

## 2.11 Como Usar Este Tutorial

### Para Novos Usuários
📖 Leia os capítulos em ordem. Cada um se baseia no conhecimento anterior.

### Para Usuários Experientes
🎯 Pule para solução de problemas (Parte 5) ou serviços específicos (Parte 3).

### Para Engenheiros de Suporte
🚨 Comece com Capítulo 27 (Metodologia de Solução de Problemas de Certificados RHEL), depois mergulhe em detalhes.

### Labs Práticos
Cada capítulo inclui exemplos práticos. Você precisará:
- Um sistema RHEL (VM ou contêiner serve)
- Acesso root ou sudo
- Conectividade à internet (para instalações de pacotes)

---

## 2.12 Conceitos Chave a Dominar

Ao final deste tutorial, você entenderá:

- ✅ **O que são certificados** e por que RHEL os usa
- ✅ **Como funciona a confiança** em sistemas RHEL
- ✅ **Onde vivem os certificados** (`/etc/pki/`)
- ✅ **Quais ferramentas usar** (openssl, certutil, certmonger)
- ✅ **Diferenças de versão** (RHEL 7 vs 8 vs 9 vs 10)
- ✅ **Como resolver problemas** de qualquer certificado
- ✅ **Como automatizar** o ciclo de vida de certificados
- ✅ **Como proteger** sistemas (FIPS, conformidade)

---

## 2.13 Impacto no Mundo Real

Problemas de certificados causam:
- ❌ Interrupções de serviço (certificados expirados)
- ❌ Vulnerabilidades de segurança (cifras fracas)
- ❌ Migrações falhadas (atualizações RHEL)
- ❌ Falhas de conformidade (rejeições de auditoria)
- ❌ Perda de produtividade (tempo de solução de problemas)

**Após este tutorial:**
- ✅ Prevenir problemas antes que aconteçam
- ✅ Resolver problemas em minutos, não horas
- ✅ Automatizar gestão de certificados
- ✅ Passar auditorias de segurança
- ✅ Migrar versões RHEL com confiança

---

## 2.14 Seu Primeiro Exercício

Vamos verificar que seu sistema RHEL está pronto:

```bash
# Verificar versão RHEL
cat /etc/redhat-release

# Verificar OpenSSL
openssl version

# Verificar se certmonger está instalado
rpm -q certmonger

# Verificar se você pode usar sudo
sudo whoami

# Verificar conectividade à internet (para instalações de pacotes)
ping -c 3 access.redhat.com

# Listar CAs confiáveis atuais (amostra)
trust list | head -20
```

✅ Se todos os comandos funcionam, você está pronto para prosseguir!

---

## 2.15 Vamos Começar!

Agora você entende:
- O que são certificados
- Por que importam no RHEL
- Onde vivem no sistema de arquivos
- Quais ferramentas você usará
- O que você aprenderá neste tutorial

**Pronto para mergulhar mais fundo?**

---

## Referência Rápida

```
┌─────────────────────────────────────────────────────────────────┐
│ INÍCIO RÁPIDO DE CERTIFICADO (RHEL)                             │
├─────────────────────────────────────────────────────────────────┤
│ Ver cert:           openssl x509 -in cert.crt -noout -text      │
│ Ver expiração:      openssl x509 -in cert.crt -noout -dates     │
│ Adicionar CA:       cp ca.crt /etc/pki/ca-trust/source/anchors/ │
│                     sudo update-ca-trust                        │
│ Listar rastreados:  getcert list                                │
│ Ver política:       update-crypto-policies --show  (RHEL 8+)    │
└─────────────────────────────────────────────────────────────────┘

Localização cert:  /etc/pki/tls/certs/
Localização key:   /etc/pki/tls/private/  (modo 600!)
Confiança CA:      /etc/pki/ca-trust/
```

---

## 🧪 Laboratório Prático

**Lab 01: Configuração do Ambiente**

Valide seu ambiente RHEL e instale ferramentas essenciais de gerenciamento de certificados

- 📁 **Localização:** `labs/pt_BR/01-environment-setup/`
- ⏱️ **Tempo:** 15-20 minutos
- 🎯 **Nível:** Iniciante

---

**Navegação do Capítulo**

| [← Anterior: Capítulo 1 - Criptografia, Estrutura PKI e Fundamentos](01-cryptography-pki-basics.md) | [Próximo: Capítulo 3 - Visão Geral das Ferramentas de Certificados do RHEL →](03-rhel-tools-overview.md) |
|:---|---:|
