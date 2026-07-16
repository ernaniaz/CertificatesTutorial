# Lab 21: Kubernetes cert-manager

## Objetivos de aprendizaje

Al completar este lab, usted:
- Comprenderá la arquitectura y componentes de cert-manager
- Instalará y configurará minikube para pruebas locales de Kubernetes
- Desplegará cert-manager en un clúster de Kubernetes
- Creará múltiples tipos de issuer (self-signed, CA, ACME)
- Solicitará y gestionará certificados usando cert-manager
- Configurará TLS para Kubernetes Ingress
- Comprenderá la renovación automática de certificados

## Requisitos previos

- **Dependencias del lab:** Labs 01-05 completados (fundamentos de certificados)
- **Versión de RHEL:** RHEL 8, 9 o 10
- **Acceso al sistema:** Se requieren privilegios root o sudo
- **Requisitos adicionales:**
  - Mínimo 2 núcleos de CPU (para minikube)
  - 2 GB de RAM disponibles
  - 20 GB de espacio en disco
  - Conectividad a Internet para descargas
  - Docker o podman instalado (para el driver de minikube)

## Tiempo estimado

**40-50 minutos** (incluye configuración de minikube y despliegue de cert-manager)

## Descripción general

cert-manager es un proyecto de la Cloud Native Computing Foundation (CNCF) que automatiza la gestión de certificados en clústeres de Kubernetes. Actúa como un controlador de certificados, solicitando certificados de varias fuentes y garantizando que sean válidos y estén actualizados.

---

## Arquitectura de cert-manager

### Componentes principales

**Issuer / ClusterIssuer:**
- Define la autoridad de certificación (CA) o el servidor ACME
- Issuer: alcance de namespace
- ClusterIssuer: alcance de todo el clúster

**Certificate:**
- Recurso personalizado de Kubernetes que define el certificado deseado
- Especifica nombres DNS, duración, configuración de renovación
- Resulta en un Secret de Kubernetes que contiene el certificado

**Controller:**
- Observa recursos Certificate
- Solicita certificados de los Issuers configurados
- Almacena certificados en Secrets de Kubernetes
- Maneja la renovación automática

---

## Instrucciones

### Paso 1: Instalar Minikube

Instale e inicie minikube para pruebas locales de Kubernetes:

```bash
./install-minikube.sh
```

**Qué hace esto:**
- Descarga e instala el binario de minikube
- Instala kubectl si no está presente
- Inicia un clúster local de Kubernetes
- Configura el contexto de kubectl

**Salida orientativa:**
```
Encabezado del paso actual
Mensajes sobre detección o instalación de docker/podman, kubectl y minikube
Inicio o reutilización del clúster minikube
Verificación final con `kubectl cluster-info` y `kubectl get nodes`
Resumen con el estado real del clúster y los siguientes pasos
```

**Verificación:**
```bash
kubectl cluster-info
kubectl get nodes
```

---

### Paso 2: Instalar cert-manager

Despliegue cert-manager en el clúster de Kubernetes:

```bash
./install-cert-manager.sh
```

**Qué hace esto:**
- Aplica CRDs (Custom Resource Definitions) de cert-manager
- Despliega componentes de cert-manager
- Espera a que los pods estén listos
- Verifica la instalación

**Salida orientativa:**
```
Encabezado del paso actual
Comprobación de requisitos y aplicación de los manifests de cert-manager
Espera de pods y CRDs con mensajes de progreso
Resumen final indicando que cert-manager quedó instalado y qué script ejecutar después
```

**Verificación:**
```bash
kubectl get pods -n cert-manager
```

---

### Paso 3: Crear Issuer autofirmado

Cree un issuer de certificados autofirmados:

```bash
./create-selfsigned-issuer.sh
```

**Qué hace esto:**
- Crea un ClusterIssuer para certificados autofirmados
- Útil para pruebas y desarrollo
- Certificados firmados por su propia clave privada

**Salida orientativa:**
```
Comprobación de requisitos
Creación de `selfsigned-issuer`
Espera breve hasta que el issuer quede Ready, o advertencia si el estado aún no es claro
Resumen con `kubectl get clusterissuer` y `kubectl describe clusterissuer selfsigned-issuer`
```

---

### Paso 4: Crear Issuer CA

Cree un issuer basado en CA usando una CA personalizada:

```bash
./create-ca-issuer.sh
```

**Qué hace esto:**
- Genera un certificado y clave de CA personalizada
- Almacena la CA en un Secret de Kubernetes
- Crea un ClusterIssuer que usa la CA
- Permite emitir certificados firmados por su CA

**Salida orientativa:**
```
Generación de una CA local en `ca-output/`
Creación del secret `ca-key-pair` en el namespace `cert-manager`
Creación de `ca-issuer`
Espera hasta que el issuer quede Ready o muestre una advertencia de inicialización
```

---

### Paso 5: Crear Issuer de Let's Encrypt

