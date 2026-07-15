# Capítulo 12: Características Actuales de RHEL 10

> **Vanguardia:** RHEL 10 GA se lanzó el 20 de mayo de 2025; RHEL 10.2 es la versión menor actual. Aprende sobre las últimas características y prepárate para el futuro de la gestión de certificados en Red Hat Enterprise Linux.

---

## 12.1 Resumen de RHEL 10

**Lanzamiento GA:** 20 de mayo de 2025
**Versión Actual:** RHEL 10.2
**Soporte Hasta:** 31 de mayo de 2035
**Estado:** ✅ Lanzamiento de Producción

**Características Clave:**
- **Versión OpenSSL:** 3.5.5-2 (paquete: `openssl-3.5.5-2.el10_2.x86_64`)
- **Misma base que:** RHEL 9.8 (OpenSSL 3.5.5)
- **Enfoque:** Fortalecimiento continuo, preparación post-cuántica, nativo de nube
- **Filosofía:** Mejora incremental sobre RHEL 9

> **Importante:** Las características de RHEL 10 pueden evolucionar a través de versiones menores (10.1, 10.2, etc.). Siempre consulta la documentación oficial de Red Hat para tu lanzamiento específico de RHEL 10.x.

---

## 12.2 ¿Qué Hay de Nuevo vs. RHEL 9?

### Diferencias Clave

| Característica | RHEL 9 | RHEL 10 |
|----------------|--------|---------|
| OpenSSL | 3.5.5 | 3.5.5 (misma base) |
| Crypto-Policies | Subpolíticas | Subpolíticas mejoradas |
| Versiones TLS | 1.2, 1.3 | 1.3 preferido, 1.2 soportado |
| FIPS | Módulos 140-2 | Transición 140-3 |
| Valores Predeterminados de Seguridad | Estricto | **Más Estricto** |
| Soporte de Contenedores | Bueno | **Mejorado** |
| Post-Cuántico | Fundamento | **Preparación activa** |

**Paquete:** `openssl-3.5.5-2.el10_2.x86_64`

### No es un Cambio Revolucionario

A diferencia de RHEL 7→8 (crypto-policies) o RHEL 8→9 (OpenSSL 3.x), RHEL 10 es una **mejora incremental**.

**Piénsalo como:**
- RHEL 7 → 8: 🚀 Revolucionario (crypto-policies)
- RHEL 8 → 9: 🔄 Mayor (OpenSSL 3.x)
- RHEL 9 → 10: ⬆️  Incremental (refinamientos)

---

## 12.3 Gestión de Certificados en RHEL 10

### Mismo Fundamento que RHEL 9

```bash
#============================================#
# CONCEPTOS BÁSICOS DE CERTIFICADOS RHEL 10
#============================================#

# Misma versión de OpenSSL que RHEL 9.8
openssl version
# OpenSSL 3.5.5 27 Jan 2026

# Mismo sistema crypto-policies
update-crypto-policies --show

# Mismo certmonger
getcert list

# Misma estructura de directorios
ls -la /etc/pki/tls/
```

**Conclusión:** ¡Si conoces RHEL 9, conoces certificados de RHEL 10!

---

## 12.4 Características de Seguridad Mejoradas

### Valores Predeterminados Más Estrictos

```bash
#============================================#
# MEJORAS DE SEGURIDAD RHEL 10
#============================================#

# 1. La política DEFAULT es más estricta
# - Preferencias de cifrado más fuertes
# - Algoritmos débiles adicionales eliminados
# - Validación mejorada

# 2. Política LEGACY más restringida
# - Menos algoritmos legacy permitidos
# - Mínimos más fuertes incluso en LEGACY

# 3. Gestión de certificados de contenedor mejorada
# - Mejor integración con Podman
# - Montaje de certificados simplificado
# - Gestión de secretos mejorada
```

### Preparación para Criptografía Post-Cuántica

