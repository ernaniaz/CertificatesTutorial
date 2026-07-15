# Lab 22: HashiCorp Vault PKI

## Objetivos de aprendizaje

Al completar este lab, usted:
- Comprenderá el motor de secretos PKI dinámico de Vault
- Instalará y configurará HashiCorp Vault en modo dev
- Habilitará y configurará el motor de secretos PKI
- Creará una jerarquía de CA raíz e intermedia
- Configurará roles PKI para emisión de certificados
- Emitirá certificados dinámicamente vía API/CLI
- Comprenderá los beneficios de certificados de corta duración
- Revocará certificados y gestionará CRLs

## Requisitos previos

- **Dependencias del lab:** Labs 01-05 completados (fundamentos de certificados)
- **Versión de RHEL:** RHEL 8, 9 o 10
- **Acceso al sistema:** Se requieren privilegios root o sudo
- **Requisitos adicionales:**
  - curl instalado
  - jq instalado (para análisis JSON)
  - Conectividad a Internet para descarga de Vault
  - 1 GB de RAM disponible

## Tiempo estimado

**35-45 minutos** (incluye instalación de Vault y configuración PKI)

## Descripción general

HashiCorp Vault proporciona un sistema PKI dinámico donde los certificados se emiten bajo demanda con valores TTL (time-to-live) cortos. Este enfoque reduce la necesidad de revocación de certificados y simplifica la gestión del ciclo de vida de certificados. Vault centraliza la aplicación de políticas y proporciona gestión de certificados impulsada por API.

---

## ¿Por qué usar Vault para PKI?

### Beneficios

**Emisión dinámica de certificados:**
- Certificados creados bajo demanda
- TTL corto (minutos a horas) reduce necesidades de revocación
- Renovación automática mediante agentes de Vault

**Política centralizada:**
- Control de acceso basado en roles
- Políticas de certificados consistentes
- Registro de auditoría de todas las operaciones

**Impulsado por API:**
- API REST para automatización
- CLI para operaciones manuales
- Integración sencilla con CI/CD

**Seguridad:**
- Las claves privadas nunca salen de Vault
- Rotación automática
- Almacenamiento seguro de secretos

---

## Arquitectura PKI de Vault

```
┌─────────────────────────────────────┐
│         CA raíz (interna)           │
│     Larga duración (10 años)            │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│      CA intermedia                 │
│     Duración media (5 años)           │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│    Certificados finales (dinámicos)       │
│    Corta duración (horas a días)       │
│    Emitidos mediante roles                  │
└─────────────────────────────────────┘
```

---

## Instrucciones

### Paso 1: Instalar Vault

Descargue e instale HashiCorp Vault:

```bash
./install-vault.sh
```

**Qué hace esto:**
- Descarga el binario de Vault desde HashiCorp
- Instala en /usr/local/bin/
- Verifica la instalación
- Comprueba la versión

**Salida orientativa:**
```
Encabezado del paso actual
Mensajes sobre reutilización de una instalación existente o descarga de Vault
Verificación de la versión instalada
Resumen final con comandos rápidos y el siguiente paso recomendado
```

**Verificación:**
```bash
vault version
vault --help
```

---

### Paso 2: Iniciar Vault en modo dev

Inicie el servidor Vault en modo de desarrollo:

```bash
./start-vault-dev.sh
```

**Notas importantes:**
- ⚠️ **El modo dev NO es para producción** - todos los datos se almacenan en memoria
- ⚠️ Vault se ejecuta unsealed y con un root token
- ⚠️ Los datos se pierden cuando Vault se detiene
- 💡 Perfecto para aprendizaje y pruebas

**Salida orientativa:**
```
Comprobación de prerequisitos y de procesos Vault ya existentes
Inicio de Vault en modo dev y espera hasta que responda
Guardado de `vault-env.sh`
Resumen con la dirección de Vault, el token raíz `root`, el PID real y advertencias de seguridad propias del modo dev
```

**Verificación:**
```bash
source vault-env.sh
vault status
```

