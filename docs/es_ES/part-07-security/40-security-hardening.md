# Capítulo 40: Fortalecimiento de Seguridad RHEL para Certificados

> **Defensa en Profundidad:** Más allá de FIPS, aprende cómo fortalecer la seguridad de certificados en RHEL usando SELinux, TPM, tarjetas inteligentes y herramientas de escaneo de seguridad.

---

## 40.1 Resumen de Fortalecimiento de Seguridad

**Capas de Seguridad de Certificados:**

1. **Permisos de Archivo** - Proteger claves privadas
2. **SELinux** - Control de acceso obligatorio
3. **Firewall** - Limitar exposición
4. **Auditoría** - Rastrear acceso
5. **TPM** - Protección de clave por hardware
6. **Tarjetas Inteligentes** - Tokens físicos
7. **Monitoreo** - Detectar problemas
8. **Escaneo de Cumplimiento** - Verificar configuración

---

## 40.2 SELinux para Certificados

### Contextos SELinux Apropiados

```bash
#============================================#
# CONTEXTOS DE CERTIFICADO SELINUX
#============================================#

# Verificar contextos actuales
ls -Z /etc/pki/tls/certs/*.crt
ls -Z /etc/pki/tls/private/*.key

# Contextos correctos:
# Certificados: system_u:object_r:cert_t:s0
# Claves privadas: system_u:object_r:cert_t:s0

# Corregir contextos si están mal
sudo restorecon -Rv /etc/pki/tls/

# Verificar
ls -Z /etc/pki/tls/certs/server.crt
# system_u:object_r:cert_t:s0  ← Correcto
```

### Política de Certificados SELinux

```bash
#============================================#
# ENDURECIMIENTO DE CERTIFICADOS SELINUX
#============================================#

# Asegurar SELinux enforcing
getenforce
# Enforcing  ← Bueno

# Si permissive, habilitar enforcing
sudo setenforce 1

# Hacer permanente
sudo sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config

# Verificar denegaciones relacionadas con certificados
sudo ausearch -m avc -ts recent | grep cert

# Si se encuentran denegaciones, generar política
sudo ausearch -m avc -ts recent | audit2allow -M mycert-policy
sudo semodule -i mycert-policy.pp
```

---

## 40.3 Fortalecimiento de Permisos de Archivo

### Modelo de Permisos Estrictos

```bash
#============================================#
# PERMISOS DE ARCHIVO FORTALECIDOS
#============================================#

# Certificados (públicos) - acceso mínimo
sudo chmod 444 /etc/pki/tls/certs/*.crt
sudo chown root:root /etc/pki/tls/certs/*.crt

# Claves privadas (¡secretas!) - solo propietario
sudo chmod 400 /etc/pki/tls/private/*.key
sudo chown root:root /etc/pki/tls/private/*.key

# Aún más estricto: Inmutable (no puede modificarse ni por root sin eliminar flag)
sudo chattr +i /etc/pki/tls/certs/critical.crt
sudo chattr +i /etc/pki/tls/private/critical.key

# Eliminar inmutable cuando se necesite actualizar
# sudo chattr -i /etc/pki/tls/private/critical.key

# Verificar
ls -l /etc/pki/tls/private/
# -r--------. 1 root root  ← 400, muy restrictivo
```

---

## 40.4 TPM (Módulo de Plataforma Confiable)

### Usar TPM para Almacenamiento de Claves

**Beneficios de TPM:**
- ✅ Claves protegidas por hardware
- ✅ Las claves nunca salen del TPM
- ✅ Resistente a manipulación
- ✅ Atestación de plataforma

```bash
#============================================#
# TPM PARA CLAVES DE CERTIFICADO (AVANZADO)
#============================================#

# Verificar si TPM está disponible
ls /dev/tpm*

# Instalar herramientas TPM
sudo dnf install tpm2-tools -y

# Generar clave en TPM
tpm2_createprimary -C o -g sha256 -G rsa -c primary.ctx
tpm2_create -G rsa -u rsa.pub -r rsa.priv -C primary.ctx

# Usar clave TPM con OpenSSL requiere configuración adicional
# (Complejo, caso de uso empresarial)

# Para certmonger con TPM:
# Experimental/avanzado - verificar docs Red Hat
```

---

## 40.5 Tarjetas Inteligentes y PIV

### Usar Tarjetas Inteligentes para Autenticación

```bash
#============================================#
# CONFIGURACIÓN TARJETA INTELIGENTE (PIV/CAC)
#============================================#

# Instalar soporte de tarjeta inteligente
sudo dnf install opensc pcsc-lite -y

# Iniciar demonio PC/SC
sudo systemctl enable --now pcscd

# Verificar si tarjeta es legible
pkcs11-tool --list-slots

# Listar certificados en tarjeta
pkcs11-tool --list-objects

# Usar tarjeta inteligente con SSH
# /etc/ssh/sshd_config:
# PubkeyAuthentication yes

# Extraer clave pública de tarjeta
ssh-keygen -D /usr/lib64/opensc-pkcs11.so > ~/.ssh/authorized_keys
```

---

## 40.6 Auditoría y Monitoreo

### auditd para Acceso a Certificados

