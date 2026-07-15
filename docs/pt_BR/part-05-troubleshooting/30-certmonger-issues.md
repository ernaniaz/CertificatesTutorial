# Capítulo 30: Solução de Problemas do certmonger

> **Problemas de Automação:** certmonger é a ferramenta de automatização de certificados do RHEL. Quando falha, certificados não renovam. Este capítulo ensina você a diagnosticar e corrigir problemas do certmonger rapidamente.

---

## 30.1 Valores de Status do certmonger

### Entendendo Mensagens de Status

| Status | Significado | Ação Requerida |
|--------|-------------|----------------|
| `MONITORING` | ✅ Tudo bem - cert emitido, rastreando expiração | Nenhuma |
| `SUBMITTING` | 🔄 Solicitando cert da CA | Aguardar (usualmente segundos) |
| `CA_UNREACHABLE` | ❌ Não consegue contatar servidor CA | Corrigir conectividade |
| `CA_REJECTED` | ❌ CA recusou requisição | Corrigir principal/permissões |
| `NEED_KEY_GEN_PIN` | ⏸️ Aguardando PIN (HSM) | Fornecer PIN |
| `NEED_GUIDANCE` | ⚠️ Necessita intervenção manual | Verificar detalhes requisição |
| `PRE_SAVE_COMMAND` | 🔄 Executando script pre-save | Aguardar |
| `POST_SAVE_COMMAND` | 🔄 Executando script post-save | Aguardar |
| `NEWLY_ADDED` | 🆕 Recém adicionado, ainda não processado | Aguardar |

---

## 30.2 Solução de Problemas CA_UNREACHABLE

### Problema Mais Comum do certmonger!

**Sintoma:**
```bash
sudo getcert list
# status: CA_UNREACHABLE
```

### Passos de Diagnóstico

```bash
#============================================#
# DIAGNOSTICAR CA_UNREACHABLE
#============================================#

# Passo 1: Qual CA estamos tentando alcançar?
sudo getcert list -v | grep "CA:"
# CA: IPA

# Passo 2: Conseguimos alcançar IPA?
ipa ping
# Pong!  ← Bom
# ipa: ERROR: cannot connect to 'https://ipa.example.com/ipa/xml'  ← Ruim!

# Passo 3: Verificar ticket Kerberos
klist
# Ticket cache: FILE:/tmp/krb5cc_0
# Valid starting     Expires            Service principal
# ...

# Passo 4: Verificar se ticket expirou
klist | grep "host/"
# Se sem ticket host ou expirado → Problema!

# Passo 5: Verificar status servidor IPA
ssh ipa.example.com "sudo ipactl status"

# Passo 6: Verificar rede
ping ipa.example.com
curl -k https://ipa.example.com/ipa/config/ca.crt

# Passo 7: Verificar DNS
nslookup ipa.example.com
```

### Soluções para CA_UNREACHABLE

**Solução 1: Renovar Ticket Kerberos**
```bash
# Obter novo ticket host
sudo kinit -k host/$(hostname -f)@REALM

# Verificar
klist

# Retentar requisição cert
sudo ipa-getcert resubmit -f /etc/pki/tls/certs/web.crt
```

**Solução 2: Verificar Servidor IPA**
```bash
# No servidor IPA
sudo ipactl status

# Se serviços desligados
sudo ipactl restart

# Verificar serviço específico
sudo systemctl status pki-tomcatd@pki-tomcat  # Serviço CA
```

**Solução 3: Rede/Firewall**
```bash
# Testar conectividade IPA
curl -vk https://ipa.example.com/ipa/xml

# Verificar firewall no servidor IPA
ssh ipa.example.com "sudo firewall-cmd --list-services | grep https"

# Verificar rotas
traceroute ipa.example.com
```

**Solução 4: Reiniciar certmonger**
```bash
sudo systemctl restart certmonger

# Aguardar um momento
sleep 10

# Verificar status
sudo getcert list
```

---

## 30.3 Solução de Problemas CA_REJECTED

### Quando CA Recusa a Requisição

