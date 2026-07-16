# Lab 18: Migração de Certificados RHEL 8→9

## Objetivos de aprendizagem

Ao concluir este laboratório, você irá:
- Entender mudanças de certificados no RHEL 9
- Lidar com migração OpenSSL 3.x
- Lidar com padrões de segurança mais rigorosos
- Atualizar algoritmos obsoletos
- Testar certificados após upgrade
- Resolver problemas específicos do RHEL 9

## Pré-requisitos

- **Compreensão das diferenças entre RHEL 8 e 9**
- **Labs 01-17** concluídos
- **O lab abrange ambos os sistemas** — execute avaliação/backup/verificações de compatibilidade no RHEL 8 e depois execute `configure-rhel9.sh` e `validate-migration.sh` no sistema RHEL 9 já atualizado
- **Acesso ao sistema:** Root/sudo necessário

## Tempo estimado

**40-50 minutos**

## Visão geral

RHEL 9 introduz OpenSSL 3.x com padrões de segurança mais rigorosos. Aprenda a migrar certificados adaptando-se a requisitos de segurança aprimorados e tratamento de algoritmos obsoletos.

---

## Principais diferenças: RHEL 8 vs RHEL 9

### Versão OpenSSL

**RHEL 8:**
- OpenSSL 1.1.1
- Padrões mais permissivos
- Suporte a algoritmos legados

**RHEL 9:**
- OpenSSL 3.0+
- Padrões de segurança mais rigorosos
- Algoritmos legados em provider separado
- Avisos de obsolescência aprimorados

### Padrões de segurança

**RHEL 8:**
- Política DEFAULT permite algumas opções antigas
- Assinaturas SHA-1 permitidas em LEGACY
- Validação de certificados mais leniente

**RHEL 9:**
- Política DEFAULT mais rigorosa
- SHA-1 completamente bloqueado
- SANs obrigatórios (somente CN obsoleto)
- Tamanhos mínimos de chave aplicados

### Crypto-Policies

**RHEL 8:**
- DEFAULT, LEGACY, FUTURE, FIPS
- Em todo o sistema, mas com exceções

**RHEL 9:**
- Mesmos níveis de política
- Aplicação mais rigorosa
- Melhor integração com OpenSSL 3
- Provider legacy para compatibilidade

---

## Instruções

### Passo 1: Avaliação pré-migração

Avalie o estado dos certificados no RHEL 8:

```bash
./assess-rhel8.sh
```

Verifica:
- Compatibilidade dos certificados atuais
- Uso de OpenSSL 1.1.1
- Algoritmos obsoletos
- Configurações de serviços

---

### Passo 2: Backup de tudo

Faça backup dos certificados no host RHEL 8 atual antes do upgrade:

```bash
sudo ./backup-certificates.sh
```

Faz backup de:
- Todos os certificados e chaves em `/etc/pki/`
- Configurações de serviços (Apache, NGINX, Postfix, OpenLDAP quando presentes)
- Configuração e política atual de crypto-policies
- Arquivo compactado para armazenamento externo

---

### Passo 3: Identifique problemas de compatibilidade

Encontre possíveis problemas:

```bash
./check-compatibility.sh
```

Identifica:
- Certificados sem SANs
- Tamanhos de chave fracos
- Algoritmos obsoletos
- Problemas de configuração

---

### Passo 4: Configuração pós-upgrade (RHEL 9)

No sistema RHEL 9 já atualizado:

```bash
sudo ./configure-rhel9.sh
```

Configura:
- Configurações OpenSSL 3.x
- Crypto-policies atualizadas
- Adaptações de serviços
- Provider legacy se necessário

---

### Passo 5: Validar migração no RHEL 9

No sistema RHEL 9 já atualizado, execute a validação abrangente:

```bash
./validate-migration.sh
```

Testa:
- Funcionalidade OpenSSL 3.x
- Validade dos certificados
- Operações de serviços
- Conexões TLS

---

## Checklist de migração

### Antes da migração (RHEL 8)

- [ ] Fazer backup de todos os certificados
- [ ] Documentar crypto-policy
- [ ] Verificar certificados somente CN
- [ ] Verificar tamanhos de chave (RSA 2048+)
- [ ] Testar cadeias de certificados
- [ ] Documentar configs OpenSSL personalizadas
- [ ] Verificar algoritmos legados

### Durante a migração

- [ ] Realizar upgrade do SO para RHEL 9
- [ ] Anotar avisos OpenSSL 3.x
- [ ] Preservar configurações
- [ ] Manter logs de upgrade

### Após a migração (RHEL 9)

