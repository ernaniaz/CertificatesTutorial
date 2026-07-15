# Capítulo 21: Melhores Práticas de Certificados de Serviço

> **Crítico para Operações:** Aprenda as melhores práticas que previnem 90% dos problemas de certificado antes que aconteçam.

---

## 21.1 O Custo de Gerenciamento Pobre de Certificados

**Impactos mundo real:**
- ❌ Certificado expirado → Website fora do ar (perda receita)
- ❌ Permissões erradas → Serviço falha ao iniciar (downtime)
- ❌ Sem backup → Falha CA significa reemissão manual (horas/dias)
- ❌ Nomenclatura ruim → Confusão durante incidente (resposta atrasada)
- ❌ Sem monitoramento → Expiração surpresa (resposta emergência)

**Este capítulo previne estes problemas.**

---

## 21.2 Melhores práticas de organização de arquivos

### Estrutura Diretório Padrão

```bash
/etc/pki/tls/
├── certs/                      # Arquivos certificado (públicos)
│   ├── service-name.crt        # Certificados reais
│   ├── service-name-chain.crt  # Com cadeia intermediária
│   └── ca-bundle.crt           # Bundle CA
│
├── private/                    # Chaves privadas (protegidas!)
│   └── service-name.key        # Chaves privadas (modo 600)
│
├── csr/                        # Requisições certificado (opcional)
│   └── service-name.csr        # CSRs para rastreamento
│
└── backup/                     # Backups (opcional mas recomendado)
    └── YYYY-MM-DD/
        ├── service-name.crt
        └── service-name.key
```

### Convenções de Nomenclatura

**Boa nomenclatura previne confusão:**

```bash
# ✅ BOM - Claro, descritivo
/etc/pki/tls/certs/web01-example-com.crt
/etc/pki/tls/certs/mail-smtp-example-com.crt
/etc/pki/tls/certs/ldap-primary-example-com.crt

# ❌ RUIM - Não claro, genérico
/etc/pki/tls/certs/cert1.crt
/etc/pki/tls/certs/new.crt
/etc/pki/tls/certs/temp.crt
```

**Padrão nomenclatura:**
```
[serviço]-[hostname/função]-[domínio].crt
[serviço]-[hostname/função]-[domínio].key

Exemplos:
apache-web01-example-com.crt
nginx-www-example-com.crt
postfix-mail-example-com.crt
ldap-dir01-example-com.crt
postgresql-db-primary-example-com.crt
```

### Padrões Permissão Arquivo

```bash
#============================================#
# CRÍTICO: Permissões Apropriadas
#============================================#

# Certificados (públicos) - legíveis por todos
/etc/pki/tls/certs/*.crt           → 644 (rw-r--r--)
/etc/pki/tls/certs/                → 755 (rwxr-xr-x)

# Chaves privadas (secretas!) - apenas legíveis pelo proprietário
/etc/pki/tls/private/*.key         → 600 (rw-------)
/etc/pki/tls/private/              → 711 (rwx--x--x)

# Chaves específicas serviço - propriedade usuário serviço
/etc/pki/tls/private/apache.key    → 600, owner: root ou apache
/etc/pki/tls/private/postgres.key  → 600, owner: postgres
```

**Script definir permissões:**
```bash
#!/bin/bash
# set-cert-permissions.sh
# Define permissões apropriadas em arquivos certificado

CERT_DIR="/etc/pki/tls/certs"
KEY_DIR="/etc/pki/tls/private"

# Diretório certificados
chmod 755 "$CERT_DIR"
chmod 644 "$CERT_DIR"/*.crt 2>/dev/null

# Diretório chaves privadas
chmod 711 "$KEY_DIR"
chmod 600 "$KEY_DIR"/*.key 2>/dev/null

# Verificar
echo "Permissões certificados:"
ls -ld "$CERT_DIR" "$CERT_DIR"/*.crt 2>/dev/null

echo ""
echo "Permissões chaves privadas:"
ls -ld "$KEY_DIR" "$KEY_DIR"/*.key 2>/dev/null

# Verificar por chaves excessivamente permissivas
echo ""
echo "Verificando por problemas segurança:"
find "$KEY_DIR" -type f -not -perm 600 -ls 2>/dev/null && \
  echo "⚠️ AVISO: Algumas chaves têm permissões incorretas!" || \
  echo "✅ Todas chaves apropriadamente protegidas"
```

