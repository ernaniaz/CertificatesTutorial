# Capítulo 41: Cumplimiento y Auditoría

> **Cumplir Requisitos:** Aprende cómo cumplir requisitos de cumplimiento de seguridad (STIG, CIS, PCI-DSS) y auditar configuraciones de certificados en RHEL.

---

## 41.1 Marcos de Cumplimiento

### Requisitos Comunes Relacionados con Certificados

| Marco | Enfoque | Requisitos de Certificados |
|-------|---------|----------------------------|
| **STIG** | Seguridad DoD | FIPS, algoritmos fuertes, auditoría |
| **CIS Benchmark** | Mejores prácticas industria | TLS 1.2+, cifrados fuertes, permisos |
| **PCI-DSS** | Industria tarjetas de pago | Crypto fuerte, no TLS/cifrados débiles |
| **HIPAA** | Salud | Cifrado, control acceso, auditoría |
| **NIST 800-53** | Sistemas federales | FIPS, algoritmos aprobados, monitoreo |

---

## 41.2 Cumplimiento STIG

### Requisitos DISA STIG para Certificados

**Requisitos STIG Clave:**

```markdown
## Controles STIG de Certificados

### V-238200: SSH debe usar cifrados fuertes
- Requisito: Solo algoritmos aprobados por FIPS
- Verificar: /etc/ssh/sshd_config
- Solución: Usar crypto-policies (RHEL 8+)

### V-238201: Servidor web debe usar TLS fuerte
- Requisito: Solo TLS 1.2+
- Verificar: Configuración Apache/NGINX
- Solución: Deshabilitar TLS 1.0/1.1

### V-238202: Certificados deben ser de CA aprobada por DoD
- Requisito: Usar CA aprobada
- Verificar: Emisor del certificado
- Solución: Obtener de fuente aprobada

### V-238203: Claves privadas deben estar protegidas
- Requisito: Modo 600 o más estricto
- Verificar: ls -l /etc/pki/tls/private/
- Solución: chmod 600

### V-238204: Expiración de certificado debe monitorearse
- Requisito: Monitoreo automatizado
- Verificar: Sistema de monitoreo en lugar
- Solución: Implementar (ver Capítulo 26)
```

### Escaneo de Cumplimiento STIG

```bash
#============================================#
# ESCANEO CUMPLIMIENTO STIG PARA CERTIFICADOS
#============================================#

# Instalar SCAP Security Guide
sudo dnf install scap-security-guide openscap-scanner -y

# Ejecutar escaneo STIG
sudo oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_stig \
  --results stig-results.xml \
  --report stig-report.html \
  /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml

# Ver reporte
firefox stig-report.html

# Verificar hallazgos específicos de certificados
grep -i "cert\|tls\|ssl" stig-report.html
```

---

## 41.3 Cumplimiento CIS Benchmark

### Controles CIS para Certificados

**Recomendaciones CIS RHEL Benchmark:**

```markdown
## Controles de Certificados CIS

### 5.2.14: Asegurar que solo se usen cifrados fuertes
- Verificar: Crypto-policy DEFAULT o FUTURE
- Comando: `update-crypto-policies --show`

### 5.2.15: Asegurar que solo se usen algoritmos fuertes
- Verificar: No MD5, SHA-1, claves débiles
- Escanear: Verificar todos los certificados

### 5.2.16: Asegurar TLS 1.2 mínimo
- Verificar: Crypto-policy o config de servicio
- Probar: `openssl s_client -tls1_2`

### 5.3.1: Asegurar permisos en claves privadas
- Requisito: 600 o más estricto
- Verificar: `ls -l /etc/pki/tls/private/`

### 5.3.2: Asegurar monitoreo de expiración de certificados
- Requisito: Verificaciones automatizadas
- Implementación: certmonger o script de monitoreo
```

### Escaneo de Cumplimiento CIS

```bash
#============================================#
# ESCANEO CIS BENCHMARK
#============================================#

# Ejecutar escaneo CIS
sudo oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis \
  --results cis-results.xml \
  --report cis-report.html \
  /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml

# Generar script de remediación
sudo oscap xccdf generate fix \
  --profile xccdf_org.ssgproject.content_profile_cis \
  --fix-type bash \
  stig-results.xml > remediation.sh

# Revisar y ejecutar remediación
chmod +x remediation.sh
sudo ./remediation.sh
```

---

## 41.4 Cumplimiento PCI-DSS

### Requisitos de Certificados PCI-DSS

**Requisitos PCI-DSS v4.0:**

