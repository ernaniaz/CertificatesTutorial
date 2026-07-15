# Capítulo 37: Solución de Problemas y Recuperación de Migración

> **Cuando las Cosas Salen Mal:** Las migraciones no siempre van suavemente. Este capítulo cubre problemas comunes de migración y procedimientos de recuperación.

---

## 37.1 Problemas Comunes de Migración

### Top 10 Problemas de Migración de Certificados

| Problema | Síntomas | Causa | Solución Rápida |
|----------|----------|-------|-----------------|
| 1. Servicios no inician | systemctl status falla | Sintaxis config cambió | Restaurar config, actualizar sintaxis |
| 2. Rechazo SHA-1 (RHEL 9) | "ca md too weak" | Firma SHA-1 | Reemitir certificado |
| 3. Desajuste versión TLS | Clientes no pueden conectar | TLS 1.0/1.1 bloqueado | Política LEGACY (temp) |
| 4. Problemas crypto-policy | Varios errores | Nuevo sistema de política | Entender y configurar |
| 5. certmonger perdió rastreo | getcert list vacío | Corrupción DB | Restaurar desde respaldo |
| 6. CAs faltantes | Cert verify failed | Almacén confianza reiniciado | Re-agregar CAs |
| 7. Cambios de permisos | Permission denied | Ownership cambió | Corregir permisos |
| 8. Denegaciones SELinux | Servicio bloqueado | Contexto cambió | Reetiquetar archivos |
| 9. Errores proveedor (RHEL 9) | Algoritmo no soportado | Cambio OpenSSL 3.x | Usar -provider legacy |
| 10. Degradación rendimiento | Conexiones lentas | Crypto más estricta | Esperado, o ajustar |

---

## 37.2 Procedimientos de Rollback

### Cuándo Hacer Rollback

**Hacer rollback si:**
- Los servicios críticos no pueden iniciar
- Los problemas de certificados no pueden corregirse rápidamente
- El impacto al negocio es severo
- Dentro de ventana de rollback (usualmente 24-48 horas)

### Rollback de leapp

```bash
#============================================#
# ROLLBACK MIGRACIÓN RHEL
#============================================#

# leapp crea snapshot durante actualización
# Rollback ANTES de reiniciar a nueva versión

# Durante actualización (si se detectan problemas):
# No reiniciar - investigar y corregir

# Después de actualización pero problemas encontrados:
# Verificar si dentro de ventana de rollback

# leapp no tiene rollback automático
# Usar snapshot/respaldo para restaurar

# Con snapshot LVM (si se creó pre-migración):
# Arrancar desde snapshot
# O restaurar desde respaldo
```

### Rollback Específico de Certificados

```bash
#============================================#
# RESTAURAR CERTIFICADOS DESPUÉS DE MIGRACIÓN FALLIDA
#============================================#

# Escenario: Migrado, pero problemas de certificados
# Necesita restaurar estado de certificados

# Paso 1: Detener servicios
sudo systemctl stop httpd nginx postfix slapd

# Paso 2: Restaurar certificados
sudo tar xzf /var/backups/pre-migration-*/certificates.tar.gz -C /

# Paso 3: Restaurar configuraciones de servicio
sudo tar xzf /var/backups/pre-migration-*/service-configs.tar.gz -C /

# Paso 4: Restaurar certmonger
sudo systemctl stop certmonger
sudo tar xzf /var/backups/pre-migration-*/certmonger.tar.gz -C /
sudo systemctl start certmonger

# Paso 5: Restaurar crypto-policy (si RHEL 8+)
POLICY=$(cat /var/backups/pre-migration-*/crypto-policy.txt)
sudo update-crypto-policies --set $POLICY

# Paso 6: Iniciar servicios
sudo systemctl start httpd nginx postfix slapd

# Paso 7: Verificar
curl -v https://localhost/
sudo getcert list
```

---

## 37.3 El Servicio No Inicia Después de Migración

### Diagnóstico

```bash
#============================================#
# SOLUCIÓN DE PROBLEMAS INICIO DE SERVICIO
#============================================#

# Verificar estado del servicio
systemctl status httpd

# Ver errores detallados
sudo journalctl -xe -u httpd

# Probar configuración
# Apache:
sudo apachectl configtest

# NGINX:
sudo nginx -t

# Postfix:
sudo postfix check

# Errores comunes relacionados con certificados:
# - Archivo no encontrado
# - Permission denied
# - Formato de certificado inválido
# - ca md too weak (SHA-1)
```

