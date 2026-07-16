# Contributing Labs to the Certificates Tutorial

Thank you for your interest in contributing lab exercises to the PKI & Digital Certificates Tutorial!

## Overview

This tutorial includes **22 lab exercises** for hands-on practice with certificates on RHEL systems. Labs are stored in `labs/<LOCALE>/` and organized by topic.

## Types of Contributions

### 1. New Lab Exercises

Complete lab directories with:
- README with step-by-step instructions
- Scripts for setup/cleanup
- Sample configurations
- Verification steps

### 2. Exercise Improvements

- Bug fixes in existing labs
- Better documentation
- Additional scenarios
- RHEL version compatibility updates

### 3. Translation

- Translate existing labs to pt_BR or es_ES
- Maintain command examples in English
- Translate explanatory text

## Lab Structure

Each lab follows this structure:

```
NN-lab-name/
├── README.md           # Lab description and instructions
├── setup.sh            # Environment setup script (optional)
├── cleanup.sh          # Cleanup script (optional)
├── configs/            # Sample configuration files (optional)
│   ├── httpd-ssl.conf
│   └── openssl.cnf
├── certs/              # Sample certificates for testing (optional)
│   └── README.md       # Instructions for generating test certs
├── solutions/          # Solutions and expected outputs (optional)
│   └── SOLUTION.md
└── assets/             # Supporting files (optional)
```

## Lab Categories

| Labs | Category | Topics |
|------|----------|--------|
| 01-05 | Fundamentals | Encryption, keys, signatures, X.509, trust store |
| 06-10 | Services | Apache, NGINX, Postfix, OpenLDAP, PostgreSQL |
| 11-14 | Automation | certmonger, crypto-policies, Let's Encrypt, Ansible |
| 15-16 | Troubleshooting | Scenarios, emergency procedures |
| 17-18 | Migration | RHEL 7→8, RHEL 8→9 |
| 19-20 | Security | FIPS mode, hardening |
| 21-22 | Advanced | Kubernetes cert-manager, HashiCorp Vault |

## README Template

````markdown
# Lab NN: [Lab Name]

## Overview

[Brief description of what this lab demonstrates]

**Related Chapters**: X, Y, Z

## Learning Objectives

After completing this lab, you will be able to:

- [Objective 1]
- [Objective 2]
- [Objective 3]

## Prerequisites

### Knowledge

- [Required knowledge]
- [Prior labs completed]

### Environment

- RHEL [7/8/9/10] system (VM recommended)
- [Required packages]
- [Network requirements]

### Time Required

⏱️ [XX-YY] minutes

### Difficulty Level

🎯 [Beginner/Intermediate/Advanced]

## Lab Setup

```bash
# Install required packages
sudo dnf install [packages]

# Verify prerequisites
[verification commands]
```

## Exercises

### Exercise 1: [Title]

**Objective**: [What the learner will accomplish]

**Steps**:

1. [Step 1]
   ```bash
   [command]
   ```

2. [Step 2]
   ```bash
   [command]
   ```

**Expected Output**:
```
[sample output]
```

**Verification**:
```bash
[verification command]
```

### Exercise 2: [Title]

[Continue pattern...]

## Troubleshooting

### Common Issue 1

**Symptom**: [What the user sees]

**Cause**: [Why it happens]

**Solution**:
```bash
[fix command]
```

### Common Issue 2

[Continue pattern...]

## Cleanup

```bash
# Remove lab resources
[cleanup commands]
```

## Key Takeaways

- [Takeaway 1]
- [Takeaway 2]
- [Takeaway 3]

## Further Reading

- Chapter X: [Topic]
- [External resource URL]

## Next Lab

Next Lab: `../NN+1-next-lab/README.md`
````

## Code Guidelines

### Shell Scripts

```bash
#!/bin/bash
#
# script-name.sh - Brief description
#
# Usage: ./script-name.sh [options]
#
# This script does [longer description if needed].
#

set -euo pipefail

# Constants
CERT_DIR="/etc/pki/tls/certs"
KEY_DIR="/etc/pki/tls/private"

# Functions
function check_root ()
{
  if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root"
    exit 1
  fi
}

function main ()
{
  check_root
  # Main logic
}

main "$@"
```

### Configuration Files

Include comments explaining each section:

```apache
# httpd-ssl.conf - Apache SSL configuration for Lab 06
#
# This configuration demonstrates:
# - Basic SSL/TLS setup
# - Certificate and key file paths
# - Cipher suite configuration

<VirtualHost *:443>
    ServerName example.com
    DocumentRoot /var/www/html

    # Enable SSL
    SSLEngine on

    # Certificate files
    SSLCertificateFile /etc/pki/tls/certs/server.crt
    SSLCertificateKeyFile /etc/pki/tls/private/server.key

    # Optional: Certificate chain
    # SSLCertificateChainFile /etc/pki/tls/certs/chain.crt
</VirtualHost>
```

