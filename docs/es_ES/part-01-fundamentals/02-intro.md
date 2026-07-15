# Capítulo 2: Introducción a los Certificados en RHEL

> **¡Bienvenido!** Este tutorial te llevará desde no saber nada sobre certificados digitales hasta resolver problemas de certificados con confianza en sistemas Red Hat Enterprise Linux.

---

## 2.1 ¿Por Qué Este Tutorial?

Eres un administrador de RHEL. Un día, algo se rompe:

- Apache se niega a iniciar: `SSL_CTX_use_certificate:ca md too weak`
- Las conexiones LDAP fallan: `TLS: hostname does not match CN`
- certmonger muestra: `CA_UNREACHABLE`
- curl retorna: `SSL certificate problem: unable to get local issuer certificate`

**¿Te suena familiar?** Estos son problemas de certificados, y están en todas partes en los sistemas Linux modernos.

Este tutorial te enseña a:

- ✅ Entender qué son los certificados (perspectiva RHEL)
- ✅ Configurar certificados para servicios comunes de RHEL
- ✅ **Resolver problemas de certificados** (¡objetivo principal!)
- ✅ Automatizar el ciclo de vida de certificados con herramientas RHEL
- ✅ Manejar diferencias de versiones de RHEL (7, 8, 9, 10)
- ✅ Pasar auditorías (FIPS, STIG, cumplimiento)

---

## 2.2 ¿Para Quién es Este Tutorial?

**Audiencia Principal:**
- Administradores e ingenieros RHEL
- Ingenieros de soporte que resuelven problemas de certificados
- Cualquiera que gestione sistemas RHEL con HTTPS, LDAPS o TLS

**Prerrequisitos:**
- Conocimientos básicos de línea de comandos Linux
- Acceso a sistemas RHEL (7, 8, 9 o 10)
- ¡No se necesita conocimiento previo de certificados!

---

## 2.3 ¿Qué Son los Certificados? (En 60 Segundos)

Imagina que visitas https://example.com. ¿Cómo sabe tu navegador que realmente está hablando con example.com y no con un impostor?

**Respuesta: Certificados digitales.**

Un certificado es como una tarjeta de identificación digital que:
1. **Prueba identidad** ("Soy example.com")
2. **Habilita cifrado** (comunicación segura)
3. **Está firmado por una autoridad confiable** (como una CA)

### En Sistemas RHEL

Los certificados se usan en todas partes:
- **Servidores web** (Apache, NGINX) → HTTPS
- **Servicios de directorio** (OpenLDAP, FreeIPA) → LDAPS
- **Servidores de correo** (Postfix, Dovecot) → SMTPS/IMAPS
- **Bases de datos** (PostgreSQL, MySQL) → Conexiones TLS
- **APIs y servicios** (REST, microservicios) → mTLS
- **Túneles VPN** → Conexiones seguras
- **Registros de contenedores** → Imágenes seguras

**Conclusión:** Si está en red y es seguro en RHEL, probablemente usa certificados.

---

## 2.4 Tu Primera Inspección de Certificado

Vamos a hacerlo práctico inmediatamente. Conéctate por SSH a cualquier sistema RHEL y ejecuta:

```bash
# Ver el certificado del servidor SSH de tu sistema
sudo openssl s_client -connect localhost:22 -starttls smtp 2>/dev/null | openssl x509 -noout -text

# Mejor ejemplo: Verificar un certificado web
echo | openssl s_client -connect access.redhat.com:443 2>/dev/null | openssl x509 -noout -text | head -20
```

Verás una salida como:

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            0a:5d:d2:48:fc:4e:2f:e2:99:81:09:74:2d:4c:d5:69
        Signature Algorithm: ecdsa-with-SHA384
        Issuer: C=US, O=DigiCert Inc, CN=DigiCert Global G3 TLS ECC SHA384 2020 CA1
        Validity
            Not Before: Oct 30 00:00:00 2025 GMT
            Not After : Oct 27 23:59:59 2026 GMT
        Subject: C=US, ST=North Carolina, L=Raleigh, O=Red Hat, Inc., CN=access.redhat.com
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub:
                    04:fc:08:bf:d2:d8:63:0c:84:a4:c8:dd:04:9c:8c:
                    99:4f:cb:93:31:7f:9e:64:27:ea:3d:a7:18:fd:3e:
                    4c:c2:58:8b:cb:f2:5c:6e:95:bf:f3:97:ba:b8:2b:
                    49:c6:51:30:f4:71:88:e3:fa:d4:f1:73:74:1d:e3:
                    2b:49:bc:9e:6e
