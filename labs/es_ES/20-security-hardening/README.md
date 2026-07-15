# Lab 20: Endurecimiento de seguridad para certificados

## Objetivos de aprendizaje

Al completar este lab, usted:
- Endurecerá configuraciones SSL/TLS de Apache y NGINX
- Deshabilitará protocolos y cifrados débiles
- Implementará encabezados de seguridad
- Aplicará TLS 1.3
- Configurará HSTS
- Aplicará mejores prácticas de seguridad

## Requisitos previos

- **Labs 01-10** completados
- **RHEL 8 o 9** recomendado
- **Acceso al sistema:** Se requiere root/sudo
- **Apache o NGINX** instalado

## Tiempo estimado

**30-40 minutos**

## Descripción general

Aprenda a aplicar mejores prácticas de endurecimiento de seguridad a configuraciones de certificados, garantizando máxima protección contra ataques y vulnerabilidades conocidos.

---

## Instrucciones

### Paso 1: Endurecer Apache

```bash
sudo ./harden-apache.sh
```

### Paso 2: Endurecer NGINX

```bash
sudo ./harden-nginx.sh
```

### Paso 3: Deshabilitar protocolos débiles

```bash
sudo ./disable-weak-protocols.sh
```

### Paso 4: Aplicar TLS 1.3

```bash
sudo ./enforce-tls13.sh
```

### Paso 5: Configurar HSTS

```bash
sudo ./enable-hsts.sh
```

### Paso 6: Auditar configuración

```bash
./audit-security.sh
```

---

## Mejores prácticas de seguridad

### Versiones del protocolo TLS
- ✅ TLS 1.3 (mejor)
- ✅ TLS 1.2 (aceptable)
- ❌ TLS 1.1 (obsoleto)
- ❌ TLS 1.0 (inseguro)
- ❌ SSLv3 (vulnerable)

### Conjuntos de cifrado
Use cifrados con forward secrecy:
- ECDHE-RSA-AES256-GCM-SHA384
- ECDHE-RSA-AES128-GCM-SHA256
- ECDHE-RSA-CHACHA20-POLY1305

### Encabezados de seguridad
```
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
```

---

## Validación

Verifique el endurecimiento de seguridad:

```bash
./audit-security.sh
```

**Resultados esperados:**
- ✓ Si existe `/etc/httpd/conf.d/ssl-hardening.conf`, `./audit-security.sh` reporta la configuración de endurecimiento de Apache
- ✓ Si existe `/etc/nginx/conf.d/ssl-hardening.conf`, `./audit-security.sh` reporta la configuración de endurecimiento de NGINX
- ✓ El script muestra un resumen pass/fail para los archivos drop-in de endurecimiento presentes en el sistema

**Pruebas manuales adicionales:**
```bash
# Probar versión TLS
openssl s_client -connect localhost:443 -tls1
# Debe fallar

# Probar TLS 1.2
openssl s_client -connect localhost:443 -tls1_2
# Debe tener éxito

# Verificar encabezados
curl -I https://localhost
# Debe incluir HSTS y encabezados de seguridad

# Verificar fortaleza del cifrado
nmap --script ssl-enum-ciphers -p 443 localhost
```

---

## Limpieza

```bash
sudo ./cleanup.sh
```

---

**Nivel de dificultad:** Avanzado
