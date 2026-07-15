# Tutorial de PKI y Certificados Digitales

**Una guía completa para dominar los certificados en Red Hat Enterprise Linux.**

---

## 📘 Acerca de Este Tutorial

Este tutorial te enseña todo sobre certificados digitales en RHEL, desde principiante completo hasta experto en solución de problemas.

**Objetivo Principal:** Permitirte resolver con confianza problemas de certificados en sistemas RHEL.

**Cobertura:**
- Todas las versiones de RHEL (7, 8, 9, 10)
- Todos los servicios principales (Apache, NGINX, Postfix, LDAP, Bases de datos, FreeIPA)
- Automatización completa (certmonger, crypto-policies, Ansible)
- Solución de problemas experta
- Guía de migración
- FIPS y cumplimiento normativo

---

## 🎯 Para Quién es Este Tutorial

- **Administradores RHEL** - Gestiona certificados profesionalmente
- **Ingenieros de Soporte** - Resuelve problemas de certificados
- **Equipos de Seguridad** - Implementa FIPS y cumplimiento
- **Ingenieros DevOps** - Automatiza el ciclo de vida de certificados
- **Cualquiera** - Que gestione sistemas RHEL con TLS/SSL

**Prerrequisitos:**
- Conocimientos básicos de línea de comandos Linux
- Acceso a sistemas RHEL (una VM está bien)
- ¡No se necesita conocimiento previo de certificados!

---

## 📚 Estructura del Tutorial

### PARTE 01: Fundamentos (Capítulos 1-7)
Introducción a los certificados en el contexto de RHEL.

### PARTE 02: Gestión Específica por Versión (Capítulos 8-13) ⭐
Inmersión Profunda en las diferencias de RHEL 7, 8, 9, 10.

### PARTE 03: Servicios y Configuración TLS (Capítulos 14-21) ⭐
Configura certificados para todos los servicios principales de RHEL.

### PARTE 04: Automatización de Certificados (Capítulos 22-26) ⭐
Automatiza el ciclo de vida de certificados con herramientas RHEL.

### PARTE 05: Solución de Problemas (Capítulos 27-33) ⭐⭐⭐
**¡El núcleo de este tutorial!** Metodología completa de solución de problemas.

### PARTE 06: Migración y Actualizaciones (Capítulos 34-37)
Migra certificados de forma segura entre versiones de RHEL.

### PARTE 07: Seguridad y FIPS (Capítulos 38-41)
FIPS, fortalecimiento y auditoría de cumplimiento.

### APÉNDICES (A-I)
Kubernetes, Vault, Zero Trust, DevSecOps, IoT, VPN, Glosario, Referencias.

---

## ⚡ Inicio Rápido

📖 **Consulta la [Guía de Camino de Aprendizaje](LEARNING-PATH.md) para instrucciones detalladas y rutas de aprendizaje.**

### Opción 1: Comienza con los Fundamentos
**Para principiantes completos:**
- Comienza en [Capítulo 1: Criptografía, Estructura PKI y Fundamentos](part-01-fundamentals/01-cryptography-pki-basics.md), luego continúa con el Capítulo 2 y siguientes en orden
- Sigue el [Camino de Aprendizaje](LEARNING-PATH.md)

### Opción 2: Comienza con Solución de Problemas
**Para administradores experimentados:**
- Salta a [Capítulo 27: Metodología de Solución de Problemas de Certificados RHEL](part-05-troubleshooting/27-troubleshooting-methodology.md)
- Usa la [Guía de Inicio Rápido de Solución de Problemas](TROUBLESHOOTING-QUICK-START.md)

### Opción 3: Referencia Rápida
**Para búsquedas rápidas:**
- [Guía de Referencia Rápida de Versiones RHEL para Certificados](RHEL-VERSION-CHEAT-SHEET.md)
- Tabla de Contenidos completa en SUMMARY.md

---

## 🔑 Características Clave

### ✅ Enfoque RHEL-First
Todo el contenido está escrito específicamente para RHEL. Sin información genérica - solo comandos específicos de RHEL, herramientas y mejores prácticas.

### ✅ Comparación de Versiones
Cada capítulo compara comportamientos entre RHEL 7, 8, 9 y 10. Siempre sabrás qué versión estás usando.

### ✅ Ejemplos Prácticos
151 scripts listos para producción que puedes copiar y pegar. Todos probados en RHEL real.

### ✅ Enfoque en Solución de Problemas
7 capítulos completos dedicados a la resolución sistemática de problemas. Aprende a diagnosticar CUALQUIER problema de certificado.

### ✅ Guía de Migración
Procedimientos paso a paso para migrar certificados entre versiones de RHEL (7→8, 8→9).

### ✅ Cumplimiento FIPS
Guías completas para modo FIPS, fortalecimiento y auditoría de cumplimiento.

---

## 📖 Cómo Usar Este Tutorial

### Estudiantes Principiantes
1. Lee los capítulos en orden (1-41)
2. Practica cada comando en tu sistema RHEL
3. Completa los escenarios y laboratorios donde estén disponibles
4. Consulta el glosario cuando encuentres términos nuevos

**Tiempo estimado:** 40-50 horas

### Administradores Experimentados
1. Revisa la [Guía de Referencia Rápida de Versiones RHEL para Certificados](RHEL-VERSION-CHEAT-SHEET.md)
2. Lee solo los capítulos específicos de tu versión
3. Enfócate en los capítulos de solución de problemas (27-33)
4. Usa el tutorial como referencia

**Tiempo estimado:** 15-20 horas

### Ingenieros de Soporte
1. Comienza con la [Guía de Inicio Rápido de Solución de Problemas](TROUBLESHOOTING-QUICK-START.md)
2. Lee la Parte 05 completa (solución de problemas)
3. Marca los capítulos de servicio relevantes
4. Mantén abierto para referencia durante incidentes

