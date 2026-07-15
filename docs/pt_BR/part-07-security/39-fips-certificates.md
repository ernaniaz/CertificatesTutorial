# Capítulo 39: Certificados Conformes FIPS

> **Pronto Conformidade:** Aprenda como gerar, validar e gerenciar certificados conformes FIPS no RHEL para ambientes federais e regulamentados.

---

## 39.1 Requisitos Certificado FIPS

### Requisitos Obrigatórios

**Para Conformidade FIPS 140-2/140-3:**

```
✅ Algoritmo Chave: RSA 2048+ ou ECC P-256/384/521
✅ Assinatura: SHA-256, SHA-384 ou SHA-512
✅ Protocolos TLS: Apenas 1.2 ou 1.3
✅ Gerado em modo FIPS (para chaves novas)
✅ Módulo validado usado para operações

❌ SEM MD5, SHA-1
❌ SEM RSA < 2048 bits
❌ SEM TLS 1.0/1.1
❌ SEM 3DES, RC4, DES
❌ SEM algoritmos não aprovados
```

---

## 39.2 Gerando Certificados FIPS

### Fluxo de Trabalho Certificado FIPS Completo

```bash
#============================================#
# GERAÇÃO CERTIFICADO FIPS COMPLETA
#============================================#

# Pré-requisitos: Modo FIPS deve estar habilitado
fips-mode-setup --check
# FIPS mode is enabled.

# Passo 1: Gerar chave RSA conforme FIPS
openssl genpkey -algorithm RSA \
  -out /etc/pki/tls/private/fips-server.key \
  -pkeyopt rsa_keygen_bits:2048

# Ou mais forte (3072/4096)
openssl genpkey -algorithm RSA \
  -out /etc/pki/tls/private/fips-server.key \
  -pkeyopt rsa_keygen_bits:3072

# Passo 2: Definir permissões
sudo chmod 600 /etc/pki/tls/private/fips-server.key

# Passo 3: Gerar CSR com SHA-256
openssl req -new \
  -key /etc/pki/tls/private/fips-server.key \
  -out /tmp/fips-server.csr \
  -sha256 \
  -subj "/C=US/O=Federal Agency/OU=IT/CN=secure.example.gov" \
  -addext "subjectAltName=DNS:secure.example.gov,DNS:www.secure.example.gov"

# Passo 4: Verificar CSR
openssl req -in /tmp/fips-server.csr -noout -text | grep -E "(Signature Algorithm|Public-Key)"
# Signature Algorithm: sha256WithRSAEncryption  ← Deve ser SHA-256+
# Public-Key: (2048 bit)  ← Deve ser 2048+

# Passo 5: Submeter para CA conforme FIPS
# Receber certificado de volta

# Passo 6: Verificar conformidade certificado
openssl x509 -in fips-server.crt -noout -text | grep "Signature Algorithm"
# Signature Algorithm: sha256WithRSAEncryption  ← Bom!
```

### Chaves EC Conformes FIPS

```bash
#============================================#
# CHAVES ELLIPTIC CURVE PARA FIPS
#============================================#

# P-256 (aprovada FIPS)
openssl genpkey -algorithm EC \
  -out /etc/pki/tls/private/fips-ec.key \
  -pkeyopt ec_paramgen_curve:P-256

# P-384 (mais forte, aprovada FIPS)
openssl genpkey -algorithm EC \
  -out /etc/pki/tls/private/fips-ec.key \
  -pkeyopt ec_paramgen_curve:P-384

# Gerar CSR
openssl req -new -key /etc/pki/tls/private/fips-ec.key \
  -out /tmp/fips-ec.csr \
  -sha256 \
  -subj "/CN=secure.example.gov"
```

---

## 39.3 Validando Conformidade FIPS

### Verificação Conformidade Certificado