---

## 21.3 Gerenciamento do ciclo de vida de certificados

### Timeline Renovação

```
Ciclo de Vida Certificado (validade 365 dias):

Dia   0: Certificado emitido
Dia  30: Primeiro lembrete renovação (335 dias restantes)
Dia  60: Segundo lembrete (305 dias restantes)
Dia 300: Janela renovação crítica inicia (65 dias restantes)
Dia 330: URGENTE - Renovação necessária (35 dias restantes)
Dia 350: CRÍTICO - Renovação atrasada (15 dias restantes)
Dia 365: EXPIRADO - Interrupção serviço!

Ações Recomendadas:
- Dias 300-330: Planejar e executar renovação
- Dias 330-350: Renovação emergência se perdida
- Dias 350+: Resposta incidente, cert temporário
```

### Estratégias Renovação

**Estratégia 1: Automatizada (Recomendada)**
```bash
# Usando certmonger (RHEL)
sudo getcert request \
  -f /etc/pki/tls/certs/web.crt \
  -k /etc/pki/tls/private/web.key \
  -D web.example.com \
  -K host/web.example.com@REALM \
  -C "systemctl reload httpd"  # Auto-recarregar serviço

# Auto-renovação acontece em 2/3 do tempo vida cert
# cert 365 dias → renova no dia 243 (122 dias restantes)
```

**Estratégia 2: Renovação Manual Agendada**
```bash
# Job cron para verificação renovação manual
# /etc/cron.weekly/check-certificates

#!/bin/bash
# Verificar certificados expirando em 60 dias
find /etc/pki/tls/certs/ -name "*.crt" | while read cert; do
  if openssl x509 -in "$cert" -noout -checkend $((86400*60)); then
    echo "✅ $cert: OK"
  else
    echo "⚠️ $cert: Expira dentro de 60 dias!"
    # Enviar alerta
    mail -s "Certificado Expirando Em Breve: $cert" admin@example.com
  fi
done
```

**Estratégia 3: Lembretes Calendário**
```bash
# Para ambientes sem automatização
# Criar entradas calendário:
# - 90 dias antes expiração: Iniciar renovação
# - 60 dias antes: Verificar renovação em progresso
# - 30 dias antes: Completar renovação
# - 7 dias antes: Emergência se não feito
```

---

## 21.4 Rastreamento de metadados de certificados

### Inventário Certificados

Manter inventário certificados (planilha ou banco dados):

```csv
Service,Hostname,Certificate_Path,Key_Path,Issuer,Issue_Date,Expiry_Date,SANs,Owner,Notes
Apache,web01,/etc/pki/tls/certs/web01.crt,/etc/pki/tls/private/web01.key,Internal CA,2024-01-01,2025-01-01,"web01.example.com,www.example.com",John Doe,Production
NGINX,web02,/etc/pki/tls/certs/web02.crt,/etc/pki/tls/private/web02.key,Let's Encrypt,2024-06-15,2024-09-15,"web02.example.com",Jane Smith,Staging
```

**Script gerar inventário:**
```bash
#!/bin/bash
# generate-cert-inventory.sh
# Cria inventário certificados do sistema

echo "Service,Hostname,Certificate_Path,Issuer,Issue_Date,Expiry_Date,Days_Remaining"

# Escanear localizações certificado comuns
for cert in /etc/pki/tls/certs/*.crt /etc/httpd/conf/ssl/*.crt /etc/nginx/ssl/*.crt; do
  [ -f "$cert" ] || continue

  subject=$(openssl x509 -in "$cert" -noout -subject 2>/dev/null | sed 's/subject=//')
  issuer=$(openssl x509 -in "$cert" -noout -issuer 2>/dev/null | sed 's/issuer=//')
  notbefore=$(openssl x509 -in "$cert" -noout -startdate 2>/dev/null | cut -d= -f2)
  notafter=$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | cut -d= -f2)

  # Calcular dias restantes
  expiry_epoch=$(date -d "$notafter" +%s 2>/dev/null)
  now_epoch=$(date +%s)
  days_remaining=$(( ($expiry_epoch - $now_epoch) / 86400 ))

  # Determinar serviço do caminho
  service="Unknown"
  [[ "$cert" =~ httpd ]] && service="Apache"
  [[ "$cert" =~ nginx ]] && service="NGINX"

  echo "$service,$(hostname),$cert,\"$issuer\",$notbefore,$notafter,$days_remaining"
done
```

