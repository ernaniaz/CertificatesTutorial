# Lab 16: Procedimentos de Emergência para Certificados

## Objetivos de aprendizagem

Ao concluir este laboratório, você irá:
- Realizar substituição emergencial de certificados
- Criar certificados autoassinados temporários
- Contornar temporariamente verificação SSL (para testes)
- Restaurar rapidamente a partir de backups
- Reverter alterações de certificados
- Implementar procedimentos de recuperação de desastres

## Pré-requisitos

- **Labs 01-15** concluídos
- **Versão do RHEL:** 7, 8, 9 ou 10
- **Acesso ao sistema:** Root/sudo necessário
- **Calma sob pressão** necessária

## Tempo estimado

**30-40 minutos**

## Visão geral

Quando certificados falham em produção, você precisa de soluções rápidas. Este laboratório ensina procedimentos de emergência para restaurar o serviço rapidamente e implementar correções adequadas depois.

---

## Cenários de emergência

### Quando usar procedimentos de emergência

- Serviço de produção fora do ar por causa de certificado
- Certificado expirou durante a noite
- Certificado errado implantado
- Chave privada perdida
- CA inacessível para renovação
- Restauração imediata de serviço necessária

### Prioridade de resposta de emergência

1. **Restaurar serviço** - Colocar em funcionamento (pode usar certificado temporário)
2. **Avaliar impacto** - Entender o que aconteceu
3. **Implementar correção adequada** - Substituir solução temporária
4. **Evitar recorrência** - Corrigir causa raiz

---

## Instruções

### Substituição emergencial

Substitua rapidamente um certificado com falha:

```bash
sudo ./emergency-replacement.sh
```

Cria e implanta novo certificado imediatamente.

---

### Criar autoassinado temporário

Gere certificado autoassinado temporário:

```bash
sudo ./self-signed-temp.sh
```

Use quando:
- CA está inacessível
- Precisa de certificado imediato
- Ganhar tempo para solução adequada

---

### Contornar verificação SSL (somente testes)

Teste conectividade sem validar o certificado (somente resolução de problemas):

```bash
# curl: ignorar validação do certificado
curl -k https://localhost/

# openssl: conectar sem verificar a cadeia
openssl s_client -connect localhost:443 </dev/null
```

**AVISO:** Somente para resolução de problemas! Nunca em produção!

---

### Restaurar de backup

Restaure certificados a partir de backup:

```bash
sudo ./restore-backup.sh
```

Restaura certificados em estado conhecido e bom.

---

### Reverter alterações

Reverta alterações recentes de certificados:

```bash
sudo ./rollback.sh
```

Retorna ao estado anterior funcional.

---

## Scripts principais

### emergency-replacement.sh

**Finalidade:** Substituição rápida de certificado
**Use quando:** Certificado falhou, precisa de correção imediata
**Tempo:** <5 minutos
**Resultado:** Serviço restaurado com novo certificado

### self-signed-temp.sh

**Finalidade:** Criar certificado temporário
**Use quando:** CA indisponível, precisa de solução rápida
**Tempo:** <2 minutos
**Resultado:** Certificado autoassinado temporário implantado

### restore-backup.sh

**Finalidade:** Restaurar de backup
**Use quando:** Tem backup bom, precisa reverter
**Tempo:** <3 minutos
**Resultado:** Certificados em estado conhecido e bom restaurados

### rollback.sh

**Finalidade:** Desfazer alterações recentes
**Use quando:** Novo certificado está causando problemas
**Tempo:** <3 minutos
**Resultado:** Configuração anterior restaurada

---

## Checklist de emergência

Quando ocorrer emergência de certificado:

### Ações imediatas (0-5 minutos)

- [ ] Confirmar que o serviço está fora do ar
- [ ] Verificar expiração do certificado
- [ ] Verificar se arquivos de certificado/chave existem
- [ ] Verificar logs do serviço
- [ ] Avaliar impacto (quantos serviços/usuários)

### Correção rápida (5-15 minutos)

- [ ] Executar substituição emergencial
- [ ] OU implantar autoassinado temporário
- [ ] Reiniciar serviços afetados
- [ ] Testar funcionalidade básica
- [ ] Notificar stakeholders