```

**Lo que estás viendo:**
- **Issuer:** Quién firmó este certificado
- **Subject:** A quién pertenece este certificado
- **Validity:** Cuándo es válido (expira el 15 de marzo de 2025)
- **Signature Algorithm:** Cómo está asegurado (SHA-256 con RSA)

**🎉 ¡Felicitaciones!** Acabas de inspeccionar tu primer certificado.

---

## 2.5 Cómo Funcionan los Certificados (Contexto RHEL)

### Los Tres Componentes Clave

1. **Certificado** (`.crt`, `.pem`)
   - Información pública: "Soy server.example.com"
   - Contiene la clave pública
   - Almacenado en `/etc/pki/tls/certs/` en RHEL

2. **Clave Privada** (`.key`, `.pem`)
   - ¡Secreto! Nunca compartas esto
   - Se usa para probar que posees el certificado
   - Almacenado en `/etc/pki/tls/private/` en RHEL (¡modo 600!)

3. **Autoridad Certificadora (CA)**
   - Emite y firma certificados
   - Puede ser pública (Let's Encrypt, DigiCert)
   - O interna (FreeIPA, CA corporativa)
   - CAs confiables almacenadas en `/etc/pki/ca-trust/` en RHEL

### La Cadena de Confianza

```
CA Raíz (confiable para el sistema RHEL)
  └─ CA Intermedia
      └─ Certificado del Servidor (tu servidor web)
```

Cuando alguien se conecta a tu servidor RHEL:
1. El servidor envía su certificado
2. El cliente verifica la cadena de firmas hasta una CA raíz confiable
3. Si la cadena es válida → la conexión procede
4. Si la cadena se rompe → error (¡y tú recibes la llamada de soporte!)

---

## 2.6 Arquitectura de Certificados de RHEL

### Directorios Clave

```
/etc/pki/
├── ca-trust/
│   ├── source/anchors/      ← Pon aquí los certificados CA personalizados
│   └── extracted/           ← Almacén de confianza del sistema
│       ├── pem/             ← CAs en formato PEM
│       ├── openssl/         ← Confianza OpenSSL
│       └── java/            ← Confianza Java (cacerts)
├── tls/
│   ├── certs/               ← Certificados de servidor
│   ├── private/             ← Claves privadas (¡modo 700!)
│   └── cert.pem             ← Enlace simbólico de certificado predeterminado
└── nssdb/                   ← Base de datos NSS (Firefox, etc.)
```

### Herramientas Clave

```bash
# OpenSSL - Navaja suiza de certificados
openssl version  # Verifica tu versión

# Herramientas NSS - Para bases de datos NSS
certutil -L -d /etc/pki/nssdb

# Gestión de Confianza - Agregar/eliminar CAs
update-ca-trust  # Actualizador del almacén de confianza de RHEL

# Gestor de Certificados - Renovación automática (RHEL 7+)
getcert list  # Mostrar certificados rastreados

# Crypto-Policies - Seguridad en todo el sistema (RHEL 8+)
update-crypto-policies --show  # Verificar política actual
```

---

## 2.7 Un Día en la Vida: Escenarios de Certificados

### Escenario 1: Agregar una CA Personalizada

```bash
# Tienes una CA corporativa que firmó tus servidores internos
sudo cp corporate-ca.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust extract

# ¡Ahora RHEL confía en certificados firmados por tu CA corporativa!
```

### Escenario 2: Configurar Apache HTTPS

```bash
# Instalar Apache con SSL/TLS
sudo dnf install httpd mod_ssl

# Generar una clave privada
sudo openssl genpkey -algorithm RSA -out /etc/pki/tls/private/server.key \
  -pkeyopt rsa_keygen_bits:2048