---

### Paso 3: Habilitar motor de secretos PKI

Habilite el motor de secretos PKI:

```bash
./enable-pki.sh
```

**Qué hace esto:**
- Habilita el motor de secretos PKI en la ruta `pki/`
- Configura el TTL máximo de lease
- Configura el backend PKI

**Salida orientativa:**
```
Carga del entorno de Vault
Comprobación de accesibilidad de Vault
Habilitación de `pki/` o aviso de que ya estaba habilitado
Ajuste del TTL máximo y resumen con los siguientes pasos
```

**Verificación:**
```bash
vault secrets list
```

---

### Paso 4: Configurar CA raíz

Genere la CA raíz interna:

```bash
./configure-root-ca.sh
```

**Qué hace esto:**
- Genera el certificado de CA raíz internamente
- Establece common name y TTL
- Configura URLs del certificado emisor
- Configura puntos de distribución CRL

**Salida orientativa:**
```
Generación de la CA raíz interna
Configuración de URLs de certificado emisor y CRL
Resumen con el common name, el TTL configurado y las URLs reales publicadas por Vault
```

**Verificación:**
```bash
vault read pki/cert/ca
```

---

### Paso 5: Configurar CA intermedia

Configure la CA intermedia para emitir certificados finales:

```bash
./configure-intermediate-ca.sh
```

**Qué hace esto:**
- Habilita el motor de secretos PKI en `pki_int/`
- Genera CSR de CA intermedia
- Firma el CSR intermedio con la CA raíz
- Establece el certificado intermedio
- Configura URLs de CA intermedia

**Salida orientativa:**
```
Carga del entorno y comprobación de que la CA raíz existe
Habilitación o reutilización de `pki_int/`
Generación de `intermediate.csr`, firma con la CA raíz e importación del certificado intermedio
Configuración de URLs y comprobación opcional de la cadena con OpenSSL
```

**Verificación:**
```bash
vault read pki_int/cert/ca
```

---

### Paso 6: Crear rol PKI

Cree un rol para emisión de certificados:

```bash
./create-role.sh
```

**Qué hace esto:**
- Crea rol PKI llamado "web-server"
- Define dominios permitidos
- Establece TTL predeterminado y máximo
- Configura políticas de certificados

**Salida orientativa:**
```
Comprobación de que `pki_int/` está listo
Creación del rol PKI `web-server`
Lectura posterior de la configuración real del rol desde Vault
Ejemplos de uso para emitir certificados con distintos nombres y TTL
```

**Verificación:**
```bash
vault read pki_int/roles/web-server
```

---

### Paso 7: Emitir certificados

Emita certificados usando el rol configurado:

```bash
./issue-certificate.sh
```

**Qué hace esto:**
- Emite múltiples certificados de prueba
- Demuestra distintos common names
- Muestra detalles del certificado
- Guarda certificados en archivos

**Salida orientativa:**
```
Carga del entorno de Vault y comprobación del rol PKI
Emisión de varios certificados de prueba con números de serie reales y archivos en `certs/`
Resumen de certificados generados
Verificación adicional con OpenSSL, que puede mostrar advertencias según el entorno de prueba
```

**Verificación:**
```bash
openssl x509 -in certs/server01.lab.local.crt -noout -text
openssl verify -CAfile certs/server01.lab.local-ca.crt certs/server01.lab.local.crt
```

---

### Paso 8: Revocar certificado (Opcional)

Demuestre la revocación de certificados:

```bash
./revoke-certificate.sh
```

**Qué hace esto:**
- Revoca un certificado de prueba
- Actualiza la CRL
- Verifica la revocación

**Salida orientativa:**
```
Carga del entorno y elección del certificado más reciente o del objetivo indicado
Confirmación interactiva antes de revocar
Revocación del certificado, descarga de `crl.pem` y comprobación de si el número de serie aparece en la CRL
Resumen con comandos para inspeccionar la CRL
```

