# Lab 22: HashiCorp Vault PKI

## Objetivos de aprendizagem

Ao concluir este laboratório, você irá:
- Entender o mecanismo de segredos PKI dinâmico do Vault
- Instalar e configurar HashiCorp Vault em modo dev
- Habilitar e configurar o mecanismo de segredos PKI
- Criar hierarquia de CA raiz e intermediária
- Configurar roles PKI para emissão de certificados
- Emitir certificados dinamicamente via API/CLI
- Entender benefícios de certificados de curta duração
- Revogar certificados e gerenciar CRLs

## Pré-requisitos

- **Dependências de laboratório:** Labs 01-05 concluídos (noções básicas de certificados)
- **Versão do RHEL:** RHEL 8, 9 ou 10
- **Acesso ao sistema:** Privilégios de root ou sudo necessários
- **Requisitos adicionais:**
  - curl instalado
  - jq instalado (para parsing JSON)
  - Conectividade com internet para download do Vault
  - 1GB de RAM disponível

## Tempo estimado

**35-45 minutos** (inclui instalação do Vault e configuração PKI)

## Visão geral

HashiCorp Vault fornece um sistema PKI dinâmico onde certificados são emitidos sob demanda com tempos de vida (TTL) curtos. Essa abordagem reduz a necessidade de revogação de certificados e simplifica o gerenciamento do ciclo de vida. O Vault centraliza a aplicação de políticas e fornece gerenciamento de certificados orientado por API.

---

## Por que usar Vault para PKI?

### Benefícios

**Emissão dinâmica de certificados:**
- Certificados criados sob demanda
- TTL curto (minutos a horas) reduz necessidade de revogação
- Renovação automática via agentes Vault

**Política centralizada:**
- Controle de acesso baseado em roles
- Políticas de certificados consistentes
- Registro de auditoria de todas as operações

**Orientado a API:**
- REST API para automação
- CLI para operações manuais
- Integração fácil com CI/CD

**Segurança:**
- Chaves privadas nunca saem do Vault
- Rotação automática
- Armazenamento seguro de secrets

---

## Arquitetura Vault PKI

```
┌─────────────────────────────────────┐
│         CA raiz (interna)           │
│     Longa duração (10 anos)            │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│      CA intermediária                 │
│     Duração média (5 anos)           │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│    Certificados finais (dinâmicos)       │
│    Curta duração (horas a dias)       │
│    Emitidos via roles                  │
└─────────────────────────────────────┘
```

---

## Instruções

### Passo 1: Instale o Vault

Baixe e instale HashiCorp Vault:

```bash
./install-vault.sh
```

**O que isto faz:**
- Baixa binário Vault da HashiCorp
- Instala em /usr/local/bin/
- Verifica instalação
- Verifica versão

**Saída orientativa:**
```
Cabeçalho da etapa atual
Mensagens sobre reaproveitamento de uma instalação existente ou download do Vault
Verificação da versão instalada
Resumo final com comandos rápidos e o próximo passo recomendado
```

**Verificação:**
```bash
vault version
vault --help
```

---

### Passo 2: Inicie Vault em modo dev

Inicie servidor Vault em modo de desenvolvimento:

```bash
./start-vault-dev.sh
```

**Notas importantes:**
- ⚠️ **Modo dev NÃO é para produção** - todos os dados armazenados em memória
- ⚠️ Vault executa já desbloqueado (`unsealed`) e com token raiz
- ⚠️ Dados são perdidos quando Vault para
- 💡 Perfeito para aprendizado e testes

**Saída orientativa:**
```
Checagem de pré-requisitos e de processos Vault já existentes
Inicialização do Vault em modo dev e espera até ele responder
Gravação de `vault-env.sh`
Resumo com o endereço do Vault, o token raiz `root`, o PID real e avisos de segurança próprios do modo dev
```

**Verificação:**
```bash
source vault-env.sh
vault status
```

---