---

## 21.5 Backup e Recuperação

### O Que Fazer Backup

```bash
Arquivos críticos para backup:
✅ Chaves privadas (arquivos .key)
✅ Certificados (arquivos .crt)
✅ Certificados CA
✅ Cadeias certificado
✅ CSRs (para referência)
✅ Arquivos configuração (Apache ssl.conf, etc.)
⚠️ NÃO senhas ou passphrases (armazenar separadamente em vault)
```

### Script Backup

```bash
#!/bin/bash
# backup-certificates.sh
# Faz backup de todos certificados e chaves

BACKUP_DIR="/var/backups/certificates"
DATE=$(date +%Y-%m-%d)
BACKUP_PATH="$BACKUP_DIR/$DATE"

# Criar diretório backup
mkdir -p "$BACKUP_PATH"

# Backup certificados
echo "Fazendo backup certificados..."
cp -a /etc/pki/tls/certs/*.crt "$BACKUP_PATH/" 2>/dev/null

# Backup chaves privadas (criptografadas!)
echo "Fazendo backup chaves privadas..."
tar czf - /etc/pki/tls/private/*.key 2>/dev/null | \
  openssl enc -aes-256-cbc -salt -out "$BACKUP_PATH/keys.tar.gz.enc" -pass pass:CHANGEME

# Backup arquivos configuração
echo "Fazendo backup configs..."
cp -a /etc/httpd/conf.d/ssl.conf "$BACKUP_PATH/" 2>/dev/null
cp -a /etc/nginx/nginx.conf "$BACKUP_PATH/" 2>/dev/null

# Criar inventário
ls -lh "$BACKUP_PATH"

# Definir permissões
chmod 700 "$BACKUP_PATH"

echo "✅ Backup completo: $BACKUP_PATH"
echo "⚠️ Lembrar de mudar senha criptografia!"
```

### Procedimento Recuperação

```bash
#============================================#
# PROCEDIMENTO RECUPERAÇÃO CERTIFICADO
#============================================#

# 1. Parar serviço afetado
sudo systemctl stop httpd

# 2. Restaurar certificado
sudo cp /var/backups/certificates/2024-11-15/web.crt /etc/pki/tls/certs/

# 3. Restaurar chave privada (descriptografar)
cd /var/backups/certificates/2024-11-15/
openssl enc -aes-256-cbc -d -in keys.tar.gz.enc -pass pass:CHANGEME | \
  sudo tar xzf - -C /

# 4. Definir permissões
sudo chmod 600 /etc/pki/tls/private/*.key
sudo chmod 644 /etc/pki/tls/certs/*.crt

# 5. Verificar arquivos
sudo openssl x509 -in /etc/pki/tls/certs/web.crt -noout -text
sudo openssl rsa -in /etc/pki/tls/private/web.key -check

# 6. Iniciar serviço
sudo systemctl start httpd

# 7. Testar
curl -v https://localhost/
```

---

## 21.6 Melhores práticas de segurança

### Proteção Chave Privada

```bash
#============================================#
# CHECKLIST SEGURANÇA CHAVE PRIVADA
#============================================#

✅ Permissões: 600 (ou 400 para proteção extra)
✅ Propriedade: root ou apenas usuário serviço
✅ Localização: /etc/pki/tls/private/ (modo 711)
✅ SELinux: Contexto apropriado (cert_t)
✅ Backup: Criptografado em repouso
✅ Nunca: Email, colar em tickets, commit no git
✅ Nunca: Compartilhar entre sistemas (gerar novo)
✅ Auditoria: Logar acesso com auditd

# Verificar segurança
ls -lZ /etc/pki/tls/private/*.key
# -rw------- root root unconfined_u:object_r:cert_t:s0 server.key
```

### Melhores Práticas Geração Chave

```bash
#============================================#
# GERAR CHAVES SEGURAS
#============================================#

# RSA 2048 (mínimo para RHEL 8+)
openssl genpkey -algorithm RSA -out server.key -pkeyopt rsa_keygen_bits:2048

# RSA 4096 (recomendado para certs longevidade longa)
openssl genpkey -algorithm RSA -out server.key -pkeyopt rsa_keygen_bits:4096

# EC P-256 (moderno, menor, rápido)
openssl genpkey -algorithm EC -out server.key -pkeyopt ec_paramgen_curve:P-256

# Definir permissões imediatamente!
chmod 600 server.key

# ❌ NUNCA fazer isto:
# openssl genrsa -out server.key 1024   # Muito fraco!
# chmod 644 server.key                  # Muito permissivo!
```