**Sintoma:**
```bash
sudo getcert list -v
# status: CA_REJECTED
# ca-error: Server at https://ipa.example.com/ipa/xml unwilling to issue certificate
```

### Passos de Diagnóstico

```bash
#============================================#
# DIAGNOSTICAR CA_REJECTED
#============================================#

# Passo 1: Verificar detalhes do erro
sudo getcert list -v -f /etc/pki/tls/certs/web.crt
# Procurar campo 'ca-error'

# Passo 2: Principal de serviço existe?
ipa service-show HTTP/$(hostname -f)
# Se erro: Service not found

# Passo 3: Host está registrado?
ipa host-show $(hostname -f)

# Passo 4: Verificar se perfil certificado existe
sudo getcert list -v | grep "profile:"
ipa certprofile-show caIPAserviceCert

# Passo 5: Verificar detalhes da requisição
sudo getcert list -v | grep -A30 "Request ID"
```

### Soluções para CA_REJECTED

**Solução 1: Criar Principal de Serviço**
```bash
# Adicionar principal de serviço faltando
ipa service-add HTTP/$(hostname -f)

# Adicionar SAN (se necessário)
ipa service-mod HTTP/$(hostname -f) --addattr=cn=web.example.com

# Retentar
sudo ipa-getcert resubmit -f /etc/pki/tls/certs/web.crt
```

**Solução 2: Corrigir Entrada Host**
```bash
# Re-registrar no IPA se necessário
sudo ipa-client-install --force-join

# Verificar
ipa host-show $(hostname -f)
```

**Solução 3: Verificar Permissões**
```bash
# Verificar se você tem permissão para solicitar certs
ipa permission-find --name="Request Certificate"

# Verificar ACLs
ipa aci-find --name="*cert*"

# Pode necessitar admin IPA para conceder permissões
```

---

## 30.4 Falhas de Renovação

### Certificado Não Renovando

**Sintoma:** Certificado aproximando-se de expiração mas não renovando

**Diagnóstico:**
```bash
#============================================#
# DIAGNOSTICAR FALHA DE RENOVAÇÃO
#============================================#

# Passo 1: Verificar status atual
sudo getcert list -f /etc/pki/tls/certs/web.crt

# Passo 2: Quando deveria renovar?
# certmonger renova em 2/3 do tempo de vida cert
# cert de 365 dias → renova no dia 243 (122 dias antes expiração)

# Passo 3: Verificar logs certmonger
sudo journalctl -u certmonger --since "7 days ago" | grep -i renew

# Passo 4: Forçar tentativa de renovação
sudo ipa-getcert resubmit -f /etc/pki/tls/certs/web.crt

# Passo 5: Observar logs em tempo real
sudo journalctl -u certmonger -f
```

### Problemas Comuns de Renovação

**Problema 1: Comando post-save falha**
```bash
# Verificar comando post-save
sudo getcert list -f /etc/pki/tls/certs/web.crt | grep "post-save"
# post-save command: systemctl reload httpd

# Testar comando manualmente
sudo systemctl reload httpd
# Se falha → corrigir o comando

# Atualizar comando (recriar entrada de rastreamento; não use getcert rekey)
sudo getcert stop-tracking -f /etc/pki/tls/certs/web.crt
sudo getcert start-tracking \
  -f /etc/pki/tls/certs/web.crt \
  -k /etc/pki/tls/private/web.key \
  -C "systemctl reload httpd"
```

**Problema 2: Servidor IPA desligado durante janela renovação**
```bash
# certmonger vai retentar
# Verificar cronograma de retentativa nos logs
sudo journalctl -u certmonger | grep "will try again"

# Retentativa manual
sudo ipa-getcert resubmit -f /etc/pki/tls/certs/web.crt
```

---

## 30.5 Problemas de Rastreamento

### Certificado Não Sendo Rastreado

**Sintoma:** Certificado expira porque certmonger não estava rastreando

