# Capítulo 37: Solução de Problemas e Recuperação de Migração

> **Quando Coisas Dão Errado:** Migrações nem sempre vão suavemente. Este capítulo cobre problemas migração comuns e procedimentos recuperação.

---

## 37.1 Problemas Migração Comuns

### Top 10 Problemas Certificado Migração

| Problema | Sintomas | Causa | Correção Rápida |
|----------|----------|-------|-----------------|
| 1. Serviços não iniciam | systemctl status falha | Sintaxe config mudou | Restaurar config, atualizar sintaxe |
| 2. Rejeição SHA-1 (RHEL 9) | "ca md too weak" | Assinatura SHA-1 | Reemitir certificado |
| 3. Desajuste versão TLS | Clientes não conectam | TLS 1.0/1.1 bloqueados | Política LEGACY (temp) |
| 4. Problemas crypto-policy | Vários erros | Novo sistema política | Entender e configurar |
| 5. certmonger perdeu rastreamento | getcert list vazio | Corrupção BD | Restaurar de backup |
| 6. CAs faltando | Cert verify failed | Repositório de confiança resetado | Re-adicionar CAs |
| 7. Mudanças permissão | Permission denied | Propriedade mudou | Corrigir permissões |
| 8. Negações SELinux | Serviço bloqueado | Contexto mudou | Relabeling arquivos |
| 9. Erros provider (RHEL 9) | Algoritmo unsupported | Mudança OpenSSL 3.x | Usar -provider legacy |
| 10. Degradação desempenho | Conexões lentas | Crypto mais rigoroso | Esperado, ou ajustar |

---

## 37.2 Procedimentos Rollback

### Quando Fazer Rollback

**Rollback se:**
- Serviços críticos não conseguem iniciar
- Problemas certificado não podem ser corrigidos rapidamente
- Impacto negócio é severo
- Dentro janela rollback (usualmente 24-48 horas)

### Rollback leapp

```bash
#============================================#
# ROLLBACK MIGRAÇÃO RHEL
#============================================#

# leapp cria snapshot durante atualização
# Rollback ANTES de reiniciar para nova versão

# Durante atualização (se problemas detectados):
# Não reiniciar - investigar e corrigir

# Após atualização mas problemas encontrados:
# Verificar se dentro janela rollback

# leapp não tem rollback automático
# Usar snapshot/backup para restaurar

# Com snapshot LVM (se criado pré-migração):
# Boot do snapshot
# Ou restaurar de backup
```

### Rollback Específico Certificado

```bash
#============================================#
# RESTAURAR CERTIFICADOS APÓS MIGRAÇÃO FALHADA
#============================================#

# Cenário: Migrado, mas problemas certificado
# Necessita restaurar estado certificado

# Passo 1: Parar serviços
sudo systemctl stop httpd nginx postfix slapd

# Passo 2: Restaurar certificados
sudo tar xzf /var/backups/pre-migration-*/certificates.tar.gz -C /

# Passo 3: Restaurar configs serviço
sudo tar xzf /var/backups/pre-migration-*/service-configs.tar.gz -C /

# Passo 4: Restaurar certmonger
sudo systemctl stop certmonger
sudo tar xzf /var/backups/pre-migration-*/certmonger.tar.gz -C /
sudo systemctl start certmonger

# Passo 5: Restaurar crypto-policy (se RHEL 8+)
POLICY=$(cat /var/backups/pre-migration-*/crypto-policy.txt)
sudo update-crypto-policies --set $POLICY

# Passo 6: Iniciar serviços
sudo systemctl start httpd nginx postfix slapd

# Passo 7: Verificar
curl -v https://localhost/
sudo getcert list
```

---

## 37.3 Serviço Não Inicia Após Migração

### Diagnóstico

```bash
#============================================#
# SOLUÇÃO DE PROBLEMAS STARTUP SERVIÇO
#============================================#

# Verificar status serviço
systemctl status httpd

# Ver erros detalhados
sudo journalctl -xe -u httpd

# Testar configuração
# Apache:
sudo apachectl configtest

# NGINX:
sudo nginx -t

# Postfix:
sudo postfix check

# Erros comuns relacionados certificado:
# - Arquivo não encontrado
# - Permissão negada
# - Formato certificado inválido
# - ca md too weak (SHA-1)
```

### Soluções

**Problema: Sintaxe Configuração Mudou**
```bash
# Algumas diretivas mudaram entre versões
# Verificar notas lançamento para mudanças

# Temporariamente restaurar config antiga
sudo cp /var/backups/pre-migration-*/ssl.conf /etc/httpd/conf.d/

# Atualizar para nova sintaxe
# Pesquisar sintaxe correta para nova versão
```