**Fundamento para el Futuro:**

```bash
# RHEL 10 se prepara para algoritmos post-cuánticos
# (Aún no predeterminado, pero infraestructura lista)

# Capacidad futura (a medida que los estándares se finalicen):
# - ML-KEM (Module-Lattice Key Encapsulation)
# - ML-DSA (Module-Lattice Digital Signatures)
# - Criptografía híbrida clásica/cuántica

# Estado actual: Monitoreando estándares NIST
# Esperado: Lanzamientos menores RHEL 10.x agregarán soporte PQC
```

> **Nota:** La criptografía post-cuántica aún está evolucionando. RHEL 10 proporciona el fundamento, la implementación real vendrá a medida que los estándares se finalicen.

---

## 12.5 Características Específicas de RHEL 10

### Característica 1: Módulos de Crypto-Policy Mejorados

```bash
#============================================#
# MEJORAS EN CRYPTO-POLICY DE RHEL 10
#============================================#

# Control más granular
sudo update-crypto-policies --set DEFAULT:NO-SHA1

# Mejor validación
update-crypto-policies --check

# Mensajes de error mejorados cuando las políticas entran en conflicto
```

### Característica 2: Soporte Mejorado de Certificados de Contenedor

```bash
#============================================#
# CONTENEDORES CON CERTIFICADOS (RHEL 10)
#============================================#

# Montaje de certificados más fácil en Podman
podman run -d \
  -v /etc/pki/tls/certs/web.crt:/certs/web.crt:ro \
  -v /etc/pki/tls/private/web.key:/certs/web.key:ro \
  -p 443:443 \
  nginx

# Gestión de secretos mejorada
podman secret create web-cert /etc/pki/tls/certs/web.crt
podman secret create web-key /etc/pki/tls/private/web.key

# Usar secretos en contenedor
podman run -d --secret web-cert --secret web-key nginx
```

### Característica 3: Modo FIPS Mejorado

```bash
#============================================#
# FIPS EN RHEL 10
#============================================#

# Modo FIPS con proveedor FIPS de OpenSSL 3.x
sudo fips-mode-setup --enable
sudo reboot

# Verificar estado FIPS
fips-mode-setup --check

# RHEL 10: Transición hacia FIPS 140-3
# Actual: Aún módulos validados FIPS 140-2
# Futuro: Cumplimiento FIPS 140-3 a medida que se complete la certificación
```

---

## 12.6 Migración desde RHEL 9

### ¿Deberías Actualizar?

**Consideraciones de Actualización:**

**Razones para Actualizar:**
- ✅ Quieres 10+ años de soporte (hasta 2035)
- ✅ Necesitas las últimas mejoras de seguridad
- ✅ Preparación para el futuro (preparación post-cuántica)
- ✅ Soporte mejorado de contenedores
- ✅ Últimas características y mejoras

**Razones para Esperar:**
- ⏸️ RHEL 9 soportado hasta 2032
- ⏸️ No hay características urgentes relacionadas con certificados
- ⏸️ Deja que otros prueben RHEL 10 en producción primero
- ⏸️ Quieres esperar por RHEL 10.3 o 10.4

**Impacto en Certificados: BAJO**
- Misma base OpenSSL (3.5.5)
- Mismas herramientas y comandos
- Cambios incompatibles mínimos
- Mayormente transparente

### Proceso de Migración

```bash
#============================================#
# MIGRACIÓN DE CERTIFICADOS RHEL 9 → RHEL 10
#============================================#

# 1. Pre-migración: Verificar certificados
for cert in /etc/pki/tls/certs/*.crt; do
  openssl x509 -in "$cert" -noout -text | grep "Signature Algorithm"
done
# Todos deberían mostrar SHA-256+ (sin SHA-1 ni MD5)

# 2. Respaldo
tar czf rhel9-certs-backup-$(date +%Y%m%d).tar.gz \
  /etc/pki/tls/ \
  /etc/pki/ca-trust/source/anchors/

# 3. Realizar actualización de RHEL
sudo leapp upgrade

# 4. Verificar crypto-policy
update-crypto-policies --show

# 5. Reiniciar servicios
sudo systemctl restart httpd nginx postfix

# 6. Probar certificados
curl -v https://localhost/
openssl s_client -connect localhost:443

# 7. Verificar certmonger
sudo getcert list
```