### Validação Certificado Antes de Implantação

```bash
#!/bin/bash
# validate-certificate.sh
# Valida certificado antes de implantação

CERT=$1
KEY=$2

echo "=== Validação Certificado Pré-Implantação ==="

# Verificação 1: Arquivo certificado existe e legível
if [ ! -f "$CERT" ]; then
  echo "❌ Arquivo certificado não encontrado: $CERT"
  exit 1
fi

# Verificação 2: Chave privada existe e legível
if [ ! -f "$KEY" ]; then
  echo "❌ Chave privada não encontrada: $KEY"
  exit 1
fi

# Verificação 3: Certificado é X.509 válido
if ! openssl x509 -in "$CERT" -noout 2>/dev/null; then
  echo "❌ Certificado X.509 inválido"
  exit 1
fi

# Verificação 4: Certificado não expirou
if ! openssl x509 -in "$CERT" -noout -checkend 0; then
  echo "❌ Certificado está expirado!"
  exit 1
fi

# Verificação 5: Par certificado/chave coincide
CERT_MOD=$(openssl x509 -noout -modulus -in "$CERT" | openssl md5)
KEY_MOD=$(openssl rsa -noout -modulus -in "$KEY" 2>/dev/null | openssl md5)

if [ "$CERT_MOD" != "$KEY_MOD" ]; then
  echo "❌ Certificado e chave não coincidem!"
  exit 1
fi

# Verificação 6: SANs presentes (requerido para navegadores modernos)
if ! openssl x509 -in "$CERT" -noout -ext subjectAltName 2>/dev/null | grep -q "DNS:"; then
  echo "⚠️ AVISO: Nenhum Subject Alternative Name encontrado"
fi

# Verificação 7: Algoritmo assinatura forte
SIG_ALG=$(openssl x509 -in "$CERT" -noout -text | grep "Signature Algorithm" | head -2)
if echo "$SIG_ALG" | grep -qi "sha1\|md5"; then
  echo "❌ Algoritmo assinatura fraco: $SIG_ALG"
  exit 1
fi

# Verificação 8: Tamanho chave adequado
KEY_SIZE=$(openssl x509 -in "$CERT" -noout -text | grep "Public-Key:" | grep -oP '\d+')
if [ "$KEY_SIZE" -lt 2048 ]; then
  echo "❌ Tamanho chave muito pequeno: $KEY_SIZE bits (mínimo 2048)"
  exit 1
fi

echo ""
echo "✅ Validação certificado passou!"
echo "   Subject: $(openssl x509 -in "$CERT" -noout -subject)"
echo "   Issuer: $(openssl x509 -in "$CERT" -noout -issuer)"
echo "   Expires: $(openssl x509 -in "$CERT" -noout -enddate | cut -d= -f2)"
echo "   Key Size: $KEY_SIZE bits"
```

---

## 21.7 Coordenação Multi-Serviço

### Quando Múltiplos Serviços Compartilham Certificados

```bash
# Cenário: Load balancer + múltiplos servidores web

# Problema: Certificado no LB, serviços atrás necessitam mesmo CN/SANs

# Solução 1: Usar mesmo certificado em todos (se hostnames coincidem)
# web01, web02, web03 todos usam cert para: web.example.com

# Solução 2: Certificado wildcard
# *.example.com funciona para web01.example.com, web02.example.com, etc.

# Solução 3: SANs abrangentes
# Cert único com SANs: web.example.com, web01.example.com, web02.example.com
```

### Fluxo Trabalho Implantação Certificado