# Generar una solicitud de firma de certificado (CSR)
sudo openssl req -new -key /etc/pki/tls/private/server.key \
  -out /tmp/server.csr \
  -subj "/CN=web.example.com"

# Enviar CSR a CA, obtener certificado de vuelta, instalarlo
sudo cp server.crt /etc/pki/tls/certs/

# Configurar Apache, reiniciar
sudo systemctl restart httpd
```

### Escenario 3: Resolver un Certificado Expirado

```bash
# El servicio falla con: "certificate has expired"
# Verificar expiración del certificado
sudo openssl x509 -in /etc/pki/tls/certs/server.crt -noout -dates

# La salida muestra:
# notAfter=Jan 15 23:59:59 2024 GMT  ← ¡Ups, expirado!

# Renovar certificado, reemplazar archivo, reiniciar servicio
```

---

## 2.8 Diferencias de Versiones RHEL (Vista Previa)

La gestión de certificados ha evolucionado significativamente a través de las versiones de RHEL:

| Versión RHEL | Característica Clave | Enfoque de Solución de Problemas |
|--------------|---------------------|---------------------------|
| **RHEL 7** | Enfoque tradicional | Configuración manual, problemas TLS heredados |
| **RHEL 8** | **Crypto-policies** | Conflictos de políticas, integración certmonger |
| **RHEL 9** | OpenSSL 3.x | Problemas de proveedores, validación más estricta |
| **RHEL 10** | Valores predeterminados fortalecidos | Solo moderno, herramientas mejoradas |

> **¡No te preocupes!** El Capítulo 8 cubre estas diferencias de versión en detalle.

---

## 2.9 Problemas Comunes de Certificados (Vista Previa)

Aprenderás a resolver:

**Problemas de Configuración:**
- Desajuste certificado/clave
- Permisos de archivo incorrectos
- Rutas incorrectas en archivos de configuración

**Problemas de Confianza:**
- Certificados autofirmados rechazados
- Errores de CA desconocida
- Fallos de validación de cadena

**Problemas de Expiración:**
- Certificados expirados
- Problemas de desfase de reloj
- Fallos de renovación

**Problemas de Versión:**
- Desajustes de versión TLS
- Problemas de conjunto de cifrado
- Conflictos de crypto-policy (RHEL 8+)
- Compatibilidad OpenSSL 3.x (RHEL 9+)

**Específicos de Servicio:**
- Apache: Errores de `SSLCertificateFile`
- NGINX: Problemas de `ssl_certificate`
- Postfix: Fallos de handshake TLS
- LDAP: `TLS: hostname does not match`

---

## 2.10 Resumen del Camino de Aprendizaje

Este tutorial está organizado para administradores RHEL:

### Parte 1: Fundamentos (Capítulos 1-7)
Comienza aquí. Aprende los conceptos básicos de certificados en contexto RHEL.

### Parte 2: Específico por Versión (Capítulos 8-13)
Inmersión Profunda en diferencias de RHEL 7, 8, 9, 10.

### Parte 3: Servicios (Capítulos 14-21)
Configura certificados para Apache, NGINX, Postfix, LDAP, etc.

### Parte 4: Automatización (Capítulos 22-26)
Domina certmonger, crypto-policies, Let's Encrypt, Ansible.

### Parte 5: Solución de Problemas (Capítulos 27-33) ⭐
**¡Aquí es donde te conviertes en un experto!**
Resolución sistemática de problemas, errores comunes, procedimientos de emergencia.

### Parte 6: Migración (Capítulos 34-37)
Actualizaciones de versiones RHEL y migración de certificados.

### Parte 7: Seguridad (Capítulos 38-41)
Modo FIPS, cumplimiento, fortalecimiento, auditoría.

### Apéndices
Temas avanzados opcionales (Kubernetes, Vault, Zero Trust, etc.)

---

## 2.11 Cómo Usar Este Tutorial

### Para Usuarios Nuevos
📖 Lee los capítulos en orden. Cada uno se basa en el conocimiento previo.

### Para Usuarios Experimentados
🎯 Salta a solución de problemas (Parte 5) o servicios específicos (Parte 3).

### Para Ingenieros de Soporte
🚨 Comienza con el Capítulo 27 (Metodología de Solución de Problemas de Certificados RHEL), luego profundiza en detalles.

### Laboratorios Prácticos
Cada capítulo incluye ejemplos prácticos. Necesitarás:
- Un sistema RHEL (una VM o contenedor está bien)
- Acceso root o sudo
- Conectividad a Internet (para instalaciones de paquetes)

---

## 2.12 Conceptos Clave a Dominar

Al final de este tutorial, entenderás:

- ✅ **Qué son los certificados** y por qué RHEL los usa
- ✅ **Cómo funciona la confianza** en sistemas RHEL
- ✅ **Dónde viven los certificados** (`/etc/pki/`)
- ✅ **Qué herramientas usar** (openssl, certutil, certmonger)
- ✅ **Diferencias de versión** (RHEL 7 vs 8 vs 9 vs 10)
- ✅ **Cómo resolver problemas** de cualquier certificado
- ✅ **Cómo automatizar** el ciclo de vida de certificados
- ✅ **Cómo asegurar** sistemas (FIPS, cumplimiento)

---

## 2.13 Impacto en el Mundo Real

Los problemas de certificados causan:
- ❌ Interrupciones de servicio (certificados expirados)
- ❌ Vulnerabilidades de seguridad (cifrados débiles)
- ❌ Migraciones fallidas (actualizaciones de RHEL)
- ❌ Fallos de cumplimiento (rechazos de auditoría)
- ❌ Pérdida de productividad (tiempo de solución de problemas)

**Después de este tutorial:**
- ✅ Prevenir problemas antes de que sucedan
- ✅ Resolver problemas en minutos, no horas
- ✅ Automatizar la gestión de certificados
- ✅ Pasar auditorías de seguridad
- ✅ Migrar versiones de RHEL con confianza

---

## 2.14 Tu Primer Ejercicio

Vamos a verificar que tu sistema RHEL está listo:

```bash
# Verificar versión de RHEL
cat /etc/redhat-release