---

## 12.7 Mejores Prácticas para RHEL 10

### Configuración Recomendada

```bash
#============================================#
# CONFIGURACIÓN RECOMENDADA DE RHEL 10
#============================================#

# 1. Usar crypto-policy DEFAULT (ya óptima)
sudo update-crypto-policies --set DEFAULT

# 2. Preferir TLS 1.3
# (Ya preferido automáticamente por política DEFAULT)

# 3. Usar claves EC para nuevos certificados
openssl genpkey -algorithm EC -out ec.key \
  -pkeyopt ec_paramgen_curve:P-256

# 4. Automatizar con la herramienta correcta
# Certificado público de Let's Encrypt: usar certbot
sudo certbot certonly --apache -d web.example.com

# Certificado interno de FreeIPA / IdM: usar certmonger
# sudo ipa-getcert request \
#   -f /etc/pki/tls/certs/web.crt \
#   -k /etc/pki/tls/private/web.key \
#   -K HTTP/web.example.com@REALM \
#   -D web.example.com \
#   -C "systemctl reload httpd"

# 5. Monitorear certificados
# Usar monitoreo integrado o herramientas externas

# 6. Planificar para PQC futuro
# Mantente al día con lanzamientos menores RHEL 10.x
```

---

## 12.8 Mirando Hacia Adelante: Preparación Post-Cuántica

### ¿Qué es la Criptografía Post-Cuántica?

**Problema:** Las computadoras cuánticas futuras podrían romper el cifrado actual (RSA, ECC)
**Solución:** Nuevos algoritmos resistentes a cuántica

**Estándares NIST (Finalizados 2024):**
- **ML-KEM-768** (Encapsulación de Clave)
- **ML-DSA-65** (Firmas Digitales)
- **SLH-DSA** (Firmas sin estado)

**Rol de RHEL 10:**
- Proporciona fundamento para PQC
- La arquitectura OpenSSL 3.x soporta nuevos algoritmos
- Futuros lanzamientos RHEL 10.x agregarán soporte PQC

### Criptografía Híbrida (Futuro)

```bash
# Capacidad futura en RHEL 10.x:
# Usar criptografía clásica Y resistente a cuántica

# Ejemplo (conceptual - aún no en RHEL 10.2):
openssl genpkey -algorithm hybrid-rsa-mlkem768 -out hybrid.key

# Proporciona:
# - Seguridad contra ataques clásicos (RSA)
# - Seguridad contra ataques cuánticos (ML-KEM)
```

> **Nota:** El soporte PQC vendrá en versiones menores futuras de RHEL 10.x a medida que los estándares se finalicen y prueben.

---

## 12.9 Qué Permanece Igual

### Sin Cambios Incompatibles Mayores

```bash
#============================================#
# LOS COMANDOS FAMILIARES AÚN FUNCIONAN
#============================================#

# Generar clave (igual que RHEL 9)
openssl genpkey -algorithm RSA -out server.key \
  -pkeyopt rsa_keygen_bits:2048

# Generar CSR (igual que RHEL 9)
openssl req -new -key server.key -out server.csr \
  -subj "/CN=server.example.com" \
  -addext "subjectAltName=DNS:server.example.com"

# Ver certificado (igual)
openssl x509 -in cert.crt -noout -text

# Probar conexión (igual)
openssl s_client -connect server:443

# Gestión de confianza (igual)
sudo cp ca.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust

# certmonger (igual)
sudo getcert list

# crypto-policies (igual)
update-crypto-policies --show
```

