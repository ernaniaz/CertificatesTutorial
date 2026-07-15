# Capítulo 30: Solución de Problemas de certmonger

> **Problemas de Automatización:** certmonger es la herramienta de automatización de certificados de RHEL. Cuando falla, los certificados no se renuevan. Este capítulo te enseña a diagnosticar y solucionar problemas de certmonger rápidamente.

---

## 30.1 Valores de Estado de certmonger

### Entender Mensajes de Estado

| Estado | Significado | Acción Requerida |
|--------|-------------|------------------|
| `MONITORING` | ✅ Todo bien - cert emitido, rastreando expiración | Ninguna |
| `SUBMITTING` | 🔄 Solicitando cert de CA | Esperar (usualmente segundos) |
| `CA_UNREACHABLE` | ❌ No se puede contactar servidor CA | Corregir conectividad |
| `CA_REJECTED` | ❌ CA rechazó solicitud | Corregir principal/permisos |
| `NEED_KEY_GEN_PIN` | ⏸️ Esperando PIN (HSM) | Proporcionar PIN |
| `NEED_GUIDANCE` | ⚠️ Necesita intervención manual | Verificar detalles de solicitud |
| `PRE_SAVE_COMMAND` | 🔄 Ejecutando script pre-guardado | Esperar |
| `POST_SAVE_COMMAND` | 🔄 Ejecutando script post-guardado | Esperar |
| `NEWLY_ADDED` | 🆕 Recién agregado, aún no procesado | Esperar |

---

## 30.2 Solución de Problemas de CA_UNREACHABLE

### ¡Problema Más Común de certmonger!

**Síntoma:**
```bash
sudo getcert list
# status: CA_UNREACHABLE
```

### Pasos de Diagnóstico

```bash
#============================================#
# DIAGNOSTICAR CA_UNREACHABLE
#============================================#

# Paso 1: ¿Qué CA estamos intentando alcanzar?
sudo getcert list -v | grep "CA:"
# CA: IPA

# Paso 2: ¿Podemos alcanzar IPA?
ipa ping
# Pong!  ← Bueno
# ipa: ERROR: cannot connect to 'https://ipa.example.com/ipa/xml'  ← ¡Malo!

# Paso 3: Verificar ticket Kerberos
klist
# Ticket cache: FILE:/tmp/krb5cc_0
# Valid starting     Expires            Service principal
# ...

# Paso 4: Verificar si ticket expiró
klist | grep "host/"
# Si no hay ticket de host o expiró → ¡Problema!

# Paso 5: Verificar estado del servidor IPA
ssh ipa.example.com "sudo ipactl status"

# Paso 6: Verificar red
ping ipa.example.com
curl -k https://ipa.example.com/ipa/config/ca.crt

# Paso 7: Verificar DNS
nslookup ipa.example.com
```

### Soluciones para CA_UNREACHABLE

**Solución 1: Renovar Ticket Kerberos**
```bash
# Obtener nuevo ticket de host
sudo kinit -k host/$(hostname -f)@REALM

# Verificar
klist

# Reintentar solicitud de cert
sudo ipa-getcert resubmit -f /etc/pki/tls/certs/web.crt
```

**Solución 2: Verificar Servidor IPA**
```bash
# En servidor IPA
sudo ipactl status

# Si servicios caídos
sudo ipactl restart

# Verificar servicio específico
sudo systemctl status pki-tomcatd@pki-tomcat  # Servicio CA
```

**Solución 3: Red/Firewall**
```bash
# Probar conectividad IPA
curl -vk https://ipa.example.com/ipa/xml

# Verificar firewall en servidor IPA
ssh ipa.example.com "sudo firewall-cmd --list-services | grep https"

# Verificar rutas
traceroute ipa.example.com
```

**Solución 4: Reiniciar certmonger**
```bash
sudo systemctl restart certmonger

# Esperar un momento
sleep 10

# Verificar estado
sudo getcert list
```

---

## 30.3 Solución de Problemas de CA_REJECTED

### Cuando CA Rechaza la Solicitud

