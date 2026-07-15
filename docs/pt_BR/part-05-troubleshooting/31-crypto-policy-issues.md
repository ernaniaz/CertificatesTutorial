# Capítulo 31: Solução de Problemas Crypto-Policy

> **Apenas RHEL 8/9/10:** Crypto-policies são poderosas mas podem causar problemas de compatibilidade. Aprenda como diagnosticar e corrigir problemas de crypto-policy.

---

## 31.1 Visão Geral Crypto-Policy

**Disponível:** Apenas RHEL 8, 9, 10 (NÃO RHEL 7)

**Verificação Rápida:**
```bash
# Verificar se crypto-policies disponíveis
which update-crypto-policies

# Se encontrado: RHEL 8/9/10
# Se não encontrado: RHEL 7 (sem crypto-policies)

# Política atual
update-crypto-policies --show
```

---

## 31.2 Problemas Comuns de Crypto-Policy

### Problema 1: Aplicação Falha Após Mudança de Política

**Sintoma:** Serviço funcionava, então você mudou crypto-policy, agora falha

**Cenário:**
```bash
# Antes
update-crypto-policies --show
# DEFAULT

# Você mudou
sudo update-crypto-policies --set FUTURE
sudo systemctl restart httpd

# Agora httpd não inicia ou clientes não conseguem conectar
```

**Diagnóstico:**
```bash
#============================================#
# DIAGNOSTICAR IMPACTO MUDANÇA POLÍTICA
#============================================#

# Passo 1: Verificar o que mudou
cat /etc/crypto-policies/back-ends/opensslcnf.config

# Passo 2: Verificar logs
sudo journalctl -xe -u httpd | grep -i cipher

# Passo 3: Testar conexão
openssl s_client -connect localhost:443

# Passo 4: Verificar se app sobrescrevendo política
grep -r "SSLProtocol\|SSLCipherSuite" /etc/httpd/
```

**Solução:**
```bash
# Solução 1: Reverter política
sudo update-crypto-policies --set DEFAULT
sudo systemctl restart httpd

# Solução 2: Corrigir config aplicação
# Remover especificações cipher codificadas
# Deixar crypto-policy lidar com isso

# Solução 3: Criar módulo política customizado (RHEL 9+)
# Ver Capítulo 23 para detalhes
```

---

### Problema 2: "no shared cipher"

**Sintoma:** Clientes não conseguem conectar após mudança política

**Erro Completo:**
```
SSL routines:SSL23_GET_SERVER_HELLO:sslv3 alert handshake failure
no shared cipher
```

**Diagnóstico:**
```bash
#============================================#
# DIAGNOSTICAR DESAJUSTE CIPHER
#============================================#

# Passo 1: Verificar política atual
update-crypto-policies --show
# FUTURE  ← Muito restritiva!

# Passo 2: Quais ciphers estão disponíveis?
openssl ciphers -v | head -20

# Passo 3: Testar capacidades cliente
openssl s_client -connect server:443 -cipher 'ALL'

# Passo 4: Cliente é muito antigo?
# Cliente antigo pode suportar apenas ciphers fracos bloqueados por política FUTURE
```

**Soluções:**
```bash
# Solução 1: Usar política menos restritiva (temporário!)
sudo update-crypto-policies --set DEFAULT
sudo systemctl restart services

# Solução 2: Atualizar cliente para suportar ciphers modernos

# Solução 3: Criar módulo política customizado
# Permitir cipher específico para compatibilidade
```

---

### Problema 3: Cliente TLS 1.0/1.1 Não Consegue Conectar

**Sintoma:** Clientes antigos falham ao conectar ao servidor RHEL 8+

**Erro:**
```
SSL routines:ssl3_read_bytes:tlsv1 alert protocol version
wrong version number
```

