# Chapter 26: Monitoring & Alerting on RHEL

> **Prevent Outages:** Proactive monitoring prevents certificate expiration surprises. Learn how to monitor certificates and set up alerts on RHEL.

---

## 26.1 Why Monitor Certificates?

**Without Monitoring:**
```
❌ Certificate expires
❌ Website goes down at 2 AM
❌ Emergency incident
❌ Revenue loss
❌ Reputation damage
❌ Stressful night for ops team
```

**With Monitoring:**
```
✅ Alert 30 days before expiry
✅ Planned renewal during business hours
✅ No outages
✅ No emergencies
✅ Happy customers
✅ Well-rested ops team
```

---

## 26.2 What to Monitor

### Certificate Metrics

```markdown
## Critical Metrics:

✅ **Expiration date** (days until expiry)
✅ **Certificate validity** (not yet valid, expired)
✅ **Certificate/key pair match**
✅ **Trust chain validity**
✅ **certmonger status** (if used)
✅ **Service health** (using the certificate)
✅ **Renewal success/failure**

## Warning Thresholds:

🟡 60 days: First warning
🟠 30 days: Second warning
🔴 15 days: Critical alert
🚨 7 days: Emergency escalation
```

---

## 26.3 Simple Monitoring Scripts

### Basic Expiration Check

```bash
#!/bin/bash
# check-cert-expiration.sh
# Simple certificate expiration checker

WARN_DAYS=30
CRIT_DAYS=7

check_cert() {
  local cert=$1
  local name=$(basename "$cert")

  if [ ! -f "$cert" ]; then
    echo "❌ $name: File not found"
    return 2
  fi

  # Get expiration date
  expiry=$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | cut -d= -f2)

  if [ -z "$expiry" ]; then
    echo "❌ $name: Invalid certificate"
    return 2
  fi

  # Calculate days remaining
  expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null)
  now_epoch=$(date +%s)
  days_left=$(( ($expiry_epoch - $now_epoch) / 86400 ))

  # Check thresholds
  if [ $days_left -lt 0 ]; then
    echo "🚨 $name: EXPIRED $((- days_left)) days ago!"
    return 2
  elif [ $days_left -lt $CRIT_DAYS ]; then
    echo "🔴 $name: CRITICAL - $days_left days left"
    return 2
  elif [ $days_left -lt $WARN_DAYS ]; then
    echo "🟡 $name: WARNING - $days_left days left"
    return 1
  else
    echo "✅ $name: OK - $days_left days left"
    return 0
  fi
}

# Check all certificates
for cert in /etc/pki/tls/certs/*.crt; do
  check_cert "$cert"
done
```

### certmonger Status Monitor

```bash
#!/bin/bash
# monitor-certmonger.sh
# Monitor certmonger tracking status

echo "=== certmonger Status Monitor ==="

# Check if certmonger is running
if ! systemctl is-active --quiet certmonger; then
  echo "🚨 CRITICAL: certmonger is not running!"
  systemctl status certmonger
  exit 2
fi

# Get certmonger status
STATUS_OUTPUT=$(sudo getcert list 2>&1)

# Count certificates by status
TOTAL=$(echo "$STATUS_OUTPUT" | grep -c "Request ID")
MONITORING=$(echo "$STATUS_OUTPUT" | grep -c "status: MONITORING")
UNREACHABLE=$(echo "$STATUS_OUTPUT" | grep -c "status: CA_UNREACHABLE")
REJECTED=$(echo "$STATUS_OUTPUT" | grep -c "status: CA_REJECTED")

echo "Total certificates: $TOTAL"
echo "  MONITORING: $MONITORING ✅"
echo "  CA_UNREACHABLE: $UNREACHABLE $([ $UNREACHABLE -gt 0 ] && echo '⚠️')"
echo "  CA_REJECTED: $REJECTED $([ $REJECTED -gt 0 ] && echo '❌')"

# Alert if problems
if [ $UNREACHABLE -gt 0 ] || [ $REJECTED -gt 0 ]; then
  echo ""
  echo "🚨 ATTENTION REQUIRED:"
  sudo getcert list | grep -B5 "status: CA_" | grep -E "(Request ID|status:)"
  exit 1
fi

echo "✅ All certificates OK"
```

