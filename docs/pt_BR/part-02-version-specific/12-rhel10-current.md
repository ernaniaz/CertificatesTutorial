# Capítulo 12: Recursos Atuais do RHEL 10

> **Vanguarda:** O RHEL 10 GA foi lançado em 20 de maio de 2025; o RHEL 10.2 é a versão menor atual. Aprenda sobre os recursos mais recentes e prepare-se para o futuro do gerenciamento de certificados no Red Hat Enterprise Linux.

---

## 12.1 Visão Geral RHEL 10

**Lançamento GA:** 20 de maio de 2025
**Versão Atual:** RHEL 10.2
**Suporte Até:** 31 de maio de 2035
**Status:** ✅ Lançamento Produção

**Características Chave:**
- **Versão OpenSSL:** 3.5.5-2 (pacote: `openssl-3.5.5-2.el10_2.x86_64`)
- **Mesma base que:** RHEL 9.8 (OpenSSL 3.5.5)
- **Foco:** Fortalecimento contínuo, preparação pós-quântica, cloud-native
- **Filosofia:** Melhoria incremental sobre RHEL 9

> **Importante:** Recursos RHEL 10 podem evoluir através das versões menores (10.1, 10.2, etc.). Sempre consulte documentação oficial Red Hat para seu lançamento RHEL 10.x específico.

---

## 12.2 O Que Há de Novo vs. RHEL 9?

### Diferenças Chave

| Recurso | RHEL 9 | RHEL 10 |
|---------|--------|---------|
| OpenSSL | 3.5.5 | 3.5.5 (mesma base) |
| Crypto-Policies | Subpolíticas | Subpolíticas aprimoradas |
| Versões TLS | 1.2, 1.3 | 1.3 preferido, 1.2 suportado |
| FIPS | Módulos 140-2 | Transição 140-3 |
| Padrões Segurança | Rigoroso | **Mais Rigoroso** |
| Suporte Container | Bom | **Aprimorado** |
| Pós-Quântico | Fundação | **Preparação ativa** |

**Pacote:** `openssl-3.5.5-2.el10_2.x86_64`

### Não É Mudança Revolucionária

Diferente RHEL 7→8 (crypto-policies) ou RHEL 8→9 (OpenSSL 3.x), RHEL 10 é **melhoria incremental**.

**Pense nisso como:**
- RHEL 7 → 8: 🚀 Revolucionário (crypto-policies)
- RHEL 8 → 9: 🔄 Principal (OpenSSL 3.x)
- RHEL 9 → 10: ⬆️  Incremental (refinamentos)

---

## 12.3 Gerenciamento de Certificados no RHEL 10

### Mesma Fundação que RHEL 9

```bash
#============================================#
# BÁSICOS CERTIFICADO RHEL 10
#============================================#

# Mesma versão OpenSSL que RHEL 9.8
openssl version
# OpenSSL 3.5.5 27 Jan 2026

# Mesmo sistema crypto-policies
update-crypto-policies --show

# Mesmo certmonger
getcert list

# Mesma estrutura diretório
ls -la /etc/pki/tls/
```

**Conclusão:** Se você conhece RHEL 9, você conhece certificados RHEL 10!

---

## 12.4 Recursos Segurança Aprimorados

### Padrões Mais Rigorosos

```bash
#============================================#
# APRIMORAMENTOS SEGURANÇA RHEL 10
#============================================#

# 1. Política DEFAULT é mais rigorosa
# - Preferências cipher mais fortes
# - Algoritmos fracos adicionais removidos
# - Validação aprimorada

# 2. Política LEGACY mais restrita
# - Menos algoritmos legados permitidos
# - Mínimos mais fortes mesmo em LEGACY

# 3. Gerenciamento certificado container melhorado
# - Melhor integração com Podman
# - Montagem cert simplificada
# - Gerenciamento secret aprimorado
```

### Preparação Criptografia Pós-Quântica

**Fundação para Futuro:**

```bash
# RHEL 10 prepara para algoritmos pós-quânticos
# (Ainda não padrão, mas infraestrutura pronta)

# Capacidade futura (quando padrões finalizarem):
# - ML-KEM (Module-Lattice Key Encapsulation)
# - ML-DSA (Module-Lattice Digital Signatures)
# - Criptografia híbrida clássica/quântica

# Status atual: Monitorando padrões NIST
# Esperado: Lançamentos menores RHEL 10.x adicionarão suporte PQC
```

> **Nota:** Criptografia pós-quântica ainda está evoluindo. RHEL 10 fornece fundação, implementação real virá quando padrões forem finalizados.