```bash
#============================================#
# AUDITAR ACCESO A CERTIFICADOS
#============================================#

# Agregar reglas de auditoría para acceso a clave privada
sudo auditctl -w /etc/pki/tls/private/ -p war -k certificate-access

# Hacer permanente
echo "-w /etc/pki/tls/private/ -p war -k certificate-access" | \
  sudo tee -a /etc/audit/rules.d/certificate.rules

# Recargar reglas
sudo augenrules --load

# Monitorear acceso
sudo ausearch -k certificate-access

# Monitoreo en tiempo real
sudo ausearch -k certificate-access -ts recent -i
```

---

## 40.7 Escaneo OpenSCAP

### Escaneo de Cumplimiento de Seguridad

```bash
#============================================#
# ESCANEO DE CERTIFICADOS OPENSCAP
#============================================#

# Instalar OpenSCAP
sudo dnf install openscap-scanner scap-security-guide -y

# Escanear problemas de certificados
sudo oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_pci-dss \
  --results scan-results.xml \
  --report scan-report.html \
  /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml

# Ver reporte
firefox scan-report.html

# Verificaciones relacionadas con certificados:
# - Permisos de archivo
# - Contextos SELinux
# - Algoritmos débiles
# - Expiración
```

---

## 40.8 Lista de Verificación de Fortalecimiento de Seguridad

```markdown
## Lista de Verificación Fortalecimiento de Seguridad de Certificados

### Seguridad de Archivo
- [ ] Claves privadas modo 400 o 600 (¡nunca 644!)
- [ ] Certificados modo 444 o 644
- [ ] Ownership: root:root o usuario del servicio
- [ ] Contextos SELinux: cert_t
- [ ] Considerar flag inmutable (+i) para certs críticos

### Control de Acceso
- [ ] SELinux enforcing
- [ ] Reglas de auditoría para acceso a clave privada
- [ ] Firewall limitando puertos TLS
- [ ] Principio de menor privilegio aplicado

### Seguridad de Algoritmo
- [ ] Solo firmas SHA-256+
- [ ] Claves RSA 2048+ o ECC P-256+
- [ ] Solo TLS 1.2+ (no 1.0/1.1)
- [ ] Cifrados fuertes (vía crypto-policy)
- [ ] Modo FIPS si es requerido

### Seguridad Operacional
- [ ] Certificados monitoreados para expiración
- [ ] Renovación automática habilitada (certmonger)
- [ ] Respaldos cifrados
- [ ] Claves nunca enviadas por email o en tickets
- [ ] Acceso registrado y revisado
- [ ] Escaneos de seguridad regulares

### Seguridad de Red
- [ ] Reglas de firewall restrictivas
- [ ] Solo puertos necesarios abiertos
- [ ] Certificate pinning (donde aplique)
- [ ] HSTS habilitado para servidores web
- [ ] OCSP stapling habilitado

### Cumplimiento
- [ ] Escaneos OpenSCAP pasando
- [ ] Cumplimiento STIG verificado
- [ ] Benchmarks CIS cumplidos
- [ ] Documentación actual
- [ ] Pista de auditoría mantenida
```

---

## 40.9 Conclusiones Clave

1. **Defensa en profundidad** - Múltiples capas de seguridad
2. **SELinux enforcing** - Obligatorio para producción
3. **Permisos de archivo críticos** - 400/600 para claves
4. **Auditar todo** - Rastrear acceso a claves
5. **TPM para alta seguridad** - Protección por hardware
6. **OpenSCAP para cumplimiento** - Escaneo automatizado
7. **Monitorear continuamente** - La seguridad es continua

---

## Tarjeta de Referencia Rápida

```
┌──────────────────────────────────────────────────────────────┐
│ ENDURECIMIENTO DE SEGURIDAD DE CERTIFICADOS                  │
├──────────────────────────────────────────────────────────────┤
│ Permisos:     chmod 400 /etc/pki/tls/private/*.key           │
│               chmod 444 /etc/pki/tls/certs/*.crt             │
│                                                              │
│ SELinux:      getenforce (debe ser Enforcing)                │
│               restorecon -Rv /etc/pki/tls/                   │
│               ls -Z (verificar contextos)                    │
│                                                              │
│ Auditoría:    auditctl -w /etc/pki/tls/private/ -p war       │
│               ausearch -k certificate-access                 │
│                                                              │
│ Escanear:     oscap xccdf eval --profile pci-dss ...         │
│                                                              │
│ Inmutable:    chattr +i /etc/pki/tls/private/key.key         │
│               chattr -i (para modificar)                     │
└──────────────────────────────────────────────────────────────┘

✅ SELinux enforcing es obligatorio
✅ Auditar acceso a clave privada
✅ Usar 400 (no 600) para máxima seguridad
```

---

## 🧪 Laboratorio Práctico

**Lab 20: Fortalecimiento de Seguridad**

Aplique mejores prácticas de seguridad a configuraciones de certificados

- 📁 **Ubicación:** `labs/es_ES/20-security-hardening/`
- ⏱️ **Tiempo:** 30-40 minutos
- 🎯 **Nivel:** Avanzado

---

**Navegación del Capítulo**

| [← Anterior: Capítulo 39 - Certificados Compatibles con FIPS](39-fips-certificates.md) | [Siguiente: Capítulo 41 - Cumplimiento y Auditoría →](41-compliance-auditing.md) |
|:---|---:|