---

## 26.4 Systemd Timer for Monitoring

### Create Monitoring Timer

```bash
#============================================#
# CREATE SYSTEMD TIMER FOR MONITORING
#============================================#

# Create service file
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

# Create timer file (run daily)
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

# Install monitoring script
sudo cp check-cert-expiration.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/check-cert-expiration.sh

# Enable timer
sudo systemctl daemon-reload
sudo systemctl enable cert-monitor.timer
sudo systemctl start cert-monitor.timer

# Verify
systemctl list-timers | grep cert-monitor

# Test manually
sudo systemctl start cert-monitor.service
sudo journalctl -u cert-monitor.service
```

---

## 26.5 Email Alerts

### Simple Email Alerting

```bash
#!/bin/bash
# cert-monitor-with-email.sh
# Certificate monitor with email alerts

EMAIL="admin@example.com"
WARN_DAYS=30

ALERTS=""

for cert in /etc/pki/tls/certs/*.crt; do
  [ -f "$cert" ] || continue

  if ! openssl x509 -in "$cert" -noout -checkend $((86400*WARN_DAYS)) 2>/dev/null; then
    expiry=$(openssl x509 -in "$cert" -noout -enddate | cut -d= -f2)
    ALERTS="$ALERTS\nCertificate: $cert\nExpires: $expiry\n"
  fi
done

if [ -n "$ALERTS" ]; then
  echo -e "Certificate Expiration Warnings:\n$ALERTS" | \
    mail -s "⚠️ Certificate Expiration Alert - $(hostname)" "$EMAIL"
fi
```

---

## 26.6 Prometheus Monitoring (Advanced)

### Certificate Exporter

```bash
#============================================#
# PROMETHEUS CERTIFICATE MONITORING
#============================================#

# Install x509-certificate-exporter (example)
# https://github.com/enix/x509-certificate-exporter

# Or use Node Exporter textfile collector

# Create metrics collector script
cat > /usr/local/bin/cert-metrics.sh << 'EOF'
#!/bin/bash
# Generate Prometheus metrics for certificates

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

# Run via cron
echo "*/5 * * * * /usr/local/bin/cert-metrics.sh" | sudo crontab -
```

### Prometheus Alert Rules

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
          summary: "Certificate expiring in {{ $value }} days"
          description: "Certificate {{ $labels.cert }} on {{ $labels.hostname }} expires in {{ $value }} days"

      - alert: CertificateExpiryCritical
        expr: certificate_expiry_days < 7
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Certificate expiring in {{ $value }} days!"
          description: "URGENT: Certificate {{ $labels.cert }} on {{ $labels.hostname }} expires in {{ $value }} days!"

      - alert: CertificateExpired
        expr: certificate_expiry_days < 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Certificate EXPIRED!"
          description: "Certificate {{ $labels.cert }} on {{ $labels.hostname }} has expired!"
```

---

## 26.7 Centralized Logging

### Send Certificate Events to Syslog

```bash
#============================================#
# LOG CERTIFICATE EVENTS
#============================================#

# certmonger logs to journal
sudo journalctl -u certmonger -f

# Forward to central syslog
# /etc/rsyslog.conf
*.* @@syslog-server.example.com:514

# Or configure specific certmonger logging
# Monitor certmonger renewals
sudo journalctl -u certmonger --since today | grep -i "renewed\|failed"
```

---

## 26.8 Monitoring Tools Comparison

### Options for RHEL

| Tool | Complexity | Cost | Integration | Alerting |
|------|------------|------|-------------|----------|
| **Simple scripts** | Low | Free | Easy | Email/syslog |
| **Nagios/Icinga** | Medium | Free | Good | Multiple |
| **Prometheus + Grafana** | Medium-High | Free | Excellent | Powerful |
| **Zabbix** | Medium | Free | Good | Multiple |
| **Commercial (Datadog, etc.)** | Low | $$$ | Excellent | Advanced |
| **Red Hat Insights** | Low | Subscription | Native | Dashboard |

**Recommendation for RHEL:**
- Small: Simple scripts + email
- Medium: Prometheus + Grafana
- Enterprise: Commercial or Red Hat Insights

---

## 26.9 Complete Monitoring Solution

### Comprehensive Monitoring Script

```bash
#!/bin/bash
# comprehensive-cert-monitor.sh
# Complete certificate monitoring for RHEL

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