---

## 12.5 Recursos Específicos RHEL 10

### Recurso 1: Módulos Crypto-Policy Aprimorados

```bash
#============================================#
# MELHORIAS CRYPTO-POLICY RHEL 10
#============================================#

# Controle mais granular
sudo update-crypto-policies --set DEFAULT:NO-SHA1

# Melhor validação
update-crypto-policies --check

# Mensagens erro melhoradas quando políticas conflitam
```

### Recurso 2: Suporte Certificado Container Melhorado

```bash
#============================================#
# CONTAINERS COM CERTIFICADOS (RHEL 10)
#============================================#

# Montagem certificado mais fácil no Podman
podman run -d \
  -v /etc/pki/tls/certs/web.crt:/certs/web.crt:ro \
  -v /etc/pki/tls/private/web.key:/certs/web.key:ro \
  -p 443:443 \
  nginx

# Gerenciamento secret aprimorado
podman secret create web-cert /etc/pki/tls/certs/web.crt
podman secret create web-key /etc/pki/tls/private/web.key

# Usar secrets em container
podman run -d --secret web-cert --secret web-key nginx
```

### Recurso 3: Modo FIPS Aprimorado

```bash
#============================================#
# FIPS NO RHEL 10
#============================================#

# Modo FIPS com provider FIPS OpenSSL 3.x
sudo fips-mode-setup --enable
sudo reboot

# Verificar status FIPS
fips-mode-setup --check

# RHEL 10: Transição para FIPS 140-3
# Atual: Ainda módulos validados FIPS 140-2
# Futuro: Conformidade FIPS 140-3 quando certificação completar
```

---

## 12.6 Migração do RHEL 9

### Deveria Atualizar?

**Considerações Atualização:**

**Razões para Atualizar:**
- ✅ Quer 10+ anos suporte (até 2035)
- ✅ Necessita últimos aprimoramentos segurança
- ✅ Preparação futura (preparação pós-quântica)
- ✅ Suporte container aprimorado
- ✅ Últimos recursos e melhorias

**Razões para Aguardar:**
- ⏸️ RHEL 9 suportado até 2032
- ⏸️ Sem recursos urgentes relacionados certificado
- ⏸️ Deixar outros testarem RHEL 10 em produção primeiro
- ⏸️ Quer aguardar RHEL 10.3 ou 10.4

**Impacto Certificado: BAIXO**
- Mesma base OpenSSL (3.5.5)
- Mesmas ferramentas e comandos
- Mudanças disruptivas mínimas
- Maioria transparente

### Processo Migração

```bash
#============================================#
# MIGRAÇÃO CERTIFICADO RHEL 9 → RHEL 10
#============================================#

# 1. Pré-migração: Verificar certificados
for cert in /etc/pki/tls/certs/*.crt; do
  openssl x509 -in "$cert" -noout -text | grep "Signature Algorithm"
done
# Todos deveriam mostrar SHA-256+ (sem SHA-1 e MD5)

# 2. Backup
tar czf rhel9-certs-backup-$(date +%Y%m%d).tar.gz \
  /etc/pki/tls/ \
  /etc/pki/ca-trust/source/anchors/

# 3. Executar atualização RHEL
sudo leapp upgrade

# 4. Verificar crypto-policy
update-crypto-policies --show

# 5. Reiniciar serviços
sudo systemctl restart httpd nginx postfix

# 6. Testar certificados
curl -v https://localhost/
openssl s_client -connect localhost:443

# 7. Verificar certmonger
sudo getcert list
```

---

## 12.7 Melhores Práticas para RHEL 10

### Configuração Recomendado

```bash
#============================================#
# CONFIGURAÇÃO RECOMENDADA RHEL 10
#============================================#

# 1. Usar crypto-policy DEFAULT (já ótima)
sudo update-crypto-policies --set DEFAULT

# 2. Preferir TLS 1.3
# (Automaticamente preferido pela política DEFAULT)

# 3. Usar chaves EC para novos certificados
openssl genpkey -algorithm EC -out ec.key \
  -pkeyopt ec_paramgen_curve:P-256

# 4. Automatizar com a ferramenta certa
# Certificado público do Let's Encrypt: usar certbot
sudo certbot certonly --apache -d web.example.com

# Certificado interno do FreeIPA / IdM: usar certmonger
# sudo ipa-getcert request \
#   -f /etc/pki/tls/certs/web.crt \
#   -k /etc/pki/tls/private/web.key \
#   -K HTTP/web.example.com@REALM \
#   -D web.example.com \
#   -C "systemctl reload httpd"

# 5. Monitorar certificados
# Usar monitoramento integrado ou ferramentas externas

# 6. Planejar para PQC futuro
# Acompanhar lançamentos menores RHEL 10.x
```