**Problema: Permissão Mudou Durante Migração**
```bash
# Corrigir permissões
sudo chmod 600 /etc/pki/tls/private/*.key
sudo chmod 644 /etc/pki/tls/certs/*.crt

# Corrigir propriedade
sudo chown root:root /etc/pki/tls/private/*.key

# Corrigir contextos SELinux
sudo restorecon -Rv /etc/pki/tls/
```

---

## 37.4 Falhas Conexão Cliente Pós-Migração

### Incompatibilidade Versão TLS

**Sintoma:** Clientes não conseguem conectar após migração para RHEL 8/9

**Diagnóstico:**
```bash
# Testar do servidor
openssl s_client -connect localhost:443 -tls1_2
# Funciona

openssl s_client -connect localhost:443 -tls1
# Falha (esperado no RHEL 8/9 DEFAULT)

# Verificar crypto-policy
update-crypto-policies --show
# DEFAULT  ← Bloqueia TLS 1.0/1.1
```

**Solução Temporária:**
```bash
# Permitir TLS 1.0/1.1 temporariamente
sudo update-crypto-policies --set LEGACY
sudo systemctl restart httpd nginx postfix

# Testar clientes
# Documentar quais clientes necessitam TLS 1.0/1.1

# Planejar atualizar aqueles clientes, então reverter para DEFAULT
```

**Solução Apropriada:**
```bash
# Atualizar clientes para suportar TLS 1.2+
# Então usar política DEFAULT

sudo update-crypto-policies --set DEFAULT
```

---

## 37.5 Problemas certmonger Pós-Migração

### Rastreamento certmonger Perdido

**Sintoma:**
```bash
sudo getcert list
# (vazio ou certificados faltando)
```

**Solução:**
```bash
# Restaurar banco dados certmonger
sudo systemctl stop certmonger
sudo tar xzf /var/backups/pre-migration-*/certmonger.tar.gz -C /
sudo systemctl start certmonger

# Verificar
sudo getcert list

# Se ainda problemas, re-adicionar certificados manualmente
```

### certmonger CA_UNREACHABLE Após Migração

**Comum após atualização RHEL**

**Solução:**
```bash
# Renovar ticket Kerberos
sudo kinit -k host/$(hostname -f)@REALM

# Reiniciar certmonger
sudo systemctl restart certmonger

# Reenviar requisições
for cert in $(sudo getcert list | grep "certificate:" | sed -n "s/.*location='\\([^']*\\)'.*/\\1/p"); do
  sudo ipa-getcert resubmit -f "$cert"
done
```

---

## 37.6 Procedimentos Recuperação Emergência

### Emergência: Todos Serviços Fora

**Situação:** Migração completa mas nada funciona

**Recuperação Rápida:**
```bash
#!/bin/bash
# emergency-post-migration-recovery.sh

echo "=== EMERGÊNCIA: Recuperação Certificado Pós-Migração ==="

# 1. Verificar versão RHEL (confirmar migração aconteceu)
cat /etc/redhat-release

# 2. Emergência: Desabilitar SSL temporariamente
# Apache
sudo mv /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/ssl.conf.disabled
sudo systemctl start httpd
# Agora Apache roda apenas em HTTP (porta 80)

# 3. Identificar problemas certificado
sudo journalctl -xe | grep -i cert | tail -50

# 4. Para RHEL 9: Verificar por rejeições SHA-1
grep "ca md too weak" /var/log/messages

# 5. Gerar certificados autoassinados temporários
/usr/local/bin/emergency-self-signed-cert.sh $(hostname -f) 90

# 6. Re-habilitar SSL com cert temp
sudo mv /etc/httpd/conf.d/ssl.conf.disabled /etc/httpd/conf.d/ssl.conf
# Atualizar para usar cert temp
sudo systemctl restart httpd

# 7. Serviços restaurados (com avisos)
# Planejar correções certificado apropriadas

echo "✅ Recuperação emergência completa"
echo "⚠️ Usando certificados temporários - corrigir ASAP!"
```

---

## 37.7 Script Validação Pós-Migração

### Validação Abrangente