Cree un issuer ACME para certificados de Let's Encrypt:

```bash
./create-letsencrypt-issuer.sh
```

**Notas importantes:**
- ⚠️ Usa el entorno **staging** de Let's Encrypt (seguro para pruebas)
- ⚠️ Requiere un nombre de dominio válido para uso en producción
- ⚠️ Requiere acceso externo para el desafío HTTP-01
- 💡 En este lab, cree el issuer para que `./verify.sh` pueda confirmar que el ClusterIssuer `letsencrypt-staging` existe y está Ready, pero no emitirá certificados ACME reales

**Salida orientativa:**
```
Creación de `letsencrypt-staging`
Advertencias indicando que se usa el entorno staging y que no sirve para confianza de navegador
Generación de una plantilla separada para producción
Posible espera breve mientras cert-manager registra la cuenta ACME
```

---

### Paso 6: Solicitar certificados

> **Obligatorio:** Los pasos 3 y 4 deben completarse primero. Este script
> requiere que existan tanto el emisor autofirmado como el emisor CA, y saldrá
> con error si falta alguno.

Solicite certificados usando distintos issuers:

```bash
./request-certificate.sh
```

**Qué hace esto:**
- Verifica que ambos issuers existan (sale si no)
- Crea recursos Certificate
- Solicita certificado autofirmado
- Solicita certificado firmado por CA
- Espera a que se emitan los certificados
- Verifica que los certificados estén almacenados en Secrets

**Salida orientativa:**
```
Solicitud de `selfsigned-cert` y `ca-signed-cert`
Mensajes de espera mientras cert-manager emite los certificados
Confirmación de readiness para cada certificado o advertencia si alguno tarda demasiado
Resumen con los Secrets TLS creados y comandos sugeridos para inspección
```

**Verificación:**
```bash
kubectl get certificates
kubectl get secrets | grep tls
kubectl describe certificate selfsigned-cert
```

---

### Paso 7: Probar Ingress TLS

Despliegue una aplicación de prueba con Ingress TLS:

```bash
./test-ingress-tls.sh
```

**Qué hace esto:**
- Despliega una aplicación nginx simple
- Crea un Service
- Crea un Ingress con anotación TLS
- cert-manager crea el certificado automáticamente
- Configura Ingress para usar el certificado

**Salida orientativa:**
```
Habilitación o reutilización del addon/controller de Ingress
Despliegue de la aplicación de prueba, Service e Ingress
Espera mientras cert-manager crea el certificado de `test-app.local`
Resumen con recursos desplegados, estado del Secret TLS e instrucciones de acceso (`/etc/hosts`, `curl -k`, `minikube tunnel`)
```

**Verificación:**
```bash
kubectl get ingress
kubectl describe ingress test-app-ingress
kubectl get certificate test-app-tls
```

---

## Validación

Para verificar que el lab está completo, ejecute el script de validación:

```bash
./verify.sh
```

**Resultado orientativo:**
```
Serie de comprobaciones PASS/FAIL para minikube, kubectl, cert-manager, issuers, certificados, Secret TLS e Ingress
Resumen final con contadores de pruebas aprobadas y fallidas
Si todo está correcto, mensaje de finalización del lab
Si algo falla, bloque de troubleshooting con comandos para revisar pods, logs y certificados
```

---

## Resultado esperado

Después de completar este lab, debería tener:
- ✅ Clúster de Kubernetes minikube funcionando
- ✅ cert-manager desplegado y operativo
- ✅ Múltiples issuers de certificados configurados
- ✅ Certificados emitidos y almacenados en Secrets
- ✅ Aplicación de prueba con Ingress habilitado para TLS
- ✅ Comprensión de la gestión automática de certificados

Puede verificar esto mediante:
- Ejecutar `kubectl get clusterissuers` (debe mostrar 3 issuers)
- Ejecutar `kubectl get certificates` (debe mostrar múltiples certificados)
- Ejecutar `kubectl get secrets | grep tls` (debe mostrar secrets de certificados)

---

## Resolución de problemas

### Problema 1: Minikube no inicia

**Síntoma:**
```
Error: Failed to start minikube
```

**Causa:**
- Docker/podman no instalado o no en ejecución
- Recursos del sistema insuficientes
- Virtualización VT-x/AMD-v no habilitada

**Solución:**
```bash
# Verificar que docker esté en ejecución
sudo systemctl status docker

# Verificar recursos del sistema
free -h
df -h

# Probar con driver podman
minikube start --driver=podman

# O especificar recursos
minikube start --cpus=2 --memory=2048
```

---

### Problema 2: Pods de cert-manager no listos

**Síntoma:**
```
cert-manager pods in CrashLoopBackOff or Pending state
```

**Causa:**
- Recursos del clúster insuficientes
- CRDs no instalados correctamente
- Problemas de red