### OpenSSL Commands

Document commands with explanation:

```bash
# Generate a 2048-bit RSA private key
# - -out: Output file for the key
# - 2048: Key size in bits (minimum recommended)
openssl genrsa -out server.key 2048

# Generate a Certificate Signing Request (CSR)
# - -new: Create new CSR
# - -key: Use this private key
# - -out: Output file for CSR
# - -subj: Subject DN (avoids interactive prompts)
openssl req -new -key server.key -out server.csr \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=example.com"
```

## Exercise Guidelines

### Difficulty Levels

- **Beginner** (Labs 01-05):
  - Clear step-by-step instructions
  - Expected output shown
  - Minimal decision-making required

- **Intermediate** (Labs 06-14):
  - Some steps require thinking
  - Multiple valid approaches
  - Troubleshooting included

- **Advanced** (Labs 15-22):
  - Real-world complexity
  - Problem-solving required
  - Minimal hand-holding

### RHEL Version Considerations

Always specify RHEL version requirements:

```markdown
### RHEL Version Notes

| Step | RHEL 7 | RHEL 8 | RHEL 9 |
|------|--------|--------|--------|
| Install | `yum install` | `dnf install` | `dnf install` |
| Crypto-policy | N/A | `update-crypto-policies` | `update-crypto-policies` |
| OpenSSL | 1.0.2k | 1.1.1k | 3.x |
```

### Security Considerations

For labs involving security-sensitive operations:

```markdown
## ⚠️ Security Notes

- **Use VMs**: Practice in isolated virtual machines
- **Don't use in production**: These are learning exercises
- **Protect private keys**: Never commit real private keys
- **Self-signed only**: Use self-signed certs for learning
```

## Submission Process

### 1. Fork and Clone

```bash
git clone https://github.com/ernaniaz/CertificatesTutorial.git
cd CertificatesTutorial
```

### 2. Create Branch

```bash
git checkout -b add-lab-NN-description
# or
git checkout -b improve-lab-NN-description
```

### 3. Create Your Content

Follow the structure and guidelines above.

### 4. Test Thoroughly

```bash
# Test on RHEL 8
cd labs/en_US/NN-your-lab
./setup.sh
# Run through all exercises manually
./cleanup.sh

# Test on RHEL 9
# (repeat in different VM)
```

### 5. Update Documentation

Add entry to `labs/README.md` if adding a new lab.

### 6. Commit

```bash
git add labs/en_US/NN-your-lab/
git add labs/README.md
git commit -m "Add lab: NN-your-lab - Brief description"
```

### 7. Create Pull Request

Include:
- Description of the lab/changes
- Which chapters it supports
- RHEL versions tested
- Time to complete
- Any special requirements

## Quality Checklist

### New Labs

- [ ] Follows directory structure
- [ ] README uses template format
- [ ] Clear learning objectives
- [ ] Step-by-step instructions
- [ ] Expected outputs shown
- [ ] Troubleshooting section included
- [ ] Cleanup instructions provided
- [ ] Tested on target RHEL versions
- [ ] Scripts are executable and have shebangs
- [ ] No hardcoded paths that won't work elsewhere
- [ ] No real private keys or sensitive data

### Lab Improvements

- [ ] Original functionality preserved
- [ ] Changes documented in commit message
- [ ] Tested before and after changes
- [ ] Backwards compatible (or breaking changes noted)

### Translations

- [ ] All explanatory text translated
- [ ] Commands remain in English
- [ ] File paths remain unchanged
- [ ] Technical terms kept or explained
- [ ] Formatting preserved

## Testing Requirements

### Basic Tests

```bash
# Verify setup script works
./setup.sh

# Run through exercises
# (manual verification)

# Verify cleanup works
./cleanup.sh

# Verify clean state
ls /etc/pki/tls/certs/
```

### RHEL Version Matrix

Test on at least one version:

| Lab Type | Minimum Testing |
|----------|-----------------|
| Fundamentals | RHEL 8 or 9 |
| Services | RHEL 8 and 9 |
| Automation | RHEL 8 and 9 |
| Migration | Source and target versions |
| FIPS | RHEL 8 or 9 |

## Platform Compatibility

Target platforms:
- RHEL 7 (where applicable, nearing EOL)
- RHEL 8 (primary)
- RHEL 9 (primary)
- RHEL 10 (when available)

Note: Labs should also work on:
- CentOS Stream 8/9
- Rocky Linux 8/9
- AlmaLinux 8/9

Document any platform-specific requirements in README.

## Getting Help

- **Questions**: Open a GitHub Discussion
- **Issues**: File a GitHub Issue
- **Style questions**: Reference existing labs

## Recognition

Contributors are acknowledged in:
- Repository README
- Lab README files (if desired)
- Release notes

---

Thank you for helping learners master PKI and certificate management through hands-on practice!