```bash
#============================================#
# IMPLANTAÇÃO MULTI-SERVIDOR
#============================================#

# Passo 1: Gerar certificado no nó gerenciamento
openssl genpkey -algorithm RSA -out web.key -pkeyopt rsa_keygen_bits:2048
openssl req -new -key web.key -out web.csr \
  -subj "/CN=web.example.com" \
  -addext "subjectAltName=DNS:web.example.com,DNS:web01.example.com,DNS:web02.example.com"

# Passo 2: Obter certificado da CA
# (submeter web.csr para CA, receber web.crt)

# Passo 3: Validar localmente
./validate-certificate.sh web.crt web.key

# Passo 4: Distribuir com segurança
for host in web01 web02 web03; do
  scp web.crt root@$host:/etc/pki/tls/certs/
  scp web.key root@$host:/etc/pki/tls/private/
  ssh root@$host "chmod 644 /etc/pki/tls/certs/web.crt"
  ssh root@$host "chmod 600 /etc/pki/tls/private/web.key"
done

# Passo 5: Recarregar serviços
for host in web01 web02 web03; do
  ssh root@$host "systemctl reload httpd"
done

# Passo 6: Testar cada servidor
for host in web01 web02 web03; do
  echo "Testando $host..."
  curl -vk https://$host/ 2>&1 | grep "subject:"
done
```

---

## 21.8 Padrões de documentação

### Template Documentação Certificado

```markdown
## Certificado: web.example.com

### Informação Básica
- **Serviço:** Apache (httpd)
- **Servidor:** web01.example.com
- **Caminho Certificado:** `/etc/pki/tls/certs/web-example-com.crt`
- **Caminho Chave:** `/etc/pki/tls/private/web-example-com.key`
- **Proprietário:** Web Team (webadmin@example.com)

### Detalhes Certificado
- **Common Name (CN):** web.example.com
- **SANs:** web.example.com, www.example.com
- **Emissor:** Internal CA (ca.example.com)
- **Data Emissão:** 2024-01-01
- **Data Expiração:** 2025-01-01
- **Tipo Chave:** RSA 2048

### Processo Renovação
- **Método:** certmonger automático
- **Janela Renovação:** 65 dias antes expiração
- **Pós-Renovação:** `systemctl reload httpd`
- **Contato:** webadmin@example.com

### Configuração Serviço
- **Arquivo Config:** `/etc/httpd/conf.d/ssl.conf`
- **Serviço:** `httpd.service`
- **Comando Restart:** `systemctl reload httpd`

### Solução de Problemas
- **Logs:** `/var/log/httpd/ssl_error_log`
- **Comando Teste:** `curl -v https://web.example.com/`
- **Problemas Comuns:** Nenhum relatado

### Histórico Mudanças
- 2024-01-01: Implantação inicial
- 2024-06-15: Adicionado SAN www.example.com
```

---

## 21.9 Monitoramento e Alertas

### O Que Monitorar

```bash
✅ Expiração certificado (60, 30, 7 dias antes)
✅ Validade certificado (não expirado, ainda não válido)
✅ Coincidência par certificado/chave
✅ Cadeia confiança certificado
✅ Saúde serviço (está usando o cert?)
✅ Status rastreamento certmonger
✅ Sucesso/falha renovação
```

### Script Monitoramento Simples

```bash
#!/bin/bash
# monitor-certificates.sh
# Monitoramento certificado simples

WARN_DAYS=30
CRIT_DAYS=7
EMAIL="admin@example.com"

check_cert() {
  local cert=$1
  local name=$(basename "$cert")

  # Verificar se expira dentro período aviso
  if ! openssl x509 -in "$cert" -noout -checkend $((86400*WARN_DAYS)); then
    if ! openssl x509 -in "$cert" -noout -checkend $((86400*CRIT_DAYS)); then
      echo "🚨 CRÍTICO: $name expira dentro de $CRIT_DAYS dias!"
      return 2
    else
      echo "⚠️ AVISO: $name expira dentro de $WARN_DAYS dias"
      return 1
    fi
  fi

  return 0
}

# Verificar todos certificados
WARNINGS=0
CRITICALS=0

