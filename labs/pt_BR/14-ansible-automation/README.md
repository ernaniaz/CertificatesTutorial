# Lab 14: Automação de Certificados com Ansible

## Objetivos de aprendizagem

Ao concluir este laboratório, você irá:
- Instalar e configurar Ansible
- Criar inventário para gerenciamento de certificados
- Escrever playbooks para implantação de certificados
- Automatizar configuração de certificados Apache/NGINX
- Implantar certificados em múltiplos hosts
- Implementar gerenciamento idempotente de certificados

## Pré-requisitos

- **Labs 01-06** concluídos (compreensão de certificados)
- **Versão do RHEL:** 8, 9 ou 10
- **Acesso ao sistema:** Root/sudo necessário
- **Múltiplos hosts** (ou localhost para testes)

## Tempo estimado

**50-60 minutos**

## Visão geral

Ansible permite automação de infraestrutura em escala. Aprenda a gerenciar certificados em múltiplos servidores usando o `playbook-apache.yml` incluído, garantindo implantações consistentes e repetíveis sem intervenção manual.

---

## Instruções

### Passo 1: Instale o Ansible

Instale o nó de controle Ansible:

```bash
sudo ./install-ansible.sh
```

Isso instala:
- Pacote `ansible`
- `ansible-core` (RHEL 9+)
- Arquivos de configuração

---

### Passo 2: Crie inventário

Configure o inventário Ansible:

```bash
./create-inventory.sh
```

Isso cria:
- Arquivo de inventário
- Grupos de hosts
- Configurações de conexão

---

### Passo 3: Execute playbook Apache

Implante certificados com o playbook Ansible incluído:

```bash
./run-apache-playbook.sh
```

Isso:
- Gera/copia certificados
- Configura SSL do Apache
- Reinicia serviços
- Valida configuração

---

### Passo 4: Teste idempotência

Teste comportamento idempotente:

```bash
./test-idempotency.sh
```

Isso verifica:
- Execuções repetidas não fazem alterações
- Estabilidade da configuração
- Boas práticas Ansible

---

### Passo 5: Verifique implantação

Execute validação abrangente:

```bash
./verify.sh
```

---

## Validação

```bash
./test.sh
```

Todas as verificações devem passar.

## Resultado esperado

Após concluir este laboratório:
- ✅ Ansible instalado e configurado
- ✅ Playbook de certificados implantado (`playbook-apache.yml`)
- ✅ Capacidade de implantação multi-host
- ✅ Automação idempotente

---

## Conceitos-chave

### Arquitetura Ansible

```
Control Node (Ansible)
    ↓
Inventory (hosts)
    ↓
Playbooks (what to do)
    ↓
Managed Nodes (targets)
```

### Exemplo de inventário

```ini
[webservers]
web1.example.com
web2.example.com

[databases]
db1.example.com

[all:vars]
ansible_user=admin
ansible_become=yes
```

### Estrutura de playbook

```yaml
---
- name: Implantar certificados SSL
  hosts: webservers
  become: yes

  tasks:
    - name: Copiar certificado
      copy:
        src: files/server.crt
        dest: /etc/pki/tls/certs/server.crt
        mode: '0644'

    - name: Copiar chave privada
      copy:
        src: files/server.key
        dest: /etc/pki/tls/private/server.key
        mode: '0600'
        owner: root
        group: root

    - name: Configurar SSL do Apache
      template:
        src: templates/ssl.conf.j2
        dest: /etc/httpd/conf.d/ssl.conf
      notify: Reiniciar Apache

  handlers:
    - name: Reiniciar Apache
      service:
        name: httpd
        state: restarted
```

### Playbook incluído (`playbook-apache.yml`)

Este lab inclui um playbook que:
- Gera um certificado autoassinado para o lab
- Configura SSL do Apache (`ansible-ssl.conf`)
- Reinicia `httpd` via handlers
- Valida o certificado implantado

Execute com:

```bash
./run-apache-playbook.sh
```

Ou manualmente:

```bash
ansible-playbook -i inventory.ini playbook-apache.yml
```

### Módulos Ansible principais

**Operações de arquivo:**
```yaml
- copy:              # Copiar arquivos
- template:          # Templates Jinja2
- file:              # Gerenciar arquivos/dirs
- fetch:             # Baixar do remoto
```

**Gerenciamento de serviços:**
```yaml
- service:           # Gerenciar serviços
- systemd:           # Específico systemd
```

**Execução de comandos:**
```yaml
- command:           # Executar comandos
- shell:             # Executar comandos shell
- script:            # Executar scripts
```

**Gerenciamento de pacotes:**
```yaml
- yum:               # RHEL 7
- dnf:               # RHEL 8+
- package:           # Genérico
```

### Idempotência

Operações Ansible devem ser idempotentes — executar várias vezes produz o mesmo resultado:

```yaml
# Bom: Idempotente
- name: Garantir que Apache esteja em execução
  service:
    name: httpd
    state: started
    enabled: yes

# Ruim: Não idempotente
- name: Iniciar Apache
  command: systemctl start httpd
```

---

## Resolução de problemas

### Problema: Conexão recusada

**Sintoma:**
```
Failed to connect to the host
```

**Solução:**
```yaml
# Verifique conectividade
ansible all -m ping

# Teste com usuário diferente
ansible all -m ping -u admin

# Use autenticação por senha
ansible all -m ping --ask-pass
```

---

### Problema: Permissão negada

**Sintoma:**
```
Permission denied
```

**Solução:**
```yaml
# Use become (sudo)
ansible-playbook -i inventory.ini playbook-apache.yml --become

# Especifique usuário become
ansible-playbook -i inventory.ini playbook-apache.yml --become-user=root

# No playbook:
become: yes
become_user: root
```

---

### Problema: Módulo não encontrado

**Sintoma:**
```
The module ... was not found
```

**Solução:**
```bash
# Instale collections ansible
ansible-galaxy collection install ansible.posix

# Atualize Ansible
dnf update ansible
```

---

## Notas específicas por versão

### RHEL 8
- Ansible 2.9.x ou ansible-core
- Usa módulo `dnf`
- Python 3 por padrão

### RHEL 9
- ansible-core (minimal)
- Exige collections
- Python 3.9+

---

## Limpeza

```bash
sudo ./cleanup.sh
```

Isso desfaz todas as tarefas do lab: para e remove o Apache (httpd, mod_ssl), remove certificados implantados, configuração SSL, página de teste, configuração do Ansible, arquivo de inventário e o pacote Ansible.

---

## Recursos adicionais

**Capítulos relacionados:**
- Capítulo 25: Automatização Ansible para Certificados

**Documentação:**
- `man ansible`
- `man ansible-playbook`
- https://docs.ansible.com/
- https://galaxy.ansible.com/

**Ansible Galaxy:**
```bash
# Pesquisar roles
ansible-galaxy search certificate

# Instalar role
ansible-galaxy install geerlingguy.certbot
```

---

## Próximos passos

Parabéns! Você concluiu todos os laboratórios de automação (11-14). Agora você tem um kit completo para gerenciamento de certificados no RHEL, da configuração manual à automação completa.

---

**Nível de dificuldade:** Avançado