**Diagnóstico:**
```bash
# Verificar política
update-crypto-policies --show
# DEFAULT  ← Bloqueia TLS 1.0/1.1

# Testar se TLS 1.0 funciona
openssl s_client -connect server:443 -tls1
# Deveria falhar com política DEFAULT

# Testar se TLS 1.2 funciona
openssl s_client -connect server:443 -tls1_2
# Deveria funcionar
```

**Soluções:**
```bash
# Solução 1: Política LEGACY temporária (NÃO recomendado!)
sudo update-crypto-policies --set LEGACY
sudo systemctl restart services
# Agora TLS 1.0/1.1 permitidos

# Solução 2: Atualizar cliente para suportar TLS 1.2+
# Esta é a correção APROPRIADA

# Solução 3: Override por aplicação (último recurso)
# Exemplo Apache:
# SSLProtocol all -SSLv3  # Re-habilita TLS 1.0/1.1
```

---

### Problema 4: Serviço Sobrescrevendo Crypto-Policy

**Sintoma:** Mudanças de política não afetam serviço

**Diagnóstico:**
```bash
#============================================#
# VERIFICAR POR OVERRIDES DE POLÍTICA
#============================================#

# Apache
grep -r "SSLProtocol\|SSLCipherSuite" /etc/httpd/

# NGINX
grep -r "ssl_protocols\|ssl_ciphers" /etc/nginx/

# Postfix
sudo postconf | grep -E "smtp.*_tls_protocols|smtp.*_tls_ciphers"

# Se encontrado → Serviço está sobrescrevendo política!
```

**Solução:**
```bash
# Remover overrides de arquivos config
# Deixar crypto-policy lidar com ajustes TLS

# Apache: Remover ou comentar
# #SSLProtocol all -SSLv3
# #SSLCipherSuite ...

# NGINX: Remover
# #ssl_protocols ...
# #ssl_ciphers ...

# Reiniciar serviço
sudo systemctl restart httpd
```

---

## 31.3 Crypto-Policy Não Aplicada

### Política Definida Mas Não Surtindo Efeito

**Sintomas:**
- Mudou política mas serviços ainda usam ajustes antigos
- Ciphers fracos ainda aceitos

**Diagnóstico:**
```bash
#============================================#
# VERIFICAR SE POLÍTICA ESTÁ ATIVA
#============================================#

# Passo 1: Confirmar política definida
update-crypto-policies --show

# Passo 2: Verificar quando política foi atualizada pela última vez
ls -l /etc/crypto-policies/back-ends/

# Passo 3: Verificar se serviços foram reiniciados
systemctl status httpd nginx postfix | grep "Active:"
# Serviços DEVEM ser reiniciados após mudança política!

# Passo 4: Testar ciphers reais em uso
openssl s_client -connect localhost:443 | grep "Cipher"
```

**Solução:**
```bash
# Reiniciar TODOS serviços
sudo systemctl restart httpd nginx postfix slapd

# Ou reiniciar (garante que tudo pega as mudanças)
sudo reboot

# Verificar após reinício
openssl s_client -connect localhost:443
```

---

## 31.4 Problemas de Política FIPS

### Falhas de Política FIPS

**Sintoma:** Serviços falham em modo FIPS

**Diagnóstico:**
```bash
#============================================#
# DIAGNOSTICAR PROBLEMAS FIPS
#============================================#

# Passo 1: Verificar modo FIPS habilitado
fips-mode-setup --check

# Passo 2: Verificar crypto-policy
update-crypto-policies --show
# Deveria mostrar: FIPS

# Passo 3: Verificar por algoritmos não-FIPS
# Culpados comuns: MD5, SHA-1, ciphers fracos

# Passo 4: Testar com provider FIPS
openssl list -providers | grep fips
```

**Problemas Comuns FIPS:**
```bash
# Problema: Aplicação usa MD5 (não aprovado FIPS)
# Erro: "digital envelope routines:EVP_DigestInit_ex:disabled for fips"

# Solução: Atualizar aplicação para usar SHA-256

# Problema: Certificado tem assinatura SHA-1
# Erro: "ca md too weak"

# Solução: Reemitir certificado com SHA-256 ou melhor
```

