# Capítulo 31: Solución de Problemas de Crypto-Policy

> **Solo RHEL 8/9/10:** Las crypto-policies son poderosas pero pueden causar problemas de compatibilidad. Aprende cómo diagnosticar y solucionar problemas de crypto-policy.

---

## 31.1 Resumen de Crypto-Policy

**Disponible:** Solo RHEL 8, 9, 10 (NO RHEL 7)

**Verificación Rápida:**
```bash
# Verificar si crypto-policies está disponible
which update-crypto-policies

# Si se encuentra: RHEL 8/9/10
# Si no se encuentra: RHEL 7 (sin crypto-policies)

# Política actual
update-crypto-policies --show
```

---

## 31.2 Problemas Comunes de Crypto-Policy

### Problema 1: La Aplicación Falla Después de Cambio de Política

**Síntoma:** El servicio funcionaba, luego cambiaste crypto-policy, ahora falla

**Escenario:**
```bash
# Antes
update-crypto-policies --show
# DEFAULT

# Lo cambiaste
sudo update-crypto-policies --set FUTURE
sudo systemctl restart httpd

# Ahora httpd no inicia o los clientes no pueden conectar
```

**Diagnóstico:**
```bash
#============================================#
# DIAGNOSTICAR IMPACTO DE CAMBIO DE POLÍTICA
#============================================#

# Paso 1: Verificar qué cambió
cat /etc/crypto-policies/back-ends/opensslcnf.config

# Paso 2: Verificar logs
sudo journalctl -xe -u httpd | grep -i cipher

# Paso 3: Probar conexión
openssl s_client -connect localhost:443

# Paso 4: Verificar si app sobrescribe política
grep -r "SSLProtocol\|SSLCipherSuite" /etc/httpd/
```

**Solución:**
```bash
# Solución 1: Revertir política
sudo update-crypto-policies --set DEFAULT
sudo systemctl restart httpd

# Solución 2: Corregir configuración de aplicación
# Eliminar especificaciones de cifrado codificadas
# Dejar que crypto-policy lo maneje

# Solución 3: Crear módulo de política personalizado (RHEL 9+)
# Ver Capítulo 23 para detalles
```

---

### Problema 2: "no shared cipher"

**Síntoma:** Los clientes no pueden conectar después de cambio de política

**Error Completo:**
```
SSL routines:SSL23_GET_SERVER_HELLO:sslv3 alert handshake failure
no shared cipher
```

**Diagnóstico:**
```bash
#============================================#
# DIAGNOSTICAR DESAJUSTE DE CIFRADO
#============================================#

# Paso 1: Verificar política actual
update-crypto-policies --show
# FUTURE  ← ¡Muy estricta!

# Paso 2: ¿Qué cifrados están disponibles?
openssl ciphers -v | head -20

# Paso 3: Probar capacidades del cliente
openssl s_client -connect server:443 -cipher 'ALL'

# Paso 4: ¿El cliente es muy antiguo?
# Cliente antiguo podría solo soportar cifrados débiles bloqueados por política FUTURE
```

**Soluciones:**
```bash
# Solución 1: Usar política menos estricta (¡temporal!)
sudo update-crypto-policies --set DEFAULT
sudo systemctl restart services

# Solución 2: Actualizar cliente para soportar cifrados modernos

# Solución 3: Crear módulo de política personalizado
# Permitir cifrado específico para compatibilidad
```

---

### Problema 3: Cliente TLS 1.0/1.1 No Puede Conectar

**Síntoma:** Clientes antiguos fallan al conectar a servidor RHEL 8+

**Error:**
```
SSL routines:ssl3_read_bytes:tlsv1 alert protocol version
wrong version number
```

**Diagnóstico:**
```bash
# Verificar política
update-crypto-policies --show
# DEFAULT  ← Bloquea TLS 1.0/1.1

# Probar si TLS 1.0 funciona
openssl s_client -connect server:443 -tls1
# Debería fallar con política DEFAULT

# Probar si TLS 1.2 funciona
openssl s_client -connect server:443 -tls1_2
# Debería funcionar
```