### Correção adequada (15-60 minutos)

- [ ] Obter certificado adequado da CA
- [ ] Testar certificado antes da implantação
- [ ] Implantar certificado adequado
- [ ] Verificar toda funcionalidade
- [ ] Remover soluções temporárias

### Pós-incidente (após serviço restaurado)

- [ ] Documentar o que aconteceu
- [ ] Analisar causa raiz
- [ ] Implementar monitoramento
- [ ] Atualizar procedimentos
- [ ] Realizar post-mortem

---

## Validação

Para verificar seu conhecimento de procedimentos de emergência:

```bash
./verify.sh
```

**Resultados esperados:**
- ✓ `emergency-replacement.sh`, `self-signed-temp.sh`, `restore-backup.sh` e `rollback.sh` existem e são executáveis
- ✓ `/etc/pki/tls/certs` e `/etc/pki/tls/private` existem no sistema
- ✓ Diretórios de backup de emergência existentes em `/root/cert-backup-*` são contados e reportados
- ✓ Quaisquer arquivos `emergency.crt` ou `temp-*.crt` encontrados em `/etc/pki/tls/certs` são listados com detalhes de subject e validade

**Verificação manual:**
1. Você consegue gerar certificado temporário em < 2 minutos?
2. Você entende quando usar cada procedimento?
3. Você tem pelo menos um backup conhecido e válido para restaurar?
4. O plano de rollback está documentado e pronto para teste manual?

---

## Boas práticas

### Sempre tenha backups

```bash
# Backup antes de alterações
cp /etc/pki/tls/certs/server.crt /etc/pki/tls/certs/server.crt.backup
cp /etc/pki/tls/private/server.key /etc/pki/tls/private/server.key.backup

# Com timestamp
DATE=$(date +%Y%m%d-%H%M%S)
cp /etc/pki/tls/certs/server.crt /etc/pki/tls/certs/server.crt.$DATE
```

### Teste antes de implantar

```bash
# Teste se certificado corresponde à chave
diff <(openssl x509 -noout -modulus -in cert.pem | openssl md5) \
     <(openssl rsa -noout -modulus -in key.pem | openssl md5)

# Teste validade do certificado
openssl x509 -in cert.pem -noout -checkend 0

# Teste com serviço
# Implante primeiro em sistema de teste
```

### Documente tudo

- O que quebrou
- Quando quebrou
- O que você fez
- O que funcionou
- O que não funcionou
- Como evitar

---

## Cenários comuns de emergência

### Cenário: Certificado expirou durante a noite

```bash
# Correção rápida
sudo ./self-signed-temp.sh
sudo systemctl restart httpd

# Depois obtenha certificado adequado
sudo certbot renew --force-renewal
```

### Cenário: Certificado errado implantado

```bash
# Reverter
sudo ./rollback.sh
sudo systemctl restart nginx

# Verificar
curl -v https://localhost/
```

### Cenário: Chave privada perdida

```bash
# Gerar novo par
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout new.key -out new.crt -days 90

# Implantar
sudo cp new.crt /etc/pki/tls/certs/
sudo cp new.key /etc/pki/tls/private/
sudo systemctl restart httpd
```

---

## Limpeza

```bash
sudo ./cleanup.sh
```

Remove certificados de emergência e restaura estado normal.

---

## Recursos adicionais

**Capítulos relacionados:**
- Capítulo 33: Procedimentos de Emergência
- Capítulo 27: Metodologia de Solução de Problemas de Certificados RHEL

**Contatos de emergência:**
- Suporte da Certificate Authority
- Administradores de sistema
- Proprietários de aplicativos
- Escalação para gestão

**Ferramentas:**
- `openssl` - Geração de certificados
- `systemctl` - Gerenciamento de serviços
- `journalctl` - Análise de logs

---

## Próximos passos

Você concluiu os laboratórios de resolução de problemas! A seguir:
- **Labs 17-18:** Procedimentos de migração
- **Labs 19-20:** Segurança e FIPS
- **Labs 21-22:** Tópicos avançados (Kubernetes, Vault)

---

**Nível de dificuldade**: Avançado  
**Nota**: Pratique estes procedimentos antes de precisar deles!