**Solución:**
```bash
# Verificar estado de pods
kubectl get pods -n cert-manager
kubectl describe pod -n cert-manager <pod-name>

# Revisar registros
kubectl logs -n cert-manager deployment/cert-manager

# Reinstalar cert-manager
kubectl delete namespace cert-manager
./install-cert-manager.sh
```

---

### Problema 3: Certificado no listo

**Síntoma:**
```
Certificate status: Issuing (stuck)
```

**Causa:**
- Issuer no configurado correctamente
- Desafío ACME fallando
- Problemas de DNS

**Solución:**
```bash
# Verificar detalles del certificado
kubectl describe certificate <cert-name>

# Revisar registros de cert-manager
kubectl logs -n cert-manager deployment/cert-manager

# Verificar estado del issuer
kubectl describe clusterissuer <issuer-name>

# Para problemas con issuers autofirmados, recrear issuer
kubectl delete clusterissuer selfsigned-issuer
./create-selfsigned-issuer.sh
```

---

### Problema 4: Comando kubectl no encontrado

**Síntoma:**
```
bash: kubectl: command not found
```

**Causa:**
- kubectl no instalado
- No está en PATH

**Solución:**
```bash
# Instalar kubectl manualmente
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# O ejecutar install-minikube.sh nuevamente
./install-minikube.sh
```

---

## Notas específicas por versión

### RHEL 8
- Docker/podman disponible en repos estándar
- Puede necesitar habilitar módulo container-tools
- `sudo dnf module enable container-tools`

### RHEL 9
- Podman recomendado sobre Docker
- Herramientas de contenedores integradas
- Puede necesitar configurar cgroup v2 para minikube

### RHEL 10
- Última versión de podman
- Soporte completo de runtime de contenedores
- No se requiere configuración especial

---

## Limpieza

Para restablecer su sistema y eliminar todos los recursos de Kubernetes:

```bash
./cleanup.sh
```

**Advertencia:** Esto:
- Eliminará todos los recursos de cert-manager
- Detendrá y eliminará el clúster minikube
- Eliminará binarios de minikube y kubectl (opcional)

**Limpieza parcial:**
```bash
# Solo eliminar cert-manager
kubectl delete namespace cert-manager

# Solo detener minikube (conservar para después)
minikube stop

# Eliminar minikube completamente
minikube delete
```

---

## Temas avanzados

### Renovación de certificados

cert-manager renueva certificados automáticamente:
- Predeterminado: renueva a los 2/3 de la vida útil del certificado
- Configurable mediante `renewBefore` en la especificación Certificate
- Monitorear renovación: `kubectl describe certificate <name>`

### Múltiples namespaces

- Use `Issuer` para issuers con alcance de namespace
- Use `ClusterIssuer` para issuers de todo el clúster
- Los certificados pueden referenciar cualquiera de los dos tipos

### Consideraciones de producción

**Let's Encrypt en producción:**
- Cambiar al endpoint ACME de producción
- Implementar conciencia de límites de tasa
- Usar desafío DNS-01 para wildcards
- Monitorear vencimiento de certificados

**Alta disponibilidad:**
- Ejecutar múltiples réplicas de cert-manager
- Usar almacenamiento distribuido para cuentas ACME
- Implementar monitoreo y alertas

---

## Recursos adicionales

**Capítulos relacionados:**
- Apéndice A: Kubernetes cert-manager (teoría detallada)
- Capítulo 24: Let's Encrypt con Certbot (protocolo ACME)
- Capítulo 25: Automatización Ansible para Certificados (conceptos de automatización)

**Documentación:**
- Documentación de cert-manager: https://cert-manager.io/docs/
- Documentación de Kubernetes: https://kubernetes.io/docs/
- Documentación de minikube: https://minikube.sigs.k8s.io/docs/

**Lectura adicional:**
- Protocolo ACME RFC 8555
- TLS de Kubernetes Ingress
- Gestión del ciclo de vida de certificados

---

## Próximos pasos

Después de completar este lab, puede:
1. **Continuar con Lab 22:** HashiCorp Vault PKI - Gestión dinámica de certificados
2. **Revisar:** Apéndice A para arquitectura más profunda de cert-manager
3. **Practicar:** Desplegar sus propias aplicaciones con TLS
4. **Explorar:** Desafíos DNS-01 para certificados wildcard
5. **Integrar:** Conectar cert-manager con CAs externas

---

## Casos de uso del mundo real

**Entornos de desarrollo:**
- Pruebas TLS locales con certificados autofirmados
- Entornos staging con Let's Encrypt staging
- Desarrollo en equipo con CA compartida

**Entornos de producción:**
- Certificados automáticos de Let's Encrypt para servicios públicos
- Integración con PKI empresarial mediante ACME
- Gestión de certificados multi-tenant
- Automatización TLS para microservicios

---

**Versiones de RHEL probadas**: 8, 9, 10  
**Nivel de dificultad**: Intermedio/Avanzado