**Soluciones:**
```bash
# Solución 1: Política LEGACY temporal (¡NO recomendado!)
sudo update-crypto-policies --set LEGACY
sudo systemctl restart services
# Ahora TLS 1.0/1.1 permitido

# Solución 2: Actualizar cliente para soportar TLS 1.2+
# Esta es la solución APROPIADA

# Solución 3: Sobrescritura por aplicación (último recurso)
# Ejemplo Apache:
# SSLProtocol all -SSLv3  # Re-habilita TLS 1.0/1.1
```

---

### Problema 4: Servicio Sobrescribiendo Crypto-Policy

**Síntoma:** Los cambios de política no afectan al servicio

**Diagnóstico:**
```bash
#============================================#
# VERIFICAR SOBRESCRITURAS DE POLÍTICA
#============================================#

# Apache
grep -r "SSLProtocol\|SSLCipherSuite" /etc/httpd/

# NGINX
grep -r "ssl_protocols\|ssl_ciphers" /etc/nginx/

# Postfix
sudo postconf | grep -E "smtp.*_tls_protocols|smtp.*_tls_ciphers"

# ¡Si se encuentra → El servicio está sobrescribiendo la política!
```

**Solución:**
```bash
# Eliminar sobrescrituras de archivos de configuración
# Dejar que crypto-policy maneje ajustes TLS

# Apache: Eliminar o comentar
# #SSLProtocol all -SSLv3
# #SSLCipherSuite ...

# NGINX: Eliminar
# #ssl_protocols ...
# #ssl_ciphers ...

# Reiniciar servicio
sudo systemctl restart httpd
```

---

## 31.3 Crypto-Policy No Aplicada

### Política Establecida Pero Sin Efecto

**Síntomas:**
- Política cambiada pero servicios aún usan ajustes antiguos
- Cifrados débiles aún aceptados

**Diagnóstico:**
```bash
#============================================#
# VERIFICAR QUE LA POLÍTICA ESTÁ ACTIVA
#============================================#

# Paso 1: Confirmar política establecida
update-crypto-policies --show

# Paso 2: Verificar cuándo se actualizó última vez la política
ls -l /etc/crypto-policies/back-ends/

# Paso 3: Verificar si servicios se reiniciaron
systemctl status httpd nginx postfix | grep "Active:"
# ¡Los servicios DEBEN reiniciarse después de cambio de política!

# Paso 4: Probar cifrados reales en uso
openssl s_client -connect localhost:443 | grep "Cipher"
```

**Solución:**
```bash
# Reiniciar TODOS los servicios
sudo systemctl restart httpd nginx postfix slapd

# O reiniciar (asegura que todo recoja los cambios)
sudo reboot

# Verificar después de reiniciar
openssl s_client -connect localhost:443
```

---

## 31.4 Problemas de Política FIPS

### Fallos de Política FIPS

**Síntoma:** Los servicios fallan en modo FIPS

**Diagnóstico:**
```bash
#============================================#
# DIAGNOSTICAR PROBLEMAS FIPS
#============================================#

# Paso 1: Verificar modo FIPS habilitado
fips-mode-setup --check

# Paso 2: Verificar crypto-policy
update-crypto-policies --show
# Debería mostrar: FIPS

# Paso 3: Verificar algoritmos no-FIPS
# Culpables comunes: MD5, SHA-1, cifrados débiles

# Paso 4: Probar con proveedor FIPS
openssl list -providers | grep fips
```

**Problemas FIPS Comunes:**
```bash
# Problema: La aplicación usa MD5 (no aprobado por FIPS)
# Error: "digital envelope routines:EVP_DigestInit_ex:disabled for fips"

# Solución: Actualizar aplicación para usar SHA-256

# Problema: El certificado tiene firma SHA-1
# Error: "ca md too weak"

# Solución: Reemitir certificado con SHA-256 o mejor
```