---

## 12.8 Olhando Para Frente: Prontidão Pós-Quântica

### O Que é Criptografia Pós-Quântica?

**Problema:** Computadores quânticos futuros poderiam quebrar criptografia atual (RSA, ECC)
**Solução:** Novos algoritmos resistentes quânticos

**Padrões NIST (Finalizados 2024):**
- **ML-KEM-768** (Key Encapsulation)
- **ML-DSA-65** (Digital Signatures)
- **SLH-DSA** (Stateless signatures)

**Papel RHEL 10:**
- Fornece fundação para PQC
- Arquitetura OpenSSL 3.x suporta novos algoritmos
- Lançamentos futuros RHEL 10.x adicionarão suporte PQC

### Criptografia Híbrida (Futuro)

```bash
# Capacidade futura no RHEL 10.x:
# Usar crypto clássica E resistente quântica

# Exemplo (conceitual - ainda não no RHEL 10.2):
openssl genpkey -algorithm hybrid-rsa-mlkem768 -out hybrid.key

# Fornece:
# - Segurança contra ataques clássicos (RSA)
# - Segurança contra ataques quânticos (ML-KEM)
```

> **Nota:** Suporte PQC vem em versões menores futuras RHEL 10.x quando padrões forem finalizados e testados.

---

## 12.9 O Que Permanece Igual

### Sem Mudanças Disruptivas Principais

```bash
#============================================#
# COMANDOS FAMILIARES AINDA FUNCIONAM
#============================================#

# Gerar chave (mesmo que RHEL 9)
openssl genpkey -algorithm RSA -out server.key \
  -pkeyopt rsa_keygen_bits:2048

# Gerar CSR (mesmo que RHEL 9)
openssl req -new -key server.key -out server.csr \
  -subj "/CN=server.example.com" \
  -addext "subjectAltName=DNS:server.example.com"

# Ver certificado (mesmo)
openssl x509 -in cert.crt -noout -text

# Testar conexão (mesmo)
openssl s_client -connect server:443

# Gerenciamento trust (mesmo)
sudo cp ca.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust

# certmonger (mesmo)
sudo getcert list

# crypto-policies (mesmo)
update-crypto-policies --show
```

**Se você conhece RHEL 9, está pronto para RHEL 10!**

---

## 12.10 Quando Adotar RHEL 10

### Recomendações Timeline Adoção

**Adotantes Iniciais (2025-2026):**
- Ambientes teste
- Cargas trabalho não-críticas
- Querem recursos mais recentes
- Pesquisa segurança

**Adoção generalizada (2026-2027):**
- Novas implantações
- Infraestrutura renovada
- Após lançamento RHEL 10.3/10.4
- Quando apps principais certificados

**Conservador (2027-2028):**
- Sistemas produção críticos
- Cargas trabalho estáveis
- Após teste comunidade extensivo
- Quando migração do RHEL 9 necessária

**Recomendação Atual (Final 2025):**
- ✅ **Novos projetos:** Considere RHEL 10
- ⏸️ **RHEL 9 existente:** Sem urgência atualizar
- ✅ **RHEL 8 ou anterior:** Avaliar RHEL 9 ou 10
- ❌ **RHEL 7:** Atualização requerida (suporte terminou)

---

## 12.11 Monitorando Evolução RHEL 10

### Manter-se Atualizado

```bash
# Verificar versão menor RHEL 10
cat /etc/redhat-release
# Red Hat Enterprise Linux release 10.2 (Coughlan)

# Verificar por atualizações
sudo dnf check-update

# Monitorar anúncios Red Hat
# - https://access.redhat.com/articles/3078
# - Notas lançamento RHEL 10
# - Avisos segurança Red Hat

# Subscrever newsletters Red Hat
# Seguir notas lançamento para 10.3, 10.4, etc.
```

### Recursos a Observar

**Esperado em lançamentos menores RHEL 10.x:**
- Suporte criptografia pós-quântica
- Aprimoramentos crypto-policy adicionais
- Integração container adicional
- Ferramentas automatização aprimoradas
- Módulos FIPS 140-3 adicionais

---

## 12.12 Configuração Prática de Certificado RHEL 10

### Exemplo Completo: Configuração HTTPS Moderna