# Verificar OpenSSL
openssl version

# Verificar si certmonger está instalado
rpm -q certmonger

# Verificar si puedes usar sudo
sudo whoami

# Verificar conectividad a Internet (para instalaciones de paquetes)
ping -c 3 access.redhat.com

# Listar CAs confiables actuales (muestra)
trust list | head -20
```

✅ ¡Si todos los comandos funcionan, estás listo para continuar!

---

## 2.15 ¡Comencemos!

Ahora entiendes:
- Qué son los certificados
- Por qué importan en RHEL
- Dónde viven en el sistema de archivos
- Qué herramientas usarás
- Qué aprenderás en este tutorial

**¿Listo para profundizar más?**

---

## Referencia Rápida

```
┌─────────────────────────────────────────────────────────────────┐
│ INICIO RÁPIDO DE CERTIFICADOS (RHEL)                            │
├─────────────────────────────────────────────────────────────────┤
│ Ver cert:           openssl x509 -in cert.crt -noout -text      │
│ Ver expiración:     openssl x509 -in cert.crt -noout -dates     │
│ Agregar CA:         cp ca.crt /etc/pki/ca-trust/source/anchors/ │
│                     sudo update-ca-trust                        │
│ Listar rastreados:  getcert list                                │
│ Ver política:       update-crypto-policies --show  (RHEL 8+)    │
└─────────────────────────────────────────────────────────────────┘

Ubicación cert:  /etc/pki/tls/certs/
Ubicación key:   /etc/pki/tls/private/  (¡modo 600!)
Confianza CA:    /etc/pki/ca-trust/
```

---

## 🧪 Laboratorio Práctico

**Lab 01: Configuración del Entorno**

Valida tu entorno RHEL e instala herramientas esenciales de gestión de certificados

- 📁 **Ubicación:** `labs/es_ES/01-environment-setup/`
- ⏱️ **Tiempo:** 15-20 minutos
- 🎯 **Nivel:** Principiante

---

**Navegación del Capítulo**

| [← Anterior: Capítulo 1 - Criptografía, Estructura PKI y Fundamentos](01-cryptography-pki-basics.md) | [Siguiente: Capítulo 3 - Resumen de Herramientas de Certificados en RHEL →](03-rhel-tools-overview.md) |
|:---|---:|
