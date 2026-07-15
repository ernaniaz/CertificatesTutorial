# Lab 14: Automatización de certificados con Ansible

## Objetivos de aprendizaje

Al completar este lab, usted:
- Instalará y configurará Ansible
- Creará un inventario para gestión de certificados
- Escribirá playbooks para despliegue de certificados
- Automatizará la configuración de certificados en Apache/NGINX
- Desplegará certificados en múltiples hosts
- Implementará gestión idempotente de certificados

## Requisitos previos

- **Labs 01-06** completados (comprensión de certificados)
- **Versión de RHEL:** 8, 9 o 10
- **Acceso al sistema:** Se requiere root/sudo
- **Múltiples hosts** (o localhost para pruebas)

## Tiempo estimado

**50-60 minutos**

## Descripción general

Ansible permite automatizar infraestructura a escala. Aprenda a gestionar certificados en múltiples servidores usando el `playbook-apache.yml` incluido, garantizando despliegues consistentes y repetibles sin intervención manual.

---

## Instrucciones

### Paso 1: Instalar Ansible

Instale el nodo de control de Ansible:

```bash
sudo ./install-ansible.sh
```

Esto instala:
- Paquete `ansible`
- `ansible-core` (RHEL 9+)
- Archivos de configuración

---

### Paso 2: Crear inventario

Configure el inventario de Ansible:

```bash
./create-inventory.sh
```

Esto crea:
- Archivo de inventario
- Grupos de hosts
- Configuración de conexión

---

### Paso 3: Ejecutar playbook de Apache

Despliegue certificados con el playbook de Ansible incluido:

```bash
./run-apache-playbook.sh
```

Esto:
- Genera/copia certificados
- Configura SSL en Apache
- Reinicia servicios
- Valida la configuración

---

### Paso 4: Probar idempotencia

Pruebe el comportamiento idempotente:

```bash
./test-idempotency.sh
```

Esto verifica:
- Ejecuciones repetidas no realizan cambios
- Estabilidad de la configuración
- Mejores prácticas de Ansible

---

### Paso 5: Verificar despliegue

Ejecute una validación integral:

```bash
./verify.sh
```

---

## Validación

```bash
./test.sh
```

Todas las comprobaciones deben pasar.

## Resultado esperado

Después de completar este lab:
- ✅ Ansible instalado y configurado
- ✅ Playbook de certificados desplegado (`playbook-apache.yml`)
- ✅ Capacidad de despliegue multi-host
- ✅ Automatización idempotente

---

## Conceptos clave

### Arquitectura de Ansible

```
Nodo de control (Ansible)
    ↓
Inventario (hosts)
    ↓
Playbooks (qué hacer)
    ↓
Nodos gestionados (objetivos)
```

### Ejemplo de inventario

```ini
[webservers]
web1.example.com
web2.example.com

[databases]
db1.example.com

[all:vars]
ansible_user=admin
ansible_become=yes
```

### Estructura del playbook

```yaml
---
- name: Desplegar certificados SSL
  hosts: webservers
  become: yes

  tasks:
    - name: Copiar certificado
      copy:
        src: files/server.crt
        dest: /etc/pki/tls/certs/server.crt
        mode: '0644'

    - name: Copiar clave privada
      copy:
        src: files/server.key
        dest: /etc/pki/tls/private/server.key
        mode: '0600'
        owner: root
        group: root

    - name: Configurar SSL de Apache
      template:
        src: templates/ssl.conf.j2
        dest: /etc/httpd/conf.d/ssl.conf
      notify: Reiniciar Apache

  handlers:
    - name: Reiniciar Apache
      service:
        name: httpd
        state: restarted
```

### Playbook incluido (`playbook-apache.yml`)

Este lab incluye un playbook que:
- Genera un certificado autofirmado para el lab
- Configura SSL de Apache (`ansible-ssl.conf`)
- Reinicia `httpd` mediante handlers
- Valida el certificado desplegado

Ejecútelo con:

```bash
./run-apache-playbook.sh
```

O manualmente:

```bash
ansible-playbook -i inventory.ini playbook-apache.yml
```

### Módulos clave de Ansible

**Operaciones con archivos:**
```yaml
- copy:              # Copiar archivos
- template:          # Plantillas Jinja2
- file:              # Gestionar archivos/directorios
- fetch:             # Descargar desde remoto
```

**Gestión de servicios:**
```yaml
- service:           # Gestionar servicios
- systemd:           # Específico de systemd
```

**Ejecución de comandos:**
```yaml
- command:           # Ejecutar comandos
- shell:             # Ejecutar comandos shell
- script:            # Ejecutar scripts
```

**Gestión de paquetes:**
```yaml
- yum:               # RHEL 7
- dnf:               # RHEL 8+
- package:           # Genérico
```

### Idempotencia

Las operaciones de Ansible deben ser idempotentes: ejecutarlas varias veces produce el mismo resultado:

```yaml
# Bueno: Idempotente
- name: Asegurar que Apache esté en ejecución
  service:
    name: httpd
    state: started
    enabled: yes

# Malo: No idempotente
- name: Iniciar Apache
  command: systemctl start httpd
```

---

## Resolución de problemas

### Problema: Conexión rechazada

**Síntoma:**
```
Failed to connect to the host
```

**Solución:**
```yaml
# Verificar conectividad
ansible all -m ping

# Probar con otro usuario
ansible all -m ping -u admin

# Usar autenticación por contraseña
ansible all -m ping --ask-pass
```

---

### Problema: Permiso denegado

**Síntoma:**
```
Permission denied
```

**Solución:**
```yaml
# Usar become (sudo)
ansible-playbook -i inventory.ini playbook-apache.yml --become

# Especificar usuario become
ansible-playbook -i inventory.ini playbook-apache.yml --become-user=root

# En el playbook:
become: yes
become_user: root
```

---

### Problema: Módulo no encontrado

**Síntoma:**
```
The module ... was not found
```

**Solución:**
```bash
# Instalar colecciones de ansible
ansible-galaxy collection install ansible.posix

# Actualizar Ansible
dnf update ansible
```

---

## Notas específicas por versión

### RHEL 8
- Ansible 2.9.x o ansible-core
- Usa el módulo `dnf`
- Python 3 por defecto

### RHEL 9
- ansible-core (minimal)
- Requiere colecciones
- Python 3.9+

---

## Limpieza

```bash
sudo ./cleanup.sh
```

Esto deshace todas las tareas del lab: detiene y elimina Apache (httpd, mod_ssl), elimina certificados desplegados, configuración SSL, página de prueba, configuración de Ansible, archivo de inventario y el paquete Ansible.

---

## Recursos adicionales

**Capítulos relacionados:**
- Capítulo 25: Automatización Ansible para Certificados

**Documentación:**
- `man ansible`
- `man ansible-playbook`
- https://docs.ansible.com/
- https://galaxy.ansible.com/

**Ansible Galaxy:**
```bash
# Buscar roles
ansible-galaxy search certificate

# Instalar rol
ansible-galaxy install geerlingguy.certbot
```

---

## Próximos pasos

¡Felicitaciones! Ha completado todos los labs de automatización (11-14). Ahora tiene un conjunto completo de herramientas para gestión de certificados en RHEL, desde configuración manual hasta automatización completa.

---

**Nivel de dificultad:** Avanzado