### Soluciones

**Problema: Sintaxis de Configuración Cambió**
```bash
# Algunas directivas cambiaron entre versiones
# Verificar notas de lanzamiento para cambios

# Restaurar temporalmente configuración antigua
sudo cp /var/backups/pre-migration-*/ssl.conf /etc/httpd/conf.d/

# Actualizar a nueva sintaxis
# Investigar sintaxis correcta para nueva versión
```

**Problema: Permisos Cambiaron Durante Migración**
```bash
# Corregir permisos
sudo chmod 600 /etc/pki/tls/private/*.key
sudo chmod 644 /etc/pki/tls/certs/*.crt

# Corregir ownership
sudo chown root:root /etc/pki/tls/private/*.key

# Corregir contextos SELinux
sudo restorecon -Rv /etc/pki/tls/
```

---

## 37.4 Fallos de Conexión de Cliente Post-Migración

### Incompatibilidad de Versión TLS

**Síntoma:** Los clientes no pueden conectar después de migración a RHEL 8/9

**Diagnóstico:**
```bash
# Probar desde servidor
openssl s_client -connect localhost:443 -tls1_2
# Funciona

openssl s_client -connect localhost:443 -tls1
# Falla (esperado en RHEL 8/9 DEFAULT)

# Verificar crypto-policy
update-crypto-policies --show
# DEFAULT  ← Bloquea TLS 1.0/1.1
```

**Solución Temporal:**
```bash
# Permitir TLS 1.0/1.1 temporalmente
sudo update-crypto-policies --set LEGACY
sudo systemctl restart httpd nginx postfix

# Probar clientes
# Documentar qué clientes necesitan TLS 1.0/1.1

# Planificar actualizar esos clientes, luego revertir a DEFAULT
```

**Solución Apropiada:**
```bash
# Actualizar clientes para soportar TLS 1.2+
# Luego usar política DEFAULT

sudo update-crypto-policies --set DEFAULT
```

---

## 37.5 Problemas de certmonger Post-Migración

### Rastreo de certmonger Perdido

**Síntoma:**
```bash
sudo getcert list
# (vacío o certificados faltantes)
```

**Solución:**
```bash
# Restaurar base de datos certmonger
sudo systemctl stop certmonger
sudo tar xzf /var/backups/pre-migration-*/certmonger.tar.gz -C /
sudo systemctl start certmonger

# Verificar
sudo getcert list

# Si aún hay problemas, re-agregar certificados manualmente
```

### certmonger CA_UNREACHABLE Después de Migración

**Común después de actualización RHEL**

**Solución:**
```bash
# Renovar ticket Kerberos
sudo kinit -k host/$(hostname -f)@REALM

# Reiniciar certmonger
sudo systemctl restart certmonger

# Reenviar solicitudes
for cert in $(sudo getcert list | grep "certificate:" | sed -n "s/.*location='\\([^']*\\)'.*/\\1/p"); do
  sudo ipa-getcert resubmit -f "$cert"
done
```

---

## 37.6 Procedimientos de Recuperación de Emergencia

### Emergencia: Todos los Servicios Caídos

**Situación:** Migración completa pero nada funciona

**Recuperación Rápida:**
```bash
#!/bin/bash
# emergency-post-migration-recovery.sh

echo "=== EMERGENCIA: Recuperación de Certificados Post-Migración ==="

# 1. Verificar versión RHEL (confirmar que migración ocurrió)
cat /etc/redhat-release

# 2. Emergencia: Deshabilitar SSL temporalmente
# Apache
sudo mv /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/ssl.conf.disabled
sudo systemctl start httpd
# Ahora Apache se ejecuta solo en HTTP (puerto 80)

# 3. Identificar problemas de certificados
sudo journalctl -xe | grep -i cert | tail -50

# 4. Para RHEL 9: Verificar rechazos SHA-1
grep "ca md too weak" /var/log/messages

# 5. Generar certificados autofirmados temporales
/usr/local/bin/emergency-self-signed-cert.sh $(hostname -f) 90

# 6. Re-habilitar SSL con cert temp
sudo mv /etc/httpd/conf.d/ssl.conf.disabled /etc/httpd/conf.d/ssl.conf
# Actualizar para usar cert temp
sudo systemctl restart httpd

# 7. Servicios restaurados (con advertencias)
# Planificar correcciones apropiadas de certificados

echo "✅ Recuperación de emergencia completa"
echo "⚠️ Usando certificados temporales - ¡corregir LO ANTES POSIBLE!"
```