**Tiempo estimado:** 10-15 horas

---

## 🎓 Caminos de Aprendizaje

Ver [LEARNING-PATH.md](LEARNING-PATH.md) para caminos de aprendizaje detallados por rol:
- Principiante Completo
- Administrador de Sistemas RHEL
- Ingeniero de Soporte
- Ingeniero DevOps
- Arquitecto de Seguridad

---

## 💡 Mejores Prácticas Destacadas

Este tutorial enfatiza:

### ✅ Usar Herramientas Nativas de RHEL
- **certmonger** para renovación automática
- **update-ca-trust** para gestión de almacén de confianza
- **crypto-policies** para configuración en todo el sistema

### ✅ Automatización Primero
Automatiza todo con certmonger, Ansible o scripts. Los certificados manuales son un riesgo.

### ✅ Monitoreo de Expiración
Configura alertas 30 días antes de la expiración. Nunca dejes que expiren certificados.

### ✅ Procedimientos de Migración
Siempre prueba las migraciones de certificados antes de actualizar RHEL.

### ✅ Documentación FIPS
Documenta todas las decisiones de configuración FIPS para auditorías.

---

## 🔧 Herramientas RHEL Cubiertas

### Herramientas de Gestión de Certificados
- **certmonger** - Renovación automática de certificados
- **openssl** - Operaciones de certificados
- **update-ca-trust** - Gestión de almacén de confianza
- **crypto-policies** - Política de cifrado en todo el sistema

### Herramientas de Solución de Problemas
- **sosreport** - Recolección de datos del sistema
- **openssl verify** - Validación de certificados
- **openssl s_client** - Prueba de conexión TLS
- **getcert list** - Estado de certmonger

### Herramientas de Automatización
- **Ansible** - Automatización de configuración
- **certbot** - Let's Encrypt (de EPEL)
- **FreeIPA** - CA empresarial

---

## 📊 Estadísticas del Tutorial

- **41 Capítulos** en 7 partes principales
- **9 Apéndices** de referencia
- **151 Scripts** listos para producción
- **90+ Tablas** de comparación
- **32 Tarjetas** de referencia rápida
- **50+ Procedimientos** de solución de problemas
- **~27,000 Líneas** de contenido

---

## 🆘 Obtener Ayuda

### Durante el Aprendizaje
- Consulta el **Glosario** (Apéndice H) para definiciones de términos
- Revisa las **Referencias** (Apéndice I) para recursos externos
- Consulta la **Guía de Solución de Problemas** (Capítulos 27-33)

### Para Problemas Específicos de RHEL
- Red Hat Customer Portal: https://access.redhat.com
- Documentación RHEL: https://access.redhat.com/documentation
- Red Hat KB: Busca códigos de error específicos

### Para Conceptos PKI Generales
- OpenSSL Documentation: https://www.openssl.org/docs/
- RFC 5280 (X.509): https://www.rfc-editor.org/rfc/rfc5280
- Let's Encrypt Docs: https://letsencrypt.org/docs/

---

## ✅ Lo Que Aprenderás

Al completar este tutorial, podrás:

### Fundamentos
- ✅ Explicar cómo funcionan los certificados digitales
- ✅ Entender PKI, CAs y cadenas de confianza
- ✅ Trabajar con herramientas OpenSSL
- ✅ Gestionar el almacén de confianza de RHEL

### Específico por Versión
- ✅ Identificar diferencias entre RHEL 7/8/9/10
- ✅ Usar crypto-policies en RHEL 8+
- ✅ Gestionar certificados en cada versión
- ✅ Manejar problemas de compatibilidad

### Configuración de Servicios
- ✅ Configurar TLS para Apache y NGINX
- ✅ Asegurar Postfix con TLS
- ✅ Configurar LDAPS en OpenLDAP
- ✅ Habilitar TLS para bases de datos
- ✅ Integrar con FreeIPA
- ✅ Asegurar otros servicios RHEL

### Automatización
- ✅ Configurar certmonger para renovación automática
- ✅ Personalizar crypto-policies
- ✅ Integrar Let's Encrypt con certbot
- ✅ Automatizar con Ansible
- ✅ Configurar monitoreo y alertas

### Solución de Problemas ⭐⭐⭐
- ✅ Diagnosticar CUALQUIER problema de certificado
- ✅ Resolver errores comunes de certificados
- ✅ Solucionar problemas específicos de servicio
- ✅ Depurar problemas de certmonger
- ✅ Resolver conflictos de crypto-policy
- ✅ Analizar informes SOS
- ✅ Ejecutar procedimientos de emergencia

### Migración
- ✅ Planificar migraciones de certificados
- ✅ Migrar RHEL 7→8
- ✅ Migrar RHEL 8→9
- ✅ Solucionar problemas de migración
- ✅ Validar después de la migración

### Seguridad
- ✅ Habilitar y usar modo FIPS
- ✅ Generar certificados compatibles con FIPS
- ✅ Fortalecer configuraciones de TLS
- ✅ Auditar cumplimiento
- ✅ Implementar mejores prácticas de seguridad

---

## 🌟 ¡Comienza a Aprender!

**Comienza aquí:** [Capítulo 1: Criptografía, Estructura PKI y Fundamentos →](part-01-fundamentals/01-cryptography-pki-basics.md)

**O salta a:** [Guía de Inicio Rápido de Solución de Problemas](TROUBLESHOOTING-QUICK-START.md)

---

*Autor: Ernani Azevedo <azevedo@voipdomain.io>*
*Repositorio: [github.com/ernaniaz/CertificatesTutorial](https://github.com/ernaniaz/CertificatesTutorial)*
*Licencia: [CC BY 4.0](../../LICENSE.md)*