```bash
#!/bin/bash
# Configuração HTTPS moderna completa no RHEL 10

echo "=== Configuração HTTPS moderna RHEL 10 ==="

# 1. Instalar pacotes
sudo dnf install -y httpd mod_ssl epel-release certbot python3-certbot-apache

# 2. Habilitar serviços
sudo systemctl enable --now httpd

# 3. Solicitar certificado Let's Encrypt com certbot
sudo certbot --apache -d $(hostname -f)

# 4. Verificar o certificado
sudo certbot certificates

# 5. Atualizar configuração Apache
# certbot normalmente atualiza o Apache automaticamente; ajuste manualmente apenas se necessário
sudo sed -i "s|SSLCertificateFile.*|SSLCertificateFile /etc/letsencrypt/live/$(hostname -f)/fullchain.pem|" \
  /etc/httpd/conf.d/ssl.conf
sudo sed -i "s|SSLCertificateKeyFile.*|SSLCertificateKeyFile /etc/letsencrypt/live/$(hostname -f)/privkey.pem|" \
  /etc/httpd/conf.d/ssl.conf

# 6. Crypto-policy já ótima (DEFAULT)
update-crypto-policies --show

# 7. Abrir firewall
sudo firewall-cmd --add-service=https --permanent
sudo firewall-cmd --reload

# 8. Recarregar Apache
sudo systemctl reload httpd

# 9. Testar
curl -v https://$(hostname -f)/

echo "✅ Configuração HTTPS moderna RHEL 10 concluída!"
echo "   - TLS 1.3 suportado"
echo "   - Certificado Let's Encrypt"
echo "   - Renovação automática habilitada"
echo "   - Segurança ótima (política DEFAULT)"
```

---

## 12.13 Estratégias Preparação Futura

### Preparando para Evolução RHEL 10.x

```bash
#============================================#
# GERENCIAMENTO CERTIFICADO PREPARADO FUTURO
#============================================#

# 1. Usar algoritmos modernos (pronto para transição PQC)
# Preferir EC sobre RSA
openssl genpkey -algorithm EC -out ec.key -pkeyopt ec_paramgen_curve:P-256

# 2. Manter certificados vida-curta (90 dias ou menos)
# Mais fácil rotacionar quando algoritmos mudam

# 3. Automatizar tudo
# Usar certbot para ACME público e certmonger para fluxos IPA/internos

# 4. Monitorar anúncios Red Hat
# Subscrever notificações segurança e lançamento

# 5. Testar PQC quando disponível
# Ser testador inicial novos recursos no RHEL 10.x

# 6. Documentar seu setup
# Torna transições futuras mais fáceis
```

---

## 12.14 Problemas Conhecidos e Workarounds

### Problema 1: Mesmo que RHEL 9 (OpenSSL 3.x)

**Maioria problemas RHEL 9 aplicam ao RHEL 10:**
- Algoritmos legados necessitam `-provider legacy`
- SHA-1 bloqueado
- Apps customizadas podem necessitar atualizações OpenSSL 3.x

**Referência:** Ver Capítulo 11 para problemas OpenSSL 3.x

### Problema 2: Validação Ainda Mais Rigorosa

**RHEL 10 pode capturar problemas que RHEL 9 permitiu:**

```bash
# Exemplo: Certificado marginal que funcionou no RHEL 9
# pode falhar no RHEL 10

# Solução: Sempre usar melhores práticas
# - Assinaturas SHA-256+
# - Chaves 2048+ bits (4096 recomendado)
# - SANs apropriados
# - Cadeias trust válidas
```

---

## 12.15 Quando Escolher RHEL 10

### Matriz Decisão

| Cenário | RHEL 9 | RHEL 10 | Recomendação |
|---------|--------|---------|--------------|
| **Nova implantação 2025+** | ✅ Bom | ✅ Melhor | RHEL 10 |
| **RHEL 9 existente** | ✅ Manter | ⏸️ Aguardar | Ficar em 9 por ora |
| **Migrando do RHEL 8** | ✅ Sim | ✅ Considere | Ambos (9 é mais seguro) |
| **Migrando do RHEL 7** | ✅ Sim | ⚠️ Grande salto | Ir para 9 primeiro |
| **Horizonte 10+ anos** | ⏸️ Suporte 2032 | ✅ Suporte 2035 | RHEL 10 |
| **Segurança vanguarda** | ✅ Boa | ✅ Melhor | RHEL 10 |
| **Produção crítica** | ✅ Provado | ⏸️ Mais novo | RHEL 9 (mais seguro) |

---

## 12.16 Conclusões Chave