**Verificación:**
```bash
vault write pki_int/revoke serial_number="xx:xx:xx:xx"
vault read pki_int/cert/crl
```

---

## Validación

Para verificar que el lab está completo, ejecute el script de validación:

```bash
./verify.sh
```

**Resultado orientativo:**
```
Comprobaciones PASS/FAIL para el proceso Vault, acceso al API, motores PKI, CA raíz, CA intermedia, rol PKI y certificados emitidos
Resumen con el número de pruebas aprobadas y fallidas
Si todo está correcto, mensaje de finalización del lab
Si algo falla, bloque de troubleshooting con comandos para revisar `vault status`, `vault-env.sh` y los scripts previos
```

---

## Resultado esperado

Después de completar este lab, debería tener:
- ✅ Vault instalado y ejecutándose en modo dev
- ✅ Motor de secretos PKI configurado
- ✅ Jerarquía de CA raíz e intermedia
- ✅ Rol PKI configurado para emisión de certificados
- ✅ Certificados emitidos dinámicamente
- ✅ Comprensión de la revocación de certificados

Puede verificar esto mediante:
- Ejecutar `vault status` (debe mostrar unsealed)
- Ejecutar `vault secrets list` (debe mostrar pki/ y pki_int/)
- Listar certificados emitidos en el directorio `certs/`

---

## Resolución de problemas

### Problema 1: Vault no inicia

**Síntoma:**
```
Error: Failed to start Vault server
```

**Causa:**
- Puerto 8200 ya en uso
- Vault ya en ejecución

**Solución:**
```bash
# Verificar si Vault está en ejecución
ps aux | grep vault

# Terminar procesos Vault existentes
pkill vault

# Verificar disponibilidad del puerto
ss -tulpn | grep 8200

# Reiniciar Vault
./start-vault-dev.sh
```

---

### Problema 2: Conexión rechazada

**Síntoma:**
```
Error: Get "http://127.0.0.1:8200/v1/sys/health": dial tcp 127.0.0.1:8200: connect: connection refused
```

**Causa:**
- Vault no en ejecución
- VAULT_ADDR no establecido

**Solución:**
```bash
# Verificar estado de Vault
vault status

# Asegurar que las variables de entorno estén establecidas
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

# O cargar el archivo de entorno
source vault-env.sh
```

---

### Problema 3: Permiso denegado

**Síntoma:**
```
Error: permission denied
```

**Causa:**
- Token inválido o vencido
- Token incorrecto usado

**Solución:**
```bash
# Usar el root token de start-vault-dev.sh
export VAULT_TOKEN='root'

# O iniciar sesión nuevamente
vault login root
```

---

### Problema 4: Motor PKI no encontrado

**Síntoma:**
```
Error: namespace not found
```

**Causa:**
- Motor PKI no habilitado
- Ruta incorrecta

**Solución:**
```bash
# Listar motores de secretos habilitados
vault secrets list

# Re-habilitar PKI si es necesario
./enable-pki.sh
```

---

## Notas específicas por versión

### RHEL 8
- Todas las funciones soportadas
- Usar dnf para instalar dependencias
- SELinux puede afectar archivos locales de Vault

### RHEL 9
- Todas las funciones soportadas
- Compatible con OpenSSL 3.x
- Compatibilidad completa con Vault

### RHEL 10
- Última versión de Vault soportada
- Todas las funciones modernas disponibles
- Rendimiento óptimo

---

## Limpieza

Para restablecer su sistema y detener Vault:

```bash
./cleanup.sh
```

**Advertencia:** Esto:
- Detendrá el servidor Vault
- Eliminará todos los datos PKI (solo modo dev)
- Eliminará certificados generados
- Limpiará archivos temporales

**Limpieza manual:**
```bash
# Detener Vault
pkill vault

# Eliminar certificados
rm -rf certs/

# Eliminar archivo de entorno
rm -f vault-env.sh
```

---

## Temas avanzados

### Despliegue en producción

