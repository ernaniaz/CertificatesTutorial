# Lab 19: Configuração do Modo FIPS

## Objetivos de aprendizagem

Ao concluir este laboratório, você irá:
- Entender requisitos de conformidade FIPS 140-2
- Habilitar modo FIPS no RHEL
- Configurar certificados para FIPS
- Testar conformidade FIPS
- Resolver problemas FIPS
- Entender limitações FIPS

## Pré-requisitos

- **RHEL 8 ou 9** (suporte a habilitar/desabilitar FIPS)
- **Labs 01-10** concluídos
- **Acesso ao sistema:** Root/sudo necessário
- **Capacidade de reinicialização** necessária

> **Nota RHEL 10:** O RHEL 10 não suporta habilitar ou desabilitar o modo FIPS
> após a instalação. O FIPS deve ser configurado durante a instalação do SO
> adicionando `fips=1` aos parâmetros de boot do kernel ou selecionando FIPS na
> política de segurança do instalador Anaconda. Os scripts de verificação e teste
> deste lab funcionam no RHEL 10, mas `enable-fips.sh` e `disable-fips.sh` não.

## Tempo estimado

**40-50 minutos** (inclui reinicialização)

## Visão geral

FIPS 140-2 é um padrão de segurança do governo dos EUA para módulos criptográficos. Aprenda a habilitar e configurar o modo FIPS para requisitos de conformidade.

---

## Visão geral do modo FIPS

### O que é FIPS?

**FIPS 140-2:** Federal Information Processing Standard Publication 140-2
- Programa de validação de módulos criptográficos
- Exigido para sistemas governamentais
- Especifica algoritmos aprovados
- Valida implementações

### Algoritmos aprovados FIPS

**Permitidos:**
- AES (128, 192, 256 bits)
- RSA (2048+ bits)
- SHA-256, SHA-384, SHA-512
- ECDSA com curvas aprovadas
- HMAC com SHA-2

**Bloqueados:**
- MD5
- SHA-1 (assinaturas)
- DES, 3DES
- RC4
- RSA <2048 bits

---

## Instruções

### Passo 1: Avaliação pré-FIPS

Verifique o estado atual do sistema:

```bash
./check-fips-readiness.sh
```

### Passo 2: Habilitar modo FIPS

Habilite FIPS (exige reinicialização):

```bash
sudo ./enable-fips.sh
# O sistema será reinicializado
```

### Passo 3: Verificar modo FIPS

Após reinicialização, verifique:

```bash
./verify-fips.sh
```

### Passo 4: Testar certificados

Teste compatibilidade de certificados:

```bash
./test-fips-certificates.sh
```

### Passo 5: Configurar serviços

Atualize serviços para FIPS:

```bash
sudo ./configure-services-fips.sh
```

---

## Comandos principais

```bash
# Verificar status FIPS
fips-mode-setup --check

# Habilitar FIPS (exige reinicialização) — apenas RHEL 8 e 9
fips-mode-setup --enable

# Desabilitar FIPS (exige reinicialização) — apenas RHEL 8 e 9
fips-mode-setup --disable

# Verificar flag FIPS do kernel
cat /proc/sys/crypto/fips_enabled
```

> **RHEL 10:** `fips-mode-setup --enable` e `--disable` não são suportados.
> O FIPS é definido apenas no momento da instalação.

---

## Validação

Verifique se o modo FIPS está configurado corretamente:

```bash
./verify-fips.sh
```

**Resultados esperados:**
- ✓ Modo FIPS habilitado: `/proc/sys/crypto/fips_enabled` mostra `1`
- ✓ `fips-mode-setup --check` informa que FIPS está habilitado
- ✓ `openssl md5 /dev/null` falha porque MD5 está desabilitado em modo FIPS

**Verificações manuais adicionais:**
```bash
# Verificar parâmetro FIPS do kernel
cat /proc/sys/crypto/fips_enabled  # Deve mostrar 1

# Verificar crypto-policy
update-crypto-policies --show  # Deve mostrar FIPS

# Testar OpenSSL FIPS
openssl md5 /etc/hosts  # Deve falhar com erro FIPS

# Verificar configurações de serviços
systemctl status httpd
journalctl -u httpd | grep -i fips
```

---

## Problemas comuns

### Problema: Serviço não inicia

**Sintoma:** Serviço falha com erro "FIPS mode"

**Solução:** Use apenas algoritmos aprovados FIPS

### Problema: Chave fraca rejeitada

**Sintoma:** RSA <2048 bits rejeitado

**Solução:** Regenere com 2048+ bits

### Problema: Certificado SHA-1 falha

**Sintoma:** Certificado com assinatura SHA-1 rejeitado

**Solução:** Use certificados SHA-256+

---

## Limpeza

```bash
sudo ./cleanup.sh
```

**Nota:** Desabilitar FIPS exige outra reinicialização.

---

**Nível de dificuldade:** Avançado
**Nota:** O modo FIPS tem implicações significativas de compatibilidade
