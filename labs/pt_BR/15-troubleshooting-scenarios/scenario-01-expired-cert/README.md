# Cenário 01: Certificado expirado

## Descrição do problema

Um certificado expirou, causando falhas de conexão SSL/TLS. Este é um dos problemas de certificados mais comuns em produção.

## Sintomas

- Erros "certificate has expired"
- Falhas de handshake SSL
- Avisos de segurança no navegador
- Aplicativos recusando conexão

## Objetivos de aprendizagem

- Detectar certificados expirados
- Entender períodos de validade de certificados
- Implementar procedimentos adequados de renovação
- Configurar monitoramento de expiração

## Arquivos

- `create-problem.sh` - Cria certificado expirado
- `diagnose.sh` - Mostra passos de diagnóstico
- `fix.sh` - Renova o certificado
- `verify-fix.sh` - Confirma a correção

## Início rápido

```bash
sudo ./create-problem.sh
./diagnose.sh
sudo ./fix.sh
sudo ./verify-fix.sh
```

## Comandos de diagnóstico

```bash
# Verificar expiração do certificado
openssl x509 -in /etc/pki/tls/certs/expired.crt -noout -dates

# Verificar se expirou
openssl x509 -in /etc/pki/tls/certs/expired.crt -noout -checkend 0

# Inspecionar o arquivo de certificado (este lab não o associa à porta 443)
openssl x509 -in /etc/pki/tls/certs/expired.crt -noout -text
```

## Causa raiz

A data "Not After" do certificado passou. Causas comuns:
- Renovação esquecida
- Monitoramento não configurado
- Processo manual interrompido
- Gerenciador de certificados falhou

## Solução

1. Gerar novo certificado com expiração futura
2. Substituir certificado expirado
3. Reiniciar serviços afetados
4. Implementar monitoramento para evitar recorrência

## Prevenção

- Use certmonger ou certbot para renovação automática
- Configure monitoramento de expiração
- Renove 30 dias antes da expiração
- Teste o processo de renovação regularmente