**Síntoma:**
```bash
sudo getcert list -v
# status: CA_REJECTED
# ca-error: Server at https://ipa.example.com/ipa/xml unwilling to issue certificate
```

### Pasos de Diagnóstico

```bash
#============================================#
# DIAGNOSTICAR CA_REJECTED
#============================================#

# Paso 1: Verificar detalles de error
sudo getcert list -v -f /etc/pki/tls/certs/web.crt
# Mirar campo 'ca-error'

# Paso 2: ¿Existe el principal de servicio?
ipa service-show HTTP/$(hostname -f)
# Si error: Service not found

# Paso 3: ¿Está el host inscrito?
ipa host-show $(hostname -f)

# Paso 4: Verificar que el perfil de certificado existe
sudo getcert list -v | grep "profile:"
ipa certprofile-show caIPAserviceCert

# Paso 5: Verificar detalles de solicitud
sudo getcert list -v | grep -A30 "Request ID"
```

### Soluciones para CA_REJECTED

**Solución 1: Crear Principal de Servicio**
```bash
# Agregar principal de servicio faltante
ipa service-add HTTP/$(hostname -f)

# Agregar SAN (si es necesario)
ipa service-mod HTTP/$(hostname -f) --addattr=cn=web.example.com

# Reintentar
sudo ipa-getcert resubmit -f /etc/pki/tls/certs/web.crt
```

**Solución 2: Corregir Entrada de Host**
```bash
# Re-inscribir a IPA si es necesario
sudo ipa-client-install --force-join

# Verificar
ipa host-show $(hostname -f)
```

**Solución 3: Verificar Permisos**
```bash
# Verificar si tienes permiso para solicitar certs
ipa permission-find --name="Request Certificate"

# Verificar ACLs
ipa aci-find --name="*cert*"

# Puede necesitar que admin de IPA otorgue permisos
```

---

## 30.4 Fallos de Renovación

### El Certificado No Se Renueva

**Síntoma:** Certificado acercándose a expiración pero no se renueva

**Diagnóstico:**
```bash
#============================================#
# DIAGNOSTICAR FALLO DE RENOVACIÓN
#============================================#

# Paso 1: Verificar estado actual
sudo getcert list -f /etc/pki/tls/certs/web.crt

# Paso 2: ¿Cuándo debería renovarse?
# certmonger renueva a 2/3 del tiempo de vida del cert
# Cert de 365 días → renueva en día 243 (122 días antes de expirar)

# Paso 3: Verificar logs de certmonger
sudo journalctl -u certmonger --since "7 days ago" | grep -i renew

# Paso 4: Forzar intento de renovación
sudo ipa-getcert resubmit -f /etc/pki/tls/certs/web.crt

# Paso 5: Observar logs en tiempo real
sudo journalctl -u certmonger -f
```

### Problemas Comunes de Renovación

**Problema 1: Comando post-guardado falla**
```bash
# Verificar comando post-guardado
sudo getcert list -f /etc/pki/tls/certs/web.crt | grep "post-save"
# post-save command: systemctl reload httpd

# Probar comando manualmente
sudo systemctl reload httpd
# Si falla → corregir el comando

# Actualizar comando (recrear entrada de rastreo; no usar getcert rekey)
sudo getcert stop-tracking -f /etc/pki/tls/certs/web.crt
sudo getcert start-tracking \
  -f /etc/pki/tls/certs/web.crt \
  -k /etc/pki/tls/private/web.key \
  -C "systemctl reload httpd"
```

**Problema 2: Servidor IPA caído durante ventana de renovación**
```bash
# certmonger reintentará
# Verificar calendario de reintentos en logs
sudo journalctl -u certmonger | grep "will try again"

# Reintento manual
sudo ipa-getcert resubmit -f /etc/pki/tls/certs/web.crt
```

---

## 30.5 Problemas de Rastreo

### El Certificado No Está Siendo Rastreado

**Síntoma:** El certificado expira porque certmonger no lo estaba rastreando

**Solución:**
```bash
#============================================#
# COMENZAR A RASTREAR CERTIFICADO EXISTENTE
#============================================#

sudo getcert start-tracking \
  -f /etc/pki/tls/certs/existing.crt \
  -k /etc/pki/tls/private/existing.key \
  -c IPA \
  -K HTTP/$(hostname -f)@REALM
```

