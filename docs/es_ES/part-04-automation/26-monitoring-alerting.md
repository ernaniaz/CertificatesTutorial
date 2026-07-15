# Capítulo 26: Monitoreo y Alertas en RHEL

> **Prevenir Interrupciones:** El monitoreo proactivo previene sorpresas de expiración de certificados. Aprende cómo monitorear certificados y configurar alertas en RHEL.

---

## 26.1 ¿Por Qué Monitorear Certificados?

**Sin Monitoreo:**
```
❌ El certificado expira
❌ El sitio web cae a las 2 AM
❌ Incidente de emergencia
❌ Pérdida de ingresos
❌ Daño a reputación
❌ Noche estresante para el equipo de operaciones
```

**Con Monitoreo:**
```
✅ Alerta 30 días antes de expirar
✅ Renovación planificada durante horario laboral
✅ Sin interrupciones
✅ Sin emergencias
✅ Clientes contentos
✅ Equipo de operaciones bien descansado
```

---

## 26.2 Qué Monitorear

### Métricas de Certificados

```markdown
## Métricas Críticas:

✅ **Fecha de expiración** (días hasta expirar)
✅ **Validez del certificado** (aún no válido, expirado)
✅ **Coincidencia par certificado/clave**
✅ **Validez de cadena de confianza**
✅ **Estado de certmonger** (si se usa)
✅ **Salud del servicio** (usando el certificado)
✅ **Éxito/fallo de renovación**

## Umbrales de Advertencia:

🟡 60 días: Primera advertencia
🟠 30 días: Segunda advertencia
🔴 15 días: Alerta crítica
🚨 7 días: Escalación de emergencia
```

---

## 26.3 Scripts Simples de Monitoreo

### Verificación Básica de Expiración

```bash
#!/bin/bash
# check-cert-expiration.sh
# Verificador simple de expiración de certificados

WARN_DAYS=30
CRIT_DAYS=7

check_cert() {
  local cert=$1
  local name=$(basename "$cert")

  if [ ! -f "$cert" ]; then
    echo "❌ $name: Archivo no encontrado"
    return 2
  fi

  # Obtener fecha de expiración
  expiry=$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | cut -d= -f2)

  if [ -z "$expiry" ]; then
    echo "❌ $name: Certificado inválido"
    return 2
  fi

  # Calcular días restantes
  expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null)
  now_epoch=$(date +%s)
  days_left=$(( ($expiry_epoch - $now_epoch) / 86400 ))

  # Verificar umbrales
  if [ $days_left -lt 0 ]; then
    echo "🚨 $name: ¡EXPIRADO hace $((- days_left)) días!"
    return 2
  elif [ $days_left -lt $CRIT_DAYS ]; then
    echo "🔴 $name: CRÍTICO - quedan $days_left días"
    return 2
  elif [ $days_left -lt $WARN_DAYS ]; then
    echo "🟡 $name: ADVERTENCIA - quedan $days_left días"
    return 1
  else
    echo "✅ $name: OK - quedan $days_left días"
    return 0
  fi
}

# Verificar todos los certificados
for cert in /etc/pki/tls/certs/*.crt; do
  check_cert "$cert"
done
```

### Monitor de Estado de certmonger

```bash
#!/bin/bash
# monitor-certmonger.sh
# Monitorear estado de rastreo de certmonger

echo "=== Monitor de Estado certmonger ==="

# Verificar si certmonger está ejecutándose
if ! systemctl is-active --quiet certmonger; then
  echo "🚨 CRÍTICO: ¡certmonger no está ejecutándose!"
  systemctl status certmonger
  exit 2
fi

# Obtener estado de certmonger
STATUS_OUTPUT=$(sudo getcert list 2>&1)

# Contar certificados por estado
TOTAL=$(echo "$STATUS_OUTPUT" | grep -c "Request ID")
MONITORING=$(echo "$STATUS_OUTPUT" | grep -c "status: MONITORING")
UNREACHABLE=$(echo "$STATUS_OUTPUT" | grep -c "status: CA_UNREACHABLE")
REJECTED=$(echo "$STATUS_OUTPUT" | grep -c "status: CA_REJECTED")

echo "Total de certificados: $TOTAL"
echo "  MONITORING: $MONITORING ✅"
echo "  CA_UNREACHABLE: $UNREACHABLE $([ $UNREACHABLE -gt 0 ] && echo '⚠️')"
echo "  CA_REJECTED: $REJECTED $([ $REJECTED -gt 0 ] && echo '❌')"

# Alertar si hay problemas
if [ $UNREACHABLE -gt 0 ] || [ $REJECTED -gt 0 ]; then
  echo ""
  echo "🚨 SE REQUIERE ATENCIÓN:"
  sudo getcert list | grep -B5 "status: CA_" | grep -E "(Request ID|status:)"
  exit 1
fi

echo "✅ Todos los certificados OK"
```