- [ ] Verificar OpenSSL 3.x ativo
- [ ] Verificar crypto-policy
- [ ] Testar todos os serviços
- [ ] Atualizar certificados se necessário
- [ ] Habilitar provider legacy se exigido
- [ ] Validar conexões TLS
- [ ] Atualizar monitoramento

---

## Validação

Verifique migração bem-sucedida para RHEL 9:

```bash
./validate-migration.sh
```

**Resultados esperados:**
- ✓ OpenSSL 3.x ativo
- ✓ Todos os certificados usam assinaturas SHA-256+
- ✓ Certificados incluem SANs
- ✓ Serviços em execução sem erros
- ✓ Crypto-policies aplicadas
- ✓ Sem avisos de algoritmos obsoletos

**Verificação manual:**
1. Verifique versão OpenSSL: `openssl version`
2. Verifique certificados: `openssl x509 -in cert.pem -noout -text`
3. Teste conexões: `curl -v https://localhost`
4. Verifique SANs em todos os certificados
5. Revise logs por avisos de obsolescência

---

## Problemas comuns

### Problema: Certificado sem SAN

**Sintoma:** Certificado rejeitado, erro "no SAN"

**Solução:**
```bash
# Regenere com SANs ou use provider legacy temporariamente
# Para habilitar provider legacy:
sudo update-crypto-policies --set DEFAULT:FEDORA32
```

---

### Problema: Tamanho de chave fraco rejeitado

**Sintoma:** Chaves RSA <2048 bits rejeitadas

**Solução:**
```bash
# Regenere com chave maior
openssl genrsa -out new.key 2048
# Ou habilite provider legacy (não recomendado)
```

---

### Problema: Serviço não inicia

**Sintoma:** Erros de init SSL/TLS no OpenSSL 3.x

**Solução:**
```bash
# Verifique uso de API obsoleta
journalctl -xeu service-name

# Atualize aplicativo ou habilite provider legacy
# Edite /etc/pki/tls/openssl.cnf:
# openssl_conf = openssl_init
# [openssl_init]
# providers = provider_sect
# [provider_sect]
# default = default_sect
# legacy = legacy_sect
# [default_sect]
# activate = 1
# [legacy_sect]
# activate = 1
```

---

## Mudanças OpenSSL 3.x

### Arquitetura de providers

OpenSSL 3.x usa providers:
- **default** - Algoritmos padrão
- **legacy** - Algoritmos obsoletos (MD5, DES, etc.)
- **fips** - Algoritmos aprovados FIPS

### Habilitar provider legacy

```bash
# Em todo o sistema (não recomendado)
sudo tee -a /etc/pki/tls/openssl.cnf << 'EOF'
openssl_conf = openssl_init

[openssl_init]
providers = provider_sect

[provider_sect]
default = default_sect
legacy = legacy_sect

[default_sect]
activate = 1

[legacy_sect]
activate = 1
EOF
```

### Requisitos de certificados

**Requisitos RHEL 9:**
1. **SANs obrigatórios** - Não dependa apenas do CN
2. **RSA 2048+ bits** - Tamanho mínimo de chave
3. **Assinaturas SHA-256+** - Sem SHA-1
4. **Cadeia válida** - Cadeia de certificados completa
5. **Extensões adequadas** - Key usage, extended key usage

---

## Boas práticas

### Geração de certificados para RHEL 9

```bash
# Gerar com SANs
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout server.key -out server.crt -days 365 \
  -subj "/CN=server.example.com" \
  -addext "subjectAltName=DNS:server.example.com,DNS:www.example.com"
```

### Testar compatibilidade

```bash
# Testar com OpenSSL 3.x
openssl version
openssl s_client -connect localhost:443

# Verificar SANs do certificado
openssl x509 -in cert.pem -noout -ext subjectAltName

# Verificar com configurações rigorosas
openssl verify -CAfile ca.pem cert.pem
```

---

## Limpeza

```bash
sudo ./cleanup.sh
```

Remove artefatos de migração.

---

## Recursos adicionais

**Capítulos relacionados:**
- Capítulo 36: Migração RHEL 8→9
- Capítulo 11: Segurança Moderna no RHEL 9

**Documentação:**
- Notas de release do RHEL 9
- Guia de migração OpenSSL 3.x
- `man openssl-providers`

**Principais mudanças:**
- https://www.openssl.org/docs/man3.0/man7/migration_guide.html
- https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/

---

## Próximos passos

Você concluiu os laboratórios de migração! A seguir:
- **Labs 19-20:** Laboratórios de segurança (FIPS, Endurecimento)
- **Labs 21-22:** Tópicos avançados (Kubernetes, Vault)

---

**Nível de dificuldade**: Avançado  
**Nota**: OpenSSL 3.x exige testes cuidadosos