```markdown
## Controles de Certificados PCI-DSS

### Requisito 4.2.1: Criptografía fuerte
- TLS 1.2 mínimo (1.3 recomendado)
- Solo suites de cifrado fuertes
- Verificar: crypto-policy DEFAULT o FUTURE

### Requisito 4.2.1.1: Protocolos inseguros deshabilitados
- NO SSL, TLS 1.0, TLS 1.1
- Verificar: `openssl s_client -tls1`
- Debería fallar en sistema conforme

### Requisito 4.2.1.2: Algoritmos de cifrado fuertes
- AES-128 mínimo
- NO 3DES, DES, RC4
- Verificar: `openssl ciphers -v`

### Requisito 8.3.2: Autenticación basada en certificado
- Para acceso administrativo
- Implementación: Certificados de cliente, tarjetas inteligentes

### Requisito 10: Auditar acceso a certificados
- Registrar todo acceso a clave privada
- Implementación: Reglas auditd
```

### Script de Validación PCI-DSS

```bash
#!/bin/bash
# pci-dss-cert-check.sh

echo "=== Verificación de Cumplimiento PCI-DSS de Certificados ==="

# Verificación 1: Solo TLS 1.2+
echo "1. Verificación de Versión TLS:"
if openssl s_client -connect localhost:443 -tls1 &>/dev/null; then
  echo "  ❌ FALLÓ: TLS 1.0 está habilitado"
else
  echo "  ✅ PASÓ: TLS 1.0 deshabilitado"
fi

# Verificación 2: Cifrados fuertes
echo ""
echo "2. Fortaleza de Cifrado:"
WEAK=$(openssl ciphers -v | grep -Ei "3des|rc4|des-cbc" | wc -l)
if [ $WEAK -gt 0 ]; then
  echo "  ❌ FALLÓ: Cifrados débiles disponibles"
else
  echo "  ✅ PASÓ: Sin cifrados débiles"
fi

# Verificación 3: Monitoreo de expiración de certificado
echo ""
echo "3. Monitoreo de Expiración:"
if systemctl is-active --quiet certmonger || \
   systemctl list-timers | grep -q cert-monitor; then
  echo "  ✅ PASÓ: Monitoreo habilitado"
else
  echo "  ⚠️ ADVERTENCIA: No se detectó monitoreo automatizado"
fi

# Verificación 4: Permisos de clave privada
echo ""
echo "4. Permisos de Clave Privada:"
BAD_PERMS=$(find /etc/pki/tls/private/ -name "*.key" -not -perm 600 2>/dev/null | wc -l)
if [ $BAD_PERMS -gt 0 ]; then
  echo "  ❌ FALLÓ: $BAD_PERMS claves con permisos incorrectos"
else
  echo "  ✅ PASÓ: Todas las claves apropiadamente protegidas"
fi

echo ""
echo "=== Verificación Completa ==="
```

---

## 41.5 Procedimientos de Auditoría

### Lista de Verificación de Auditoría de Certificados

```markdown
## Lista de Verificación Auditoría Trimestral de Certificados

### Revisión de Inventario
- [ ] Todos los certificados documentados
- [ ] Inventario de certificados actual
- [ ] Ownership documentado
- [ ] Propósito documentado

### Revisión de Expiración
- [ ] Sin certificados expirados
- [ ] Sin certificados expirando < 30 días
- [ ] Proceso de renovación documentado
- [ ] Alertas de monitoreo funcionando

### Revisión de Seguridad
- [ ] Solo firmas SHA-256+ (sin SHA-1 ni MD5)
- [ ] Claves RSA 2048+ o ECC P-256+
- [ ] Solo TLS 1.2+ (no 1.0/1.1)
- [ ] Permisos de clave privada correctos (600)
- [ ] Contextos SELinux correctos
- [ ] Sin certificados innecesarios

### Revisión de Configuración
- [ ] Configuraciones de servicio revisadas
- [ ] Crypto-policy apropiada
- [ ] Sin sobrescrituras de cifrado débil
- [ ] HSTS habilitado (servidores web)
- [ ] Certificate pinning documentado

### Revisión de Acceso
- [ ] Logs de auditoría revisados
- [ ] Acceso no autorizado investigado
- [ ] Acceso a clave limitado a personal autorizado
- [ ] Acceso a respaldo controlado

### Revisión de Cumplimiento
- [ ] Cumplimiento STIG/CIS/PCI verificado
- [ ] Escaneos de seguridad pasando
- [ ] Remediación completa
- [ ] Documentación actualizada
```

---

## 41.6 Reportes de Cumplimiento Automatizados

### Generar Reporte de Cumplimiento

