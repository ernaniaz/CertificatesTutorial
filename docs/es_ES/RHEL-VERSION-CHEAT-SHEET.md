# Guía de Referencia Rápida de Versiones RHEL para Certificados

Referencia rápida para diferencias de certificados entre versiones de RHEL.

---

## Resumen de Versiones

| RHEL | Lanzado | OpenSSL | Soporte TLS | Crypto-Policies | Característica Principal |
|------|---------|---------|-------------|-----------------|--------------------------|
| **7** | 2014 | 1.0.2k-26 | 1.0/1.1/1.2 | ❌ No | Configuración manual |
| **8** | 2019 | 1.1.1k-14 | 1.2/1.3 | ✅ **¡NUEVO!** | Políticas en todo el sistema |
| **9** | 2022 | 3.5.5-2 | 1.2/1.3 | ✅ Mejorado | OpenSSL 3.x, estricto |
| **10** | 2025 | 3.5.5-2 | 1.3 pref | ✅ Mejorado | Preparación PQC, moderno |

---

## Detección Rápida

```bash
# Verificar versión RHEL
cat /etc/redhat-release

# Verificar OpenSSL (verificación indirecta de versión)
openssl version
# 1.0.2k = RHEL 7
# 1.1.1k = RHEL 8
# 3.5.5  = RHEL 9 o 10

# Verificar crypto-policies (solo RHEL 8+)
update-crypto-policies --show 2>/dev/null || echo "RHEL 7 (sin crypto-policies)"
```

---

## Configuración TLS por Versión

### RHEL 7
```apache
# Configuración manual requerida en todas partes
SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
SSLCipherSuite HIGH:!aNULL:!MD5:!3DES
```

### RHEL 8/9/10
```apache
# ¡crypto-policies lo manejan automáticamente!
# No se necesitan SSLProtocol o SSLCipherSuite
# Solo incluir rutas de certificado
```

---

## Comandos Comunes por Versión

| Tarea | RHEL 7 | RHEL 8/9/10 |
|-------|--------|-------------|
| **Generar Clave** | `openssl genrsa -out key 2048` | `openssl genpkey -algorithm RSA -out key` |
| **Verificar Política** | N/A | `update-crypto-policies --show` |
| **Config TLS** | Manual por servicio | Automática vía crypto-policies |
| **certmonger** | Básico | Mejorado (RHEL 9: soporte ACME) |

---

## Solución de Problemas por Versión

### RHEL 7
- Verificar problemas TLS 1.0/1.1
- Configuraciones manuales de cifrado
- Sin crypto-policies

### RHEL 8
- ¡Verificar crypto-policy primero!
- TLS 1.0/1.1 deshabilitado en DEFAULT
- Política LEGACY para compatibilidad

### RHEL 9
- Problemas de proveedor OpenSSL 3.x
- SHA-1 BLOQUEADO
- Usar `-provider legacy` para algoritmos antiguos

### RHEL 10
- Igual que RHEL 9
- Valores predeterminados aún más estrictos
- Verificar documentación de versión menor

---

## Impacto de Migración

| Migración | Impacto en Certificados | Cambios Principales |
|-----------|-------------------------|---------------------|
| **7→8** | Moderado-Alto | crypto-policies, TLS 1.0/1.1 bloqueado |
| **8→9** | Alto | OpenSSL 3.x, SHA-1 bloqueado, más estricto |
| **9→10** | Bajo | Mismo OpenSSL, fortalecimiento incremental |

---

## Soluciones Rápidas por Versión

### Error "no shared cipher"
- **RHEL 7:** Actualizar configuración de cifrado manualmente
- **RHEL 8/9/10:** `sudo update-crypto-policies --set LEGACY` (¡temp!)

### Certificado SHA-1
- **RHEL 7/8:** Funciona (obsoleto)
- **RHEL 9/10:** BLOQUEADO — debe reemitirse

### Cliente TLS 1.0
- **RHEL 7:** Funciona por defecto
- **RHEL 8/9/10:** Bloqueado en DEFAULT, usar LEGACY (¡temp!)

---

**Detalles Completos:** Ver Capítulos 9-12
