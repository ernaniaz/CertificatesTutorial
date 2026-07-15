# Lab 12: Crypto-Policies

## Objetivos de aprendizaje

Al completar este lab, usted:
- Comprenderá el sistema crypto-policies de RHEL
- Verificará la política criptográfica actual
- Cambiará entre niveles de política (DEFAULT, FUTURE, LEGACY)
- Probará la compatibilidad de servicios con las políticas
- Creará módulos de política personalizados
- Comprenderá el impacto en servicios TLS/SSL

## Requisitos previos

- **Versión de RHEL:** 8, 9 o 10 (crypto-policies se introdujo en RHEL 8)
- **Acceso al sistema:** Se requiere root/sudo
- **Labs anteriores:** Es útil comprender los servicios TLS

## Tiempo estimado

**30-40 minutos**

## Descripción general

Crypto-policies es un marco de políticas criptográficas a nivel de todo el sistema en RHEL 8+. Aprenda a gestionar niveles de seguridad en todos los servicios del sistema de forma uniforme, comprendiendo las compensaciones entre seguridad y compatibilidad.

---

## Instrucciones

### Paso 1: Verificar la política actual

Verifique la crypto-policy actual:

```bash
./check-policy.sh
```

Esto muestra:
- La política activa actual
- Los archivos de configuración de la política
- Los servicios afectados

---

### Paso 2: Cambiar a la política LEGACY

Pruebe la política LEGACY para máxima compatibilidad:

```bash
sudo ./switch-legacy.sh
```

Esto:
- Cambia a la política LEGACY
- Actualiza todas las configuraciones de servicios
- Prueba la compatibilidad

---

### Paso 3: Cambiar a la política FUTURE

Pruebe la política FUTURE para máxima seguridad:

```bash
sudo ./switch-future.sh
```

Esto:
- Cambia a la política FUTURE
- Muestra requisitos más estrictos
- Prueba la compatibilidad de servicios

---

### Paso 4: Probar compatibilidad

Pruebe cómo se comportan los servicios bajo distintas políticas:

```bash
./test-compatibility.sh
```

Esto prueba:
- Versiones TLS permitidas
- Conjuntos de cifrado disponibles
- Algoritmos SSH soportados
- Funcionalidad de servicios

---

### Paso 5: Restaurar la política DEFAULT

Vuelva a la política DEFAULT:

```bash
sudo ./restore-default.sh
```

Esto:
- Restaura la política DEFAULT
- Restablece todos los servicios
- Verifica la restauración

---

### Paso 6: Verificar la configuración

Ejecute una validación integral:

```bash
sudo ./verify.sh
```

---

## Validación

```bash
sudo ./test.sh
```

Todas las comprobaciones deben pasar.

## Resultado esperado

Después de completar este lab:
- ✅ Comprensión de crypto-policies
- ✅ Capacidad para cambiar políticas
- ✅ Conocimiento del impacto de las políticas
- ✅ Prueba de varios niveles de política
- ✅ Sistema restaurado a DEFAULT

---

## Conceptos clave

### Descripción general de Crypto-Policies

**Propósito:**
- Estándares criptográficos a nivel de todo el sistema
- Seguridad consistente en todos los servicios
- Gestión sencilla de políticas
- Equilibrio entre seguridad y compatibilidad

**Servicios soportados:**
- OpenSSL
- GnuTLS
- NSS
- OpenSSH
- Kerberos
- BIND
- Apache
- NGINX

### Niveles de política

| Política | Descripción | Caso de uso |
|--------|-------------|----------|
| **DEFAULT** | Seguridad equilibrada | Operaciones normales |
| **LEGACY** | Se permiten algoritmos débiles | Sistemas antiguos/compatibilidad |
| **FUTURE** | Solo algoritmos fuertes | Necesidades de alta seguridad |
| **FIPS** | Cumple con FIPS 140-2 | Gobierno/cumplimiento normativo |

### Características de las políticas

**DEFAULT:**
- TLS 1.2+
- Firmas SHA-1 en DNSSec
- SSH RSA 2048+
- Equilibrada para la mayoría de entornos

**LEGACY:**
- TLS 1.0+
- Se permiten cifrados débiles
- Se permiten firmas SHA-1
- Máxima compatibilidad

**FUTURE:**
- TLS 1.3 preferido
- Solo cifrados fuertes
- Tamaños de clave mayores
- Seguridad orientada al futuro

**FIPS:**
- Algoritmos aprobados por FIPS 140-2
- Sin MD5 ni firmas SHA-1
- Conjuntos de cifrado específicos
- Requisito de cumplimiento normativo

### Comandos

```bash
# Verificar la política actual
update-crypto-policies --show

# Establecer política
update-crypto-policies --set LEGACY
update-crypto-policies --set DEFAULT
update-crypto-policies --set FUTURE

# Listar políticas disponibles
ls /usr/share/crypto-policies/policies/

# Ver detalles de la política
cat /usr/share/crypto-policies/policies/DEFAULT.pol

# Aplicar módulo personalizado
update-crypto-policies --set DEFAULT:module-name
```

### Archivos de configuración

```
/etc/crypto-policies/
├── config                           # Política activa
├── back-ends/                       # Configs específicas por servicio
│   ├── openssh.config
│   ├── openssl.config
│   ├── gnutls.config
│   └── nss.config
└── state/
    └── current                      # Enlace simbólico a la política actual
```

---

## Resolución de problemas

### Problema: Los servicios fallan después del cambio de política

**Síntoma:**
```
SSL handshake failed
Connection refused
```

**Solución:**
Vuelva a DEFAULT o LEGACY:
```bash
update-crypto-policies --set DEFAULT
systemctl restart <service>
```

---

### Problema: No se puede cambiar la política

**Síntoma:**
```
Setting system policy failed
```

**Solución:**
Revise los registros y los permisos:
```bash
journalctl -xe
# Asegúrese de ser root
sudo update-crypto-policies --set DEFAULT
```

---

### Problema: Los clientes antiguos no pueden conectarse

**Síntoma:**
Clientes antiguos fallan con la política FUTURE/DEFAULT

**Solución:**
Use LEGACY temporalmente o cree un módulo personalizado:
```bash
# Opción 1: Usar LEGACY
update-crypto-policies --set LEGACY

# Opción 2: Crear módulo personalizado que permita algoritmos específicos
```

---

## Notas específicas por versión

### RHEL 8
- Se introdujo Crypto-policies
- La política DEFAULT es equilibrada
- La mayoría de servicios soportados
- Se requiere reinicio manual después del cambio de política

### RHEL 9
- Crypto-policies mejorado
- Política DEFAULT más estricta
- SHA-1 bloqueado por defecto
- Mejor reinicio automático de servicios

### RHEL 10 (Beta/Preview)
- Valores predeterminados más endurecidos
- Control más granular
- Soporte extendido de servicios

---

## Limpieza

```bash
sudo ./cleanup.sh
```

Esto restaura la política DEFAULT.

---

## Recursos adicionales

**Capítulos relacionados:**
- Capítulo 23: Crypto-Policies — profundización

**Documentación:**
- `man update-crypto-policies`
- `man crypto-policies`
- `/usr/share/doc/crypto-policies/`
- https://access.redhat.com/articles/3642912

**Archivos de política:**
- `/usr/share/crypto-policies/policies/`
- `/etc/crypto-policies/config`

---

## Próximos pasos

Continúe con **Lab 13: Let's Encrypt/Certbot** para aprender automatización de certificados con ACME.

---

**Nivel de dificultad:** Intermedio
**Nota:** Este lab requiere RHEL 8+ (crypto-policies no está disponible en RHEL 7)
