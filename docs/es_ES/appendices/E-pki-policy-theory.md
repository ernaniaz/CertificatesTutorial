# Apéndice E: Teoría de Políticas PKI

## Políticas, Líneas Base y Auditorías

## 1. Por Qué Importan las Políticas

Las políticas formalizan *cómo* pueden emitirse y usarse los certificados, asegurando consistencia y defensa legal.

## 2. Requisitos de Línea Base (CAB Forum)

Requisitos que las CAs públicamente confiables deben seguir, incluyendo:

* Métodos de validación de dominio
* Tamaños de clave ≥ RSA 2048 bits / ECC 256 bits
* Validez máxima 398 días

## 3. Política de Certificado (CP) vs CPS

| Documento | Audiencia | Contenido |
|-----------|-----------|-----------|
| CP | Partes confiantes | Qué aseguramiento proporciona la PKI |
| CPS | Auditores, operadores | *Cómo* la CA cumple la CP |

## 4. Auditorías y Cumplimiento

* **Auditorías WebTrust / ETSI** para CAs públicas.
* PKIs internas pueden alinearse con NIST SP 800-53 o ISO 27001.

## 5. Caso de Estudio RHEL

El `certmonger` de RHEL puede renovar automáticamente certificados de host de acuerdo con pautas CP/CPS empresariales.
