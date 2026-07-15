# Apêndice E: Teoria de Políticas PKI

## Políticas, Linhas de Base e Auditorias

## 1. Por Que Políticas Importam

Políticas formalizam *como* certificados podem ser emitidos e usados, garantindo consistência e defensibilidade legal.

## 2. Requisitos de Linha de Base (CAB Forum)

Requisitos que CAs publicamente confiáveis devem seguir, incluindo:

* Métodos de validação de domínio
* Tamanhos de chave ≥ RSA 2048 bits / ECC 256 bits
* Validade máxima 398 dias

## 3. Política de Certificado (CP) vs CPS

| Documento | Audiência | Conteúdo |
|-----------|-----------|----------|
| CP | Partes confiantes | Que garantia a PKI fornece |
| CPS | Auditores, operadores | *Como* a CA cumpre a CP |

## 4. Auditorias e Conformidade

* **Auditorias WebTrust / ETSI** para CAs públicas.
* PKIs internas podem alinhar com NIST SP 800-53 ou ISO 27001.

## 5. Estudo de Caso RHEL

O `certmonger` do RHEL pode renovar automaticamente certificados de host de acordo com diretrizes CP/CPS empresariais.
