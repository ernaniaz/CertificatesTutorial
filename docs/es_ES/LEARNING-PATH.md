# Guía de Camino de Aprendizaje

**Cómo usar este tutorial efectivamente basado en tu rol y nivel de experiencia.**

---

## 🎯 Para Principiantes Completos

**Objetivo:** Aprender certificados desde cero

**Camino:** Leer en orden (8 semanas)

**Semana 1: Fundamentos (Cap 1-7)**
- Cap 1: Criptografía, Estructura PKI y Fundamentos
- Cap 2: Introducción a los Certificados en RHEL
- Cap 3: Resumen de Herramientas de Certificados en RHEL
- Cap 4: Criptografía Básica para Administradores RHEL
- Cap 5: Certificados X.509 en RHEL
- Cap 6: Inmersión Profunda en el Almacén de Confianza RHEL
- Cap 7: Firmas Digitales y Verificación en RHEL
- **Resultado:** Entender certificados, cadenas de confianza y herramientas RHEL

**Semana 2: Dominio de Versiones (Cap 8-13)**
- Cap 8: Diferencias entre versiones
- Cap 9: RHEL 7
- Cap 10: RHEL 8
- Cap 11: RHEL 9
- Cap 12: RHEL 10
- Cap 13: Compatibilidad
- **Resultado:** Conocer diferencias de versiones

**Semana 3-4: Servicios (Cap 14-21)**
- Configurar Apache, NGINX, Postfix, LDAP, Bases de datos, FreeIPA
- **Resultado:** Puede configurar cualquier servicio

**Semana 5: Automatización (Cap 22-26)**
- certmonger, crypto-policies, Ansible, monitoreo
- **Resultado:** Automatizar ciclo de vida de certificados

**Semana 6: Solución de Problemas (Cap 27-33)**
- Dominar solución de problemas sistemática
- **Resultado:** ¡Puede solucionar cualquier problema de certificado! ⭐

**Semana 7: Migración (Cap 34-37)**
- Procedimientos de actualización RHEL
- **Resultado:** Migrar versiones RHEL de forma segura

**Semana 8: Seguridad (Cap 38-41)**
- FIPS, fortalecimiento, cumplimiento
- **Resultado:** Cumplir requisitos de seguridad

---

## 🔧 Para Administradores de Sistemas

**Objetivo:** Configurar y mantener certificados

**Camino Recomendado:**

1. **Inicio Rápido** (3-5 horas)
   - Cap 1: Criptografía y Fundamentos de PKI
   - Cap 3: Herramientas
   - Cap 27: Metodología de Solución de Problemas de Certificados RHEL

2. **Tu Versión RHEL** (1-2 horas)
   - Cap 9 (RHEL 7), Cap 10 (RHEL 8), Cap 11 (RHEL 9), o Cap 12 (RHEL 10)

3. **Tus Servicios** (3-4 horas)
   - Cap 14-21: Elegir capítulos para servicios que usas

4. **Automatización** (2-3 horas)
   - Cap 22: certmonger
   - Cap 23: Crypto-policies (si RHEL 8+)

5. **Referencia**
   - Mantener Cap 27-33 a mano para solución de problemas

**Tiempo Total:** ~10-15 horas para competencia

---

## 🚨 Para Ingenieros de Soporte

**Objetivo:** Resolver problemas de certificados rápido

**Camino Vía Rápida:**

1. **Comenzar Aquí** (1 hora)
   - Cap 27: Metodología de Solución de Problemas de Certificados RHEL ⭐
   - [Guía de Inicio Rápido de Solución de Problemas](TROUBLESHOOTING-QUICK-START.md)

2. **Problemas Comunes** (2 horas)
   - Cap 28: Errores Comunes
   - Cap 29: Solución de Problemas Específica por Servicio
   - Cap 30: Problemas de certmonger
   - Cap 31: Problemas de Crypto-Policy

3. **Herramientas** (1 hora)
   - Cap 3: Herramientas RHEL
   - Cap 32: Informes SOS

4. **Emergencia** (30 min)
   - Cap 33: Procedimientos de Emergencia

5. **Referencia Según Necesidad**
   - Cap 9-12: Capítulos específicos por versión
   - Cap 14-21: Capítulos de servicio

**Tiempo Total:** 5-8 horas para competencia en solución de problemas

**Luego:** Usar capítulos como referencia durante incidentes

---

## 🏢 Para Arquitectos Empresariales

**Objetivo:** Diseñar infraestructura de certificados

**Camino Estratégico:**

1. **Resumen** (1 hora)
   - Cap 1-2: Fundamentos e introducción

2. **CA Empresarial** (2 horas)
   - Cap 19: FreeIPA

3. **Automatización** (3 horas)
   - Cap 22: certmonger
   - Cap 23: Crypto-policies
   - Cap 25: Automatización Ansible para Certificados

4. **Mejores Prácticas** (2 horas)
   - Cap 21: Mejores Prácticas de Servicio
   - Cap 26: Monitoreo y Alertas en RHEL

5. **Seguridad** (3 horas)
   - Cap 38-41: FIPS, fortalecimiento, cumplimiento

