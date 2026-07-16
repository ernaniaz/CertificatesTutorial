# Lab 11: Noções Básicas do certmonger

## Objetivos de aprendizagem

Ao concluir este laboratório, você irá:
- Instalar e configurar o certmonger
- Solicitar certificados autoassinados
- Solicitar certificados de CA local
- Acompanhar expiração de certificados
- Configurar renovação automática
- Configurar comandos pós-salvamento para reinício de serviços
- Entender o uso do comando getcert

## Pré-requisitos

- **Labs 01-05** concluídos
- **Versão do RHEL:** 7, 8, 9 ou 10
- **Acesso ao sistema:** Root/sudo necessário
- Pacote **certmonger** disponível

## Tempo estimado

**40-50 minutos**

## Visão geral

certmonger é um daemon de acompanhamento e renovação de certificados para RHEL. Aprenda a usá-lo para gerenciamento automático do ciclo de vida de certificados, incluindo solicitação, acompanhamento e renovação sem intervenção manual.

---

## Instruções

### Passo 1: Instale o certmonger

Instale o serviço certmonger:

```bash
sudo ./install-certmonger.sh
```

Isso instala:
- Daemon `certmonger`
- Inicia e habilita o serviço
- Configura definições básicas

---

### Passo 2: Solicite certificado autoassinado

Solicite um certificado autoassinado:

```bash
sudo ./request-self-signed.sh
```

Isso:
- Usa o comando `getcert request`
- Cria certificado e chave
- Acompanha status do certificado
- Exibe detalhes do certificado

---

### Passo 3: Solicite de CA local

Solicite certificado de CA local:

```bash
sudo ./request-local-ca.sh
```

Isso:
- Configura CA local com certmonger
- Solicita certificado assinado pela CA
- Configura definições de renovação
- Testa o acompanhamento

---

### Passo 4: Verifique status do certificado

Verifique o status de acompanhamento dos certificados:

```bash
./check-status.sh
```

Isso mostra:
- Todos os certificados acompanhados
- Datas de expiração
- Status de renovação
- IDs de acompanhamento

---

### Passo 5: Teste renovação

Simule renovação de certificado:

```bash
sudo ./test-renewal.sh
```

Isso:
- Força renovação do certificado
- Testa processo de renovação automática
- Verifica comandos pós-salvamento
- Verifica novo certificado

---

### Passo 6: Verifique a configuração

Execute a validação abrangente:

```bash
sudo ./verify.sh
```

---

## Validação

```bash
sudo ./test.sh
```

Todas as verificações devem passar.

## Resultado esperado

Após concluir este laboratório:
- ✅ certmonger instalado e em execução
- ✅ Certificado autoassinado acompanhado
- ✅ Certificado de CA local acompanhado
- ✅ Renovação automática configurada
- ✅ Compreensão do fluxo do certmonger

---

## Conceitos-chave

### Arquitetura do certmonger

```
certmonger daemon (certmonger.service)
    ↓
Banco de dados de acompanhamento de certificados
    ↓
CAs (Autoridades certificadoras)
  - Autoassinado
  - CA local (certmonger-local)
  - CA IPA
  - Provedores ACME
```

### Comando getcert

**Solicitar certificado:**
```bash
getcert request \
  -f /path/to/cert.crt \
  -k /path/to/key.key \
  -c IPA \
  -N CN=server.example.com
```

**Listar certificados:**
```bash
getcert list
getcert list -i <request-id>
```

**Verificar status:**
```bash
getcert status -i <request-id>
```

**Forçar renovação:**
```bash
getcert resubmit -i <request-id>
getcert refresh -i <request-id>
```

**Parar acompanhamento:**
```bash
getcert stop-tracking -i <request-id>
# ou
getcert stop-tracking -f /path/to/cert.crt
```

### Estados do certificado

| Estado | Descrição |
|--------|-----------|
| MONITORING | Certificado acompanhado, renovará automaticamente |
| NEED_GUIDANCE | Intervenção manual necessária |
| SUBMITTING | Solicitação sendo enviada |
| GENERATING_KEY | Gerando par de chaves |
| ISSUED | Certificado emitido com sucesso |

### Comandos pós-salvamento

Execute comandos após renovação do certificado:

```bash
getcert request \
  -f /etc/httpd/cert.crt \
  -k /etc/httpd/key.key \
  -C "systemctl reload httpd"
```

### Tempo de renovação

- certmonger verifica certificados diariamente
- Padrão: renovar quando restam <30 dias
- Configurável com opção `-T`
- Pode forçar renovação imediata

---

## Resolução de problemas

### Problema: certmonger não está em execução

**Sintoma:**
```
Cannot connect to certmonger service
```

**Solução:**
Inicie o serviço:
```bash
systemctl start certmonger
systemctl enable certmonger
systemctl status certmonger
```

---

### Problema: Solicitação de certificado travada

**Sintoma:**
```
status: SUBMITTING
stuck: yes
```

**Solução:**
Verifique logs e reenvie:
```bash
journalctl -u certmonger | tail -50
getcert resubmit -i <request-id>
# Ou pare e comece de novo
getcert stop-tracking -i <request-id>
```

---

### Problema: CA não disponível

**Sintoma:**
```
CA 'IPA' not available
```

**Solução:**
Liste CAs disponíveis:
```bash
getcert list-cas
# Use CA disponível (como 'local' para autoassinado)
getcert request -c local ...
```

---

### Problema: Permissão negada

**Sintoma:**
```
unable to write certificate file
```

**Solução:**
Verifique permissões do diretório:
```bash
# certmonger executa como root, mas verifique:
ls -ld /path/to/cert/directory
# Certifique-se de que o diretório existe e é gravável
mkdir -p /path/to/certs
chmod 755 /path/to/certs
```

---

## Notas específicas por versão

### RHEL 7
- Usa `yum` para instalação
- certmonger 0.79.x normalmente
- Suporte básico a CA
- Autoassinado e CA local

### RHEL 8
- Usa `dnf` para instalação
- certmonger 0.79.x
- Suporte aprimorado a CA
- Melhor integração com IPA

### RHEL 9
- certmonger 0.79.x ou mais recente
- Suporte ACME aprimorado
- Melhor tratamento de erros
- Registro de logs aprimorado

---

## Limpeza

```bash
sudo ./cleanup.sh
```

Isso remove o certmonger e certificados acompanhados.

---

## Recursos adicionais

**Capítulos relacionados:**
- Capítulo 22: Domínio do certmonger

**Documentação:**
- `man getcert`
- `man getcert-request`
- `man getcert-list`
- `man certmonger`
- `/usr/share/doc/certmonger/`

**Comandos úteis:**
```bash
# Listar todos os certificados acompanhados
getcert list

# Exibir status detalhado
getcert list -i <ID>

# Listar CAs disponíveis
getcert list-cas

# Atualizar todos os certificados
getcert refresh-ca -c <CA-name>

# Visualizar logs do certmonger
journalctl -u certmonger -f
```

---

## Próximos passos

Prossiga para o **Lab 12: Crypto-Policies** para aprender gerenciamento de políticas criptográficas em todo o sistema.

---

**Nível de dificuldade**: Intermediário a avançado
