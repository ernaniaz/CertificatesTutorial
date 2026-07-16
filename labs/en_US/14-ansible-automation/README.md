# Lab 14: Ansible Certificate Automation

## Learning Objectives

By completing this lab, you will:
- Install and configure Ansible
- Create inventory for certificate management
- Write playbooks for certificate deployment
- Automate Apache/NGINX certificate configuration
- Deploy certificates to multiple hosts
- Implement idempotent certificate management

## Prerequisites

- **Labs 01-06** completed (understanding of certificates)
- **RHEL Version:** 8, 9, or 10
- **System Access:** Root/sudo required
- **Multiple hosts** (or localhost for testing)

## Time Estimate

**50-60 minutes**

## Lab Overview

Ansible enables infrastructure automation at scale. Learn to manage certificates across multiple servers using the included `playbook-apache.yml`, ensuring consistent, repeatable deployments without manual intervention.

---

## Instructions

### Step 1: Install Ansible

Install Ansible control node:

```bash
sudo ./install-ansible.sh
```

This installs:
- `ansible` package
- `ansible-core` (RHEL 9+)
- Configuration files

---

### Step 2: Create Inventory

Set up Ansible inventory:

```bash
./create-inventory.sh
```

This creates:
- Inventory file
- Host groups
- Connection settings

---

### Step 3: Run Apache Playbook

Deploy certificates with the included Ansible playbook:

```bash
./run-apache-playbook.sh
```

This:
- Generates/copies certificates
- Configures Apache SSL
- Restarts services
- Validates configuration

---

### Step 4: Test Idempotency

Test idempotent behavior:

```bash
./test-idempotency.sh
```

This verifies:
- Repeated runs make no changes
- Configuration stability
- Ansible best practices

---

### Step 5: Verify Deployment

Run comprehensive validation:

```bash
./verify.sh
```

---

## Validation

```bash
./test.sh
```

All checks should pass.

## Expected Outcome

After completing this lab:
- ✅ Ansible installed and configured
- ✅ Certificate playbook deployed (`playbook-apache.yml`)
- ✅ Multi-host deployment capability
- ✅ Idempotent automation

---

## Key Concepts

### Ansible Architecture

```
Control Node (Ansible)
    ↓
Inventory (hosts)
    ↓
Playbooks (what to do)
    ↓
Managed Nodes (targets)
```

### Inventory Example

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

### Playbook Structure

```yaml
---
- name: Deploy SSL Certificates
  hosts: webservers
  become: yes

  tasks:
    - name: Copy certificate
      copy:
        src: files/server.crt
        dest: /etc/pki/tls/certs/server.crt
        mode: '0644'

    - name: Copy private key
      copy:
        src: files/server.key
        dest: /etc/pki/tls/private/server.key
        mode: '0600'
        owner: root
        group: root

    - name: Configure Apache SSL
      template:
        src: templates/ssl.conf.j2
        dest: /etc/httpd/conf.d/ssl.conf
      notify: Restart Apache

  handlers:
    - name: Restart Apache
      service:
        name: httpd
        state: restarted
```

### Included Playbook (`playbook-apache.yml`)

This lab ships a single playbook that:
- Generates a self-signed certificate for the lab
- Configures Apache SSL (`ansible-ssl.conf`)
- Restarts `httpd` via handlers
- Validates the deployed certificate

Run it with:

```bash
./run-apache-playbook.sh
```

Or manually:

```bash
ansible-playbook -i inventory.ini playbook-apache.yml
```

### Key Ansible Modules

**File Operations:**
```yaml
- copy:              # Copy files
- template:          # Jinja2 templates
- file:              # Manage files/dirs
- fetch:             # Download from remote
```

**Service Management:**
```yaml
- service:           # Manage services
- systemd:           # Systemd specific
```

**Command Execution:**
```yaml
- command:           # Run commands
- shell:             # Run shell commands
- script:            # Run scripts
```

**Package Management:**
```yaml
- yum:               # RHEL 7
- dnf:               # RHEL 8+
- package:           # Generic
```

### Idempotency

Ansible operations should be idempotent - running multiple times produces same result:

```yaml
# Good: Idempotent
- name: Ensure Apache is running
  service:
    name: httpd
    state: started
    enabled: yes

# Bad: Not idempotent
- name: Start Apache
  command: systemctl start httpd
```

---

## Troubleshooting

### Issue: Connection Refused

**Symptom:**
```
Failed to connect to the host
```

**Solution:**
```yaml
# Check connectivity
ansible all -m ping

# Test with different user
ansible all -m ping -u admin

# Use password auth
ansible all -m ping --ask-pass
```

---

### Issue: Permission Denied

**Symptom:**
```
Permission denied
```

**Solution:**
```yaml
# Use become (sudo)
ansible-playbook -i inventory.ini playbook-apache.yml --become

# Specify become user
ansible-playbook -i inventory.ini playbook-apache.yml --become-user=root

# In playbook:
become: yes
become_user: root
```

---

### Issue: Module Not Found

**Symptom:**
```
The module ... was not found
```

**Solution:**
```bash
# Install ansible collections
ansible-galaxy collection install ansible.posix

# Update Ansible
dnf update ansible
```

---

## Version-Specific Notes

### RHEL 8
- Ansible 2.9.x or ansible-core
- Uses `dnf` module
- Python 3 by default

### RHEL 9
- ansible-core (minimal)
- Requires collections
- Python 3.9+

---

## Cleanup

```bash
sudo ./cleanup.sh
```

This undoes all lab tasks: stops and removes Apache (httpd, mod_ssl), removes deployed certificates, SSL configuration, test page, Ansible configuration, inventory file, and the Ansible package.

---

## Additional Resources

**Related Chapters:**
- Chapter 25: Ansible Automation for Certificates

**Documentation:**
- `man ansible`
- `man ansible-playbook`
- https://docs.ansible.com/
- https://galaxy.ansible.com/

**Ansible Galaxy:**
```bash
# Search for roles
ansible-galaxy search certificate

# Install role
ansible-galaxy install geerlingguy.certbot
```

---

## Next Steps

Congratulations! You've completed all automation labs (11-14). You now have a complete toolkit for certificate management on RHEL, from manual configuration to full automation.

---

**Difficulty Level**: Advanced
