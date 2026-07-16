# Complete PKI & Digital Certificates Tutorial

A comprehensive, multilingual tutorial covering Public Key Infrastructure (PKI), X.509 certificates, and cryptographic security from fundamentals to enterprise implementation.

![Languages](https://img.shields.io/badge/Language-English-blue)
![Languages](https://img.shields.io/badge/Language-Spanish-blue)
![Languages](https://img.shields.io/badge/Language-Portuguese-blue)
![Chapters](https://img.shields.io/badge/Chapters-41%20Chapters-green)
![Status](https://img.shields.io/badge/Status-Production%20Ready-success)

## 📚 Tutorial Overview

This tutorial provides **41 comprehensive chapters** across **7 major parts**, covering everything from basic cryptography to advanced RHEL certificate management, troubleshooting, and security. Currently available in **English**, **Spanish** and **Portuguese** with a complete RHEL-first approach.

### What You'll Learn

- **Cryptographic Fundamentals** — RSA, ECC, digital signatures, hash functions
- **X.509 Certificates** — Structure, extensions, validation, and trust chains
- **PKI Architecture** — CAs, RAs, HSMs, certificate hierarchies
- **Automation** — certmonger, crypto-policies, Let's Encrypt, certbot, Ansible
- **Service TLS** — Apache, NGINX, Postfix, OpenLDAP, PostgreSQL, MySQL, FreeIPA
- **Migration** — RHEL 7→8→9 upgrade procedures for certificates
- **Advanced Topics** — Kubernetes cert-manager, Vault, Zero Trust, IoT, VPNs (appendices)
- **Troubleshooting** — Common issues and solutions

## 🌍 Language Status

- 🇺🇸 **English (en_US)** — 41/41 chapters ✅ **PRODUCTION READY**
  - Complete RHEL-first reorganization
  - All corrections applied
  - Production-quality content

- 🇪🇸 **Spanish (es_ES)** — 41/41 chapters ✅ **PRODUCTION READY**
  - ✅ **100% COMPLETE!** (November 18, 2025)
  - All 41 chapters translated
  - All 9 appendices translated
  - All 3 quick guides translated
  - Professional-quality translation
  - Ready for Spanish-speaking students

- 🇧🇷 **Portuguese (pt_BR)** — 41/41 chapters ✅ **PRODUCTION READY**
  - ✅ **100% COMPLETE!** (November 18, 2025)
  - All 41 chapters translated
  - All 9 appendices translated
  - All 3 quick guides translated
  - Professional-quality translation
  - Ready for Portuguese-speaking students

**Status:** Both Spanish and Portuguese translations complete and production-ready!

## 📖 Tutorial Structure

### Part 01 — RHEL Certificate Fundamentals (Chapters 1-7)
- Cryptography, PKI Structure & Fundamentals
- Introduction to Certificates on RHEL
- RHEL Certificate Tools Overview
- Basic Cryptography for RHEL Admins
- X.509 Certificates on RHEL
- RHEL Trust Store Deep Dive
- Digital Signatures & Verification

### Part 02 — RHEL Version-Specific Management (Chapters 8-13)
- RHEL Versions & Certificate Evolution
- RHEL 7 Certificate Management
- RHEL 8 & Crypto-Policies
- RHEL 9 Modern Security
- RHEL 10 Current Features
- Cross-Version Compatibility

### Part 03 — RHEL Services & TLS Configuration (Chapters 14-21)
- Apache httpd on RHEL
- NGINX on RHEL
- Postfix Mail Server TLS
- OpenLDAP & Directory Services
- Database TLS (PostgreSQL, MySQL)
- FreeIPA Certificate Services
- Other RHEL Services
- Service Certificate Best Practices

### Part 04 — Automation (Chapters 22-26)
- certmonger Mastery
- Crypto-Policies Deep Dive
- Let's Encrypt & certbot
- Ansible Automation
- Monitoring & Alerting

### Part 05 - Troubleshooting (Chapters 27-33)
- Troubleshooting Methodology
- Common RHEL Certificate Errors
- Service-Specific Troubleshooting
- certmonger Troubleshooting
- Crypto-Policy Troubleshooting
- SOS Report Analysis
- Emergency Procedures

### Part 06 - Migration & Upgrades (Chapters 34-37)
- Migration Planning & Preparation
- RHEL 7→8 Migration
- RHEL 8→9 Migration
- Migration Troubleshooting

### Part 07: Security & FIPS (Chapters 38-41)
- FIPS Mode Complete Guide
- FIPS-Compliant Certificates
- RHEL Security Hardening
- Compliance & Auditing

## 🚀 Quick Start

**Choose your preferred method:**

### Option 1: View Online (Easiest) 🌐

Access the deployed tutorial on GitHub Pages:
[https://ernaniaz.github.io/CertificatesTutorial/](https://ernaniaz.github.io/CertificatesTutorial/)

### Option 2: Build Locally 💻

**Step 1:** Install prerequisites
```bash
# Install Rust (includes cargo)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# Install mdBook and mdbook-mermaid
cargo install mdbook mdbook-mermaid
```

**Step 2:** Build and view
```bash
cd docs/en_US
mdbook-mermaid install
mdbook serve --open
```

Access at `http://localhost:3000`

📖 **See [QUICKSTART.md](QUICKSTART.md) for detailed instructions and learning paths.**

## 🌐 Deployment

### GitHub Pages (Automatic)

This tutorial includes automatic GitHub Pages deployment via GitHub Actions.

**Setup Steps:**
1. Push repository to GitHub
2. Enable GitHub Pages in Settings → Pages → Source: **GitHub Actions**
3. Push triggers automatic build and deployment
4. Access at `https://ernaniaz.github.io/CertificatesTutorial/`

📘 **Full deployment guide:** [DEPLOYMENT.md](DEPLOYMENT.md)

### Alternative Hosting

The tutorial can also be deployed to:
- **Netlify** — Drag & drop `docs/book/` folder
- **Vercel** — Connect GitHub repo
- **Self-hosted** — Any web server (Apache, NGINX)
- **AWS S3** — Static website hosting
- **Azure Static Web Apps** — Deploy from GitHub

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed instructions.

## 📂 Project Structure

```
Certificates Tutorial/
├── README.md                  # This file
├── QUICKSTART.md              # Quick start guide
├── BUILD_INSTRUCTIONS.md      # Build instructions
├── DEPLOYMENT.md              # Deployment guide
├── labs/                      # Lab materials (151 scripts per language)
│
└── docs/
    ├── build-all.sh           # Build script
    ├── serve-all.sh           # Serve script
    ├── mermaid.min.js         # Diagram rendering library
    ├── mermaid-init.js        # Diagram initialization
    │
    ├── en_US/                 # English content
    │   ├── book.toml
    │   ├── SUMMARY.md
    │   ├── README.md
    │   ├── LEARNING-PATH.md
    │   ├── RHEL-VERSION-CHEAT-SHEET.md
    │   ├── TROUBLESHOOTING-QUICK-START.md
    │   ├── part-01-fundamentals/      (7 chapters)
    │   ├── part-02-version-specific/  (6 chapters)
    │   ├── part-03-services/          (8 chapters)
    │   ├── part-04-automation/        (5 chapters)
    │   ├── part-05-troubleshooting/   (7 chapters)
    │   ├── part-06-migration/         (4 chapters)
    │   ├── part-07-security/          (4 chapters)
    │   └── appendices/                (9 appendices)
    │
    ├── es_ES/                 # Spanish content (same structure)
    │
    ├── pt_BR/                 # Portuguese content (same structure)
    │
    └── book/                  # Generated HTML output
        ├── en_US/
        ├── es_ES/
        └── pt_BR/
```

## 🎯 Use Cases

### For Students
- Learn PKI from scratch with clear explanations and diagrams
- Follow hands-on labs to build practical skills
- Reference glossary and troubleshooting guide

### For System Administrators
- Implement TLS across various services (web, database, LDAP, SMTP)
- Set up internal PKI with FreeIPA or OpenSSL
- Automate certificate management with certbot or cert-manager

### For DevOps Engineers
- Integrate certificate automation in CI/CD pipelines
- Deploy mTLS in Kubernetes with Istio/Linkerd
- Use Vault for dynamic certificate issuance

### For Security Architects
- Design enterprise PKI hierarchies
- Implement Zero Trust with certificate-based device identity
- Plan certificate lifecycle management at scale

### For Developers
- Secure APIs with client certificates
- Implement mTLS in applications (Python, Go, Node.js)
- Sign code and container images

## 🛠️ Technologies Covered

### Tools & Software
- OpenSSL, FreeIPA, EJBCA, step-ca
- Certbot, cert-manager, certmonger
- HashiCorp Vault
- Kong API Gateway
- Docker, Kubernetes

### Protocols & Standards
- TLS 1.2 & 1.3
- ACME (RFC 8555)
- OCSP (RFC 6960)
- EST (RFC 7030)
- X.509 (RFC 5280)
- Certificate Transparency (RFC 6962)

### Platforms & Services
- Apache HTTP Server, NGINX, HAProxy
- PostgreSQL, MySQL, Redis, MongoDB
- OpenLDAP, Postfix
- AWS IoT Core, Azure IoT Hub
- OpenVPN, strongSwan, WireGuard

## 📊 Statistics

- **Total Chapters:** 41 comprehensive chapters
- **Total Parts:** 7 major parts + 9 appendices
- **RHEL Versions Covered:** RHEL 7, 8, 9, and 10
- **Code Examples:** 450+ production-ready scripts (151 per language)
- **Diagrams:** 50+ interactive SVG diagrams per language
- **Content:** ~27,000 lines of professional content
- **Languages:** English, Spanish & Portuguese

### Content Breakdown:
- **Part 01:** RHEL Certificate Fundamentals (7 chapters)
- **Part 02:** Version-Specific Management (6 chapters)
- **Part 03:** Services & TLS Configuration (8 chapters)
- **Part 04:** Certificate Automation (5 chapters)
- **Part 05:** Troubleshooting (7 chapters) ⭐ Primary Focus
- **Part 06:** Migration & Upgrades (4 chapters)
- **Part 07:** Security & FIPS (4 chapters)
- **Appendices:** 9 reference sections

## 🔧 Customization

### Adding Content

1. Edit Markdown files in `docs/en_US/`, `docs/es_ES/`, or `docs/pt_BR/`
2. Update the respective `docs/<LANGUAGE>/SUMMARY.md` if adding new chapters
3. Rebuild: `cd docs/<LANGUAGE> && mdbook build`

### Styling

To customize styling, modify the language-specific `book.toml` (e.g., `docs/en_US/book.toml`):

```toml
[output.html]
additional-css = ["custom.css"]
```

### Adding Languages

Spanish (es_ES) and Portuguese (pt_BR) translations are available. The clean English version serves as the single source of truth for translations.

1. Create new language directory (e.g., `docs/es_ES/`)
2. Copy structure from `docs/en_US/`
3. Translate all markdown files
4. Create a `book.toml` and `SUMMARY.md` in the new language directory
5. Rebuild

## 📝 Contributing

This is a complete, production-ready tutorial. To contribute:

1. Fork the repository
2. Create your feature branch
3. Make your changes
4. Test with `cd docs/<LANGUAGE> && mdbook build`
5. Submit a pull request

## 📄 License

This work is licensed under a [Creative Commons Attribution 4.0 International License (CC BY 4.0)](LICENSE.md).

You are free to share and adapt this material for any purpose, including commercially, as long as you give appropriate credit to the original author. See the [full license text](LICENSE.md) for details.

## 🙏 Acknowledgments

Built with:
- [mdBook](https://rust-lang.github.io/mdBook/) — Rust-based documentation builder
- [mdbook-mermaid](https://github.com/badboy/mdbook-mermaid) — Mermaid diagram support
- [Mermaid.js](https://mermaid.js.org/) — Diagram and flowchart library

Inspired by industry best practices from:
- IETF RFCs (5280, 6960, 8555, 8446)
- NIST Special Publications (800-57, 800-207, 800-52)
- CAB Forum Baseline Requirements
- Let's Encrypt, HashiCorp Vault, cert-manager communities

## 📞 Support

For issues or questions:
- Check the **Troubleshooting Guide** (Chapter 27)
- Consult the **Glossary** (Appendix H)
- Review **References** (Appendix I)

## 🎓 Target Audience

- System Administrators
- DevOps Engineers
- Security Professionals
- Software Developers
- IT Students
- Security Architects

**Skill Level:** Beginner to Advanced (progressive difficulty)

---

## 🌟 Start Learning Now!

```bash
cd docs/en_US
mdbook-mermaid install
mdbook serve --open
```

**Happy Learning!** 🎉

---

**Author**: Ernani Azevedo <azevedo@voipdomain.io>  
**Repository**: [github.com/ernaniaz/CertificatesTutorial](https://github.com/ernaniaz/CertificatesTutorial)  
**License**: [CC BY 4.0](LICENSE.md)  
**Total Chapters**: 41 Chapters + 9 Appendices  
**Languages**: English, Spanish and Portuguese  