```bash
#!/bin/bash
# check-fips-compliance.sh
# Verificar certificado é conforme FIPS

CERT=$1

if [ -z "$CERT" ] || [ ! -f "$CERT" ]; then
  echo "Uso: $0 /path/to/certificate.crt"
  exit 1
fi

echo "=== Verificação Conformidade FIPS ==="
echo "Certificado: $CERT"
echo ""

COMPLIANT=true

# Verificar algoritmo assinatura
SIG_ALG=$(openssl x509 -in "$CERT" -noout -text | grep "Signature Algorithm" | head -2)
echo "Algoritmo Assinatura: $SIG_ALG"

if echo "$SIG_ALG" | grep -Eqi "md5|sha1"; then
  echo "  ❌ FALHA: MD5/SHA-1 não aprovados FIPS"
  COMPLIANT=false
else
  echo "  ✅ PASSOU: Assinatura aprovada FIPS"
fi

# Verificar tamanho chave
KEY_SIZE=$(openssl x509 -in "$CERT" -noout -text | grep "Public-Key" | grep -oP '\d+')
echo ""
echo "Tamanho Chave: $KEY_SIZE bits"

if [ "$KEY_SIZE" -lt 2048 ]; then
  echo "  ❌ FALHA: Tamanho chave < 2048 bits"
  COMPLIANT=false
else
  echo "  ✅ PASSOU: Tamanho chave adequado"
fi

# Verificar algoritmo chave
KEY_ALG=$(openssl x509 -in "$CERT" -noout -text | grep "Public Key Algorithm")
echo ""
echo "Algoritmo Chave: $KEY_ALG"

if echo "$KEY_ALG" | grep -qi "dsa"; then
  echo "  ❌ FALHA: DSA não aprovado FIPS"
  COMPLIANT=false
fi

# Resultado final
echo ""
echo "================================"
if [ "$COMPLIANT" = true ]; then
  echo "✅ Certificado é CONFORME FIPS"
  exit 0
else
  echo "❌ Certificado NÃO é conforme FIPS"
  echo "   Reemitir com parâmetros aprovados FIPS"
  exit 1
fi
```

---

## 39.4 Seleção CA FIPS

### CA Deve Ser Validada FIPS

**CA Interna:**
- Usar FreeIPA em modo FIPS
- Dogtag PKI (CA FreeIPA) tem validação FIPS

**CA Externa:**
- Verificar CA é validada FIPS 140-2/140-3
- Solicitar documentação conformidade FIPS
- CAs FIPS comuns: DigiCert Federal, Entrust, IdenTrust

---

## 39.5 Configuração Serviço para FIPS

### Serviços Automaticamente Conformes FIPS

Quando modo FIPS habilitado, todos serviços automaticamente usam crypto-policy FIPS:

```bash
# Apache - sem config especial necessária
# Apenas garantir certificado é conforme FIPS

# NGINX - automaticamente usa política FIPS

# Postfix - conforme FIPS automaticamente

# Verificar cada serviço
openssl s_client -connect localhost:443
# Verificar cipher usado - deveria ser aprovado FIPS
```

---

## 39.6 Conclusões Chave

1. **FIPS 140-2 é padrão atual** validado no RHEL
2. **Transição FIPS 140-3** está em progresso
3. **Habilitar na instalação** para melhores resultados
4. **Apenas RSA 2048+ ou ECC P-256/384**
5. **Assinaturas SHA-256+** requeridas
6. **Serviços automaticamente cumprem** com política FIPS
7. **Testar aplicações** antes habilitar FIPS em produção

---

## Cartão de Referência Rápida

```
┌────────────────────────────────────────────────────────────────┐
│ REFERÊNCIA RÁPIDA CERTIFICADOS CONFORMES FIPS                  │
├────────────────────────────────────────────────────────────────┤
│ Padrão:      FIPS 140-2 (atual validado)                       │
│              FIPS 140-3 (transição em progresso)               │
│                                                                │
│ Chaves:      RSA 2048/3072/4096                                │
│              ECC P-256/384/521                                 │
│                                                                │
│ Assinatura:  SHA-256, SHA-384, SHA-512                         │
│              (SEM MD5, SEM SHA-1)                              │
│                                                                │
│ Gerar:       openssl genpkey -algorithm RSA ... (em modo FIPS) │
│ CSR:         openssl req -new -sha256 ...                      │
│ Verificar:   Verificar alg assinatura, tamanho chave           │
│                                                                │
│ Testar:      echo test | openssl md5                           │
│              (deveria falhar se FIPS funcionando)              │
└────────────────────────────────────────────────────────────────┘

✅ Modo FIPS deve estar habilitado para conformidade
✅ Todas operações usam módulos criptográficos validados
⚠️ Verificar status atual 140-2/140-3 para suas necessidades
```
---

**Navegação do Capítulo**

| [← Anterior: Capítulo 38 - Guia Completo do Modo FIPS](38-fips-mode-guide.md) | [Próximo: Capítulo 40 - Fortalecimento de Segurança de Certificados no RHEL →](40-security-hardening.md) |
|:---|---:|