1. **RHEL 10 = RHEL 9 + melhorias incrementais**
2. **Mesma base OpenSSL 3.5.5** - Sem mudanças API principais
3. **Padrões segurança mais rigorosos** - Bom para segurança
4. **Preparação pós-quântica** - Infraestrutura pronta futuro
5. **Sem mudanças certificado urgentes** - Transição é suave
6. **Conhecimento RHEL 9 transfere** - Mesmas ferramentas e comandos
7. **Observar por lançamentos menores** - 10.3, 10.4 podem adicionar recursos

---

## 12.17 Solução de Problemas RHEL 10

### Abordagem Diagnóstico

```bash
#============================================#
# SOLUÇÃO DE PROBLEMAS CERTIFICADO RHEL 10
#============================================#

# Usar a metodologia de solução de problemas (Capítulo 27) e os padrões do RHEL 9 (Capítulo 11)

# 1. Verificar versão RHEL 10
cat /etc/redhat-release
# Red Hat Enterprise Linux release 10.2 (Coughlan)

# 2. Verificar OpenSSL
openssl version
# OpenSSL 3.5.5

# 3. Verificar crypto-policy
update-crypto-policies --show

# 4. Testar certificado
openssl x509 -in cert.crt -noout -text

# 5. Testar conexão
openssl s_client -connect server:443 -tls1_3

# 6. Verificar providers (se problemas)
openssl list -providers

# 7. Verificar logs
sudo journalctl -xe | grep -i cert
```

**Sem novas técnicas de solução de problemas necessárias - mesmo que RHEL 9!**

---

## 12.18 Caminho Migração Recomendado

### Do RHEL 9 para RHEL 10

```bash
#============================================#
# MIGRAÇÃO RHEL 9→10 SEGURA CERTIFICADO
#============================================#

# Fase 1: Preparação
# - Backup todos certificados
# - Documentar configuração atual
# - Testar em ambiente lab

# Fase 2: Migração
# - Usar processo atualização RHEL padrão
# - Certificados deveriam transferir sem problemas

# Fase 3: Verificação
# - Verificar crypto-policy inalterada
# - Testar todas operações certificado
# - Confirmar rastreamento certmonger mantido
# - Testar serviços usando certificados

# Fase 4: Otimização
# - Considerar chaves EC para novos certificados
# - Revisar e atualizar crypto-policy se necessário
# - Monitorar por aprimoramentos RHEL 10.x
```

---

## 12.19 Documentação e Recursos

### Recursos Oficiais

```markdown
## Recursos Certificado RHEL 10

### Documentação Oficial
- Notas Lançamento RHEL 10 (verificar para sua versão 10.x específica)
- https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/10

### Atualizações Segurança
- https://access.redhat.com/security/
- Subscrever anúncios segurança RHEL

### Crypto-Policies
- https://access.redhat.com/articles/3642912
- Verificar por atualizações específicas RHEL 10

### Suporte
- Portal Cliente Red Hat
- Casos Suporte Red Hat
- Fóruns comunidade RHEL
```

---

## 12.20 Referência Rápida

```
┌──────────────────────────────────────────────────────────────┐
│ REFERÊNCIA RÁPIDA CERTIFICADO RHEL 10                        │
├──────────────────────────────────────────────────────────────┤
│ OpenSSL:       3.5.5-2 (mesmo que RHEL 9.8)                  │
│ TLS:           1.3 preferido, 1.2 suportado                  │
│ Lançado:       20 de maio de 2025 (RHEL 10.0 GA)             │
│ Status:        Pronto produção                               │
│                                                              │
│ Mudança Chave: Melhorias segurança incrementais              │
│ Migração:      Baixo impacto do RHEL 9                       │
│ Comandos:      Mesmos que RHEL 9                             │
│ Ferramentas:   Mesmas que RHEL 9                             │
│                                                              │
│ Futuro:        Preparação crypto pós-quântica                │
│                Observar por recursos em 10.3, 10.4+          │
│                                                              │
│ Verificar:     cat /etc/redhat-release                       │
│                openssl version                               │
│                update-crypto-policies --show                 │
└──────────────────────────────────────────────────────────────┘

✅ Se você conhece certificados RHEL 9, você conhece RHEL 10!
⚠️ Sempre verificar docs oficiais para sua versão menor 10.x específica
```
---

**Navegação do Capítulo**

| [← Anterior: Capítulo 11 - Segurança Moderna no RHEL 9](11-rhel9-modern-security.md) | [Próximo: Capítulo 13 - Compatibilidade Entre Versões →](13-cross-version-compatibility.md) |
|:---|---:|