6. **Migración** (2 horas)
   - Cap 34-37: Si se planifican actualizaciones

**Tiempo Total:** ~13 horas para conocimiento de arquitectura

---

## 🔒 Para Equipos de Seguridad/Cumplimiento

**Objetivo:** Asegurar cumplimiento y seguridad

**Camino de Cumplimiento:**

1. **Fundamento** (1 hora)
   - Cap 1: Criptografía y Fundamentos de PKI
   - Cap 2: Introducción a Certificados en RHEL

2. **Enfoque Seguridad** (4 horas)
   - Cap 38: Modo FIPS
   - Cap 39: Certificados Compatibles con FIPS
   - Cap 40: Fortalecimiento de Seguridad
   - Cap 41: Cumplimiento y Auditoría ⭐

3. **Crypto-Policies** (1 hora)
   - Cap 23: Entender controles en todo el sistema

4. **Monitoreo** (1 hora)
   - Cap 26: Monitoreo y Alertas en RHEL

5. **Procedimientos de Auditoría** (1 hora)
   - Cap 32: Informes SOS
   - Cap 41: Secciones de cumplimiento y auditoría

**Tiempo Total:** ~8-10 horas para experiencia en cumplimiento

---

## 🎓 Para Preparación de Capacitación/Certificación

**Objetivo:** Dominio completo

**Camino Completo:** Todos los capítulos en orden

**Inversión de Tiempo:** 40-50 horas

**Resultado:** Conocimiento de nivel experto en gestión de certificados RHEL

---

## 📚 Puntos de Entrada Rápida

### Por Tipo de Problema:

**"El servicio no inicia"**
→ Cap 28 (Errores Comunes), Cap 29 (Solución de Problemas Específica por Servicio)

**"Los clientes no pueden conectar"**
→ Cap 13 (Compatibilidad), Cap 31 (Crypto-Policy)

**"certmonger no renueva"**
→ Cap 30 (Solución de Problemas de certmonger)

**"Planificando actualización RHEL"**
→ Cap 34-37 (Migración)

**"Necesito cumplimiento FIPS"**
→ Cap 38-39 (FIPS)

**"Configurando nuevo servicio"**
→ Cap 14-21 (Capítulos de servicio)

### Por Versión RHEL:

**Usando RHEL 7**
→ Cap 9 (Gestión RHEL 7)

**Usando RHEL 8**
→ Cap 10 (¡Crypto-Policies son clave!)

**Usando RHEL 9**
→ Cap 11 (OpenSSL 3.x, SHA-1 bloqueado)

**Usando RHEL 10**
→ Cap 12 (Últimas características)

**Entorno mixto**
→ Cap 13 (Compatibilidad entre Versiones)

---

## 🗺️ Mapa del Tutorial

```
COMENZAR AQUÍ
    │
    ├─ ¿Nuevo en certificados?
    │   └─ Cap 1 → Cap 2 → Cap 3 → Continuar en orden
    │
    ├─ ¿Necesitas resolver problemas AHORA?
    │   └─ Cap 27 → Cap 28 → Cap 29 → Cap 33
    │
    ├─ ¿Configurando un servicio?
    │   └─ Cap 14-21 (elige tu servicio)
    │
    ├─ ¿Planificando migración?
    │   └─ Cap 34 → Cap 35/36 → Cap 37
    │
    ├─ ¿Necesitas automatización?
    │   └─ Cap 22 (certmonger) → Cap 23 (crypto-policies)
    │
    └─ ¿Cumplimiento requerido?
        └─ Cap 38-41 (FIPS, seguridad, auditoría)
```

---

## ⏱️ Estimaciones de Tiempo

| Camino | Tiempo | Capítulos |
|--------|--------|-----------|
| **Inicio Rápido** | 3-5 horas | 1, 3, 27 |
| **Solución de Problemas** | 5-8 horas | 27-33 |
| **Principiante Completo** | 40-50 horas | Todos en orden |
| **Administrador de sistemas** | 10-15 horas | Capítulos seleccionados |
| **Ingeniero Soporte** | 5-8 horas | Enfoque de solución de problemas |
| **Cumplimiento** | 8-10 horas | Capítulos seguridad |

---

## 💡 Consejos de Estudio

1. **Práctica es esencial** - Practicar en VM RHEL
2. **Seguir ejemplos** - Copiar-pegar y entender
3. **Usar referencias rápidas** - Cuando el capítulo las incluya
4. **Marcar solución de problemas** - Capítulos 27-33
5. **Conocer tu versión RHEL** - Enfocarse en capítulos relevantes
6. **Construir un lab** - Usar FreeIPA para práctica

---

**Comenzar Aprendizaje:** [Capítulo 1: Criptografía, Estructura PKI y Fundamentos →](part-01-fundamentals/01-cryptography-pki-basics.md)

**¿Necesitas ayuda rápida?** [Guía de Inicio Rápido de Solución de Problemas →](TROUBLESHOOTING-QUICK-START.md)

**Referencia de Versión:** [Guía de Referencia Rápida de Versiones RHEL para Certificados →](RHEL-VERSION-CHEAT-SHEET.md)
