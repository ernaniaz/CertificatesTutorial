# Lab 02: Geração de Chaves

## Objetivos de aprendizagem

Ao concluir este laboratório, você irá:
- Gerar pares de chaves RSA (2048 bits e 4096 bits)
- Gerar pares de chaves de curva elíptica (ECC) (P-256 e P-384)
- Extrair chaves públicas a partir de chaves privadas
- Entender formatos de arquivos de chaves e permissões
- Comparar diferentes tamanhos de chaves e algoritmos

## Pré-requisitos

- **Lab 01** concluído (configuração do ambiente)
- **Versão do RHEL:** 7, 8, 9 ou 10
- **Acesso ao sistema:** Usuário comum (root não necessário)

## Tempo estimado

**20-25 minutos**

## Visão geral

Aprenda a gerar pares de chaves criptográficas usando OpenSSL. As chaves são a base das operações com certificados — entender como criá-las e gerenciá-las é essencial.

---

## Instruções

### Passo 1: Gere chaves RSA

Execute o script de geração de chaves RSA:

```bash
./generate-rsa-keys.sh
```

Isso cria:
- `output/rsa-2048.key` - Chave privada RSA de 2048 bits (mínimo para produção)
- `output/rsa-2048.pub` - Chave pública correspondente
- `output/rsa-4096.key` - Chave privada RSA de 4096 bits (recomendada para alta segurança)
- `output/rsa-4096.pub` - Chave pública correspondente

**Visualize uma chave:**
```bash
openssl pkey -in output/rsa-2048.key -text -noout | head -20
```

---

### Passo 2: Gere chaves ECC

Execute o script de geração de chaves ECC:

```bash
./generate-ecc-keys.sh
```

Isso cria:
- `output/ecc-p256.key` - Chave privada P-256 (secp256r1)
- `output/ecc-p256.pub` - Chave pública correspondente
- `output/ecc-p384.key` - Chave privada P-384 (secp384r1)
- `output/ecc-p384.pub` - Chave pública correspondente

**Visualize uma chave ECC:**
```bash
openssl pkey -in output/ecc-p256.key -text -noout
```

---

### Passo 3: Verifique as chaves

Execute o script de verificação:

```bash
./verify-keys.sh
```

Isso valida:
- Todas as chaves foram geradas com sucesso
- Chaves privadas com permissões corretas (600)
- Chaves públicas com permissões corretas (644)
- Chaves em formato OpenSSL válido

---

### Passo 4: Compare os tamanhos das chaves

Visualize os tamanhos dos arquivos:

```bash
ls -lh output/
```

**Observação:**
- Chaves RSA são arquivos maiores
- Chaves ECC são muito menores para segurança equivalente
- P-256 ECC ≈ segurança de RSA de 3072 bits
- P-384 ECC ≈ segurança de RSA de 7680 bits

---

## Validação

Execute o script de teste:

```bash
./test.sh
```

Todas as verificações devem passar.

## Resultado esperado

Após concluir este laboratório, você deve ter:
- ✅ Pares de chaves RSA de 2048 e 4096 bits gerados
- ✅ Pares de chaves ECC P-256 e P-384 gerados
- ✅ Todas as chaves com permissões corretas
- ✅ Compreensão das diferenças entre RSA e ECC

---

## Resolução de problemas

### Problema: Permissão negada

**Sintoma:**
```
Permission denied: output/
```

**Solução:**
```bash
mkdir -p output
chmod 755 output
```

---

### Problema: Comando OpenSSL não encontrado

**Sintoma:**
```
bash: openssl: command not found
```

**Solução:**
Volte ao Lab 01 e execute o script de configuração.

---

## Conceitos-chave

### Tamanhos de chaves RSA
- **2048 bits:** Mínimo para crypto-policies DEFAULT no RHEL 8+
- **4096 bits:** Recomendado para segurança de longo prazo

### Curvas ECC
- **P-256 (prime256v1):** Mínimo, equivalente a RSA de 3072 bits
- **P-384 (secp384r1):** Mais forte, equivalente a RSA de 7680 bits

### Permissões de arquivos
- **Chaves privadas:** Modo 600 (leitura/gravação apenas pelo proprietário)
- **Chaves públicas:** Modo 644 (legível por todos)

---

## Limpeza

```bash
./cleanup.sh
```

Isso remove o diretório `output/` e todas as chaves geradas.

---

## Recursos adicionais

**Capítulos relacionados:**
- Capítulo 4: Criptografia básica para administradores RHEL

**Documentação:**
- `man genpkey`
- `man pkey`
- `man ecparam`

---

## Próximos passos

Prossiga para o **Lab 03: Assinaturas Digitais** para aprender a assinar e verificar arquivos usando essas chaves.

---

**Nível de dificuldade:** Iniciante
