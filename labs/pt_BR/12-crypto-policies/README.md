# Lab 12: Crypto-Policies

## Objetivos de aprendizagem

Ao concluir este laboratório, você irá:
- Entender o sistema crypto-policies do RHEL
- Verificar a política criptográfica atual
- Alternar entre níveis de política (DEFAULT, FUTURE, LEGACY)
- Testar compatibilidade de serviços com políticas
- Criar módulos de política personalizados
- Entender o impacto em serviços TLS/SSL

## Pré-requisitos

- **Versão do RHEL:** 8, 9 ou 10 (crypto-policies introduzidas no RHEL 8)
- **Acesso ao sistema:** Root/sudo necessário
- **Laboratórios anteriores:** Compreensão de serviços TLS é útil

## Tempo estimado

**30-40 minutos**

## Visão geral

Crypto-policies é um framework de políticas criptográficas em todo o sistema no RHEL 8+. Aprenda a gerenciar níveis de segurança em todos os serviços do sistema de forma uniforme, entendendo as compensações entre segurança e compatibilidade.

---

## Instruções

### Passo 1: Verifique a política atual

Verifique a crypto-policy atual:

```bash
./check-policy.sh
```

Isso mostra:
- Política ativa atual
- Arquivos de configuração da política
- Serviços afetados

---

### Passo 2: Alterne para política LEGACY

Teste a política LEGACY para máxima compatibilidade:

```bash
sudo ./switch-legacy.sh
```

Isso:
- Alterna para política LEGACY
- Atualiza todas as configurações de serviços
- Testa compatibilidade

---

### Passo 3: Alterne para política FUTURE

Teste a política FUTURE para máxima segurança:

```bash
sudo ./switch-future.sh
```

Isso:
- Alterna para política FUTURE
- Mostra requisitos mais rigorosos
- Testa compatibilidade de serviços

---

### Passo 4: Teste compatibilidade

Teste como os serviços se comportam sob diferentes políticas:

```bash
./test-compatibility.sh
```

Isso testa:
- Versões TLS permitidas
- Conjuntos de cifras disponíveis
- Algoritmos SSH suportados
- Funcionalidade dos serviços

---

### Passo 5: Restaure política DEFAULT

Retorne à política DEFAULT:

```bash
sudo ./restore-default.sh
```

Isso:
- Restaura política DEFAULT
- Redefine todos os serviços
- Verifica a restauração

---

### Passo 6: Verifique a configuração

Execute a validação abrangente:

```bash
sudo ./verify.sh
```

---

## Validação

```bash
sudo ./test.sh
```

Todas as verificações devem passar.

## Resultado esperado

Após concluir este laboratório:
- ✅ Compreensão de crypto-policies
- ✅ Capacidade de alternar políticas
- ✅ Conhecimento dos impactos das políticas
- ✅ Testados múltiplos níveis de política
- ✅ Sistema restaurado para DEFAULT

---

## Conceitos-chave

### Visão geral das Crypto-Policies

**Finalidade:**
- Padrões criptográficos em todo o sistema
- Segurança consistente entre serviços
- Gerenciamento fácil de políticas
- Equilíbrio entre segurança e compatibilidade

**Serviços suportados:**
- OpenSSL
- GnuTLS
- NSS
- OpenSSH
- Kerberos
- BIND
- Apache
- NGINX

### Níveis de política

| Política | Descrição | Caso de uso |
|----------|-----------|-------------|
| **DEFAULT** | Segurança equilibrada | Operações normais |
| **LEGACY** | Algoritmos fracos permitidos | Sistemas antigos/compatibilidade |
| **FUTURE** | Apenas algoritmos fortes | Necessidades de alta segurança |
| **FIPS** | Compatível com FIPS 140-2 | Governo/conformidade |

### Características das políticas

**DEFAULT:**
- TLS 1.2+
- Assinaturas SHA-1 em DNSSec
- SSH RSA 2048+
- Equilibrado para a maioria dos ambientes

**LEGACY:**
- TLS 1.0+
- Cifras fracas permitidas
- Assinaturas SHA-1 permitidas
- Máxima compatibilidade

**FUTURE:**
- TLS 1.3 preferido
- Apenas cifras fortes
- Tamanhos de chave maiores
- Segurança voltada ao futuro

**FIPS:**
- Algoritmos aprovados FIPS 140-2
- Sem MD5, assinaturas SHA-1
- Conjuntos de cifras específicos
- Requisito de conformidade

### Comandos

```bash
# Verificar política atual
update-crypto-policies --show

# Definir política
update-crypto-policies --set LEGACY
update-crypto-policies --set DEFAULT
update-crypto-policies --set FUTURE

# Listar políticas disponíveis
ls /usr/share/crypto-policies/policies/

# Visualizar detalhes da política
cat /usr/share/crypto-policies/policies/DEFAULT.pol

# Aplicar módulo personalizado
update-crypto-policies --set DEFAULT:module-name
```

### Arquivos de configuração

```
/etc/crypto-policies/
├── config                           # Política ativa
├── back-ends/                       # Configs específicas por serviço
│   ├── openssh.config
│   ├── openssl.config
│   ├── gnutls.config
│   └── nss.config
└── state/
    └── current                      # Link simbólico para política atual
```

---

## Resolução de problemas

### Problema: Serviços falham após mudança de política

**Sintoma:**
```
SSL handshake failed
Connection refused
```

**Solução:**
Volte para DEFAULT ou LEGACY:
```bash
update-crypto-policies --set DEFAULT
systemctl restart <service>
```

---

### Problema: Não é possível alternar política

**Sintoma:**
```
Setting system policy failed
```

**Solução:**
Verifique logs e permissões:
```bash
journalctl -xe
# Certifique-se de estar como root
sudo update-crypto-policies --set DEFAULT
```

---

### Problema: Clientes legados não conseguem conectar

**Sintoma:**
Clientes antigos falham com política FUTURE/DEFAULT

**Solução:**
Use LEGACY temporariamente ou crie módulo personalizado:
```bash
# Opção 1: Use LEGACY
update-crypto-policies --set LEGACY

# Opção 2: Crie módulo personalizado permitindo algoritmos específicos
```

---

## Notas específicas por versão

### RHEL 8
- Crypto-policies introduzidas
- Política DEFAULT é equilibrada
- Maioria dos serviços suportados
- Reinício manual necessário após mudança de política

### RHEL 9
- Crypto-policies aprimoradas
- Política DEFAULT mais rigorosa
- SHA-1 bloqueado por padrão
- Melhor reinício automático de serviços

### RHEL 10 (Beta/Preview)
- Padrões ainda mais reforçados
- Controle mais granular
- Suporte estendido a serviços

---

## Limpeza

```bash
sudo ./cleanup.sh
```

Isso restaura a política DEFAULT.

---

## Recursos adicionais

**Capítulos relacionados:**
- Capítulo 23: Crypto-Policies — aprofundamento

**Documentação:**
- `man update-crypto-policies`
- `man crypto-policies`
- `/usr/share/doc/crypto-policies/`
- https://access.redhat.com/articles/3642912

**Arquivos de política:**
- `/usr/share/crypto-policies/policies/`
- `/etc/crypto-policies/config`

---

## Próximos passos

Prossiga para o **Lab 13: Let's Encrypt e Certbot** para aprender automação de certificados ACME.

---

**Nível de dificuldade:** Intermediário
**Nota:** Este laboratório requer RHEL 8+ (crypto-policies não disponíveis no RHEL 7)