**Diferencias clave:**
- Usar backend de almacenamiento (Consul, etcd, etc.)
- Habilitar TLS para API de Vault
- Usar proceso de inicialización y unseal
- Implementar clúster HA
- Usar métodos de autenticación (no root token)
- Habilitar registro de auditoría

**Ejemplo de inicio en producción:**
```bash
vault server -config=/etc/vault/config.hcl
```

### Certificados de corta duración

**Beneficios:**
- Reduce necesidad de revocación
- Limita ventana de exposición
- Simplifica gestión de certificados

**Ejemplo TTL de 1 hora:**
```bash
vault write pki_int/issue/web-server \
    common_name="temp.example.com" \
    ttl="1h"
```

### Renovación automática con Vault Agent

Vault Agent puede renovar certificados automáticamente:

```hcl
# vault-agent.hcl
auto_auth {
  method "approle" {
    config = {
      role_id_file_path = "roleid"
      secret_id_file_path = "secretid"
    }
  }
}

template {
  source      = "cert.tpl"
  destination = "/etc/tls/server.pem"
  command     = "systemctl reload nginx"
}
```

### Uso de API

**Emitir certificado vía API:**
```bash
curl -X POST \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -d '{"common_name":"api.example.com","ttl":"24h"}' \
  http://127.0.0.1:8200/v1/pki_int/issue/web-server
```

**Revocar vía API:**
```bash
curl -X POST \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -d '{"serial_number":"xx:xx:xx:xx"}' \
  http://127.0.0.1:8200/v1/pki_int/revoke
```

---

## Recursos adicionales

**Capítulos relacionados:**
- Apéndice B: HashiCorp Vault (teoría detallada)
- Lab 21: Kubernetes cert-manager (automatización similar)
- Capítulo 22: Dominio de certmonger (automatización nativa de RHEL)

**Documentación:**
- Vault PKI Secrets Engine: https://developer.hashicorp.com/vault/docs/secrets/pki
- Vault API Documentation: https://developer.hashicorp.com/vault/api-docs
- Endurecimiento para producción: https://developer.hashicorp.com/vault/tutorials/operations/production-hardening

**Lectura adicional:**
- Whitepaper de secretos dinámicos
- Arquitectura Zero Trust con Vault
- Automatización del ciclo de vida de certificados

---

## Próximos pasos

Después de completar este lab, puede:
1. **Revisar:** ¡Todos los 22 labs completados! 🎉
2. **Practicar:** Desplegar Vault en un entorno más similar a producción
3. **Integrar:** Conectar Vault con sus aplicaciones
4. **Explorar:** Métodos de autenticación y políticas de Vault
5. **Avanzado:** Configurar clúster HA de Vault

---

## Casos de uso del mundo real

**Microservicios:**
- Cada servicio obtiene certificados de corta duración
- Renovación automática mediante agente de Vault
- Políticas de certificados consistentes

**Pipelines CI/CD:**
- Certificados dinámicos para agentes de build
- Credenciales temporales para despliegues
- Aprovisionamiento automatizado de certificados

**TLS de bases de datos:**
- Certificados dinámicos de base de datos
- Rotación automática
- Gestión centralizada

**Service Mesh:**
- Integración con Consul Connect
- Certificados mTLS automáticos
- Autenticación servicio a servicio

---

## Comparación: Vault vs cert-manager vs certmonger

| Característica | Vault PKI | cert-manager | certmonger |
|---------|-----------|--------------|------------|
| Plataforma | Cualquiera | Kubernetes | RHEL |
| Certificados | Dinámicos | Declarativos | Rastreados |
| TTL predeterminado | Horas-Días | Días-Meses | Meses |
| Integración CA | Integrada | Externa | Externa |
| API | REST | Kubernetes | D-Bus |
| Mejor para | Microservicios | Cargas K8s | Servicios RHEL |

---

**Versiones de RHEL probadas:** 8, 9, 10
**Nivel de dificultad:** Avanzado
**¡Felicitaciones por completar los 22 labs!** 🎉