**Solução:**
```bash
#============================================#
# INICIAR RASTREAMENTO CERTIFICADO EXISTENTE
#============================================#

sudo getcert start-tracking \
  -f /etc/pki/tls/certs/existing.crt \
  -k /etc/pki/tls/private/existing.key \
  -c IPA \
  -K HTTP/$(hostname -f)@REALM
```

### Rastreamento Duplicado

**Sintoma:** Mesmo certificado rastreado múltiplas vezes

**Diagnóstico:**
```bash
# Listar todos certs rastreados
sudo getcert list | grep -E "(Request ID|certificate:)" | \
  awk -F"'" '/certificate:/{cert=$2} /Request ID/{print cert, $2}'

# Procurar por duplicados
```

**Solução:**
```bash
# Remover rastreamento duplicado
sudo getcert stop-tracking -i <duplicate-request-id>

# Manter apenas uma entrada rastreamento por certificado
```

---

## 30.6 Problemas de Configuração

### CA Errada Configurada

**Sintoma:** certmonger tentando alcançar CA errada

**Diagnóstico:**
```bash
# Verificar CA configurada
sudo getcert list -v | grep "CA:"

# Listar CAs disponíveis
sudo getcert list-cas
```

**Solução:**
```bash
# Parar rastreamento com CA errada
sudo getcert stop-tracking -f /etc/pki/tls/certs/web.crt

# Re-solicitar com CA correta
sudo ipa-getcert request \
  -c IPA \  # Especificar CA correta
  -f /etc/pki/tls/certs/web.crt \
  -k /etc/pki/tls/private/web.key \
  -K HTTP/$(hostname -f)@REALM
```

---

## 30.7 Corrupção de Banco de Dados certmonger

### Problema Raro mas Sério

**Sintoma:** certmonger completamente quebrado, todos certs mostram erros

**Diagnóstico:**
```bash
# Verificar banco de dados
ls -l /var/lib/certmonger/

# Verificar por corrupção
sudo journalctl -u certmonger | grep -i corrupt
```

**Solução (Opção Nuclear):**
```bash
# CUIDADO: Isto remove todo rastreamento!

# Passo 1: Backup estado atual
sudo tar czf certmonger-backup-$(date +%Y%m%d).tar.gz \
  /var/lib/certmonger/ \
  /etc/pki/tls/

# Passo 2: Documentar rastreamento atual
sudo getcert list > /tmp/certmonger-list-backup.txt

# Passo 3: Parar certmonger
sudo systemctl stop certmonger

# Passo 4: Remover banco de dados
sudo rm -rf /var/lib/certmonger/cas/*
sudo rm -rf /var/lib/certmonger/requests/*

# Passo 5: Iniciar certmonger
sudo systemctl start certmonger

# Passo 6: Re-adicionar certificados (da documentação backup)
# Manualmente re-solicitar cada certificado
```

---

## 30.8 Debugging certmonger

### Habilitar Logging de Debug

```bash
#============================================#
# MODO DEBUG CERTMONGER
#============================================#

# Editar arquivo service
sudo systemctl edit certmonger

# Adicionar:
[Service]
Environment="G_MESSAGES_DEBUG=all"

# Recarregar e reiniciar
sudo systemctl daemon-reload
sudo systemctl restart certmonger

# Observar logs detalhados
sudo journalctl -u certmonger -f

# Desabilitar debug após solução de problemas
sudo systemctl revert certmonger
sudo systemctl restart certmonger
```

### Teste Manual de Requisição Cert

```bash
#============================================#
# TESTAR REQUISIÇÃO CERTIFICADO MANUALMENTE
#============================================#

# Submeter requisição e observar
sudo ipa-getcert request \
  -f /tmp/test.crt \
  -k /tmp/test.key \
  -K HTTP/$(hostname -f)@REALM \
  -v  # Verbose

# Observar em outro terminal
sudo journalctl -u certmonger -f

# Se bem-sucedido, remover teste
sudo getcert stop-tracking -f /tmp/test.crt -r
rm -f /tmp/test.{crt,key}
```

---

## 30.9 Cenários Comuns

### Cenário 1: Todos Certificados Mostram CA_UNREACHABLE

**Causa Provável:** Servidor IPA desligado ou problema de rede