### Passo 3: Habilite o mecanismo de segredos PKI

Habilite o mecanismo de segredos PKI:

```bash
./enable-pki.sh
```

**O que isto faz:**
- Habilita o mecanismo de segredos PKI no caminho `pki/`
- Configura TTL máximo de lease
- Configura backend PKI

**Saída orientativa:**
```
Carregamento do ambiente do Vault
Checagem de acessibilidade do Vault
Habilitação de `pki/` ou aviso de que ele já estava habilitado
Ajuste do TTL máximo e resumo com os próximos passos
```

**Verificação:**
```bash
vault secrets list
```

---

### Passo 4: Configure CA raiz

Gere CA raiz interna:

```bash
./configure-root-ca.sh
```

**O que isto faz:**
- Gera certificado CA raiz internamente
- Define common name e TTL
- Configura URLs de certificado emissor
- Configura pontos de distribuição CRL

**Saída orientativa:**
```
Geração da CA raiz interna
Configuração de URLs de certificado emissor e CRL
Resumo com o common name, o TTL configurado e as URLs reais publicadas pelo Vault
```

**Verificação:**
```bash
vault read pki/cert/ca
```

---

### Passo 5: Configure CA intermediária

Configure CA intermediária para emitir certificados finais:

```bash
./configure-intermediate-ca.sh
```

**O que isto faz:**
- Habilita o mecanismo de segredos PKI em `pki_int/`
- Gera CSR de CA intermediária
- Assina CSR intermediário com CA raiz
- Define certificado intermediário
- Configura URLs da CA intermediária

**Saída orientativa:**
```
Carregamento do ambiente e checagem de que a CA raiz existe
Habilitação ou reaproveitamento de `pki_int/`
Geração de `intermediate.csr`, assinatura pela CA raiz e importação do certificado intermediário
Configuração de URLs e verificação opcional da cadeia com OpenSSL
```

**Verificação:**
```bash
vault read pki_int/cert/ca
```

---

### Passo 6: Crie role PKI

Crie role para emissão de certificados:

```bash
./create-role.sh
```

**O que isto faz:**
- Cria role PKI chamada "web-server"
- Define domínios permitidos
- Define TTL padrão e máximo
- Configura políticas de certificados

**Saída orientativa:**
```
Checagem de que `pki_int/` está pronto
Criação da role PKI `web-server`
Leitura posterior da configuração real da role a partir do Vault
Exemplos de uso para emitir certificados com nomes e TTLs diferentes
```

**Verificação:**
```bash
vault read pki_int/roles/web-server
```

---

### Passo 7: Emita certificados

Emita certificados usando a role configurada:

```bash
./issue-certificate.sh
```

**O que isto faz:**
- Emite múltiplos certificados de teste
- Demonstra diferentes common names
- Mostra detalhes dos certificados
- Salva certificados em arquivos

**Saída orientativa:**
```
Carregamento do ambiente do Vault e checagem da role PKI
Emissão de vários certificados de teste com números de série reais e arquivos em `certs/`
Resumo dos certificados gerados
Verificação adicional com OpenSSL, que pode mostrar avisos dependendo do ambiente de teste
```

**Verificação:**
```bash
openssl x509 -in certs/server01.lab.local.crt -noout -text
openssl verify -CAfile certs/server01.lab.local-ca.crt certs/server01.lab.local.crt
```

---

### Passo 8: Revogue certificado (opcional)

Demonstre revogação de certificado:

```bash
./revoke-certificate.sh
```

**O que isto faz:**
- Revoga certificado de teste
- Atualiza CRL
- Verifica revogação

**Saída orientativa:**
```
Carregamento do ambiente e escolha do certificado mais recente ou do alvo informado
Confirmação interativa antes da revogação
Revogação do certificado, download de `crl.pem` e checagem se o número de série aparece na CRL
Resumo com comandos para inspecionar a CRL
```

