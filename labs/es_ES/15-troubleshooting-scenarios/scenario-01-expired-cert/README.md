# Escenario 01: Certificado vencido

## Descripción del problema

Un certificado ha vencido, causando fallos de conexión SSL/TLS. Este es uno de los problemas de certificados más comunes en producción.

## Síntomas

- Errores de "certificate has expired"
- Fallos en el handshake SSL
- Advertencias de seguridad del navegador
- Aplicaciones que rechazan conectarse

## Objetivos de aprendizaje

- Detectar certificados vencidos
- Comprender los períodos de validez de certificados
- Implementar procedimientos adecuados de renovación de certificados
- Configurar monitoreo de vencimiento

## Archivos

- `create-problem.sh` - Crea un certificado vencido
- `diagnose.sh` - Muestra pasos de diagnóstico
- `fix.sh` - Renueva el certificado
- `verify-fix.sh` - Confirma la corrección

## Inicio rápido

```bash
sudo ./create-problem.sh
./diagnose.sh
sudo ./fix.sh
sudo ./verify-fix.sh
```

## Comandos de diagnóstico

```bash
# Verificar vencimiento del certificado
openssl x509 -in /etc/pki/tls/certs/expired.crt -noout -dates

# Verificar si está vencido
openssl x509 -in /etc/pki/tls/certs/expired.crt -noout -checkend 0

# Inspeccionar el archivo de certificado (este lab no lo enlaza al puerto 443)
openssl x509 -in /etc/pki/tls/certs/expired.crt -noout -text
```

## Causa raíz

La fecha "Not After" del certificado ha pasado. Causas comunes:
- Renovación olvidada
- Monitoreo no configurado
- Proceso manual interrumpido
- Fallo del gestor de certificados

## Solución

1. Generar un nuevo certificado con vencimiento futuro
2. Reemplazar el certificado vencido
3. Reiniciar los servicios afectados
4. Implementar monitoreo para evitar recurrencia

## Prevención

- Usar certmonger o certbot para renovación automática
- Configurar monitoreo de vencimiento
- Renovar 30 días antes del vencimiento
- Probar el proceso de renovación regularmente
