# Capítulo 26: Monitoramento e Alertas no RHEL

> **Prevenir Interrupções:** Monitoramento proativo previne surpresas de expiração certificado. Aprenda como monitorar certificados e configurar alertas no RHEL.

---

## 26.1 Por Que Monitorar Certificados?

**Sem Monitoramento:**
```
❌ Certificado expira
❌ Website cai às 2 da manhã
❌ Incidente emergência
❌ Perda receita
❌ Dano reputação
❌ Noite estressante para time ops
```

**Com Monitoramento:**
```
✅ Alerta 30 dias antes expiração
✅ Renovação planejada durante horário comercial
✅ Sem interrupções
✅ Sem emergências
✅ Clientes felizes
✅ Time ops bem descansado
```

---

## 26.2 O Que Monitorar

### Métricas Certificado

```markdown
## Métricas Críticas:

✅ **Data expiração** (dias até expiração)
✅ **Validade certificado** (ainda não válido, expirado)
✅ **Coincidência par certificado/chave**
✅ **Validade cadeia confiança**
✅ **Status certmonger** (se usado)
✅ **Saúde serviço** (usando o certificado)
✅ **Sucesso/falha renovação**

## Limiares Aviso:

🟡 60 dias: Primeiro aviso
🟠 30 dias: Segundo aviso
🔴 15 dias: Alerta crítico
🚨 7 dias: Escalação emergência
```

---

## 26.3 Scripts Monitoramento Simples

### Verificação Expiração Básica

```bash
#!/bin/bash
# check-cert-expiration.sh
# Verificador expiração certificado simples

WARN_DAYS=30
CRIT_DAYS=7

check_cert() {
  local cert=$1
  local name=$(basename "$cert")

  if [ ! -f "$cert" ]; then
    echo "❌ $name: Arquivo não encontrado"
    return 2
  fi

  # Obter data expiração
  expiry=$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | cut -d= -f2)

  if [ -z "$expiry" ]; then
    echo "❌ $name: Certificado inválido"
    return 2
  fi

  # Calcular dias restantes
  expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null)
  now_epoch=$(date +%s)
  days_left=$(( ($expiry_epoch - $now_epoch) / 86400 ))

  # Verificar limiares
  if [ $days_left -lt 0 ]; then
    echo "🚨 $name: EXPIRADO há $((- days_left)) dias!"
    return 2
  elif [ $days_left -lt $CRIT_DAYS ]; then
    echo "🔴 $name: CRÍTICO - $days_left dias restantes"
    return 2
  elif [ $days_left -lt $WARN_DAYS ]; then
    echo "🟡 $name: AVISO - $days_left dias restantes"
    return 1
  else
    echo "✅ $name: OK - $days_left dias restantes"
    return 0
  fi
}

# Verificar todos certificados
for cert in /etc/pki/tls/certs/*.crt; do
  check_cert "$cert"
done
```

### Monitor Status certmonger

```bash
#!/bin/bash
# monitor-certmonger.sh
# Monitorar status rastreamento certmonger

echo "=== Monitor Status certmonger ==="

# Verificar se certmonger está rodando
if ! systemctl is-active --quiet certmonger; then
  echo "🚨 CRÍTICO: certmonger não está rodando!"
  systemctl status certmonger
  exit 2
fi

# Obter status certmonger
STATUS_OUTPUT=$(sudo getcert list 2>&1)

# Contar certificados por status
TOTAL=$(echo "$STATUS_OUTPUT" | grep -c "Request ID")
MONITORING=$(echo "$STATUS_OUTPUT" | grep -c "status: MONITORING")
UNREACHABLE=$(echo "$STATUS_OUTPUT" | grep -c "status: CA_UNREACHABLE")
REJECTED=$(echo "$STATUS_OUTPUT" | grep -c "status: CA_REJECTED")

echo "Total certificados: $TOTAL"
echo "  MONITORING: $MONITORING ✅"
echo "  CA_UNREACHABLE: $UNREACHABLE $([ $UNREACHABLE -gt 0 ] && echo '⚠️')"
echo "  CA_REJECTED: $REJECTED $([ $REJECTED -gt 0 ] && echo '❌')"

# Alertar se problemas
if [ $UNREACHABLE -gt 0 ] || [ $REJECTED -gt 0 ]; then
  echo ""
  echo "🚨 ATENÇÃO REQUERIDA:"
  sudo getcert list | grep -B5 "status: CA_" | grep -E "(Request ID|status:)"
  exit 1
fi

echo "✅ Todos certificados OK"
```

---

## 26.4 Timer Systemd para Monitoramento

### Criar Timer Monitoramento