for cert in /etc/pki/tls/certs/*.crt; do
  [ -f "$cert" ] || continue
  check_cert "$cert"
  ret=$?
  [ $ret -eq 1 ] && ((WARNINGS++))
  [ $ret -eq 2 ] && ((CRITICALS++))
done

# Alertar se problemas encontrados
if [ $CRITICALS -gt 0 ] || [ $WARNINGS -gt 0 ]; then
  echo "Problemas certificado encontrados: $CRITICALS críticos, $WARNINGS avisos" | \
    mail -s "Alerta Certificado: $(hostname)" "$EMAIL"
fi
```

---

## 21.10 Procedimentos de resposta a incidentes

### Incidente Expiração Certificado

```bash
#============================================#
# EMERGÊNCIA CERTIFICADO EXPIRADO
#============================================#

# Passo 1: Avaliar impacto
systemctl status httpd
journalctl -xe | grep -i cert

# Passo 2: Correção rápida - Obter cert temporário
# Opção A: Autoassinado (apenas para interno!)
openssl req -x509 -nodes -days 30 -newkey rsa:2048 \
  -keyout /etc/pki/tls/private/temp.key \
  -out /etc/pki/tls/certs/temp.crt \
  -subj "/CN=$(hostname)"

# Opção B: Restaurar do backup
cp /var/backups/certificates/latest/*.crt /etc/pki/tls/certs/
cp /var/backups/certificates/latest/*.key /etc/pki/tls/private/

# Passo 3: Atualizar config serviço para usar cert temp
# Editar /etc/httpd/conf.d/ssl.conf
# SSLCertificateFile /etc/pki/tls/certs/temp.crt
# SSLCertificateKeyFile /etc/pki/tls/private/temp.key

# Passo 4: Reiniciar serviço
systemctl restart httpd

# Passo 5: Obter certificado apropriado ASAP
# Seguir processo requisição cert normal

# Passo 6: Documentar incidente
# O que aconteceu, por quê, como corrigido, prevenção
```

---

## 21.11 Lista de verificação de melhores práticas

```markdown
## Lista de verificação de gerenciamento de certificados

### Organização de arquivos
- [ ] Estrutura diretório padrão usada
- [ ] Convenção nomenclatura consistente
- [ ] Permissões arquivo apropriadas (600 para chaves, 644 para certs)
- [ ] Contextos SELinux corretos

### Gerenciamento do ciclo de vida
- [ ] Processo renovação definido e documentado
- [ ] Lembretes renovação definidos (60, 30, 7 dias)
- [ ] Renovação automatizada se possível (certmonger)
- [ ] Ações pós-renovação definidas

### Segurança
- [ ] Chaves privadas protegidas (permissões 600)
- [ ] Chaves nunca compartilhadas/emailadas
- [ ] Algoritmo chave forte (RSA 2048+ ou EC P-256)
- [ ] Assinatura forte (SHA-256+)

### Backup
- [ ] Certificados com backup
- [ ] Chaves privadas com backup (criptografadas)
- [ ] Backup testado e validado
- [ ] Procedimento restauração documentado

### Documentação
- [ ] Inventário certificados mantido
- [ ] Cada certificado documentado
- [ ] Procedimentos escritos
- [ ] Contatos listados

### Monitoramento
- [ ] Monitoramento expiração habilitado
- [ ] Alertas configurados
- [ ] Verificações saúde em vigor
- [ ] Plano resposta incidente pronto

### Validação
- [ ] Validação pré-implantação
- [ ] Teste pós-implantação
- [ ] Auditorias regulares agendadas
```

---

## 21.12 Conclusões Chave

1. **Organização previne confusão** - Estrutura e nomenclatura consistentes
2. **Permissões são críticas** - 600 para chaves, 644 para certs
3. **Automatizar renovação** - Usar certmonger sempre que possível
4. **Backup de tudo** - Mas criptografar chaves privadas
5. **Documentar completamente** - Seu eu futuro agradecerá
6. **Monitorar proativamente** - Não esperar por expiração
7. **Validar antes implantar** - Capturar problemas cedo
8. **Planejar para incidentes** - Ter procedimentos recuperação prontos

---

## Referência Rápida

```
┌──────────────────────────────────────────────────────────────┐
│ MELHORES PRÁTICAS CERTIFICADOS SERVIÇO                       │
├──────────────────────────────────────────────────────────────┤
│ Arquivos:   /etc/pki/tls/certs/*.crt (644)                   │
│             /etc/pki/tls/private/*.key (600)                 │
│ Nomencl:    [serviço]-[host]-[domínio].[crt|key]             │
│ Renovação:  Automatizar com certmonger                       │
│ Backup:     Diário, criptografado, testado                   │
│ Monitor:    60, 30, 7 dias antes expiração                   │
│ Validar:    Antes de cada implantação                        │
│ Document:   Tudo, todos                                      │
└──────────────────────────────────────────────────────────────┘
```
---

**Navegação do Capítulo**

| [← Anterior: Capítulo 20 - Outros Serviços RHEL com Certificados](20-other-rhel-services.md) | [Próximo: Capítulo 22 - Domínio do certmonger →](../part-04-automation/22-certmonger-mastery.md) |
|:---|---:|