---

## 31.5 Teste de Compatibilidade de Política

### Antes de Mudar Política

```bash
#!/bin/bash
# test-crypto-policy-change.sh
# Testar mudança crypto-policy antes de produção

NEW_POLICY=$1  # DEFAULT, LEGACY, FUTURE, ou FIPS

if [ -z "$NEW_POLICY" ]; then
  echo "Uso: $0 <política>"
  exit 1
fi

echo "=== Testando Mudança Crypto-Policy para $NEW_POLICY ==="

# Salvar política atual
CURRENT=$(update-crypto-policies --show)
echo "Política atual: $CURRENT"

# Mudar política
echo "Mudando para $NEW_POLICY..."
sudo update-crypto-policies --set "$NEW_POLICY"

# Reiniciar serviços
echo "Reiniciando serviços..."
sudo systemctl restart httpd nginx postfix 2>/dev/null

# Aguardar serviços iniciarem
sleep 3

# Testar cada serviço
echo ""
echo "Testando serviços:"

# Apache
if systemctl is-active --quiet httpd; then
  curl -ks https://localhost/ >/dev/null && \
    echo "✅ Apache: OK" || echo "❌ Apache: FALHOU"
else
  echo "❌ Apache: Não rodando"
fi

# NGINX
if systemctl is-active --quiet nginx; then
  curl -ks https://localhost:8443/ >/dev/null && \
    echo "✅ NGINX: OK" || echo "❌ NGINX: FALHOU"
else
  echo "⚠️ NGINX: Não instalado"
fi

# Postfix
if systemctl is-active --quiet postfix; then
  timeout 3 openssl s_client -starttls smtp -connect localhost:25 </dev/null &>/dev/null && \
    echo "✅ Postfix: OK" || echo "❌ Postfix: FALHOU"
else
  echo "⚠️ Postfix: Não instalado"
fi

# Perguntar para manter ou reverter
echo ""
read -p "Manter política $NEW_POLICY? (y/n): " KEEP

if [ "$KEEP" != "y" ]; then
  echo "Revertendo para $CURRENT..."
  sudo update-crypto-policies --set "$CURRENT"
  sudo systemctl restart httpd nginx postfix 2>/dev/null
  echo "✅ Revertido"
else
  echo "✅ Mantendo política $NEW_POLICY"
fi
```

---

## 31.6 Fluxo de Trabalho de Solução de Problemas

### Abordagem Sistemática

```
Problema Crypto-Policy?
    │
    ├─ Passo 1: Identificar política atual
    │   └─ update-crypto-policies --show
    │
    ├─ Passo 2: Verificar se política mudou recentemente
    │   └─ Verificar /var/log/messages para "crypto-policies"
    │
    ├─ Passo 3: Testar com política diferente
    │   └─ sudo update-crypto-policies --set LEGACY
    │   └─ Se funciona → política estava muito restritiva
    │
    ├─ Passo 4: Identificar incompatibilidade
    │   └─ openssl s_client -cipher 'ALL' -tls1
    │   └─ Descobrir o que cliente/servidor necessita
    │
    ├─ Passo 5: Escolher correção
    │   ├─ A) Atualizar cliente (melhor)
    │   ├─ B) Criar módulo customizado (bom)
    │   ├─ C) Usar política menos restritiva (aceitável)
    │   └─ D) Override por app (último recurso)
    │
    └─ Passo 6: Testar e documentar
        └─ Verificar que correção funciona
        └─ Documentar por que mudança necessária
```

---

## 31.7 Debugging Aplicação Crypto-Policy

### Verificar Que Política Está Aplicada