**Correção Rápida:**
```bash
# Verificar IPA
ipa ping

# Se desligado, corrigir IPA primeiro
ssh ipa-server "sudo ipactl start"

# Se problema de rede, corrigir rede

# Reiniciar certmonger
sudo systemctl restart certmonger
```

### Cenário 2: Um Certificado Travado

**Diagnóstico:**
```bash
# Verificar certificado específico
sudo getcert list -f /etc/pki/tls/certs/problem.crt

# Tentar reenviar
sudo ipa-getcert resubmit -f /etc/pki/tls/certs/problem.crt

# Se ainda travado, recriar requisição
sudo getcert stop-tracking -f /etc/pki/tls/certs/problem.crt
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/problem.crt \
  -k /etc/pki/tls/private/problem.key \
  -K HTTP/$(hostname -f)@REALM \
  -D $(hostname -f)
```

### Cenário 3: Certificado Renovado mas Serviço Não Recarregado

**Sintoma:** Novo cert existe mas serviço ainda usa antigo

**Causa:** Comando post-save falhou ou não configurado

**Solução:**
```bash
# Verificar comando post-save
sudo getcert list -f /etc/pki/tls/certs/web.crt | grep "post-save"

# Se faltando, adicionar (recriar entrada de rastreamento; não use getcert rekey)
sudo getcert stop-tracking -f /etc/pki/tls/certs/web.crt
sudo getcert start-tracking \
  -f /etc/pki/tls/certs/web.crt \
  -k /etc/pki/tls/private/web.key \
  -C "systemctl reload httpd"

# Testar comando post-save funciona
sudo systemctl reload httpd

# Forçar renovação para testar
sudo ipa-getcert resubmit -f /etc/pki/tls/certs/web.crt
```

---

## 30.10 Conclusões Chave

1. **CA_UNREACHABLE** é problema mais comum - Verificar conectividade IPA
2. **CA_REJECTED** significa problema principal - Criar principal de serviço
3. **Status MONITORING** significa que está tudo bem
4. **Comandos post-save críticos** - Testá-los independentemente
5. **Logs certmonger** no journal - Usar `journalctl -u certmonger`
6. **Retentar com resubmit** - Frequentemente corrige problemas transitórios
7. **Verificar tickets Kerberos** - Tickets expirados causam problemas

---

## Cartão de Referência Rápida

```
┌───────────────────────────────────────────────────────────────┐
│ REFERÊNCIA RÁPIDA SOLUÇÃO DE PROBLEMAS CERTMONGER             │
├───────────────────────────────────────────────────────────────┤
│ Status:          getcert list                                 │
│ Verbose:         getcert list -v                              │
│ Específico:      getcert list -f /path/to/cert.crt            │
│ Logs:            journalctl -u certmonger -f                  │
│                                                               │
│ Reenviar:        ipa-getcert resubmit -f /path/to/cert.crt    │
│ Parar rastr:     getcert stop-tracking -f /path/to/cert.crt   │
│ Iniciar rastr:   getcert start-tracking -f cert -k key        │
│                                                               │
│ CA_UNREACHABLE:  Verificar: ipa ping, klist                   │
│                  Corrigir: kinit -k host/$(hostname -f)@REALM │
│                                                               │
│ CA_REJECTED:     Verificar: ipa service-show SERVICE/host     │
│                  Corrigir: ipa service-add SERVICE/host       │
│                                                               │
│ Debug:           systemctl edit certmonger                    │
│                  Environment="G_MESSAGES_DEBUG=all"           │
└───────────────────────────────────────────────────────────────┘

✅ MONITORING = Tudo bem!
❌ CA_UNREACHABLE = Verificar conectividade IPA
❌ CA_REJECTED = Verificar principal de serviço
```
---

**Navegação do Capítulo**

| [← Anterior: Capítulo 29 - Solução de Problemas Específica por Serviço](29-service-troubleshooting.md) | [Próximo: Capítulo 31 - Solução de Problemas Crypto-Policy →](31-crypto-policy-issues.md) |
|:---|---:|