```bash
#============================================#
# CRIAR TIMER SYSTEMD PARA MONITORAMENTO
#============================================#

# Criar arquivo service
sudo tee /etc/systemd/system/cert-monitor.service << 'EOF'
[Unit]
Description=Certificate Expiration Monitor
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/check-cert-expiration.sh
StandardOutput=journal
StandardError=journal
EOF

# Criar arquivo timer (executar diariamente)
sudo tee /etc/systemd/system/cert-monitor.timer << 'EOF'
[Unit]
Description=Daily Certificate Monitoring
Requires=cert-monitor.service

[Timer]
OnCalendar=daily
OnBootSec=15min
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Instalar script monitoramento
sudo cp check-cert-expiration.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/check-cert-expiration.sh

# Habilitar timer
sudo systemctl daemon-reload
sudo systemctl enable cert-monitor.timer
sudo systemctl start cert-monitor.timer

# Verificar
systemctl list-timers | grep cert-monitor

# Testar manualmente
sudo systemctl start cert-monitor.service
sudo journalctl -u cert-monitor.service
```

---

## 26.5 Alertas Email

### Alerta Email Simples

```bash
#!/bin/bash
# cert-monitor-with-email.sh
# Monitor certificado com alertas email

EMAIL="admin@example.com"
WARN_DAYS=30

ALERTS=""

for cert in /etc/pki/tls/certs/*.crt; do
  [ -f "$cert" ] || continue

  if ! openssl x509 -in "$cert" -noout -checkend $((86400*WARN_DAYS)) 2>/dev/null; then
    expiry=$(openssl x509 -in "$cert" -noout -enddate | cut -d= -f2)
    ALERTS="$ALERTS\nCertificado: $cert\nExpira: $expiry\n"
  fi
done

if [ -n "$ALERTS" ]; then
  echo -e "Avisos Expiração Certificado:\n$ALERTS" | \
    mail -s "⚠️ Alerta Expiração Certificado - $(hostname)" "$EMAIL"
fi
```

---

## 26.6 Monitoramento Prometheus (Avançado)

### Exporter Certificado

```bash
#============================================#
# MONITORAMENTO CERTIFICADO PROMETHEUS
#============================================#

# Instalar x509-certificate-exporter (exemplo)
# https://github.com/enix/x509-certificate-exporter

# Ou usar coletor textfile Node Exporter

# Criar script coletor métricas
cat > /usr/local/bin/cert-metrics.sh << 'EOF'
#!/bin/bash
# Gerar métricas Prometheus para certificados

METRICS_FILE="/var/lib/node_exporter/textfile_collector/certificates.prom"
mkdir -p $(dirname "$METRICS_FILE")

cat > "$METRICS_FILE" << PROM
# HELP certificate_expiry_days Days until certificate expiration
# TYPE certificate_expiry_days gauge
PROM

for cert in /etc/pki/tls/certs/*.crt; do
  [ -f "$cert" ] || continue

  expiry=$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | cut -d= -f2)
  expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null)
  now_epoch=$(date +%s)
  days_left=$(( ($expiry_epoch - $now_epoch) / 86400 ))

  echo "certificate_expiry_days{cert=\"$cert\",hostname=\"$(hostname)\"} $days_left" >> "$METRICS_FILE"
done
EOF

chmod +x /usr/local/bin/cert-metrics.sh

# Executar via cron
echo "*/5 * * * * /usr/local/bin/cert-metrics.sh" | sudo crontab -
```

### Regras Alerta Prometheus

```yaml
#============================================#
# prometheus-alerts.yml
#============================================#

groups:
  - name: certificates
    rules:
      - alert: CertificateExpiringSoon
        expr: certificate_expiry_days < 30
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "Certificado expirando em {{ $value }} dias"
          description: "Certificado {{ $labels.cert }} em {{ $labels.hostname }} expira em {{ $value }} dias"

      - alert: CertificateExpiryCritical
        expr: certificate_expiry_days < 7
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Certificado expirando em {{ $value }} dias!"
          description: "URGENTE: Certificado {{ $labels.cert }} em {{ $labels.hostname }} expira em {{ $value }} dias!"

      - alert: CertificateExpired
        expr: certificate_expiry_days < 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Certificado EXPIRADO!"
          description: "Certificado {{ $labels.cert }} em {{ $labels.hostname }} expirou!"
```

---

## 26.7 Logging Centralizado

### Enviar Eventos Certificado para Syslog

```bash
#============================================#
# LOGAR EVENTOS CERTIFICADO
#============================================#

# certmonger loga para journal
sudo journalctl -u certmonger -f

# Encaminhar para syslog central
# /etc/rsyslog.conf
*.* @@syslog-server.example.com:514

# Ou configurar logging certmonger específico
# Monitorar renovações certmonger
sudo journalctl -u certmonger --since today | grep -i "renewed\|failed"
```

---

## 26.8 Comparação Ferramentas Monitoramento

### Opções para RHEL

| Ferramenta | Complexidade | Custo | Integração | Alertas |
|------------|--------------|-------|------------|---------|
| **Scripts simples** | Baixa | Gratuito | Fácil | Email/syslog |
| **Nagios/Icinga** | Média | Gratuito | Boa | Múltiplos |
| **Prometheus + Grafana** | Média-Alta | Gratuito | Excelente | Poderoso |
| **Zabbix** | Média | Gratuito | Boa | Múltiplos |
| **Comercial (Datadog, etc.)** | Baixa | $$$ | Excelente | Avançado |
| **Red Hat Insights** | Baixa | Subscription | Nativo | Dashboard |

