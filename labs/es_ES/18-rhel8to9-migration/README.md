# Lab 18: Migración de certificados RHEL 8→9

## Objetivos de aprendizaje

Al completar este lab, usted:
- Comprenderá los cambios de certificados en RHEL 9
- Manejará la migración a OpenSSL 3.x
- Lidiará con valores predeterminados de seguridad más estrictos
- Actualizará algoritmos obsoletos
- Probará certificados después de la actualización
- Resolverá problemas específicos de RHEL 9

## Requisitos previos

- **Comprensión de las diferencias** entre RHEL 8 y 9
- **Labs 01-17** completados
- **El lab abarca ambos sistemas** — ejecute evaluación/copia de seguridad/comprobaciones de compatibilidad en RHEL 8 y luego ejecute `configure-rhel9.sh` y `validate-migration.sh` en el sistema RHEL 9 ya actualizado
- **Acceso al sistema:** Se requiere root/sudo

## Tiempo estimado

**40-50 minutos**

## Descripción general

RHEL 9 introduce OpenSSL 3.x con valores predeterminados de seguridad más estrictos. Aprenda a migrar certificados adaptándose a requisitos de seguridad mejorados y al manejo de algoritmos obsoletos.

---

## Diferencias clave: RHEL 8 vs RHEL 9

### Versión de OpenSSL

**RHEL 8:**
- OpenSSL 1.1.1
- Valores predeterminados más permisivos
- Soporte de algoritmos legacy

**RHEL 9:**
- OpenSSL 3.0+
- Valores predeterminados de seguridad más estrictos
- Algoritmos legacy en proveedor separado
- Advertencias de obsolescencia mejoradas

### Valores predeterminados de seguridad

**RHEL 8:**
- La política DEFAULT permite algunas opciones antiguas
- Firmas SHA-1 permitidas en LEGACY
- Validación de certificados más flexible

**RHEL 9:**
- Política DEFAULT más estricta
- SHA-1 completamente bloqueado
- SANs requeridos (solo CN obsoleto)
- Tamaños mínimos de clave aplicados

### Crypto-Policies

**RHEL 8:**
- DEFAULT, LEGACY, FUTURE, FIPS
- A nivel de todo el sistema pero con excepciones

**RHEL 9:**
- Mismos niveles de política
- Aplicación más estricta
- Mejor integración con OpenSSL 3
- Proveedor legacy para compatibilidad

---

## Instrucciones

### Paso 1: Evaluación pre-migración

Evalúe el estado de certificados en RHEL 8:

```bash
./assess-rhel8.sh
```

Verifica:
- Compatibilidad de certificados actuales
- Uso de OpenSSL 1.1.1
- Algoritmos obsoletos
- Configuraciones de servicios

---

### Paso 2: Copia de seguridad de todo

Haga copia de seguridad de los certificados en el host RHEL 8 actual antes de actualizar:

```bash
sudo ./backup-certificates.sh
```

Respalda:
- Todos los certificados y claves en `/etc/pki/`
- Configuraciones de servicios (Apache, NGINX, Postfix, OpenLDAP cuando existan)
- Configuración y política actual de crypto-policies
- Archivo comprimido para almacenamiento externo

---

### Paso 3: Identificar problemas de compatibilidad

Encuentre posibles problemas:

```bash
./check-compatibility.sh
```

Identifica:
- Certificados sin SANs
- Tamaños de clave débiles
- Algoritmos obsoletos
- Problemas de configuración

---

### Paso 4: Configuración post-actualización (RHEL 9)

En el sistema RHEL 9 ya actualizado:

```bash
sudo ./configure-rhel9.sh
```

Configura:
- Configuración de OpenSSL 3.x
- Crypto-policies actualizadas
- Adaptaciones de servicios
- Proveedor legacy si es necesario

---

### Paso 5: Validar migración en RHEL 9

En el sistema RHEL 9 ya actualizado, ejecute una validación integral:

```bash
./validate-migration.sh
```

Prueba:
- Funcionalidad de OpenSSL 3.x
- Validez de certificados
- Operaciones de servicios
- Conexiones TLS

---

## Lista de verificación de migración

### Antes de la migración (RHEL 8)

- [ ] Copia de seguridad de todos los certificados
- [ ] Documentar crypto-policy
- [ ] Verificar certificados solo con CN
- [ ] Verificar tamaños de clave (RSA 2048+)
- [ ] Probar cadenas de certificados
- [ ] Documentar configs personalizadas de OpenSSL
- [ ] Verificar algoritmos legacy

### Durante la migración

- [ ] Realizar actualización del SO a RHEL 9
- [ ] Anotar advertencias de OpenSSL 3.x
- [ ] Preservar configuraciones
- [ ] Conservar registros de actualización

### Después de la migración (RHEL 9)