**¡Si conoces RHEL 9, estás listo para RHEL 10!**

---

## 12.10 Cuándo Adoptar RHEL 10

### Recomendaciones de Cronograma de Adopción

**Adoptadores Tempranos (2025-2026):**
- Entornos de prueba
- Cargas de trabajo no críticas
- Quieren las últimas características
- Investigación de seguridad

**Mainstream (2026-2027):**
- Nuevos despliegues
- Infraestructura renovada
- Después del lanzamiento de RHEL 10.3/10.4
- Cuando las apps principales estén certificadas

**Conservador (2027-2028):**
- Sistemas de producción críticos
- Cargas de trabajo estables
- Después de pruebas extensivas de la comunidad
- Cuando la migración desde RHEL 9 sea necesaria

**Recomendación Actual (Finales de 2025):**
- ✅ **Proyectos nuevos:** Considerar RHEL 10
- ⏸️ **RHEL 9 existente:** No hay urgencia para actualizar
- ✅ **RHEL 8 o anterior:** Evaluar RHEL 9 o 10
- ❌ **RHEL 7:** Actualización requerida (soporte terminado)

---

## 12.11 Monitorear la Evolución de RHEL 10

### Mantenerse Actualizado

```bash
# Verificar versión menor de RHEL 10
cat /etc/redhat-release
# Red Hat Enterprise Linux release 10.2 (Coughlan)

# Verificar actualizaciones
sudo dnf check-update

# Monitorear anuncios de Red Hat
# - https://access.redhat.com/articles/3078
# - Notas de lanzamiento de RHEL 10
# - Avisos de seguridad de Red Hat

# Suscribirse a boletines de Red Hat
# Seguir notas de lanzamiento para 10.3, 10.4, etc.
```

### Características a Vigilar

**Esperado en lanzamientos menores RHEL 10.x:**
- Soporte de criptografía post-cuántica
- Mejoras adicionales en crypto-policy
- Mayor integración de contenedores
- Herramientas de automatización mejoradas
- Módulos FIPS 140-3 adicionales

---

## 12.12 Configuración Práctica de Certificados en RHEL 10

### Ejemplo Completo: Configuración HTTPS Moderna

```bash
#!/bin/bash
# Configuración HTTPS moderna completa en RHEL 10

echo "=== Configuración HTTPS Moderna RHEL 10 ==="

# 1. Instalar paquetes
sudo dnf install -y httpd mod_ssl epel-release certbot python3-certbot-apache

# 2. Habilitar servicios
sudo systemctl enable --now httpd

# 3. Solicitar certificado de Let's Encrypt con certbot
sudo certbot --apache -d $(hostname -f)

# 4. Verificar el certificado
sudo certbot certificates

# 5. Actualizar configuración de Apache
# certbot normalmente actualiza Apache automáticamente; ajusta manualmente solo si hace falta
sudo sed -i "s|SSLCertificateFile.*|SSLCertificateFile /etc/letsencrypt/live/$(hostname -f)/fullchain.pem|" \
  /etc/httpd/conf.d/ssl.conf
sudo sed -i "s|SSLCertificateKeyFile.*|SSLCertificateKeyFile /etc/letsencrypt/live/$(hostname -f)/privkey.pem|" \
  /etc/httpd/conf.d/ssl.conf

# 6. Crypto-policy ya óptima (DEFAULT)
update-crypto-policies --show

# 7. Abrir firewall
sudo firewall-cmd --add-service=https --permanent
sudo firewall-cmd --reload

# 8. Recargar Apache
sudo systemctl reload httpd

# 9. Probar
curl -v https://$(hostname -f)/

echo "✅ ¡Configuración HTTPS moderna de RHEL 10 completa!"
echo "   - TLS 1.3 soportado"
echo "   - Certificado Let's Encrypt"
echo "   - Renovación automática habilitada"
echo "   - Seguridad óptima (política DEFAULT)"
```