```bash
#!/bin/bash
# post-migration-cert-validation.sh

echo "=== Validação Certificado Pós-Migração ==="

ISSUES=0

# Verificar versão RHEL
echo "1. Versão RHEL:"
cat /etc/redhat-release

# Verificar OpenSSL
echo ""
echo "2. Versão OpenSSL:"
openssl version

# Verificar crypto-policy (RHEL 8+)
if command -v update-crypto-policies &>/dev/null; then
  echo ""
  echo "3. Crypto-Policy:"
  update-crypto-policies --show
fi

# Verificar certificados
echo ""
echo "4. Status Certificado:"
CERT_COUNT=0
EXPIRED=0
for cert in /etc/pki/tls/certs/*.crt; do
  [ -f "$cert" ] || continue
  ((CERT_COUNT++))

  if ! openssl x509 -in "$cert" -noout -checkend 0 2>/dev/null; then
    echo "  ❌ EXPIRADO: $cert"
    ((EXPIRED++))
    ((ISSUES++))
  fi

  # Verificar por SHA-1 (RHEL 9)
  if [ "$(cat /etc/redhat-release)" =~ "release 9" ]; then
    if openssl x509 -in "$cert" -noout -text | grep -qi "sha1.*Signature"; then
      echo "  ❌ SHA-1: $cert"
      ((ISSUES++))
    fi
  fi
done

echo "  Total certificados: $CERT_COUNT"
echo "  Expirados: $EXPIRED"

# Verificar certmonger
echo ""
echo "5. Status certmonger:"
if command -v getcert &>/dev/null; then
  sudo getcert list | grep "status:" | sort | uniq -c

  UNREACHABLE=$(sudo getcert list | grep -c "CA_UNREACHABLE")
  if [ $UNREACHABLE -gt 0 ]; then
    echo "  ⚠️ $UNREACHABLE certificados CA_UNREACHABLE"
    ((ISSUES++))
  fi
else
  echo "  certmonger não instalado"
fi

# Verificar serviços
echo ""
echo "6. Status Serviço:"
for svc in httpd nginx postfix slapd; do
  if systemctl is-active --quiet $svc 2>/dev/null; then
    echo "  ✅ $svc: rodando"
  elif systemctl is-enabled --quiet $svc 2>/dev/null; then
    echo "  ❌ $svc: não rodando (deveria estar)"
    ((ISSUES++))
  fi
done

# Testar conexões
echo ""
echo "7. Testes Conexão:"
timeout 3 curl -ks https://localhost/ &>/dev/null && \
  echo "  ✅ HTTPS: OK" || echo "  ❌ HTTPS: FALHOU"

# Resumo
echo ""
echo "==================================="
if [ $ISSUES -eq 0 ]; then
  echo "✅ Validação migração PASSOU!"
  exit 0
else
  echo "⚠️ $ISSUES problemas encontrados - revisar acima"
  exit 1
fi
```

---

## 37.8 Conclusões Chave

1. **Ter plano rollback pronto** antes migração
2. **Maioria problemas são corrigíveis** sem rollback
3. **Mudanças Crypto-policy** causam maioria problemas compatibilidade
4. **Rejeição SHA-1** é inegociável no RHEL 9
5. **Testar, testar, testar** antes migração produção
6. **Documentar tudo** durante a solução de problemas
7. **Procedimentos emergência** (Cap 33) aplicam durante migração também

---

## Cartão de Referência Rápida

```
┌──────────────────────────────────────────────────────────────┐
│ SOLUÇÃO DE PROBLEMAS MIGRAÇÃO QUICK REFERENCE                │
├──────────────────────────────────────────────────────────────┤
│ Serviço falha:   Verificar: journalctl -xe -u <serviço>      │
│                  Tentar: Restaurar config de backup          │
│                                                              │
│ Cert rejeitado:  Verificar: Algoritmo assinatura (SHA-1?)    │
│                  Corrigir: Reemitir com SHA-256+             │
│                                                              │
│ Cliente falha:   Verificar: Suporte versão TLS               │
│                  Temp: update-crypto-policies --set LEGACY   │
│                  Corrigir: Atualizar cliente                 │
│                                                              │
│ certmonger:      Verificar: getcert list                     │
│                  Corrigir: Restaurar /var/lib/certmonger/    │
│                                                              │
│ Emergência:      Desabilitar SSL temporariamente             │
│                  Gerar temp autoassinado                     │
│                  Restaurar de backup                         │
│                                                              │
│ Rollback:        Usar snapshot/backup                        │
│                  Restaurar certificados                      │
│                  Restaurar configs                           │
└──────────────────────────────────────────────────────────────┘

✅ Maioria problemas são corrigíveis sem rollback completo
⚠️ Ter backups prontos
⚠️ Testar em não-produção primeiro
```
---

**Navegação do Capítulo**

| [← Anterior: Capítulo 36 - Migração RHEL 8→9](36-rhel8-to-9.md) | [Próximo: Capítulo 38 - Guia Completo do Modo FIPS →](../part-07-security/38-fips-mode-guide.md) |
|:---|---:|