---

## 31.5 Pruebas de Compatibilidad de Política

### Antes de Cambiar Política

```bash
#!/bin/bash
# test-crypto-policy-change.sh
# Probar cambio de crypto-policy antes de producción

NEW_POLICY=$1  # DEFAULT, LEGACY, FUTURE, o FIPS

if [ -z "$NEW_POLICY" ]; then
  echo "Uso: $0 <policy>"
  exit 1
fi

echo "=== Probando Cambio de Crypto-Policy a $NEW_POLICY ==="

# Guardar política actual
CURRENT=$(update-crypto-policies --show)
echo "Política actual: $CURRENT"

# Cambiar política
echo "Cambiando a $NEW_POLICY..."
sudo update-crypto-policies --set "$NEW_POLICY"

# Reiniciar servicios
echo "Reiniciando servicios..."
sudo systemctl restart httpd nginx postfix 2>/dev/null

# Esperar a que servicios inicien
sleep 3

# Probar cada servicio
echo ""
echo "Probando servicios:"

# Apache
if systemctl is-active --quiet httpd; then
  curl -ks https://localhost/ >/dev/null && \
    echo "✅ Apache: OK" || echo "❌ Apache: FALLÓ"
else
  echo "❌ Apache: No ejecutándose"
fi

# NGINX
if systemctl is-active --quiet nginx; then
  curl -ks https://localhost:8443/ >/dev/null && \
    echo "✅ NGINX: OK" || echo "❌ NGINX: FALLÓ"
else
  echo "⚠️ NGINX: No instalado"
fi

# Postfix
if systemctl is-active --quiet postfix; then
  timeout 3 openssl s_client -starttls smtp -connect localhost:25 </dev/null &>/dev/null && \
    echo "✅ Postfix: OK" || echo "❌ Postfix: FALLÓ"
else
  echo "⚠️ Postfix: No instalado"
fi

# Preguntar si mantener o revertir
echo ""
read -p "¿Mantener política $NEW_POLICY? (y/n): " KEEP

if [ "$KEEP" != "y" ]; then
  echo "Revirtiendo a $CURRENT..."
  sudo update-crypto-policies --set "$CURRENT"
  sudo systemctl restart httpd nginx postfix 2>/dev/null
  echo "✅ Revertido"
else
  echo "✅ Manteniendo política $NEW_POLICY"
fi
```

---

## 31.6 Flujo de Trabajo de Solución de Problemas

### Enfoque Sistemático

```
¿Problema de Crypto-Policy?
    │
    ├─ Paso 1: Identificar política actual
    │   └─ update-crypto-policies --show
    │
    ├─ Paso 2: Verificar si política cambió recientemente
    │   └─ Verificar /var/log/messages para "crypto-policies"
    │
    ├─ Paso 3: Probar con política diferente
    │   └─ sudo update-crypto-policies --set LEGACY
    │   └─ Si funciona → política era muy estricta
    │
    ├─ Paso 4: Identificar incompatibilidad
    │   └─ openssl s_client -cipher 'ALL' -tls1
    │   └─ Encontrar qué necesita cliente/servidor
    │
    ├─ Paso 5: Elegir solución
    │   ├─ A) Actualizar cliente (mejor)
    │   ├─ B) Crear módulo personalizado (bueno)
    │   ├─ C) Usar política menos estricta (aceptable)
    │   └─ D) Sobrescritura por app (último recurso)
    │
    └─ Paso 6: Probar y documentar
        └─ Verificar que la solución funciona
        └─ Documentar por qué se necesitó el cambio
```

---

## 31.7 Depurar Aplicación de Crypto-Policy

### Verificar que la Política Está Aplicada