**Verificação:**
```bash
vault write pki_int/revoke serial_number="xx:xx:xx:xx"
vault read pki_int/cert/crl
```

---

## Validação

Para verificar se o laboratório foi concluído, execute o script de validação:

```bash
./verify.sh
```

**Resultado orientativo:**
```
Verificações PASS/FAIL para o processo Vault, acesso à API, mecanismos PKI, CA raiz, CA intermediária, role PKI e certificados emitidos
Resumo com o número de testes aprovados e falhos
Se tudo estiver correto, mensagem de conclusão do lab
Se algo falhar, bloco de troubleshooting com comandos para revisar `vault status`, `vault-env.sh` e os scripts anteriores
```

---

## Resultado esperado

Após concluir este laboratório, você deve ter:
- ✅ Vault instalado e em execução em modo dev
- ✅ Mecanismo de segredos PKI configurado
- ✅ Hierarquia de CA raiz e intermediária
- ✅ Role PKI configurada para emissão de certificados
- ✅ Certificados emitidos dinamicamente
- ✅ Compreensão de revogação de certificados

Você pode verificar executando:
- `vault status` (deve mostrar unsealed)
- `vault secrets list` (deve mostrar pki/ e pki_int/)
- Listando certificados emitidos no diretório `certs/`

---

## Resolução de problemas

### Problema 1: Vault não inicia

**Sintoma:**
```
Error: Failed to start Vault server
```

**Causa:**
- Porta 8200 já em uso
- Vault já em execução

**Solução:**
```bash
# Verifique se Vault está em execução
ps aux | grep vault

# Encerre processos Vault existentes
pkill vault

# Verifique disponibilidade da porta
ss -tulpn | grep 8200

# Reinicie Vault
./start-vault-dev.sh
```

---

### Problema 2: Conexão recusada

**Sintoma:**
```
Error: Get "http://127.0.0.1:8200/v1/sys/health": dial tcp 127.0.0.1:8200: connect: connection refused
```

**Causa:**
- Vault não em execução
- VAULT_ADDR não definido

**Solução:**
```bash
# Verifique status do Vault
vault status

# Certifique-se de que variáveis de ambiente estão definidas
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

# Ou carregue o arquivo de ambiente
source vault-env.sh
```

---

### Problema 3: Permissão negada

**Sintoma:**
```
Error: permission denied
```

**Causa:**
- Token inválido ou expirado
- Token errado usado

**Solução:**
```bash
# Use o token raiz de start-vault-dev.sh
export VAULT_TOKEN='root'

# Ou faça login novamente
vault login root
```

---

### Problema 4: mecanismo PKI não encontrado

**Sintoma:**
```
Error: namespace not found
```

**Causa:**
- Mecanismo PKI não habilitado
- Caminho errado

**Solução:**
```bash
# Liste os mecanismos de segredos habilitados
vault secrets list

# Re-habilite PKI se necessário
./enable-pki.sh
```

---

## Notas específicas por versão

### RHEL 8
- Todos os recursos suportados
- Use dnf para instalar dependências
- SELinux pode afetar arquivos locais do Vault

### RHEL 9
- Todos os recursos suportados
- Compatível com OpenSSL 3.x
- Compatibilidade total com Vault

### RHEL 10
- Versão mais recente do Vault suportada
- Todos os recursos modernos disponíveis
- Desempenho ideal

---

## Limpeza

Para redefinir o sistema e parar o Vault:

```bash
./cleanup.sh
```

**Aviso:** Isto irá:
- Parar servidor Vault
- Excluir todos os dados PKI (somente modo dev)
- Remover certificados gerados
- Limpar arquivos temporários

**Limpeza manual:**
```bash
# Parar Vault
pkill vault

# Remover certificados
rm -rf certs/

# Remover arquivo de ambiente
rm -f vault-env.sh
```

---

## Tópicos avançados

### Implantação em produção

