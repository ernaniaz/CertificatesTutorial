# Lab 03: Assinaturas Digitais

## Objetivos de aprendizagem

Ao concluir este laboratório, você irá:
- Assinar arquivos usando chaves privadas
- Verificar assinaturas usando chaves públicas
- Entender algoritmos de hash (SHA-256)
- Demonstrar detecção de adulteração
- Praticar fluxos de validação de assinaturas

## Pré-requisitos

- **Lab 02** concluído (geração de chaves)
- **Versão do RHEL:** 7, 8, 9 ou 10

## Tempo estimado

**20 minutos**

## Visão geral

Assinaturas digitais comprovam autenticidade e integridade. Aprenda a assinar arquivos e verificar que as assinaturas detectam qualquer adulteração.

---

## Instruções

### Passo 1: Assine um arquivo

Assine o arquivo de exemplo:

```bash
./sign-file.sh
```

Isso cria `sample-data.sig` — uma assinatura digital de `sample-data.txt`.

**Visualize a assinatura (hex):**
```bash
hexdump -C sample-data.sig | head -5
```

---

### Passo 2: Verifique a assinatura

Verifique a assinatura:

```bash
./verify-signature.sh
```

**Saída esperada:**
```
Verified OK
```

---

### Passo 3: Teste de detecção de adulteração

Demonstre que as assinaturas detectam adulteração:

```bash
./tamper-test.sh
```

O script:
1. Modifica o arquivo
2. Tenta verificar com a assinatura original
3. **Deve falhar** — comprovando que a adulteração foi detectada

---

## Validação

```bash
./test.sh
```

Todos os testes devem passar.

## Resultado esperado

Após concluir este laboratório:
- ✅ Arquivo assinado com sucesso
- ✅ Assinatura verificada corretamente
- ✅ Arquivo adulterado falha na verificação
- ✅ Compreensão do fluxo de assinaturas digitais

---

## Conceitos-chave

### Processo de assinatura digital

1. **Calcular hash** da mensagem (SHA-256)
2. **Criptografar** o hash com a chave privada = assinatura
3. **Enviar** mensagem + assinatura
4. **Descriptografar** a assinatura com a chave pública = hash original
5. **Calcular hash** da mensagem recebida
6. **Comparar** os hashes — correspondência = válido

### Por que isso funciona

- Somente o detentor da chave privada pode criar assinaturas válidas
- Qualquer pessoa com a chave pública pode verificar
- Qualquer alteração na mensagem altera o hash
- A assinatura não corresponderá se a mensagem foi modificada

---

## Resolução de problemas

### Problema: Chaves não encontradas

**Sintoma:**
```
Error: ../02-key-generation/output/rsa-2048.key not found
```

**Solução:**
Conclua o Lab 02 primeiro:
```bash
cd ../02-key-generation
./generate-rsa-keys.sh
cd ../03-digital-signatures
```

---

## Limpeza

```bash
./cleanup.sh
```

---

## Recursos adicionais

**Capítulos relacionados:**
- Capítulo 7: Assinaturas digitais e verificação no RHEL

---

## Próximos passos

Prossiga para o **Lab 04: Certificados X.509** para criar certificados reais.

---

**Nível de dificuldade**: Iniciante