---

## 12.13 Estrategias de Preparación para el Futuro

### Preparándose para la Evolución de RHEL 10.x

```bash
#============================================#
# GESTIÓN DE CERTIFICADOS PREPARADA PARA EL FUTURO
#============================================#

# 1. Usar algoritmos modernos (listo para transición PQC)
# Preferir EC sobre RSA
openssl genpkey -algorithm EC -out ec.key -pkeyopt ec_paramgen_curve:P-256

# 2. Mantener certificados de corta vida (90 días o menos)
# Más fácil rotar cuando cambien los algoritmos

# 3. Automatizar todo
# Usar certbot para ACME público y certmonger para flujos IPA/internos

# 4. Monitorear anuncios de Red Hat
# Suscribirse a notificaciones de seguridad y lanzamiento

# 5. Probar PQC cuando esté disponible
# Ser probador temprano de nuevas características en RHEL 10.x

# 6. Documentar tu configuración
# Facilita transiciones futuras
```

---

## 12.14 Problemas Conocidos y Soluciones

### Problema 1: Igual que RHEL 9 (OpenSSL 3.x)

**La mayoría de problemas de RHEL 9 aplican a RHEL 10:**
- Los algoritmos legacy necesitan `-provider legacy`
- SHA-1 bloqueado
- Apps personalizadas pueden necesitar actualizaciones OpenSSL 3.x

**Referencia:** Ver Capítulo 11 para problemas OpenSSL 3.x

### Problema 2: Validación Aún Más Estricta

**RHEL 10 puede capturar problemas que RHEL 9 permitía:**

```bash
# Ejemplo: Certificado marginal que funcionaba en RHEL 9
# podría fallar en RHEL 10

# Solución: Siempre usar mejores prácticas
# - Firmas SHA-256+
# - Claves de 2048+ bits (4096 recomendado)
# - SANs apropiados
# - Cadenas de confianza válidas
```

---

## 12.15 Cuándo Elegir RHEL 10

### Matriz de Decisión

| Escenario | RHEL 9 | RHEL 10 | Recomendación |
|-----------|--------|---------|---------------|
| **Nuevo despliegue 2025+** | ✅ Bueno | ✅ Mejor | RHEL 10 |
| **RHEL 9 existente** | ✅ Mantener | ⏸️ Esperar | Quedarse en 9 por ahora |
| **Migrando desde RHEL 8** | ✅ Sí | ✅ Considerar | Cualquiera (9 es más seguro) |
| **Migrando desde RHEL 7** | ✅ Sí | ⚠️ Gran salto | Ir a 9 primero |
| **Horizonte 10+ años** | ⏸️ Soporte 2032 | ✅ Soporte 2035 | RHEL 10 |
| **Seguridad de vanguardia** | ✅ Bueno | ✅ Mejor | RHEL 10 |
| **Producción crítica** | ✅ Probado | ⏸️ Más nuevo | RHEL 9 (más seguro) |

---

## 12.16 Conclusiones Clave

1. **RHEL 10 = RHEL 9 + mejoras incrementales**
2. **Misma base OpenSSL 3.5.5** - Sin cambios API mayores
3. **Valores predeterminados de seguridad más estrictos** - Bueno para seguridad
4. **Preparación post-cuántica** - Infraestructura lista para el futuro
5. **Sin cambios urgentes de certificados** - La transición es suave
6. **Conocimiento de RHEL 9 se transfiere** - Mismas herramientas y comandos
7. **Vigilar lanzamientos menores** - 10.3, 10.4 pueden agregar características

---

## 12.17 Solución de Problemas en RHEL 10

### Enfoque de Diagnóstico

