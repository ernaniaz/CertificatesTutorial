# Guía de Inicio Rápido de Solución de Problemas

**¡Cuando tengas un problema de certificado, comienza aquí!**

---

## 🚨 ¿Emergencia? ¡Salta al Capítulo 33!

Si la producción está caída, ve inmediatamente a [Capítulo 33: Procedimientos de Emergencia](part-05-troubleshooting/33-emergency-procedures.md)

---

## 📋 El Método de 7 Pasos (Capítulo 27)

```
1. Identificar: versión de RHEL, OpenSSL y crypto-policy
2. Verificar: expiración, hostname, coincidencia clave-certificado y algoritmo
3. Confianza: validación de CA, cadena e intermedios
4. Configuración: archivos del servicio, rutas y permisos
5. Sistema: crypto-policy, FIPS, SELinux y firewall
6. Probar: conexiones en vivo, curl y openssl s_client
7. Logs: logs del servicio, journal y auditoría SELinux
```

**Metodología completa:** [Capítulo 27](part-05-troubleshooting/27-troubleshooting-methodology.md)

---

## ⚡ Diagnósticos Rápidos

### Primeros 60 Segundos

```bash
# ¿Qué versión de RHEL?
cat /etc/redhat-release

# ¿Certificado expirado?
openssl x509 -in /etc/pki/tls/certs/server.crt -noout -checkend 0

# ¿Servicio en ejecución?
systemctl status httpd

# ¿Errores recientes?
journalctl -xe | grep -i cert | tail -20

# ¿Crypto-policy? (RHEL 8+)
update-crypto-policies --show
```

---

## 🔍 Problemas Comunes

### Certificado Expirado
```bash
# Verificar
openssl x509 -in cert.crt -noout -dates

# Solución
sudo getcert resubmit -f cert.crt  # Si usas seguimiento con certmonger
# O renovar manualmente, o usar los procedimientos de emergencia del Capítulo 33
```

### Cadena de Confianza Rota
```bash
# Verificar
openssl verify cert.crt

# Solución
sudo cp ca.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust
```

### Permiso Denegado
```bash
# Verificar
ls -l /etc/pki/tls/private/server.key

# Solución
sudo chmod 600 /etc/pki/tls/private/server.key
sudo chown root:root /etc/pki/tls/private/server.key
```

### Desajuste de Hostname
```bash
# Verificar
openssl x509 -in cert.crt -noout -ext subjectAltName

# Solución
# Reemitir certificado con SANs correctos
```

### Sin Cifrado Compartido (RHEL 8+)
```bash
# Verificar
update-crypto-policies --show

# Solución temporal
sudo update-crypto-policies --set LEGACY
sudo systemctl restart httpd

# Solución apropiada: actualizar el cliente para soportar TLS 1.2+
```

### SHA-1 Rechazado (RHEL 9+)
```bash
# Verificar
openssl x509 -in cert.crt -noout -text | grep "Signature Algorithm"

# Solución
# Debe reemitirse con SHA-256+ (sin solución alternativa)
```

---

## 📖 Dónde Buscar

| Tipo de Problema | Ir al Capítulo |
|------------------|----------------|
| **Solución de problemas general** | Capítulo 27 |
| **Errores comunes** | Capítulo 28 |
| **Problemas Apache/NGINX/Postfix** | Capítulo 29 |
| **Problemas de certmonger** | Capítulo 30 |
| **Problemas de crypto-policy** | Capítulo 31 |
| **Análisis de informes SOS** | Capítulo 32 |
| **Emergencia en producción** | Capítulo 33 |
| **Específico para RHEL 7** | Capítulo 9 |
| **Específico para RHEL 8** | Capítulo 10 |
| **Específico para RHEL 9** | Capítulo 11 |
| **Específico para RHEL 10** | Capítulo 12 |
| **Después de migración** | Capítulos 35-36 |

---

## ⚙️ Comandos Específicos por Servicio

```bash
# Apache
apachectl configtest
tail -f /var/log/httpd/ssl_error_log

# NGINX
nginx -t
tail -f /var/log/nginx/error.log

# Postfix
postfix check
tail -f /var/log/maillog | grep TLS

# OpenLDAP
slapcat -b "cn=config" | grep TLS
# Nota: ¡Las claves deben ser propiedad de ldap:ldap!

# PostgreSQL
sudo -u postgres psql -c "SHOW ssl;"
# Nota: ¡Las claves deben ser propiedad de postgres:postgres!

# certmonger
getcert list
journalctl -u certmonger -f
```

---

## 🎯 Referencia Rápida

**Problemas Más Comunes:**
1. Certificado expirado → Renovar
2. CA faltante → Agregar al almacén de confianza
3. Permisos incorrectos → chmod 600
4. Desajuste cert/clave → Regenerar CSR
5. Desajuste de hostname → Reemitir con SANs
6. Versión TLS → Verificar crypto-policy
7. SELinux denegando → restorecon
8. certmonger CA_UNREACHABLE → Verificar IPA/Kerberos

**Emergencia:** [Capítulo 33](part-05-troubleshooting/33-emergency-procedures.md)

**Metodología:** [Capítulo 27](part-05-troubleshooting/27-troubleshooting-methodology.md)
