# Lab 05: Gerenciamento do Repositório de Confiança

## Objetivos de aprendizagem

Ao concluir este laboratório, você irá:
- Criar uma Certificate Authority (CA) personalizada
- Adicionar CA personalizada ao repositório de confiança do sistema
- Usar update-ca-trust para atualizar o sistema
- Verificar operações de confiança CA
- Remover CAs personalizadas da confiança
- Entender a estrutura de /etc/pki/ca-trust/

## Pré-requisitos

- **Lab 04** concluído (certificados X.509)
- **Versão do RHEL:** 7, 8, 9 ou 10
- **Acesso ao sistema:** Root/sudo necessário

## Tempo estimado

**25 minutos**

## Visão geral

Aprenda a gerenciar a confiança de certificados em todo o sistema no RHEL. Isso é essencial para trabalhar com CAs internas, certificados autoassinados e infraestrutura PKI personalizada.

---

## Instruções

### Passo 1: Crie um certificado CA de teste

Gere um certificado CA personalizado:

```bash
./create-test-ca.sh
```

Cria:
- `output/test-ca.key` - Chave privada da CA
- `output/test-ca.crt` - Certificado da CA

---

### Passo 2: Adicione a CA ao repositório de confiança do sistema

Adicione a CA ao repositório de confiança do sistema:

```bash
sudo ./add-custom-ca.sh
```

Isso copia o certificado CA para:
```
/etc/pki/ca-trust/source/anchors/lab-test-ca.crt
```

---

### Passo 3: Atualize a confiança do sistema

Execute update-ca-trust para reconstruir o pacote do sistema:

```bash
sudo ./update-trust.sh
```

Isso regenera `/etc/pki/tls/certs/ca-bundle.crt` para incluir sua CA personalizada.

---

### Passo 4: Verifique a confiança

Teste se sua CA agora é confiável:

```bash
./verify-trust.sh
```

Isso:
1. Cria um certificado assinado pela sua CA
2. Verifica com a confiança do sistema (deve ter sucesso)
3. Demonstra que a CA é confiável em todo o sistema

---

### Passo 5: Remova a CA personalizada

Limpe removendo a CA da confiança:

```bash
sudo ./remove-ca.sh
```

---

## Validação

```bash
sudo ./test.sh
```

Todos os testes devem passar.

## Resultado esperado

Após concluir este laboratório:
- ✅ CA personalizada criada
- ✅ CA adicionada ao repositório de confiança do sistema
- ✅ Confiança do sistema atualizada com sucesso
- ✅ Certificados assinados pela CA verificados corretamente
- ✅ CA removida da confiança
- ✅ Compreensão do gerenciamento do repositório de confiança no RHEL

---

## Conceitos-chave

### Estrutura do repositório de confiança no RHEL

```
/etc/pki/ca-trust/
├── source/
│   └── anchors/          ← Adicione CAs personalizadas aqui
├── extracted/
│   ├── openssl/          ← Pacotes gerados
│   ├── pem/
│   └── java/
└── ca-bundle.trust.p11-kit
```

### Comando update-ca-trust

Reconstrói os pacotes de confiança do sistema a partir de:
1. CAs do sistema (`/usr/share/pki/ca-trust-source/`)
2. CAs personalizadas (`/etc/pki/ca-trust/source/anchors/`)

Após a execução:
- `/etc/pki/tls/certs/ca-bundle.crt` atualizado
- Todos os aplicativos que usam a confiança do sistema refletem as alterações

### Casos de uso

**Adicione CA personalizada quando:**
- Usar CA interna/corporativa
- Trabalhar com certificados autoassinados
- Testar com PKI privada
- Integrar com serviços empresariais

---

## Resolução de problemas

### Problema: Permissão negada

**Sintoma:**
```
Permission denied: /etc/pki/ca-trust/source/anchors/
```

**Solução:**
Todas as operações de confiança exigem root:
```bash
sudo ./add-custom-ca.sh
```

---

### Problema: CA não confiável após adicionar

**Sintoma:**
Certificado ainda não verifica

**Solução:**
Você executou update-ca-trust?
```bash
sudo update-ca-trust extract
```

---

## Notas específicas por versão

### Todas as versões RHEL (7, 8, 9, 10)
- Mesma estrutura do repositório de confiança
- Mesmo comando update-ca-trust
- CAs adicionadas em `/etc/pki/ca-trust/source/anchors/`

### Boas práticas
- Use nomes descritivos para arquivos de CA
- Documente por que cada CA é confiável
- Remova CAs quando não forem mais necessárias
- Teste após adicionar CAs

---

## Limpeza

```bash
sudo ./cleanup.sh
```

Isso remove:
- CA personalizada do repositório de confiança do sistema
- Certificados e chaves gerados
- Atualiza o repositório de confiança do sistema

---

## Recursos adicionais

**Capítulos relacionados:**
- Capítulo 6: Repositório de confiança no RHEL — aprofundamento

**Documentação:**
- `man update-ca-trust`
- `/usr/share/doc/ca-certificates/`

---

## Próximos passos

**Laboratórios fundamentais concluídos!** Agora você pode:
- Prosseguir para o **Lab 06: Configuração HTTPS no Apache** para configuração de serviços
- Ou explorar automação com o **Lab 11: Noções Básicas do certmonger**
- Ou ir direto ao **Lab 15: Cenários de Resolução de Problemas** para prática guiada

---

**Nível de dificuldade**: Iniciante
