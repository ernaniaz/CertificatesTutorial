# Lab 01: Configuração do Ambiente

## Objetivos de aprendizagem

Ao concluir este laboratório, você irá:
- Verificar se o seu sistema RHEL está configurado corretamente
- Instalar ferramentas essenciais de gerenciamento de certificados
- Entender a estrutura do diretório /etc/pki/
- Validar a instalação e a versão do OpenSSL
- Preparar o sistema para os laboratórios subsequentes de certificados

## Pré-requisitos

- **Versão do RHEL:** RHEL 7, 8, 9 ou 10
- **Acesso ao sistema:** Privilégios de root ou sudo necessários
- **Rede:** Conectividade com a internet para instalação de pacotes

## Tempo estimado

**15-20 minutos**

## Visão geral

Este laboratório valida e prepara o seu sistema RHEL para os exercícios de gerenciamento de certificados. Você instalará as ferramentas necessárias e verificará se a infraestrutura de certificados está em ordem.

---

## Instruções

### Passo 1: Identifique a versão do RHEL

Primeiro, identifique qual versão do RHEL você está executando:

```bash
cat /etc/redhat-release
```

**Saída esperada:**
```
Red Hat Enterprise Linux release 8.x (Ootpa)
# ou similar para RHEL 7, 9 ou 10
```

Verifique a versão do OpenSSL:
```bash
openssl version
```

**Versão por RHEL:**
- RHEL 7: OpenSSL 1.0.2k
- RHEL 8: OpenSSL 1.1.1k
- RHEL 9: OpenSSL 3.5.5
- RHEL 10: OpenSSL 3.5.5

---

### Passo 2: Execute o script de configuração

Execute o script de configuração:

```bash
sudo ./setup.sh
```

O script instalará:
- OpenSSL (operações com certificados)
- Ferramentas NSS / certutil (gerenciamento de banco de dados NSS)
- certmonger (renovação automática de certificados)
- ca-certificates (repositório de confiança do sistema)

---

### Passo 3: Verifique a instalação

Após a instalação, execute o script de verificação:

```bash
./verify-environment.sh
```

**Resultado esperado:**
```
┌─────────────────────────────────────────────────────────┐
│ Lab 01: Verificação do Ambiente                         │
└─────────────────────────────────────────────────────────┘

Versão RHEL: 8

  ✓ OpenSSL: OpenSSL 1.1.1k FIPS  25 Mar 2021
  ✓ certutil disponível
  ✓ certmonger disponível
  ✓ Crypto-policies: DEFAULT

Diretórios de certificado:
  ✓ /etc/pki/tls/certs
  ✓ /etc/pki/tls/private
  ✓ /etc/pki/ca-trust
  ✓ Pacote CA: 140 linhas

  ✓ Todas as validações aprovadas!
  ✓ Lab 01 concluído com sucesso.

Próximo: Prossiga para Lab 02: Geração de Chaves
```

---

### Passo 4: Explore a estrutura de diretórios de certificados

Visualize a estrutura de diretórios de certificados:

```bash
tree -L 2 /etc/pki/
```

**Diretórios principais:**
- `/etc/pki/tls/certs/` - Certificados de servidor (públicos)
- `/etc/pki/tls/private/` - Chaves privadas (modo 600!)
- `/etc/pki/ca-trust/` - Certificados CA confiáveis
- `/etc/pki/nssdb/` - Banco de dados NSS

Verifique o pacote CA do sistema:
```bash
ls -lh /etc/pki/tls/certs/ca-bundle.crt
wc -l /etc/pki/tls/certs/ca-bundle.crt
```

---

## Validação

Para verificar se o laboratório foi concluído, execute:

```bash
./verify-environment.sh
```

Todas as verificações devem passar com símbolos ✓.

## Resultado esperado

Após concluir este laboratório, você deve ter:
- ✅ Versão do RHEL identificada
- ✅ OpenSSL instalado e versão verificada
- ✅ Ferramentas de certificados instaladas (certutil, certmonger)
- ✅ Estrutura do diretório /etc/pki/ validada
- ✅ Pacote CA do sistema acessível

---

## Resolução de problemas

### Problema 1: Falha na instalação de pacotes

**Sintoma:**
```
Error: Unable to find a match: certmonger
```

**Causa:**
Repositório não configurado ou assinatura RHEL inativa

**Solução:**
```bash
# Verifique o status da assinatura RHEL
sudo subscription-manager status

# Se não estiver registrado, registre o sistema
sudo subscription-manager register

# Habilite os repositórios necessários
sudo subscription-manager repos --enable=rhel-8-for-x86_64-baseos-rpms
```

---

### Problema 2: Permissão negada

**Sintoma:**
```
Permission denied when accessing /etc/pki/
```

**Causa:**
Script não executado com sudo/root

**Solução:**
Execute os scripts de configuração com sudo:
```bash
sudo ./setup.sh
```

---

## Notas específicas por versão

### RHEL 7
- Usa o gerenciador de pacotes YUM
- OpenSSL 1.0.2k (mais antigo, mas funcional)
- Configuração manual de SSL/TLS necessária para serviços

### RHEL 8+
- Usa o gerenciador de pacotes DNF
- Sistema crypto-policies introduzido
- Gerenciamento automático de versões TLS e cifras

### RHEL 9+
- OpenSSL 3.x (mudança de versão principal)
- Assinaturas SHA-1 bloqueadas por padrão
- Validação de certificados mais rigorosa

---

## Limpeza

Este laboratório não exige limpeza, pois instala apenas pacotes do sistema. Se quiser remover os pacotes:

```bash
sudo ./cleanup.sh
```

**Aviso:** Execute a limpeza somente se tiver certeza de que não precisará dessas ferramentas.

---

## Recursos adicionais

**Capítulos relacionados:**
- Capítulo 1: Criptografia, Estrutura PKI e Fundamentos
- Capítulo 2: Introdução aos Certificados no RHEL
- Capítulo 3: Visão Geral das Ferramentas de Certificados do RHEL

**Documentação:**
- `man openssl`
- `man certutil`
- `man getcert` (certmonger)

---

## Próximos passos

Após concluir este laboratório, prossiga para:

**Lab 02: Geração de Chaves** - Aprenda a gerar pares de chaves RSA e ECC

---

**Versões do RHEL testadas**: 7, 8, 9, 10  
**Nível de dificuldade**: Iniciante
