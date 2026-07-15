# Lab 04: Certificados X.509

## Objetivos de aprendizagem

Ao concluir este laboratório, você irá:
- Criar certificados X.509 autoassinados
- Gerar Certificate Signing Requests (CSRs)
- Inspecionar campos de certificados (subject, issuer, datas, SANs)
- Entender Subject Alternative Names (SANs)
- Converter entre formatos PEM e DER
- Verificar a validade de certificados

## Pré-requisitos

- **Lab 02** concluído (geração de chaves)
- **Versão do RHEL:** 7, 8, 9 ou 10

## Tempo estimado

**25-30 minutos**

## Visão geral

X.509 é o formato padrão de certificados usado em todo o RHEL. Aprenda a criar, inspecionar e validar certificados X.509.

---

## Instruções

### Passo 1: Crie um certificado autoassinado

Gere um certificado autoassinado:

```bash
./create-self-signed.sh
```

Isso cria:
- `output/server.crt` - Certificado autoassinado
- Usa a chave RSA-2048 do Lab 02
- Inclui Subject Alternative Names (SANs)

**Inspecione o certificado:**
```bash
openssl x509 -in output/server.crt -text -noout | head -40
```

---

### Passo 2: Crie um Certificate Signing Request (CSR)

Gere um CSR (para envio a uma CA):

```bash
./create-csr.sh
```

Cria `output/server.csr` com:
- Subject: /CN=server.example.com/O=Lab/C=US
- SANs: server.example.com, www.example.com

**Inspecione o CSR:**
```bash
openssl req -in output/server.csr -text -noout
```

---

### Passo 3: Inspecione os campos do certificado

Execute o script de inspeção:

```bash
./inspect-cert.sh
```

Isso exibe:
- Subject (a quem o certificado se identifica)
- Issuer (quem o assinou — o mesmo para autoassinados)
- Datas de validade (Not Before / Not After)
- Subject Alternative Names (SANs) — OBRIGATÓRIO no RHEL 9+
- Algoritmo e tamanho da chave pública
- Algoritmo de assinatura

---

### Passo 4: Converta formatos

Converta entre PEM e DER:

```bash
./convert-formats.sh
```

Cria:
- `output/server.der` - Formato DER binário
- `output/server-from-der.pem` - Convertido de volta para PEM

**Compare os tamanhos dos arquivos:**
```bash
ls -lh output/server.{crt,der}
```

DER é binário (menor), PEM é Base64 (legível por humanos).

---

## Validação

```bash
./test.sh
```

Todas as verificações devem passar.

## Resultado esperado

Após concluir este laboratório:
- ✅ Certificado autoassinado criado
- ✅ CSR criado com sucesso
- ✅ Compreensão da estrutura do certificado
- ✅ Capacidade de inspecionar campos do certificado
- ✅ Capacidade de converter entre PEM e DER

---

## Conceitos-chave

### Estrutura do certificado X.509

| Campo | Finalidade |
|-------|------------|
| Version | v3 (inclui extensões) |
| Serial Number | Identificador único |
| Signature Algorithm | Como o certificado é assinado (ex.: sha256WithRSAEncryption) |
| Issuer | Quem assinou o certificado (CA) |
| Validity | Datas Not Before / Not After |
| Subject | A quem o certificado se identifica |
| Public Key | Chave pública do subject |
| Extensions | SANs, Key Usage, etc. |
| Signature | Assinatura digital da CA |

### Subject Alternative Names (SANs)

**Crítico para RHEL 9+**: Certificados DEVEM incluir SANs para validação de hostname.

Exemplo:
```
X509v3 Subject Alternative Name:
    DNS:server.example.com, DNS:www.example.com, IP:192.168.1.10
```

### PEM vs DER

- **PEM**: Codificado em Base64, cabeçalhos `-----BEGIN CERTIFICATE-----`
- **DER**: ASN.1 binário, usado por alguns aplicativos e dispositivos

---

## Resolução de problemas

### Problema: SANs não incluídos

**Sintoma:**
Certificado não inclui Subject Alternative Names

**Solução:**
RHEL 9+ exige configuração explícita de SANs. Os scripts incluem SANs automaticamente.

---

### Problema: Certificado já expirado

**Sintoma:**
```
notAfter=... (certificate has expired)
```

**Solução:**
Certificados autoassinados são criados com validade de 365 dias. Regenere se expirado:
```bash
./create-self-signed.sh
```

---

## Notas específicas por versão

### RHEL 7-8
- SANs recomendados, mas não estritamente obrigatórios
- Avisos de navegador sem SANs

### RHEL 9+
- SANs **OBRIGATÓRIOS** para validação
- Assinaturas SHA-1 bloqueadas
- Use SHA-256 ou superior

---

## Limpeza

```bash
./cleanup.sh
```

---

## Recursos adicionais

**Capítulos relacionados:**
- Capítulo 5: Certificados X.509 no RHEL

**Documentação:**
- `man x509`
- `man req`

---

## Próximos passos

Prossiga para o **Lab 05: Gerenciamento do Repositório de Confiança** para aprender sobre confiança CA em todo o sistema.

---

**Nível de dificuldade:** Iniciante