log "=== Starting Certificate Monitor ==="

# Check 1: certmonger running?
if ! systemctl is-active --quiet certmonger; then
  send_alert "🚨 certmonger NOT running on $(hostname)" \
    "certmonger service is not running. Certificate renewals may fail!"
fi

# Check 2: certmonger status
UNREACHABLE=$(sudo getcert list | grep -c "CA_UNREACHABLE")
if [ $UNREACHABLE -gt 0 ]; then
  send_alert "⚠️ CA unreachable for $UNREACHABLE certificates on $(hostname)" \
    "$(sudo getcert list | grep -B5 'CA_UNREACHABLE')"
fi

# Check 3: Certificate expiration
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
    log "🚨 EXPIRED: $cert"
    ((CRITICAL++))
  elif [ $days_left -lt $CRIT_DAYS ]; then
    log "🔴 CRITICAL ($days_left days): $cert"
    ((CRITICAL++))
  elif [ $days_left -lt $WARN_DAYS ]; then
    log "🟡 WARNING ($days_left days): $cert"
    ((WARNING++))
  else
    log "✅ OK ($days_left days): $cert"
  fi
done

# Send summary alert if issues
if [ $CRITICAL -gt 0 ] || [ $WARNING -gt 0 ]; then
  SUMMARY="Critical: $CRITICAL, Warning: $WARNING\n\n$(tail -20 $LOG_FILE)"
  send_alert "Certificate Alert: $(hostname)" "$SUMMARY"
fi

log "=== Monitor Complete: Critical=$CRITICAL, Warning=$WARNING ==="
```

---

## 26.10 Monitoring with Grafana

### Dashboard Example

```json
{
  "dashboard": {
    "title": "RHEL Certificate Monitoring",
    "panels": [
      {
        "title": "Certificates Expiring Soon",
        "targets": [
          {
            "expr": "certificate_expiry_days < 30"
          }
        ]
      },
      {
        "title": "certmonger Status",
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

## 26.11 Key Takeaways

1. **Monitor proactively** - Don't wait for expiration
2. **30-day warning minimum** recommended
3. **certmonger status critical** if using automation
4. **Multiple alert channels** (email, Slack, PagerDuty)
5. **Test monitoring** - Ensure alerts actually reach you
6. **Log everything** for audit trail
7. **Automate remediation** where possible

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────────────┐
│ CERTIFICATE MONITORING QUICK REFERENCE                          │
├─────────────────────────────────────────────────────────────────┤
│ Check expiry:  openssl x509 -in cert.crt -noout -checkend 86400 │
│ Days left:     openssl x509 -in cert.crt -noout -enddate        │
│                                                                 │
│ certmonger:    getcert list                                     │
│ Status:        getcert list | grep "status:"                    │
│ Logs:          journalctl -u certmonger                         │
│                                                                 │
│ Alert levels:  60 days (info)                                   │
│                30 days (warning)                                │
│                7 days (critical)                                │
│                0 days (emergency!)                              │
│                                                                 │
│ Tools:         Simple scripts, Prometheus, Nagios, Zabbix       │
│ Native:        certmonger built-in tracking                     │
└─────────────────────────────────────────────────────────────────┘

✅ Monitor == No Surprises!
✅ Automate monitoring with systemd timers or cron
```
---

**Chapter Navigation**

| [← Previous: Chapter 25 - Ansible Automation for Certificates](25-ansible-automation.md) | [Next: Chapter 27 - RHEL Certificate Troubleshooting Methodology →](../part-05-troubleshooting/27-troubleshooting-methodology.md) |
|:---|---:|
