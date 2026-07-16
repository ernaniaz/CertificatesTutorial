# 🧪 Ejercicios de laboratorio

Laboratorios prácticos completos para practicar lo que has aprendido. Cada laboratorio incluye scripts funcionales, instrucciones paso a paso y procedimientos de validación.

---

## Laboratorios por categoría

### 📚 Laboratorios de fundamentos (1-5)

| Lab | Título | Tiempo | Nivel | Capítulo |
|-----|--------|--------|-------|----------|
| [01](01-environment-setup/) | Configuración del entorno | 15-20 min | Principiante | Cap. 1-3 |
| [02](02-key-generation/) | Generación de claves | 20-25 min | Principiante | Cap. 4 |
| [03](03-digital-signatures/) | Firmas digitales | 20 min | Principiante | Cap. 7 |
| [04](04-x509-certificates/) | Certificados X.509 | 25-30 min | Principiante | Cap. 5 |
| [05](05-trust-store/) | Gestión del almacén de confianza | 25 min | Principiante | Cap. 6 |

### 🌐 Laboratorios de configuración de servicios (6-10)

| Lab | Título | Tiempo | Nivel | Capítulo |
|-----|--------|--------|-------|----------|
| [06](06-apache-https/) | Configuración de Apache HTTPS | 30-40 min | Intermedio | Cap. 14 |
| [07](07-nginx-https/) | Configuración de NGINX HTTPS | 30-35 min | Intermedio | Cap. 15 |
| [08](08-postfix-tls/) | Postfix TLS | 30-40 min | Intermedio | Cap. 16 |
| [09](09-openldap-ldaps/) | OpenLDAP LDAPS | 40-50 min | Intermedio | Cap. 17 |
| [10](10-postgresql-tls/) | PostgreSQL TLS | 30-40 min | Intermedio | Cap. 18 |

### ⚙️ Laboratorios de automatización (11-14)

| Lab | Título | Tiempo | Nivel | Capítulo |
|-----|--------|--------|-------|----------|
| [11](11-certmonger-basics/) | Fundamentos de certmonger | 40-50 min | Intermedio | Cap. 22 |
| [12](12-crypto-policies/) | Crypto-Policies | 30-40 min | Intermedio | Cap. 23 |
| [13](13-letsencrypt-certbot/) | Let's Encrypt y Certbot | 40-50 min | Intermedio | Cap. 24 |
| [14](14-ansible-automation/) | Automatización con Ansible | 50-60 min | Avanzado | Cap. 25 |

### 🔧 Laboratorios de resolución de problemas (15-16) - CRÍTICO

| Lab | Título | Tiempo | Nivel | Capítulo |
|-----|--------|--------|-------|----------|
| [15](15-troubleshooting-scenarios/) | Escenarios de resolución de problemas (certificado vencido) | 15-20 min | Avanzado | Cap. 27-29 |
| [16](16-emergency-procedures/) | Procedimientos de emergencia | 30-40 min | Avanzado | Cap. 33 |

### 🔄 Laboratorios de migración (17-18)

| Lab | Título | Tiempo | Nivel | Capítulo |
|-----|--------|--------|-------|----------|
| [17](17-rhel7to8-migration/) | Migración RHEL 7→8 | 40-50 min | Avanzado | Cap. 35 |
| [18](18-rhel8to9-migration/) | Migración RHEL 8→9 | 40-50 min | Avanzado | Cap. 36 |

### 🔒 Laboratorios de seguridad (19-20)

| Lab | Título | Tiempo | Nivel | Capítulo |
|-----|--------|--------|-------|----------|
| [19](19-fips-mode/) | Configuración del modo FIPS | 40-50 min | Avanzado | Cap. 38-39 |
| [20](20-security-hardening/) | Endurecimiento de seguridad | 30-40 min | Avanzado | Cap. 40 |

### 🚀 Laboratorios avanzados/apéndice (21-22)

| Lab | Título | Tiempo | Nivel | Capítulo |
|-----|--------|--------|-------|----------|
| [21](21-kubernetes-cert-manager/) | Kubernetes cert-manager | 40-50 min | Avanzado | Apéndice A |
| [22](22-vault-pki/) | HashiCorp Vault PKI | 35-45 min | Avanzado | Apéndice B |

---

## Características de los laboratorios

Los laboratorios generalmente incluyen:
- ✅ **README.md** - Instrucciones completas y objetivos de aprendizaje
- ✅ **Scripts de shell** - Scripts de automatización funcionales y probados
- ✅ **Validación** - Un comando o procedimiento de validación documentado
- ✅ **Limpieza** - Procedimientos de limpieza cuando el lab los proporciona
- ✅ **Manejo de errores** - Salida con colores y mensajes de error útiles
- ✅ **Notas de versión de RHEL** - Revise el README de cada lab para ver las versiones compatibles

---

## Rutas de aprendizaje

### Ruta para principiantes (¡Empieza aquí!)
1. Lab 01: Configuración del entorno
2. Lab 02: Generación de claves
3. Lab 03: Firmas digitales
4. Lab 04: Certificados X.509
5. Lab 05: Almacén de confianza

### Ruta para administradores de servicios
1. Completar los laboratorios de fundamentos (1-5)
2. Lab 06: Apache HTTPS
3. Lab 07: NGINX HTTPS
4. Lab 08-10: Servicios adicionales

### Ruta para ingenieros de automatización
1. Completar los laboratorios de fundamentos (1-5)
2. Lab 11: Fundamentos de certmonger
3. Lab 12: Crypto-Policies
4. Lab 13: Let's Encrypt
5. Lab 14: Automatización con Ansible

### Ruta para soporte en producción (¡La más importante!)
1. Completar los laboratorios de fundamentos (1-5)
2. Lab 15: Escenarios de resolución de problemas ⭐
3. Lab 16: Procedimientos de emergencia ⭐
4. Labs 17-18: Laboratorios de migración
5. Labs 19-20: Laboratorios de seguridad

---

## Inicio rápido

```bash
# Navegar al directorio de laboratorios
cd labs/es_ES

# Comenzar con el Lab 01
cd 01-environment-setup
./setup.sh
./verify-environment.sh

# Cada laboratorio sigue el flujo de validación documentado en su README:
cd ../XX-lab-name/
./script-name.sh
./verify*.sh o ./test*.sh
./cleanup*.sh
```

---

## Requisitos previos

- **Sistema RHEL:** Versión 7, 8, 9 o 10
- **Acceso:** Privilegios de root o sudo
- **Conocimientos:** Conocimientos básicos de la línea de comandos de Linux
- **Tiempo:** Reservar de 15 a 90 minutos por laboratorio

---

## Soporte

- **¿Problemas?** Consulta la sección de resolución de problemas de cada laboratorio en README.md
- **¿Preguntas?** Vuelve a los capítulos relevantes del tutorial
- **¿Errores?** Los laboratorios incluyen mensajes de error detallados y sugerencias

---

**Tiempo total de laboratorios**: ~15-20 horas para los 22 laboratorios  
**Dificultad**: Progresión de principiante a avanzado