```bash
#============================================#
# VERIFICAR APLICACIÓN DE CRYPTO-POLICY
#============================================#

# Paso 1: Verificar política
update-crypto-policies --show

# Paso 2: Verificar que archivos back-end se actualizaron
ls -l /etc/crypto-policies/back-ends/
# Los archivos deberían estar modificados recientemente

# Paso 3: Ver configuración de OpenSSL
cat /etc/crypto-policies/back-ends/opensslcnf.config

# Paso 4: Probar disponibilidad real de cifrado
openssl ciphers -v | grep -E "TLS|SSL"

# Paso 5: Probar conexión
openssl s_client -connect localhost:443
# Buscar: Protocol version, Cipher

# Paso 6: Verificar si servicio se reinició desde cambio de política
systemctl status httpd | grep "Active:"
# Debería mostrar tiempo de activación reciente
```

---

## 31.8 Escenarios Comunes

### Escenario 1: Aplicación Legacy Después de Actualización a RHEL 8

**Problema:** La app funcionaba en RHEL 7, falla en RHEL 8

**Causa Raíz:** RHEL 7 no tenía crypto-policies, RHEL 8 DEFAULT bloquea TLS 1.0/1.1

**Solución:**
```bash
# Solución rápida (¡temporal!):
sudo update-crypto-policies --set LEGACY

# Solución apropiada:
# Actualizar aplicación para soportar TLS 1.2+

# Documentar excepción
echo "Aplicación X requiere política LEGACY debido a requisito TLS 1.0" > \
  /etc/crypto-policies/POLICY-EXCEPTION.txt
```

### Escenario 2: No Se Puede Conectar a Windows Server 2008

**Problema:** RHEL 9 no puede conectar a servidor Windows antiguo

**Causa:** Windows Server 2008 solo soporta TLS 1.0

**Soluciones:**
```bash
# Opción 1: Actualizar Windows (mejor)

# Opción 2: Política LEGACY (temporal)
sudo update-crypto-policies --set LEGACY

# Opción 3: Módulo de política personalizado para este caso específico
# Ver Capítulo 23
```

---

## 31.9 Conclusiones Clave

1. **Crypto-policies son solo RHEL 8+** (no RHEL 7)
2. **Los servicios DEBEN reiniciarse** después de cambio de política
3. **Los cambios de política son en todo el sistema** - Afectan todo
4. **DEFAULT es recomendada** para la mayoría de entornos
5. **LEGACY debería ser solo temporal**
6. **Probar antes de desplegar** nuevas políticas
7. **Actualizar clientes** en lugar de debilitar política

---

## Tarjeta de Referencia Rápida

```
┌───────────────────────────────────────────────────────────────┐
│ SOLUCIÓN DE PROBLEMAS CRYPTO-POLICY                           │
├───────────────────────────────────────────────────────────────┤
│ Verificar:       update-crypto-policies --show                │
│ Establecer:      sudo update-crypto-policies --set <POLICY>   │
│ Revertir:        sudo update-crypto-policies --set DEFAULT    │
│                                                               │
│ Back-ends:       /etc/crypto-policies/back-ends/              │
│ OpenSSL:         cat .../back-ends/opensslcnf.config          │
│                                                               │
│ Probar:          openssl ciphers -v                           │
│                  openssl s_client -connect :443               │
│                                                               │
│ Después cambio:  sudo systemctl restart <todos-servicios>     │
│                  O: sudo reboot                               │
│                                                               │
│ Debug:           grep -r "SSLProtocol\|ssl_protocols" /etc/   │
│                  (buscar sobrescrituras)                      │
└───────────────────────────────────────────────────────────────┘

⚠️ RHEL 7 no tiene crypto-policies
✅ Siempre reiniciar servicios después de cambio de política
✅ DEFAULT funciona para 95% de los casos
```
---

**Navegación del Capítulo**

| [← Anterior: Capítulo 30 - Solución de Problemas de certmonger](30-certmonger-issues.md) | [Siguiente: Capítulo 32 - Análisis de Informes SOS →](32-sos-report-analysis.md) |
|:---|---:|