---

## 37.7 Script de Validación Post-Migración

### Validación Comprehensiva

```bash
#!/bin/bash
# post-migration-cert-validation.sh

echo "=== Validación de Certificados Post-Migración ==="

ISSUES=0

# Verificar versión RHEL
echo "1. Versión RHEL:"
cat /etc/redhat-release

# Verificar OpenSSL
echo ""
echo "2. Versión OpenSSL:"
openssl version

# Verificar crypto-policy (RHEL 8+)
if command -v update-crypto-policies &>/dev/null; then
  echo ""
  echo "3. Crypto-Policy:"
  update-crypto-policies --show
fi

# Verificar certificados
echo ""
echo "4. Estado de Certificados:"
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

  # Verificar SHA-1 (RHEL 9)
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
echo "5. Estado de certmonger:"
if command -v getcert &>/dev/null; then
  sudo getcert list | grep "status:" | sort | uniq -c

  UNREACHABLE=$(sudo getcert list | grep -c "CA_UNREACHABLE")
  if [ $UNREACHABLE -gt 0 ]; then
    echo "  ⚠️ $UNREACHABLE certificados CA_UNREACHABLE"
    ((ISSUES++))
  fi
else
  echo "  certmonger no instalado"
fi

# Verificar servicios
echo ""
echo "6. Estado de Servicios:"
for svc in httpd nginx postfix slapd; do
  if systemctl is-active --quiet $svc 2>/dev/null; then
    echo "  ✅ $svc: ejecutándose"
  elif systemctl is-enabled --quiet $svc 2>/dev/null; then
    echo "  ❌ $svc: no ejecutándose (debería estar)"
    ((ISSUES++))
  fi
done

# Probar conexiones
echo ""
echo "7. Pruebas de Conexión:"
timeout 3 curl -ks https://localhost/ &>/dev/null && \
  echo "  ✅ HTTPS: OK" || echo "  ❌ HTTPS: FALLÓ"

# Resumen
echo ""
echo "==================================="
if [ $ISSUES -eq 0 ]; then
  echo "✅ ¡Validación de migración EXITOSA!"
  exit 0
else
  echo "⚠️ $ISSUES problemas encontrados - revisar arriba"
  exit 1
fi
```

---

## 37.8 Conclusiones Clave

1. **Tener plan de rollback listo** antes de migración
2. **La mayoría de problemas son corregibles** sin rollback
3. **Cambios de crypto-policy** causan la mayoría de problemas de compatibilidad
4. **Rechazo SHA-1** no es negociable en RHEL 9
5. **Probar, probar, probar** antes de migración de producción
6. **Documentar todo** durante la solución de problemas
7. **Procedimientos de emergencia** (Cap 33) aplican durante migración también

---

## Tarjeta de Referencia Rápida

```
┌──────────────────────────────────────────────────────────────┐
│ REFERENCIA RÁPIDA SOLUCIÓN DE PROBLEMAS DE MIGRACIÓN         │
├──────────────────────────────────────────────────────────────┤
│ Servicio falla:  Ver: journalctl -xe -u <service>            │
│                  Intentar: Restaurar config desde respaldo   │
│                                                              │
│ Cert rechazado:  Ver: Algoritmo de firma (¿SHA-1?)           │
│                  Solución: Reemitir con SHA-256+             │
│                                                              │
│ Cliente falla:   Ver: Soporte versión TLS                    │
│                  Temp: update-crypto-policies --set LEGACY   │
│                  Solución: Actualizar cliente                │
│                                                              │
│ certmonger:      Ver: getcert list                           │
│                  Solución: Restaurar /var/lib/certmonger/    │
│                                                              │
│ Emergencia:      Deshabilitar SSL temporalmente              │
│                  Generar autofirmado temp                    │
│                  Restaurar desde respaldo                    │
│                                                              │
│ Rollback:        Usar snapshot/respaldo                      │
│                  Restaurar certificados                      │
│                  Restaurar configuraciones                   │
└──────────────────────────────────────────────────────────────┘

✅ La mayoría de problemas son corregibles sin rollback completo
⚠️ Tener respaldos listos
⚠️ Probar en no-producción primero
```
---

**Navegación del Capítulo**

| [← Anterior: Capítulo 36 - Migración RHEL 8→9](36-rhel8-to-9.md) | [Siguiente: Capítulo 38 - Guía Completa del Modo FIPS →](../part-07-security/38-fips-mode-guide.md) |
|:---|---:|