---

## 26.4 Temporizador Systemd para Monitoreo

### Crear Temporizador de Monitoreo

```bash
#============================================#
# CREAR TEMPORIZADOR SYSTEMD PARA MONITOREO
#============================================#

# Crear archivo de servicio
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

# Crear archivo de temporizador (ejecutar diariamente)
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

# Instalar script de monitoreo
sudo cp check-cert-expiration.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/check-cert-expiration.sh

# Habilitar temporizador
sudo systemctl daemon-reload
sudo systemctl enable cert-monitor.timer
sudo systemctl start cert-monitor.timer

# Verificar
systemctl list-timers | grep cert-monitor

# Probar manualmente
sudo systemctl start cert-monitor.service
sudo journalctl -u cert-monitor.service
```

---

## 26.5 Alertas por Email

### Alertas Simples por Email

```bash
#!/bin/bash
# cert-monitor-with-email.sh
# Monitor de certificados con alertas por email

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
  echo -e "Advertencias de Expiración de Certificados:\n$ALERTS" | \
    mail -s "⚠️ Alerta de Expiración de Certificados - $(hostname)" "$EMAIL"
fi
```

---

## 26.6 Monitoreo Prometheus (Avanzado)

### Exportador de Certificados

```bash
#============================================#
# MONITOREO CERTIFICADOS PROMETHEUS
#============================================#

# Instalar x509-certificate-exporter (ejemplo)
# https://github.com/enix/x509-certificate-exporter

# O usar colector textfile de Node Exporter

# Crear script colector de métricas
cat > /usr/local/bin/cert-metrics.sh << 'EOF'
#!/bin/bash
# Generar métricas Prometheus para certificados

METRICS_FILE="/var/lib/node_exporter/textfile_collector/certificates.prom"
mkdir -p $(dirname "$METRICS_FILE")

cat > "$METRICS_FILE" << PROM
# HELP certificate_expiry_days Días hasta expiración de certificado
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

# Ejecutar vía cron
echo "*/5 * * * * /usr/local/bin/cert-metrics.sh" | sudo crontab -
```

### Reglas de Alerta Prometheus

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
          summary: "Certificado expirando en {{ $value }} días"
          description: "Certificado {{ $labels.cert }} en {{ $labels.hostname }} expira en {{ $value }} días"

      - alert: CertificateExpiryCritical
        expr: certificate_expiry_days < 7
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "¡Certificado expirando en {{ $value }} días!"
          description: "URGENTE: Certificado {{ $labels.cert }} en {{ $labels.hostname }} expira en {{ $value }} días!"

      - alert: CertificateExpired
        expr: certificate_expiry_days < 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "¡Certificado EXPIRADO!"
          description: "¡Certificado {{ $labels.cert }} en {{ $labels.hostname }} ha expirado!"
```

---

## 26.7 Logging Centralizado

### Enviar Eventos de Certificados a Syslog

```bash
#============================================#
# REGISTRAR EVENTOS DE CERTIFICADOS
#============================================#

# certmonger registra en journal
sudo journalctl -u certmonger -f

# Reenviar a syslog central
# /etc/rsyslog.conf
*.* @@syslog-server.example.com:514

# O configurar logging específico de certmonger
# Monitorear renovaciones de certmonger
sudo journalctl -u certmonger --since today | grep -i "renewed\|failed"
```

---

## 26.8 Comparación de Herramientas de Monitoreo

### Opciones para RHEL

| Herramienta | Complejidad | Costo | Integración | Alertas |
|-------------|-------------|-------|-------------|---------|
| **Scripts simples** | Baja | Gratis | Fácil | Email/syslog |
| **Nagios/Icinga** | Media | Gratis | Buena | Múltiples |
| **Prometheus + Grafana** | Media-Alta | Gratis | Excelente | Potente |
| **Zabbix** | Media | Gratis | Buena | Múltiples |
| **Comercial (Datadog, etc.)** | Baja | $$$ | Excelente | Avanzadas |
| **Red Hat Insights** | Baja | Suscripción | Nativa | Dashboard |

**Recomendación para RHEL:**
- Pequeño: Scripts simples + email
- Mediano: Prometheus + Grafana
- Empresa: Comercial o Red Hat Insights

---

## 26.9 Solución de Monitoreo Completa

### Script de Monitoreo Comprehensivo

```bash
#!/bin/bash
# comprehensive-cert-monitor.sh
# Monitoreo completo de certificados para RHEL

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

