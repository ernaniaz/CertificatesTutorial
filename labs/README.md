# Labs Directory

This directory contains hands-on lab exercises for the RHEL Certificate Management Tutorial.

## Structure

```
labs/
├── en_US/               # English (US) labs
├── pt_BR/               # Portuguese (Brazil) labs
└── es_ES/               # Spanish (Spain) labs

Each locale contains 22 labs:
├── 01-environment-setup/
├── 02-key-generation/
├── 03-digital-signatures/
├── 04-x509-certificates/
├── 05-trust-store/
├── 06-apache-https/
├── 07-nginx-https/
├── 08-postfix-tls/
├── 09-openldap-ldaps/
├── 10-postgresql-tls/
├── 11-certmonger-basics/
├── 12-crypto-policies/
├── 13-letsencrypt-certbot/
├── 14-ansible-automation/
├── 15-troubleshooting-scenarios/    ⭐ PRIORITY
├── 16-emergency-procedures/
├── 17-rhel7to8-migration/
├── 18-rhel8to9-migration/
├── 19-fips-mode/
├── 20-security-hardening/
├── 21-kubernetes-cert-manager/
└── 22-vault-pki/
```

## Lab Structure

Typical lab directories contain:

```
{lab-number}-{lab-name}/
├── README.md                # Lab instructions (fully translated)
├── setup.sh or setup-*.sh   # Setup scripts (version-specific if needed)
├── verify*.sh / test*.sh    # Validation scripts when the lab provides them
├── cleanup*.sh              # Cleanup/restore scripts when the lab provides them
├── [additional scripts]     # Lab-specific scripts
└── [sample data files]      # Any required input files
```

## File Naming Convention

- **Lab directories:** `{number}-{descriptive-name}/`
- **Scripts:** Descriptive names with `.sh` extension
- All scripts must be executable: `chmod +x *.sh`

## Creating Labs

### Step 1: Create en_US Lab
1. Create lab directory structure
2. Write README.md with objectives, prerequisites, steps
3. Create the setup and validation flow documented for that lab
4. Test on RHEL 7, 8, 9, 10 (where applicable)
5. Ensure cleanup works properly

### Step 2: Translate to pt_BR
1. Translate README.md completely
2. Translate script comments
3. Translate output messages
4. Test functionality (commands stay the same)

### Step 3: Translate to es_ES
1. Translate README.md completely
2. Translate script comments
3. Translate output messages
4. Test functionality

## Script Standards

### Standard Header
```bash
#!/usr/bin/env bash
# Lab XX: [Script Purpose]
# [Brief description]

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Error handling
trap 'echo -e "${RED}Error on line $LINENO${NC}"' ERR
```

### Output Messages
Use colored output for clarity:
```bash
echo -e "${GREEN}✓ Success message${NC}"
echo -e "${RED}✗ Error message${NC}"
echo -e "${YELLOW}⚠ Warning message${NC}"
```

### Make Scripts Executable
```bash
chmod +x *.sh
```

## README Template

Each lab's README.md should follow this structure:

```markdown
# Lab XX: [Lab Name]

## Learning Objectives
- [Objective 1]
- [Objective 2]
- [Objective 3]

## Prerequisites
- Lab XX completed (if applicable)
- RHEL version requirements
- Additional requirements

## Time Estimate
XX-XX minutes

## Instructions

### Step 1: [Step Name]
[Detailed instructions]

```bash
# Commands to run
```

### Step 2: [Step Name]
[Detailed instructions]

## Validation
Run the validation command documented for that lab (often `./verify.sh`)

## Expected Output
```
[Example of expected output]
```

## Troubleshooting
### Issue 1
**Symptom:** [Description]
**Solution:** [Fix]

## Cleanup
Run `./cleanup.sh` to restore the system

## Next Steps
Proceed to Lab XX: [Next Lab Name]
```

## Translation Guidelines

### What to Translate
- ✅ README.md files (completely)
- ✅ Shell script comments
- ✅ Output messages (echo statements)
- ✅ Error messages
- ✅ Documentation files

### What NOT to Translate
- ❌ Command names (`openssl`, `getcert`, `systemctl`)
- ❌ File paths (`/etc/pki/`, `/etc/httpd/`)
- ❌ Configuration directives (`SSLCertificateFile`)
- ❌ Variable names in scripts
- ❌ System error messages (keep original in quotes, add translation)

### Example Translation
```bash
# en_US:
echo "✓ Certificate generated successfully"

# pt_BR:
echo "✓ Certificado gerado com sucesso"

# es_ES:
echo "✓ Certificado generado exitosamente"
```

## Priority Order

Create labs in this order:

1. **Foundation Labs (01-05)** - Essential prerequisites
2. **Troubleshooting Labs (15-16)** - Most critical ⭐
3. **Service Labs (06-10)** - Practical applications
4. **Automation Labs (11-14)** - Advanced usage
5. **Migration & Security (17-20)** - Specialized
6. **Appendix Labs (21-22)** - Advanced appendix topics

## Testing Requirements

### Test Each Lab On:
- ✅ RHEL 7 (if applicable)
- ✅ RHEL 8
- ✅ RHEL 9
- ✅ RHEL 10 (if available)

### Validation Criteria:
- ✅ Setup script completes without errors
- ✅ All steps can be executed successfully
- ✅ Verification script passes
- ✅ Cleanup restores original state
- ✅ Can be run multiple times safely

## Quality Checklist

Before marking a lab as complete:

- [ ] README.md clear and complete
- [ ] All scripts executable (`chmod +x`)
- [ ] Error handling in all scripts
- [ ] Colored output for user feedback
- [ ] Validation command documented and tested
- [ ] Cleanup/restore command documented where applicable
- [ ] Tested on target RHEL versions
- [ ] Translation complete (pt_BR, es_ES)
- [ ] Safe to run multiple times
- [ ] Documentation accurate

## Resources

- **Chapter References:** Each lab maps to specific chapters

## Lab Categories

### Foundation Labs (01-05)
Basic certificate operations and trust management

### Service Labs (06-10)
Configure TLS for RHEL services (Apache, NGINX, Postfix, LDAP, PostgreSQL)

### Automation Labs (11-14)
Certificate lifecycle automation (certmonger, crypto-policies, certbot, Ansible)

### Troubleshooting Labs (15-16)
Systematic troubleshooting with real-world certificate scenarios (currently one implemented scenario)

### Migration Labs (17-18)
RHEL version upgrade procedures

### Security Labs (19-20)
FIPS mode and security hardening

### Appendix Labs (21-22)
Advanced topics (Kubernetes, Vault)

## Status

**Total Labs:** 22 exercises
**Total Directories:** 66 (22 × 3 locales)
**Estimated Files:** ~330 scripts and documentation files