### Rastreo Duplicado

**Síntoma:** Mismo certificado rastreado múltiples veces

**Diagnóstico:**
```bash
# Listar todos los certs rastreados
sudo getcert list | grep -E "(Request ID|certificate:)" | \
  awk -F"'" '/certificate:/{cert=$2} /Request ID/{print cert, $2}'

# Buscar duplicados
```

**Solución:**
```bash
# Eliminar rastreo duplicado
sudo getcert stop-tracking -i <duplicate-request-id>

# Mantener solo una entrada de rastreo por certificado
```

---

## 30.6 Problemas de Configuración

### CA Incorrecta Configurada

**Síntoma:** certmonger intentando alcanzar CA incorrecta

**Diagnóstico:**
```bash
# Verificar CA configurada
sudo getcert list -v | grep "CA:"

# Listar CAs disponibles
sudo getcert list-cas
```

**Solución:**
```bash
# Dejar de rastrear con CA incorrecta
sudo getcert stop-tracking -f /etc/pki/tls/certs/web.crt

# Re-solicitar con CA correcta
sudo ipa-getcert request \
  -c IPA \  # Especificar CA correcta
  -f /etc/pki/tls/certs/web.crt \
  -k /etc/pki/tls/private/web.key \
  -K HTTP/$(hostname -f)@REALM
```

---

## 30.7 Corrupción de Base de Datos de certmonger

### Problema Raro pero Serio

**Síntoma:** certmonger completamente roto, todos los certs muestran errores

**Diagnóstico:**
```bash
# Verificar base de datos
ls -l /var/lib/certmonger/

# Verificar corrupción
sudo journalctl -u certmonger | grep -i corrupt
```

**Solución (Opción Nuclear):**
```bash
# PRECAUCIÓN: ¡Esto elimina todo el rastreo!

# Paso 1: Respaldar estado actual
sudo tar czf certmonger-backup-$(date +%Y%m%d).tar.gz \
  /var/lib/certmonger/ \
  /etc/pki/tls/

# Paso 2: Documentar rastreo actual
sudo getcert list > /tmp/certmonger-list-backup.txt

# Paso 3: Detener certmonger
sudo systemctl stop certmonger

# Paso 4: Eliminar base de datos
sudo rm -rf /var/lib/certmonger/cas/*
sudo rm -rf /var/lib/certmonger/requests/*

# Paso 5: Iniciar certmonger
sudo systemctl start certmonger

# Paso 6: Re-agregar certificados (desde documentación de respaldo)
# Volver a solicitar manualmente cada certificado
```

---

## 30.8 Depurar certmonger

### Habilitar Logging de Depuración

```bash
#============================================#
# MODO DEBUG DE CERTMONGER
#============================================#

# Editar archivo de servicio
sudo systemctl edit certmonger

# Agregar:
[Service]
Environment="G_MESSAGES_DEBUG=all"

# Recargar y reiniciar
sudo systemctl daemon-reload
sudo systemctl restart certmonger

# Observar logs detallados
sudo journalctl -u certmonger -f

# Deshabilitar debug después de la solución de problemas
sudo systemctl revert certmonger
sudo systemctl restart certmonger
```

### Prueba Manual de Solicitud de Cert

```bash
#============================================#
# PROBAR SOLICITUD DE CERTIFICADO MANUALMENTE
#============================================#

# Enviar solicitud y observar
sudo ipa-getcert request \
  -f /tmp/test.crt \
  -k /tmp/test.key \
  -K HTTP/$(hostname -f)@REALM \
  -v  # Verboso

# Observar en otra terminal
sudo journalctl -u certmonger -f

# Si exitoso, eliminar prueba
sudo getcert stop-tracking -f /tmp/test.crt -r
rm -f /tmp/test.{crt,key}
```

---

## 30.9 Escenarios Comunes

### Escenario 1: Todos los Certificados Muestran CA_UNREACHABLE

**Causa Probable:** Servidor IPA caído o problema de red