log "=== Iniciando Monitor de Certificados ==="

# Verificación 1: ¿certmonger ejecutándose?
if ! systemctl is-active --quiet certmonger; then
  send_alert "🚨 certmonger NO ejecutándose en $(hostname)" \
    "¡El servicio certmonger no está ejecutándose. Las renovaciones de certificados pueden fallar!"
fi

# Verificación 2: Estado de certmonger
UNREACHABLE=$(sudo getcert list | grep -c "CA_UNREACHABLE")
if [ $UNREACHABLE -gt 0 ]; then
  send_alert "⚠️ CA inalcanzable para $UNREACHABLE certificados en $(hostname)" \
    "$(sudo getcert list | grep -B5 'CA_UNREACHABLE')"
fi

# Verificación 3: Expiración de certificado
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
    log "🔴 CRÍTICO ($days_left días): $cert"
    ((CRITICAL++))
  elif [ $days_left -lt $WARN_DAYS ]; then
    log "🟡 ADVERTENCIA ($days_left días): $cert"
    ((WARNING++))
  else
    log "✅ OK ($days_left días): $cert"
  fi
done

# Enviar alerta resumen si hay problemas
if [ $CRITICAL -gt 0 ] || [ $WARNING -gt 0 ]; then
  SUMMARY="Crítico: $CRITICAL, Advertencia: $WARNING\n\n$(tail -20 $LOG_FILE)"
  send_alert "Alerta de Certificados: $(hostname)" "$SUMMARY"
fi

log "=== Monitor Completo: Crítico=$CRITICAL, Advertencia=$WARNING ==="
```

---

## 26.10 Monitoreo con Grafana

### Ejemplo de Dashboard

```json
{
  "dashboard": {
    "title": "Monitoreo de Certificados RHEL",
    "panels": [
      {
        "title": "Certificados Expirando Pronto",
        "targets": [
          {
            "expr": "certificate_expiry_days < 30"
          }
        ]
      },
      {
        "title": "Estado de certmonger",
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

## 26.11 Conclusiones Clave

1. **Monitorear proactivamente** - No esperar a la expiración
2. **Advertencia de 30 días mínimo** recomendada
3. **Estado de certmonger crítico** si se usa automatización
4. **Múltiples canales de alerta** (email, Slack, PagerDuty)
5. **Probar monitoreo** - Asegurar que las alertas realmente te alcancen
6. **Registrar todo** para pista de auditoría
7. **Automatizar remediación** donde sea posible

---

## Tarjeta de Referencia Rápida

```
┌────────────────── ────────────────────────────────────────────────┐
│ REFERENCIA RÁPIDA MONITOREO DE CERTIFICADOS                       │
├───────────────── ─────────────────────────────────────────────────┤
│ Ver expiración:  openssl x509 -in cert.crt -noout -checkend 86400 │
│ Días restantes:  openssl x509 -in cert.crt -noout -enddate        │
│                                                                   │
│ certmonger:      getcert list                                     │
│ Estado:          getcert list | grep "status:"                    │
│ Logs:            journalctl -u certmonger                         │
│                                                                   │
│ Niveles alerta:  60 días (info)                                   │
│                  30 días (advertencia)                            │
│                  7 días (crítico)                                 │
│                  0 días (¡emergencia!)                            │
│                                                                   │
│ Herramientas:    Scripts simples, Prometheus, Nagios, Zabbix      │
│ Nativo:          Rastreo integrado de certmonger                  │
└───────────────────────────────────────────────────────────────────┘

✅ Monitorear == ¡Sin Sorpresas!
✅ Automatizar monitoreo con temporizadores systemd o cron
```
---

**Navegación del Capítulo**

| [← Anterior: Capítulo 25 - Automatización Ansible para Certificados](25-ansible-automation.md) | [Siguiente: Capítulo 27 - Metodología de Solución de Problemas de Certificados RHEL →](../part-05-troubleshooting/27-troubleshooting-methodology.md) |
|:---|---:|