```bash
#!/bin/bash
# generate-compliance-report.sh

REPORT_FILE="compliance-report-$(date +%Y%m%d).txt"

cat > "$REPORT_FILE" << EOF
=== Reporte de Cumplimiento de Certificados ===
Generado: $(date)
Sistema: $(hostname)
Versión RHEL: $(cat /etc/redhat-release)

=== Configuración ===
Versión OpenSSL: $(openssl version)
Crypto-Policy: $(update-crypto-policies --show 2>/dev/null || echo "N/A (RHEL 7)")
Modo FIPS: $(fips-mode-setup --check 2>/dev/null || echo "N/A")
SELinux: $(getenforce)

=== Inventario de Certificados ===
EOF

# Contar certificados
TOTAL=$(find /etc/pki/tls/certs/ -name "*.crt" -type f 2>/dev/null | wc -l)
echo "Total Certificados: $TOTAL" >> "$REPORT_FILE"

# Verificar expiraciones
echo "" >> "$REPORT_FILE"
echo "Estado de Expiración:" >> "$REPORT_FILE"
EXPIRING=0
for cert in /etc/pki/tls/certs/*.crt; do
  [ -f "$cert" ] || continue
  if ! openssl x509 -in "$cert" -noout -checkend $((86400*30)) 2>/dev/null; then
    echo "  ⚠️ Expira dentro de 30 días: $cert" >> "$REPORT_FILE"
    ((EXPIRING++))
  fi
done
echo "Certificados expirando < 30 días: $EXPIRING" >> "$REPORT_FILE"

# Verificar algoritmos
echo "" >> "$REPORT_FILE"
echo "Cumplimiento de Algoritmos:" >> "$REPORT_FILE"
SHA1_COUNT=0
for cert in /etc/pki/tls/certs/*.crt; do
  [ -f "$cert" ] || continue
  if openssl x509 -in "$cert" -noout -text 2>/dev/null | grep -qi "sha1.*signature"; then
    echo "  ❌ Firma SHA-1: $cert" >> "$REPORT_FILE"
    ((SHA1_COUNT++))
  fi
done
echo "Certificados SHA-1: $SHA1_COUNT (debería ser 0)" >> "$REPORT_FILE"

# Verificar permisos
echo "" >> "$REPORT_FILE"
echo "Cumplimiento de Permisos:" >> "$REPORT_FILE"
BAD_PERMS=$(find /etc/pki/tls/private/ -name "*.key" -not -perm 600 2>/dev/null | wc -l)
echo "Claves con permisos incorrectos: $BAD_PERMS (debería ser 0)" >> "$REPORT_FILE"

# Estado de certmonger
if command -v getcert &>/dev/null; then
  echo "" >> "$REPORT_FILE"
  echo "Estado de certmonger:" >> "$REPORT_FILE"
  sudo getcert list | grep "status:" | sort | uniq -c >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"
echo "=== Reporte Completo ===" >> "$REPORT_FILE"

cat "$REPORT_FILE"
echo ""
echo "Reporte guardado en: $REPORT_FILE"
```

---

## 41.7 Conclusiones Clave

1. **El cumplimiento es continuo** - No es de una sola vez
2. **Existen múltiples marcos** - STIG, CIS, PCI, HIPAA
3. **OpenSCAP automatiza escaneo** en RHEL
4. **Documentar todo** - Requerido para auditorías
5. **Auditorías regulares esenciales** - Trimestral mínimo
6. **La remediación debe rastrearse** - Corregir y verificar
7. **El monitoreo es cumplimiento** - Validación continua

---

## Tarjeta de Referencia Rápida

```
┌──────────────────────────────────────────────────────────────┐
│ REFERENCIA RÁPIDA CUMPLIMIENTO Y AUDITORÍA                   │
├──────────────────────────────────────────────────────────────┤
│ STIG:         oscap ... --profile stig                       │
│ CIS:          oscap ... --profile cis                        │
│ PCI-DSS:      oscap ... --profile pci-dss                    │
│                                                              │
│ Requisitos Comunes:                                          │
│   - Solo TLS 1.2+                                            │
│   - Algoritmos fuertes (SHA-256+, RSA 2048+)                 │
│   - Sin cifrados débiles (3DES, RC4)                         │
│   - Claves privadas protegidas (modo 600)                    │
│   - Monitoreo de expiración                                  │
│   - Logging de auditoría habilitado                          │
│   - Modo FIPS (para federal)                                 │
│                                                              │
│ Herramientas: OpenSCAP, aide, auditd                         │
│ Escanear:     oscap xccdf eval --profile <profile> ...       │
│ Remediar:     oscap xccdf generate fix ...                   │
└──────────────────────────────────────────────────────────────┘

✅ El cumplimiento es continuo, no de una sola vez
✅ Automatizar escaneo con OpenSCAP
✅ Documentar todas las configuraciones y excepciones
```
---

**Navegación del Capítulo**

| [← Anterior: Capítulo 40 - Fortalecimiento de Seguridad RHEL para Certificados](40-security-hardening.md) | |
|:---|---:|
