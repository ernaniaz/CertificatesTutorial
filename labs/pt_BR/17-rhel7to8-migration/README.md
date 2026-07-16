# Lab 17: Migração de Certificados RHEL 7→8

## Objetivos de aprendizagem

Ao concluir este laboratório, você irá:
- Entender compatibilidade de certificados entre RHEL 7 e 8
- Migrar certificados durante upgrade do SO
- Lidar com introdução das crypto-policies
- Atualizar configurações de certificados
- Testar certificados após migração
- Resolver problemas de migração

## Pré-requisitos

- **Compreensão das diferenças entre RHEL 7 e 8**
- **Labs 01-10** concluídos (fundamentos de certificados)
- **O lab abrange ambos os sistemas** — execute avaliação/backup/preparação no RHEL 7 e depois execute `configure-rhel8.sh` e `validate-migration.sh` no sistema RHEL 8 já atualizado
- **Acesso ao sistema:** Root/sudo necessário

## Tempo estimado

**40-50 minutos**

## Visão geral

RHEL 8 introduz mudanças significativas no gerenciamento de certificados, principalmente o sistema crypto-policies. Aprenda a migrar certificados do RHEL 7 para RHEL 8 mantendo segurança e compatibilidade.

---

## Principais diferenças: RHEL 7 vs RHEL 8

### Crypto-Policies

**RHEL 7:**
- Sem crypto-policies em todo o sistema
- Configuração TLS manual em cada serviço
- Configuração de cifras específica por aplicativo

**RHEL 8:**
- Framework crypto-policies em todo o sistema
- Padrões criptográficos centralizados
- Configuração automática para serviços

### Protocolos TLS

**RHEL 7:**
- TLS 1.0, 1.1, 1.2 suportados por padrão
- Seleção manual de protocolos
- Cifras antigas permitidas

**RHEL 8:**
- TLS 1.2+ por padrão (política DEFAULT)
- TLS 1.0/1.1 desabilitados
- Requisitos de cifras mais fortes

### Validação de certificados

**RHEL 7:**
- Validação mais permissiva
- Assinaturas SHA-1 permitidas
- Requisitos de certificados mais flexíveis

**RHEL 8:**
- Validação mais rigorosa
- SHA-1 bloqueado na política DEFAULT
- SANs preferidos em relação ao CN

---

## Instruções

### Passo 1: Avaliação pré-migração

Avalie o estado atual dos certificados:

```bash
./assess-rhel7.sh
```

Isso verifica:
- Certificados atuais
- Configurações TLS
- Possíveis problemas de compatibilidade
- Serviços que usam certificados

---

### Passo 2: Backup de certificados

Faça backup de todos os certificados antes da migração:

```bash
sudo ./backup-certificates.sh
```

Cria backup abrangente de:
- Todos os arquivos de certificados
- Arquivos de configuração
- Repositório de confiança
- Configurações de serviços

---

### Passo 3: Preparação para migração

Prepare-se para a migração:

```bash
./prepare-migration.sh
```

Isso:
- Identifica certificados incompatíveis
- Verifica assinaturas SHA-1
- Revisa configurações TLS
- Cria checklist de migração

---

### Passo 4: Configuração pós-upgrade (RHEL 8)

No sistema RHEL 8 já atualizado, configure as crypto-policies:

```bash
sudo ./configure-rhel8.sh
```

Isso:
- Define crypto-policy apropriada
- Atualiza configurações de serviços
- Migra configurações TLS
- Testa conectividade

---

### Passo 5: Validar migração no RHEL 8

No sistema RHEL 8 já atualizado, verifique se tudo funciona:

```bash
./validate-migration.sh
```

Testa:
- Validade dos certificados
- Funcionalidade dos serviços
- Conexões TLS
- Aplicação de crypto-policies

---

## Validação

Verifique a migração bem-sucedida no RHEL 8:

```bash
./validate-migration.sh
```

