# Lab 07: Configuração HTTPS no NGINX

## Objetivos de aprendizagem

Ao concluir este laboratório, você irá:
- Instalar o servidor web NGINX
- Configurar NGINX para HTTPS com certificados
- Entender a sintaxe de configuração SSL do NGINX
- Trabalhar com server blocks do NGINX
- Testar conexões HTTPS com NGINX
- Entender diferenças específicas por versão do RHEL

## Pré-requisitos

- **Labs 01-05** concluídos
- **Versão do RHEL:** 7, 8, 9 ou 10
- **Acesso ao sistema:** Root/sudo necessário
- **Firewall:** Acesso às portas 80 e 443

## Tempo estimado

**30-40 minutos**

## Visão geral

NGINX é um servidor web e proxy reverso de alto desempenho. Aprenda a configurá-lo com certificados TLS em todas as versões do RHEL, entendendo como ele difere do Apache.

---

## Instruções

### Passo 1: Instale o NGINX

Instale o NGINX:

```bash
sudo ./install-nginx.sh
```

Isso instala:
- Servidor web `nginx`
- Abre as portas 80 e 443 no firewall
- Cria configuração básica

**Notas**:
- RHEL 7 não inclui NGINX em seus repositórios base. O script instala EPEL (`epel-release` de archives.fedoraproject.org, pois o EPEL 7 está arquivado) para fornecer o pacote `nginx`;
- O nome do serviço é `nginx` em todas as versões suportadas do RHEL.

---

### Passo 2: Configure SSL (específico por versão)

Execute o script de configuração:

```bash
sudo ./configure-ssl.sh
```

Isso:
- Copia certificados do Lab 04
- Cria configuração de server block SSL
- Aplica configurações TLS específicas por versão
- Reinicia o NGINX

---

### Passo 3: Teste a conexão HTTPS

Teste sua configuração HTTPS no NGINX:

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
- ✅ NGINX instalado e em execução
- ✅ HTTPS configurado com certificados
- ✅ Porta 443 acessível
- ✅ Certificado servido corretamente
- ✅ Compreensão das diferenças entre NGINX e Apache

---

## Conceitos-chave

### Estrutura de configuração do NGINX

```
/etc/nginx/
├── nginx.conf               # Configuração principal
├── conf.d/                  # Configurações personalizadas
│   └── default.conf         # Server block padrão
└── default.d/               # Configurações adicionais
```

### Diretivas SSL básicas

```nginx
server {
    listen 443 ssl;
    server_name example.com;

    ssl_certificate /path/to/cert.crt;
    ssl_certificate_key /path/to/key.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
}
```

### NGINX vs Apache

**NGINX:**
- Arquitetura orientada a eventos
- Configuração em `nginx.conf` e `/etc/nginx/conf.d/`
- Testar config: `nginx -t`
- Recarregar: `nginx -s reload`
- Server blocks em vez de VirtualHosts

**Apache:**
- Orientado a processos/threads
- Configuração em `/etc/httpd/conf.d/`
- Testar config: `apachectl configtest`
- Recarregar: `systemctl reload httpd`
- VirtualHosts

### Diferenças por versão

**RHEL 7:**
- Configuração manual de protocolos TLS
- Configuração explícita de conjuntos de cifras
- `ssl_protocols TLSv1.2 TLSv1.3;`
- Configuração explícita de `ssl_ciphers`

**RHEL 8+:**
- Crypto-policies podem ser usadas
- Mas NGINX exige configuração mais explícita que Apache
- Ainda é necessário especificar protocolos e cifras
- Política do sistema afeta opções disponíveis

---

## Resolução de problemas

### Problema: NGINX não inicia

**Sintoma:**
```
Job for nginx.service failed
```

**Solução:**
Verifique a sintaxe e os logs:
```bash
sudo nginx -t
sudo journalctl -xeu nginx
```

---

### Problema: Erro de sintaxe na configuração

**Sintoma:**
```
nginx: [emerg] unexpected "}" in /etc/nginx/...
```

**Solução:**
Verifique ponto e vírgula e chaves ausentes:
```bash
nginx -t
# Cada diretiva precisa de ponto e vírgula
# Blocos server precisam de { }
```

---

### Problema: Erro de certificado

**Sintoma:**
```
nginx: [emerg] cannot load certificate
```

**Solução:**
Verifique caminhos e permissões dos arquivos:
```bash
ls -l /etc/pki/nginx/server.crt
ls -l /etc/pki/nginx/private/server.key
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

### Problema: SELinux bloqueando acesso ao certificado

**Sintoma:**
```
nginx: [emerg] BIO_new_file(...) failed
```

**Solução:**
Verifique contextos SELinux:
```bash
sudo setenforce 0  # Teste temporário
# Se isso resolver, corrija os contextos SELinux:
sudo restorecon -Rv /etc/pki/nginx/
sudo setenforce 1
```

---

## Notas específicas por versão

### RHEL 7
- Usa `yum` para instalação
- NGINX versão 1.20.x normalmente
- Exige configuração explícita de cifras
- Controle manual de versões TLS

### RHEL 8+
- Usa `dnf` para instalação
- NGINX versão 1.20.x normalmente
- Crypto-policies existem, mas NGINX precisa de config explícita
- Pode referenciar a política do sistema

### RHEL 9+
- NGINX versão 1.20.x ou mais recente
- SHA-1 bloqueado por padrão
- Validação de certificados mais rigorosa
- SANs obrigatórios
- TLSv1.3 preferido

---

## Limpeza

```bash
sudo ./cleanup.sh
```

Isso remove o NGINX e restaura o estado do sistema.

---

## Recursos adicionais

**Capítulos relacionados:**
- Capítulo 15: NGINX no RHEL

**Documentação:**
- `man nginx`
- `/usr/share/doc/nginx/`
- https://nginx.org/en/docs/

**Módulo SSL do NGINX:**
- http://nginx.org/en/docs/http/ngx_http_ssl_module.html

---

## Próximos passos

Prossiga para o **Lab 08: TLS no Postfix** para aprender a configuração TLS de servidor de e-mail.

---

**Nível de dificuldade:** Intermediário
