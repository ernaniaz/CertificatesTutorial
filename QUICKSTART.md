# Quick Start Guide

Get started with the PKI & Digital Certificates Tutorial in under 5 minutes.

## ⚡ Fastest Path to Learning

### Option 1: View Pre-built Online (Recommended)

Once deployed to GitHub Pages: [https://ernaniaz.github.io/CertificatesTutorial/](https://ernaniaz.github.io/CertificatesTutorial/)

No installation needed. Open in browser and start learning.

---

### Option 2: Build & View Locally

#### Step 1: Install Prerequisites

**On Linux (Fedora/RHEL 8+):**

```bash
# Install cargo (includes Rust)
dnf install cargo

# Or install Rust manually
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# Install mdBook and mdbook-mermaid
cargo install mdbook mdbook-mermaid
```

**On macOS:**

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Or use Homebrew for mdbook
brew install mdbook
cargo install mdbook-mermaid
```

**On Windows:**

```powershell
# Install Rust from https://rustup.rs/
# Then in PowerShell:
cargo install mdbook mdbook-mermaid
```

#### Step 2: Clone & Build

Each language has its own independent book. Pick one (or build all):

```bash
# Build English version
cd docs/en_US
mdbook-mermaid install
mdbook build
cd ../..

# Build Spanish version
cd docs/es_ES
mdbook-mermaid install
mdbook build
cd ../..

# Build Portuguese version
cd docs/pt_BR
mdbook-mermaid install
mdbook build
cd ../..

# Or build all at once
cd docs
./build-all.sh
```

#### Step 3: View

**Option A: Local Server (Recommended)**

```bash
cd docs/en_US
mdbook serve --open
```

Access at: `http://localhost:3000`

To serve multiple languages simultaneously, open separate terminals (or use the serve script):

**Terminal 1 (English):**
```bash
cd docs/en_US && mdbook serve --port 3000
```

**Terminal 2 (Spanish):**
```bash
cd docs/es_ES && mdbook serve --port 3001
```

**Terminal 3 (Portuguese):**
```bash
cd docs/pt_BR && mdbook serve --port 3002
```

Or serve all three from one command:
```bash
cd docs
./serve-all.sh
```

**Option B: Static Files**

```bash
firefox docs/book/en_US/index.html
# or
xdg-open docs/book/en_US/index.html
```

---

## Tutorial Structure

The tutorial has **41 chapters** across **7 parts** plus **9 appendices**, available in English, Spanish, and Portuguese.

| Part | Chapters | Topic |
|------|----------|-------|
| **01** | 1–7 | RHEL Certificate Fundamentals |
| **02** | 8–13 | RHEL Version-Specific Management |
| **03** | 14–21 | RHEL Services & TLS Configuration |
| **04** | 22–26 | RHEL Certificate Automation |
| **05** | 27–33 | RHEL Certificate Troubleshooting |
| **06** | 34–37 | RHEL Migration & Upgrades |
| **07** | 38–41 | RHEL Security & FIPS |
| **Appendices** | A–I | Advanced Topics (Kubernetes, Vault, Zero Trust, IoT, etc.) |

---

## Tutorial Navigation

### English

- **Online:** [https://ernaniaz.github.io/CertificatesTutorial/en_US/](https://ernaniaz.github.io/CertificatesTutorial/en_US/)
- **Local:** `docs/book/en_US/index.html`

### Spanish (Español)

- **Online:** [https://ernaniaz.github.io/CertificatesTutorial/es_ES/](https://ernaniaz.github.io/CertificatesTutorial/es_ES/)
- **Local:** `docs/book/es_ES/index.html`

### Portuguese (Português)

- **Online:** [https://ernaniaz.github.io/CertificatesTutorial/pt_BR/](https://ernaniaz.github.io/CertificatesTutorial/pt_BR/)
- **Local:** `docs/book/pt_BR/index.html`

---

## 🎯 Learning Paths

### Path 1: Complete Beginner

**Goal:** Understand PKI and RHEL certificates from scratch

1. **Part 01: Fundamentals** — Chapters 1–7 (cryptography, X.509, trust stores)
2. **Part 02: Version Mastery** — Chapters 8–13 (RHEL 7, 8, 9, 10 differences)
3. **Part 03: Services** — Chapters 14–21 (Apache, NGINX, Postfix, LDAP, databases, FreeIPA)
4. **Part 04: Automation** — Chapters 22–26 (certmonger, crypto-policies, Ansible)
5. **Part 05: Troubleshooting** — Chapters 27–33 (methodology, common errors, emergencies)
6. **Part 06: Migration** — Chapters 34–37 (RHEL version upgrades)
7. **Part 07: Security & FIPS** — Chapters 38–41 (FIPS, hardening, compliance)
8. Reference **Appendix H** (Glossary) and **Appendix I** (References) as needed

**Time:** ~8 weeks

---

### Path 2: System Administrator

**Goal:** Configure and maintain certificates in production

1. **Ch 1** — Cryptography, PKI Structure & Fundamentals
2. **Ch 3** — RHEL Certificate Tools Overview
3. **Ch 9–12** — Your RHEL version (RHEL 7, 8, 9, or 10)
4. **Ch 14–20** — Pick chapters for the services you manage
5. **Ch 22** — certmonger Mastery
6. **Ch 23** — Crypto-Policies Deep Dive (RHEL 8+)
7. **Ch 27** — Troubleshooting Methodology

**Keep handy:** Chapters 28–33 (troubleshooting reference)

**Time:** ~10–15 hours

---

### Path 3: Support Engineer

**Goal:** Troubleshoot certificate issues fast

1. **Ch 27** — Troubleshooting Methodology
2. **Ch 28** — Common RHEL Certificate Errors
3. **Ch 29** — Service-Specific Troubleshooting
4. **Ch 30** — certmonger Troubleshooting
5. **Ch 31** — Crypto-Policy Troubleshooting
6. **Ch 32** — SOS Report Analysis
7. **Ch 33** — Emergency Procedures

**Also useful:** Ch 3 (Tools), Ch 9–12 (version-specific chapters)

**Time:** ~5–8 hours

---

### Path 4: Enterprise/Security Architect

**Goal:** Design certificate infrastructure and ensure compliance

1. **Ch 1–2** — Fundamentals overview
2. **Ch 19** — FreeIPA Certificate Services
3. **Ch 22–23** — certmonger & Crypto-Policies
4. **Ch 25** — Ansible Automation
5. **Ch 38–41** — FIPS, hardening, compliance, auditing
6. **Appendix C** — Zero Trust Architecture
7. **Appendix E** — PKI Policy Theory

**Time:** ~13 hours

---

### Path 5: DevOps Engineer

**Goal:** Automate certificate management

1. **Ch 1** — Cryptography & PKI fundamentals (quick refresher)
2. **Ch 22** — certmonger Mastery
3. **Ch 24** — Let's Encrypt & certbot
4. **Ch 25** — Ansible Automation
5. **Ch 26** — Monitoring & Alerting
6. **Appendix A** — Kubernetes cert-manager
7. **Appendix B** — HashiCorp Vault PKI
8. **Appendix D** — DevSecOps Integration

**Time:** ~8–10 hours

---

For more detailed learning paths, see [docs/en_US/LEARNING-PATH.md](docs/en_US/LEARNING-PATH.md).

---

## 🔥 Power User Tips

### Search Functionality

Use the built-in search (press `s` or click search icon) to find:
- Specific commands (e.g., "openssl x509")
- Concepts (e.g., "OCSP stapling")
- Tools (e.g., "certbot")

### Keyboard Shortcuts

- `s` — Focus search
- `←` `→` — Navigate chapters
- `/` — Search page

### Bookmarks

Bookmark frequently referenced chapters:
- **Ch 27:** Troubleshooting Methodology (your go-to for fixing issues)
- **Appendix H:** Glossary (quick term lookups)
- **Ch 3:** RHEL Certificate Tools Overview (command reference)
- **RHEL Version Cheat Sheet** (quick version differences)

### Print-Friendly

Click the print icon for printer-optimized view of any chapter.

---

## 🛠 Development Workflow

### Edit → Build → View Cycle

```bash
# Terminal 1: Auto-rebuild on changes
cd docs/en_US
mdbook-mermaid install
mdbook serve

# Terminal 2: Edit content
vi part-01-fundamentals/01-cryptography-pki-basics.md

# Browser: Auto-refreshes at http://localhost:3000
```

### Adding New Content

1. Create new `.md` file in appropriate part directory
2. Add entry to `docs/<LANGUAGE>/SUMMARY.md`:
   ```markdown
   - Your Chapter Title -> path/to/file.md
   ```
3. Rebuild: `cd docs/<LANGUAGE> && mdbook build`
4. Commit and push to trigger deployment

---

## 📱 Mobile Access

The tutorial is fully responsive and works on smartphones, tablets, laptops, and desktops. Mermaid diagrams are interactive and scale to screen size.

---

## 🎓 Recommended Learning Schedule

### Intensive (1 Week)
- **Day 1–2:** Part 01 — Fundamentals (Chapters 1–7)
- **Day 3:** Part 02 — Version-Specific Management (Chapters 8–13)
- **Day 4:** Part 03 — Services & TLS (Chapters 14–21)
- **Day 5:** Part 04 — Automation (Chapters 22–26)
- **Day 6:** Part 05 — Troubleshooting (Chapters 27–33)
- **Day 7:** Parts 06–07 — Migration & Security (Chapters 34–41)

### Moderate (2 Weeks)
- **Week 1:** Theory & Configuration (Parts 01–04)
- **Week 2:** Troubleshooting, Migration & Security (Parts 05–07)

### Self-Paced (1 Month)
- **Weeks 1–2:** Fundamentals, Versions & Services (Parts 01–03)
- **Week 3:** Automation & Troubleshooting (Parts 04–05)
- **Week 4:** Migration, Security & Appendices (Parts 06–07 + Appendices)

---

## ✅ First Steps Checklist

New to the tutorial? Follow this checklist:

- [ ] Open the tutorial in browser
- [ ] Read Chapter 1: Cryptography, PKI Structure & Fundamentals
- [ ] Bookmark the tutorial URL
- [ ] Choose your learning path (above)
- [ ] Explore the RHEL Certificate Tools Overview (Chapter 3)
- [ ] Reference Glossary (Appendix H) when encountering new terms
- [ ] Keep Troubleshooting Methodology (Chapter 27) bookmarked for when you need it

---

## 🆘 Getting Help

**Built-in Resources:**
1. **Chapter 27:** Troubleshooting Methodology
2. **Chapters 28–33:** Error catalogs, service-specific fixes, emergency procedures
3. **Appendix H:** Glossary (term definitions)
4. **Appendix I:** References (external resources)

**Quick References (inside the tutorial):**
- [Troubleshooting Quick-Start](docs/en_US/TROUBLESHOOTING-QUICK-START.md)
- [RHEL Version Cheat Sheet](docs/en_US/RHEL-VERSION-CHEAT-SHEET.md)
- [Learning Path Guide](docs/en_US/LEARNING-PATH.md)

**Community:**
- Let's Encrypt Community: https://community.letsencrypt.org/
- r/netsec (Reddit): https://www.reddit.com/r/netsec/

**Testing Tools:**
- SSL Labs: https://www.ssllabs.com/ssltest/
- testssl.sh: https://testssl.sh/

---

## 🎉 Ready to Start?

```bash
cd docs/en_US
mdbook-mermaid install
mdbook serve --open
```

Start learning at Chapter 1. 📖

---

*For build details, see [BUILD_INSTRUCTIONS.md](BUILD_INSTRUCTIONS.md)*  
*For deployment options, see [DEPLOYMENT.md](DEPLOYMENT.md)*  
*For full documentation, see [README.md](README.md)*