**Principais diferenças:**
- Use backend de armazenamento (Consul, etcd, etc.)
- Habilite TLS para API Vault
- Use processo de inicialização e unseal
- Implemente cluster HA
- Use métodos de autenticação (não token raiz)
- Habilite registro de auditoria

**Exemplo de início em produção:**
```bash
vault server -config=/etc/vault/config.hcl
```

### Certificados de curta duração

**Benefícios:**
- Reduz necessidade de revogação
- Limita janela de exposição
- Simplifica gerenciamento de certificados

**Exemplo TTL de 1 hora:**
```bash
vault write pki_int/issue/web-server \
    common_name="temp.example.com" \
    ttl="1h"
```

### Renovação automática Vault Agent

Vault Agent pode renovar certificados automaticamente:

```hcl
# vault-agent.hcl
auto_auth {
  method "approle" {
    config = {
      role_id_file_path = "roleid"
      secret_id_file_path = "secretid"
    }
  }
}

template {
  source      = "cert.tpl"
  destination = "/etc/tls/server.pem"
  command     = "systemctl reload nginx"
}
```

### Uso da API

**Emitir certificado via API:**
```bash
curl -X POST \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -d '{"common_name":"api.example.com","ttl":"24h"}' \
  http://127.0.0.1:8200/v1/pki_int/issue/web-server
```

**Revogar via API:**
```bash
curl -X POST \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -d '{"serial_number":"xx:xx:xx:xx"}' \
  http://127.0.0.1:8200/v1/pki_int/revoke
```

---

## Recursos adicionais

**Capítulos relacionados:**
- Apêndice B: HashiCorp Vault (teoria detalhada)
- Lab 21: Kubernetes cert-manager (automação similar)
- Capítulo 22: Domínio do certmonger (automação nativa RHEL)

**Documentação:**
- Vault PKI Secrets Engine: https://developer.hashicorp.com/vault/docs/secrets/pki
- Documentação API Vault: https://developer.hashicorp.com/vault/api-docs
- Endurecimento de produção: https://developer.hashicorp.com/vault/tutorials/operations/production-hardening

**Leitura adicional:**
- Whitepaper de segredos dinâmicos
- Arquitetura Zero Trust com Vault
- Automação do ciclo de vida de certificados

---

## Próximos passos

Após concluir este laboratório, você pode:
1. **Revisar:** Todos os 22 laboratórios concluídos! 🎉
2. **Praticar:** Implantar Vault em ambiente mais próximo de produção
3. **Integrar:** Conectar Vault com suas aplicações
4. **Explorar:** Métodos de autenticação e políticas do Vault
5. **Avançado:** Configurar cluster HA do Vault

---

## Casos de uso do mundo real

**Microsserviços:**
- Cada serviço recebe certificados de curta duração
- Renovação automática via agente Vault
- Políticas de certificados consistentes

**Pipelines CI/CD:**
- Certificados dinâmicos para agentes de build
- Credenciais temporárias para implantações
- Provisionamento automatizado de certificados

**TLS de banco de dados:**
- Certificados dinâmicos de banco de dados
- Rotação automática
- Gerenciamento centralizado

**Service mesh:**
- Integração com Consul Connect
- Certificados mTLS automáticos
- Autenticação serviço a serviço

---

## Comparação: Vault vs cert-manager vs certmonger

| Recurso | Vault PKI | cert-manager | certmonger |
|---------|-----------|--------------|------------|
| Plataforma | Qualquer | Kubernetes | RHEL |
| Certificados | Dinâmicos | Declarativos | Acompanhados |
| TTL padrão | Horas-Dias | Dias-Meses | Meses |
| Integração CA | Integrada | Externa | Externa |
| API | REST | Kubernetes | D-Bus |
| Melhor para | Microsserviços | Cargas K8s | Serviços RHEL |

---

**Versões do RHEL testadas**: 8, 9, 10  
**Nível de dificuldade**: Avançado  
**Parabéns por concluir todos os 22 laboratórios!** 🎉