**Recomendação para RHEL:**
- Pequeno: Scripts simples + email
- Médio: Prometheus + Grafana
- Empresarial: Comercial ou Red Hat Insights

---

## 26.9 Solução Monitoramento Completa

### Script Monitoramento Abrangente

```bash
#!/bin/bash
# comprehensive-cert-monitor.sh
# Monitoramento certificado completo para RHEL

WARN_DAYS=30
CRIT_DAYS=7
EMAIL="admin@example.com"
LOG_FILE="/var/log/cert-monitor.log"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

send_alert() {
  local subject=$1
  local body=$2
  echo "$body" | mail -s "$subject" "$EMAIL"
  logger -t cert-monitor "$subject"
}

log "=== Iniciando Monitor Certificado ==="

# Verificação 1: certmonger rodando?
if ! systemctl is-active --quiet certmonger; then
  send_alert "🚨 certmonger NÃO rodando em $(hostname)" \
    "Serviço certmonger não está rodando. Renovações certificado podem falhar!"
fi

# Verificação 2: status certmonger
UNREACHABLE=$(sudo getcert list | grep -c "CA_UNREACHABLE")
if [ $UNREACHABLE -gt 0 ]; then
  send_alert "⚠️ CA inacessível para $UNREACHABLE certificados em $(hostname)" \
    "$(sudo getcert list | grep -B5 'CA_UNREACHABLE')"
fi

# Verificação 3: Expiração certificado
CRITICAL=0
WARNING=0

for cert in /etc/pki/tls/certs/*.crt; do
  [ -f "$cert" ] || continue

  expiry=$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | cut -d= -f2)
  [ -z "$expiry" ] && continue

  expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null)
  now_epoch=$(date +%s)
  days_left=$(( ($expiry_epoch - $now_epoch) / 86400 ))

  if [ $days_left -lt 0 ]; then
    log "🚨 EXPIRADO: $cert"
    ((CRITICAL++))
  elif [ $days_left -lt $CRIT_DAYS ]; then
    log "🔴 CRÍTICO ($days_left dias): $cert"
    ((CRITICAL++))
  elif [ $days_left -lt $WARN_DAYS ]; then
    log "🟡 AVISO ($days_left dias): $cert"
    ((WARNING++))
  else
    log "✅ OK ($days_left dias): $cert"
  fi
done

# Enviar alerta resumo se problemas
if [ $CRITICAL -gt 0 ] || [ $WARNING -gt 0 ]; then
  SUMMARY="Crítico: $CRITICAL, Aviso: $WARNING\n\n$(tail -20 $LOG_FILE)"
  send_alert "Alerta Certificado: $(hostname)" "$SUMMARY"
fi

log "=== Monitor Completo: Crítico=$CRITICAL, Aviso=$WARNING ==="
```

---

## 26.10 Monitoramento com Grafana

### Exemplo Dashboard

```json
{
  "dashboard": {
    "title": "Monitoramento Certificado RHEL",
    "panels": [
      {
        "title": "Certificados Expirando Em Breve",
        "targets": [
          {
            "expr": "certificate_expiry_days < 30"
          }
        ]
      },
      {
        "title": "Status certmonger",
        "targets": [
          {
            "expr": "certmonger_status != 'MONITORING'"
          }
        ]
      }
    ]
  }
}
```

---

## 26.11 Conclusões Chave

1. **Monitorar proativamente** - Não esperar por expiração
2. **Aviso 30 dias mínimo** recomendado
3. **Status certmonger crítico** se usando automatização
4. **Múltiplos canais alerta** (email, Slack, PagerDuty)
5. **Testar monitoramento** - Garantir alertas realmente chegam
6. **Logar tudo** para trilha auditoria
7. **Automatizar remediação** onde possível

---

## Cartão de Referência Rápida

```
┌───────────────────────────────────────────────────────────────────┐
│ REFERÊNCIA RÁPIDA MONITORAMENTO CERTIFICADO                       │
├───────────────────────────────────────────────────────────────────┤
│ Verificar exp:   openssl x509 -in cert.crt -noout -checkend 86400 │
│ Dias restantes:  openssl x509 -in cert.crt -noout -enddate        │
│                                                                   │
│ certmonger:      getcert list                                     │
│ Status:          getcert list | grep "status:"                    │
│ Logs:            journalctl -u certmonger                         │
│                                                                   │
│ Níveis alerta:   60 dias (info)                                   │
│                  30 dias (aviso)                                  │
│                  7 dias (crítico)                                 │
│                  0 dias (emergência!)                             │
│                                                                   │
│ Ferramentas:     Scripts simples, Prometheus, Nagios, Zabbix      │
│ Nativo:          Rastreamento integrado certmonger                │
└───────────────────────────────────────────────────────────────────┘

✅ Monitorar == Sem Surpresas!
✅ Automatizar monitoramento com timers systemd ou cron
```
---

**Navegação do Capítulo**

| [← Anterior: Capítulo 25 - Automatização Ansible para Certificados](25-ansible-automation.md) | [Próximo: Capítulo 27 - Metodologia de Solução de Problemas de Certificados RHEL →](../part-05-troubleshooting/27-troubleshooting-methodology.md) |
|:---|---:|