- [ ] Verificar que OpenSSL 3.x esté activo
- [ ] Verificar crypto-policy
- [ ] Probar todos los servicios
- [ ] Actualizar certificados si es necesario
- [ ] Habilitar proveedor legacy si se requiere
- [ ] Validar conexiones TLS
- [ ] Actualizar monitoreo

---

## Validación

Verifique una migración exitosa a RHEL 9:

```bash
./validate-migration.sh
```

**Resultados esperados:**
- ✓ OpenSSL 3.x activo
- ✓ Todos los certificados usan firmas SHA-256+
- ✓ Los certificados incluyen SANs
- ✓ Servicios ejecutándose sin errores
- ✓ Crypto-policies aplicadas
- ✓ Sin advertencias de algoritmos obsoletos

**Verificación manual:**
1. Verificar versión de OpenSSL: `openssl version`
2. Verificar certificados: `openssl x509 -in cert.pem -noout -text`
3. Probar conexiones: `curl -v https://localhost`
4. Verificar SANs en todos los certificados
5. Revisar registros en busca de advertencias de obsolescencia

---

## Problemas comunes

### Problema: Certificado sin SAN

**Síntoma:** Certificado rechazado, error "no SAN"

**Solución:**
```bash
# Regenerar con SANs o usar proveedor legacy temporalmente
# Para habilitar proveedor legacy:
sudo update-crypto-policies --set DEFAULT:FEDORA32
```

---

### Problema: Tamaño de clave débil rechazado

**Síntoma:** Claves RSA <2048 bits rechazadas

**Solución:**
```bash
# Regenerar con clave más grande
openssl genrsa -out new.key 2048
# O habilitar proveedor legacy (no recomendado)
```

---

### Problema: El servicio no inicia

**Síntoma:** Errores de inicialización SSL/TLS en OpenSSL 3.x

**Solución:**
```bash
# Verificar uso de API obsoleta
journalctl -xeu service-name

# Actualizar aplicación o habilitar proveedor legacy
# Editar /etc/pki/tls/openssl.cnf:
# openssl_conf = openssl_init
# [openssl_init]
# providers = provider_sect
# [provider_sect]
# default = default_sect
# legacy = legacy_sect
# [default_sect]
# activate = 1
# [legacy_sect]
# activate = 1
```

---

## Cambios de OpenSSL 3.x

### Arquitectura de proveedores

OpenSSL 3.x usa proveedores:
- **default** - Algoritmos estándar
- **legacy** - Algoritmos obsoletos (MD5, DES, etc.)
- **fips** - Algoritmos aprobados por FIPS

### Habilitar proveedor legacy

```bash
# A nivel de todo el sistema (no recomendado)
sudo tee -a /etc/pki/tls/openssl.cnf << 'EOF'
openssl_conf = openssl_init

[openssl_init]
providers = provider_sect

[provider_sect]
default = default_sect
legacy = legacy_sect

[default_sect]
activate = 1

[legacy_sect]
activate = 1
EOF
```

### Requisitos de certificados

**Requisitos de RHEL 9:**
1. **SANs requeridos** - No depender solo de CN
2. **RSA 2048+ bits** - Tamaño mínimo de clave
3. **Firmas SHA-256+** - Sin SHA-1
4. **Cadena válida** - Cadena de certificados completa
5. **Extensiones adecuadas** - Key usage, extended key usage

---

## Mejores prácticas

### Generación de certificados para RHEL 9

```bash
# Generar con SANs
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout server.key -out server.crt -days 365 \
  -subj "/CN=server.example.com" \
  -addext "subjectAltName=DNS:server.example.com,DNS:www.example.com"
```

### Probar compatibilidad

```bash
# Probar con OpenSSL 3.x
openssl version
openssl s_client -connect localhost:443

# Verificar SANs del certificado
openssl x509 -in cert.pem -noout -ext subjectAltName

# Verificar con configuración estricta
openssl verify -CAfile ca.pem cert.pem
```

---

## Limpieza

```bash
sudo ./cleanup.sh
```

Elimina artefactos de migración.

---

## Recursos adicionales

**Capítulos relacionados:**
- Capítulo 36: Migración RHEL 8→9
- Capítulo 11: Seguridad Moderna en RHEL 9

**Documentación:**
- Notas de la versión de RHEL 9
- Guía de migración de OpenSSL 3.x
- `man openssl-providers`

**Cambios clave:**
- https://www.openssl.org/docs/man3.0/man7/migration_guide.html
- https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/

---

## Próximos pasos

¡Ha completado los labs de migración! A continuación:
- **Lab 19-20:** Labs de seguridad (FIPS, Endurecimiento)
- **Lab 21-22:** Temas avanzados (Kubernetes, Vault)

---

**Nivel de dificultad**: Avanzado  
**Nota**: OpenSSL 3.x requiere pruebas cuidadosas