**Solución Rápida:**
```bash
# Verificar IPA
ipa ping

# Si está caído, corregir IPA primero
ssh ipa-server "sudo ipactl start"

# Si problema de red, corregir red

# Reiniciar certmonger
sudo systemctl restart certmonger
```

### Escenario 2: Un Certificado Atascado

**Diagnóstico:**
```bash
# Verificar certificado específico
sudo getcert list -f /etc/pki/tls/certs/problem.crt

# Intentar reenviar
sudo ipa-getcert resubmit -f /etc/pki/tls/certs/problem.crt

# Si aún atascado, recrear solicitud
sudo getcert stop-tracking -f /etc/pki/tls/certs/problem.crt
sudo ipa-getcert request \
  -f /etc/pki/tls/certs/problem.crt \
  -k /etc/pki/tls/private/problem.key \
  -K HTTP/$(hostname -f)@REALM \
  -D $(hostname -f)
```

### Escenario 3: Certificado Renovado pero Servicio No Recargado

**Síntoma:** Nuevo cert existe pero servicio aún usa el antiguo

**Causa:** Comando post-guardado falló o no está configurado

**Solución:**
```bash
# Verificar comando post-guardado
sudo getcert list -f /etc/pki/tls/certs/web.crt | grep "post-save"

# Si falta, agregarlo (recrear entrada de rastreo; no usar getcert rekey)
sudo getcert stop-tracking -f /etc/pki/tls/certs/web.crt
sudo getcert start-tracking \
  -f /etc/pki/tls/certs/web.crt \
  -k /etc/pki/tls/private/web.key \
  -C "systemctl reload httpd"

# Probar que comando post-guardado funciona
sudo systemctl reload httpd

# Forzar renovación para probar
sudo ipa-getcert resubmit -f /etc/pki/tls/certs/web.crt
```

---

## 30.10 Conclusiones Clave

1. **CA_UNREACHABLE** es el problema más común - Verificar conectividad IPA
2. **CA_REJECTED** significa problema de principal - Crear principal de servicio
3. **Estado MONITORING** significa que todo está bien
4. **Comandos post-guardado críticos** - Probarlos independientemente
5. **Logs de certmonger** en journal - Usar `journalctl -u certmonger`
6. **Reintentar con resubmit** - A menudo corrige problemas transitorios
7. **Verificar tickets Kerberos** - Tickets expirados causan problemas

---

## Tarjeta de Referencia Rápida

```
┌────────────────────────────────────────────────────────────────┐
│ REFERENCIA RÁPIDA SOLUCIÓN DE PROBLEMAS CERTMONGER             │
├────────────────────────────────────────────────────────────────┤
│ Estado:           getcert list                                 │
│ Verboso:          getcert list -v                              │
│ Específico:       getcert list -f /path/to/cert.crt            │
│ Logs:             journalctl -u certmonger -f                  │
│                                                                │
│ Reenviar:         ipa-getcert resubmit -f /path/to/cert.crt    │
│ Dejar rastrear:   getcert stop-tracking -f /path/to/cert.crt   │
│ Iniciar rastreo:  getcert start-tracking -f cert -k key        │
│                                                                │
│ CA_UNREACHABLE:   Verificar: ipa ping, klist                   │
│                   Solución: kinit -k host/$(hostname -f)@REALM │
│                                                                │
│ CA_REJECTED:      Verificar: ipa service-show SERVICE/host     │
│                   Solución: ipa service-add SERVICE/host       │
│                                                                │
│ Debug:            systemctl edit certmonger                    │
│                   Environment="G_MESSAGES_DEBUG=all"           │
└────────────────────────────────────────────────────────────────┘

✅ MONITORING = ¡Todo bien!
❌ CA_UNREACHABLE = Verificar conectividad IPA
❌ CA_REJECTED = Verificar principal de servicio
```
---

**Navegación del Capítulo**

| [← Anterior: Capítulo 29 - Solución de Problemas Específica por Servicio](29-service-troubleshooting.md) | [Siguiente: Capítulo 31 - Solución de Problemas de Crypto-Policy →](31-crypto-policy-issues.md) |
|:---|---:|