```bash
#============================================#
# RESOLUCIÓN DE PROBLEMAS DE CERTIFICADOS RHEL 10
#============================================#

# Usar la metodología de solución de problemas (Capítulo 27) y los patrones de RHEL 9 (Capítulo 11)

# 1. Verificar versión de RHEL 10
cat /etc/redhat-release
# Red Hat Enterprise Linux release 10.2 (Coughlan)

# 2. Verificar OpenSSL
openssl version
# OpenSSL 3.5.5

# 3. Verificar crypto-policy
update-crypto-policies --show

# 4. Probar certificado
openssl x509 -in cert.crt -noout -text

# 5. Probar conexión
openssl s_client -connect server:443 -tls1_3

# 6. Verificar proveedores (si hay problemas)
openssl list -providers

# 7. Verificar logs
sudo journalctl -xe | grep -i cert
```

**¡No se necesitan nuevas técnicas de solución de problemas - igual que RHEL 9!**

---

## 12.18 Ruta de Migración Recomendada

### De RHEL 9 a RHEL 10

```bash
#============================================#
# MIGRACIÓN SEGURA PARA CERTIFICADOS RHEL 9→10
#============================================#

# Fase 1: Preparación
# - Respaldar todos los certificados
# - Documentar configuración actual
# - Probar en entorno de laboratorio

# Fase 2: Migración
# - Usar proceso estándar de actualización de RHEL
# - Los certificados deberían transferirse sin problemas

# Fase 3: Verificación
# - Verificar crypto-policy sin cambios
# - Probar todas las operaciones de certificados
# - Confirmar rastreo de certmonger mantenido
# - Probar servicios usando certificados

# Fase 4: Optimización
# - Considerar claves EC para nuevos certificados
# - Revisar y actualizar crypto-policy si es necesario
# - Monitorear mejoras de RHEL 10.x
```

---

## 12.19 Documentación y Recursos

### Recursos Oficiales

```markdown
## Recursos de Certificados RHEL 10

### Documentación Oficial
- Notas de Lanzamiento RHEL 10 (verificar tu versión 10.x específica)
- https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/10

### Actualizaciones de Seguridad
- https://access.redhat.com/security/
- Suscribirse a anuncios de seguridad de RHEL

### Crypto-Policies
- https://access.redhat.com/articles/3642912
- Verificar actualizaciones específicas de RHEL 10

### Soporte
- Portal de Clientes Red Hat
- Casos de Soporte Red Hat
- Foros de la comunidad RHEL
```

---

## 12.20 Referencia Rápida

```
┌──────────────────────────────────────────────────────────────┐
│ REFERENCIA RÁPIDA DE CERTIFICADOS RHEL 10                    │
├──────────────────────────────────────────────────────────────┤
│ OpenSSL:      3.5.5-2 (igual que RHEL 9.8)                   │
│ TLS:          1.3 preferido, 1.2 soportado                   │
│ Lanzado:      20 de mayo de 2025 (RHEL 10.0 GA)              │
│ Estado:       Listo para producción                          │
│                                                              │
│ Cambio clave: Mejoras de seguridad incrementales             │
│ Migración:    Bajo impacto desde RHEL 9                      │
│ Comandos:     Iguales que RHEL 9                             │
│ Herramientas: Iguales que RHEL 9                             │
│                                                              │
│ Futuro:       Preparación criptografía post-cuántica         │
│               Vigilar características en 10.3, 10.4+         │
│                                                              │
│ Verificar:    cat /etc/redhat-release                        │
│               openssl version                                │
│               update-crypto-policies --show                  │
└──────────────────────────────────────────────────────────────┘

✅ ¡Si conoces certificados RHEL 9, conoces RHEL 10!
⚠️ Siempre verificar docs oficiales para tu versión menor 10.x específica
```
---

**Navegación del Capítulo**

| [← Anterior: Capítulo 11 - Seguridad Moderna en RHEL 9](11-rhel9-modern-security.md) | [Siguiente: Capítulo 13 - Compatibilidad Entre Versiones →](13-cross-version-compatibility.md) |
|:---|---:|