**Resultados esperados:**
- ✓ Todos os serviços em execução no RHEL 8
- ✓ Certificados válidos e aceitos
- ✓ Crypto-policies ativas e aplicadas
- ✓ Conexões TLS funcionando
- ✓ Sem erros de compatibilidade nos logs

**Verificações manuais:**
1. Verifique crypto-policy: `update-crypto-policies --show`
2. Teste conexões de serviços: `curl https://localhost`
3. Verifique validade do certificado: `openssl s_client -connect localhost:443`
4. Verifique logs de serviços por erros

---

## Checklist de migração

### Antes da migração (RHEL 7)

- [ ] Documentar todos os certificados em uso
- [ ] Fazer backup dos arquivos de certificados
- [ ] Fazer backup das configurações de serviços
- [ ] Testar funcionalidade atual
- [ ] Identificar certificados SHA-1
- [ ] Verificar datas de expiração dos certificados
- [ ] Documentar configurações TLS personalizadas

### Durante a migração

- [ ] Realizar upgrade do SO para RHEL 8
- [ ] Preservar diretório `/etc/pki/`
- [ ] Anotar avisos de crypto-policy
- [ ] Manter logs de migração

### Após a migração (RHEL 8)

- [ ] Verificar se certificados estão presentes
- [ ] Verificar configuração de crypto-policy
- [ ] Atualizar configs de serviços para crypto-policies
- [ ] Testar todos os serviços
- [ ] Substituir certificados SHA-1 se necessário
- [ ] Atualizar monitoramento
- [ ] Documentar alterações

---

## Problemas comuns

### Problema: Clientes TLS 1.0/1.1 falham

**Sintoma:** Clientes antigos não conseguem conectar após migração

**Solução:**
```bash
# Use LEGACY temporariamente
sudo update-crypto-policies --set LEGACY

# Ou crie política personalizada permitindo TLS 1.0/1.1
```

---

### Problema: Certificados SHA-1 rejeitados

**Sintoma:** Certificados com assinaturas SHA-1 falham

**Solução:**
```bash
# Substitua por certificados SHA-256
# Ou use LEGACY temporariamente
sudo update-crypto-policies --set LEGACY
```

---

### Problema: Serviço não inicia

**Sintoma:** Serviço falha após migração com erros SSL

**Solução:**
```bash
# Verifique configuração do serviço
journalctl -xeu service-name

# Atualize para usar crypto-policies
# Remova configurações manuais de protocolo/cifra TLS
```

---

## Boas práticas

### Requisitos de certificados para RHEL 8

1. **Use SHA-256 ou superior** - Sem SHA-1
2. **Inclua SANs** - Não dependa apenas do CN
3. **RSA 2048+ ou ECC** - Tamanhos de chave fortes
4. **Cadeia de certificados válida** - Inclua intermediários
5. **Não expirado** - Datas válidas

### Migração de configuração

**Remova das configs de serviços:**
- Configurações manuais `SSLProtocol`
- Configurações manuais `SSLCipherSuite`
- Versões TLS codificadas
- Listas de cifras

**Deixe crypto-policies gerenciarem:**
- Versões de protocolo TLS
- Seleção de conjuntos de cifras
- Níveis de segurança

---

## Limpeza

```bash
sudo ./cleanup.sh
```

Remove artefatos de migração e arquivos de teste.

---

## Recursos adicionais

**Capítulos relacionados:**
- Capítulo 35: Migração RHEL 7→8
- Capítulo 10: RHEL 8 e Crypto-Policies

**Documentação:**
- Guia de upgrade do RHEL 8
- `man update-crypto-policies`
- `/usr/share/doc/crypto-policies/`

**Principais mudanças:**
- https://access.redhat.com/articles/3642912 (Crypto-policies)
- https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/

---

## Próximos passos

Prossiga para o **Lab 18: Migração RHEL 8→9** para aprender o próximo caminho de upgrade.

---

**Nível de dificuldade**: Avançado  
**Nota**: Teste a migração em ambiente não produtivo primeiro
