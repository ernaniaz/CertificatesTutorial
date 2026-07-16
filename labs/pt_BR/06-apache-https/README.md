# Lab 06: Configuração HTTPS no Apache

## Objetivos de aprendizagem

Ao concluir este laboratório, você irá:
- Instalar Apache (httpd) com mod_ssl
- Configurar Apache para HTTPS com certificados
- Entender a configuração SSL específica por versão do RHEL
- Trabalhar com crypto-policies (RHEL 8+)
- Testar conexões HTTPS
- Configurar virtual hosts com TLS

## Pré-requisitos

- **Labs 01-05** concluídos
- **Versão do RHEL:** 7, 8, 9 ou 10
- **Acesso ao sistema:** Root/sudo necessário
- **Firewall:** Acesso às portas 80 e 443

## Tempo estimado

**30-40 minutos**

## Visão geral

Apache é o servidor web mais comum no RHEL. Aprenda a configurá-lo com certificados TLS em todas as versões do RHEL, lidando com diferenças específicas por versão.

---

## Instruções

### Passo 1: Instale o Apache

Instale o Apache com suporte SSL:

```bash
sudo ./install-apache.sh
```

Isso instala:
- `httpd` (servidor web Apache)
- `mod_ssl` (módulo SSL/TLS)
- Abre as portas 80 e 443 no firewall

---

### Passo 2: Configure SSL (específico por versão)

Execute o script de configuração:

```bash
sudo ./configure-ssl.sh
```

Isso:
- Copia certificados do Lab 04
- Cria configuração de VirtualHost SSL
- Aplica configurações TLS específicas por versão
- Reinicia o Apache

---

### Passo 3: Teste a conexão HTTPS

Teste sua configuração HTTPS no Apache:

```bash
./test-connection.sh
```

Isso testa:
- Conexão HTTP (porta 80)
- Conexão HTTPS (porta 443)
- Validade do certificado
- Versão TLS e cifras

---

### Passo 4: Verifique a configuração

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
- ✅ Apache instalado e em execução
- ✅ HTTPS configurado com certificados
- ✅ Porta 443 acessível
- ✅ Certificado servido corretamente
- ✅ Compreensão das diferenças específicas por versão

---

## Conceitos-chave

### Arquivos de configuração SSL do Apache

```
/etc/httpd/
├── conf/
│   └── httpd.conf          # Configuração principal
├── conf.d/
│   └── ssl.conf            # Configuração SSL (mod_ssl)
└── conf.modules.d/
    └── 00-ssl.conf         # Carregamento do módulo
```

### Diretivas SSL básicas

```apache
SSLEngine on
SSLCertificateFile /path/to/cert.crt
SSLCertificateKeyFile /path/to/key.key
SSLCertificateChainFile /path/to/chain.crt
```

### Diferenças por versão

**RHEL 7:**
- Configuração manual de protocolos TLS
- Configuração manual de conjuntos de cifras
- `SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1`
- Configuração explícita de `SSLCipherSuite`

**RHEL 8+:**
- Crypto-policies gerenciam TLS/cifras automaticamente
- Diretivas SSL mínimas necessárias
- Aplicação de política em todo o sistema
- `SSLEngine on` + caminhos dos certificados são suficientes

---

## Resolução de problemas

### Problema: Apache não inicia

**Sintoma:**
```
Job for httpd.service failed
```

**Solução:**
Verifique a sintaxe e os logs:
```bash
sudo apachectl configtest
sudo journalctl -xeu httpd
```

---

### Problema: Erro de certificado

**Sintoma:**
```
SSL_CTX_use_PrivateKey_file: error
```

**Solução:**
Verifique caminhos e permissões dos arquivos:
```bash
ls -l /etc/pki/tls/certs/server.crt
ls -l /etc/pki/tls/private/server.key
# A chave privada deve estar no modo 600
```

---

### Problema: Firewall bloqueando

**Sintoma:**
Não é possível conectar a https://localhost

**Solução** (apenas se firewalld estiver ativo):
```bash
systemctl is-active firewalld && sudo firewall-cmd --list-services
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

> **Nota**: No RHEL 7, o firewalld pode não estar em execução. Nesse caso, use `iptables` ou simplesmente pule esta etapa.

---

## Notas específicas por versão

### RHEL 7
- Usa `yum` para instalação
- Exige configuração explícita de cifras
- Controle manual de versões TLS

### RHEL 8+
- Usa `dnf` para instalação
- Crypto-policies introduzidas
- Menos configuração SSL necessária

### RHEL 9+
- SHA-1 bloqueado por padrão
- Validação de certificados mais rigorosa
- SANs obrigatórios

---

## Limpeza

```bash
sudo ./cleanup.sh
```

Isso remove o Apache e restaura o estado do sistema.

---

## Recursos adicionais

**Capítulos relacionados:**
- Capítulo 14: Apache httpd no RHEL

**Documentação:**
- `man httpd`
- `man apachectl`
- `/usr/share/doc/httpd/`

---

## Próximos passos

Prossiga para o **Lab 07: Configuração HTTPS no NGINX** para aprender a configuração do NGINX.

---

**Nível de dificuldade**: Intermediário