```bash
#============================================#
# VERIFICAR APLICAÇÃO CRYPTO-POLICY
#============================================#

# Passo 1: Verificar política
update-crypto-policies --show

# Passo 2: Verificar que arquivos back-end foram atualizados
ls -l /etc/crypto-policies/back-ends/
# Arquivos devem estar modificados recentemente

# Passo 3: Ver configuração OpenSSL
cat /etc/crypto-policies/back-ends/opensslcnf.config

# Passo 4: Testar disponibilidade real de cipher
openssl ciphers -v | grep -E "TLS|SSL"

# Passo 5: Testar conexão
openssl s_client -connect localhost:443
# Procurar por: Versão protocolo, Cipher

# Passo 6: Verificar se serviço reiniciou desde mudança política
systemctl status httpd | grep "Active:"
# Deveria mostrar tempo ativação recente
```

---

## 31.8 Cenários Comuns

### Cenário 1: Aplicação Legada Após Atualização RHEL 8

**Problema:** App funcionava no RHEL 7, falha no RHEL 8

**Causa Raiz:** RHEL 7 não tinha crypto-policies, DEFAULT do RHEL 8 bloqueia TLS 1.0/1.1

**Solução:**
```bash
# Correção rápida (temporária!):
sudo update-crypto-policies --set LEGACY

# Correção apropriada:
# Atualizar aplicação para suportar TLS 1.2+

# Documentar exceção
echo "Aplicação X requer política LEGACY devido a requisito TLS 1.0" > \
  /etc/crypto-policies/POLICY-EXCEPTION.txt
```

### Cenário 2: Não Consegue Conectar ao Windows Server 2008

**Problema:** RHEL 9 não consegue conectar ao servidor Windows antigo

**Causa:** Windows Server 2008 suporta apenas TLS 1.0

**Soluções:**
```bash
# Opção 1: Atualizar Windows (melhor)

# Opção 2: Política LEGACY (temporário)
sudo update-crypto-policies --set LEGACY

# Opção 3: Módulo política customizado para este caso específico
# Ver Capítulo 23
```

---

## 31.9 Conclusões Chave

1. **Crypto-policies são apenas RHEL 8+** (não RHEL 7)
2. **Serviços DEVEM reiniciar** após mudança política
3. **Mudanças política são system-wide** - Afetam tudo
4. **DEFAULT é recomendado** para maioria ambientes
5. **LEGACY deve ser temporária** apenas
6. **Testar antes de implantar** novas políticas
7. **Atualizar clientes** em vez de enfraquecer política

---

## Cartão de Referência Rápida

```
┌─────────────────────────────────────────────────────────────┐
│ SOLUÇÃO DE PROBLEMAS CRYPTO-POLICY                          │
├─────────────────────────────────────────────────────────────┤
│ Verificar:     update-crypto-policies --show                │
│ Definir:       sudo update-crypto-policies --set <POLÍTICA> │
│ Reverter:      sudo update-crypto-policies --set DEFAULT    │
│                                                             │
│ Back-ends:     /etc/crypto-policies/back-ends/              │
│ OpenSSL:       cat .../back-ends/opensslcnf.config          │
│                                                             │
│ Testar:        openssl ciphers -v                           │
│                openssl s_client -connect :443               │
│                                                             │
│ Após mudança:  sudo systemctl restart <todos-serviços>      │
│                OU: sudo reboot                              │
│                                                             │
│ Debug:         grep -r "SSLProtocol\|ssl_protocols" /etc/   │
│                (procurar por overrides)                     │
└─────────────────────────────────────────────────────────────┘

⚠️ RHEL 7 não tem crypto-policies
✅ Sempre reiniciar serviços após mudança política
✅ DEFAULT funciona para 95% dos casos
```
---

**Navegação do Capítulo**

| [← Anterior: Capítulo 30 - Solução de Problemas do certmonger](30-certmonger-issues.md) | [Próximo: Capítulo 32 - Análise de Relatórios SOS →](32-sos-report-analysis.md) |
|:---|---:|
