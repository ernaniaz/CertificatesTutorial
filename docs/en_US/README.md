# PKI & Digital Certificates Tutorial

**A comprehensive guide to mastering certificates on Red Hat Enterprise Linux.**

---

## 📘 About This Tutorial

This tutorial teaches you everything about digital certificates on RHEL, from complete beginner to expert troubleshooter.

**Primary Goal:** Enable you to confidently troubleshoot certificate issues on RHEL systems.

**Coverage:**
- All RHEL versions (7, 8, 9, 10)
- All major services (Apache, NGINX, Postfix, LDAP, Databases, FreeIPA)
- Complete automation (certmonger, crypto-policies, Ansible)
- Expert troubleshooting
- Migration guidance
- FIPS and compliance

---

## 🎯 Who This Is For

- **RHEL Administrators** - Manage certificates professionally
- **Support Engineers** - Troubleshoot certificate issues
- **Security Teams** - Implement FIPS and compliance
- **DevOps Engineers** - Automate certificate lifecycle
- **Anyone** - Who manages RHEL systems with TLS/SSL

**Prerequisites:**
- Basic Linux command line knowledge
- Access to RHEL systems (VM is fine)
- No prior certificate knowledge needed!

---

## 📚 Tutorial Structure

### PART 01: Fundamentals (Chapters 1-7)
Introduction to certificates in RHEL context.

### PART 02: Version-Specific Management (Chapters 8-13) ⭐
Deep dive into RHEL 7, 8, 9, 10 differences.

### PART 03: Services & TLS Configuration (Chapters 14-21) ⭐
Configure certificates for all major RHEL services.

### PART 04: Certificate Automation (Chapters 22-26) ⭐
Automate certificate lifecycle with RHEL tools.

### PART 05: Troubleshooting (Chapters 27-33) ⭐
Master systematic troubleshooting - the core objective!

### PART 06: Migration & Upgrades (Chapters 34-37) ⭐
Handle RHEL version migrations safely.

### PART 07: Security & FIPS (Chapters 38-41) ⭐
FIPS compliance, security hardening, auditing.

---

## 🚀 Quick Start

### Complete Beginners
Start with [Chapter 1: Cryptography, PKI Structure & Fundamentals](part-01-fundamentals/01-cryptography-pki-basics.md), then continue through Chapter 2 and beyond in order

### Need to Troubleshoot Now?
Jump to [Chapter 27: Troubleshooting Methodology](part-05-troubleshooting/27-troubleshooting-methodology.md)

### Emergency?
[Chapter 33: Emergency Procedures](part-05-troubleshooting/33-emergency-procedures.md)

---

## 📖 Key Chapters

**Must-Read:**
- **Ch 1:** Cryptography, PKI Structure & Fundamentals - Start here
- **Ch 27:** Troubleshooting Methodology - Core skill
- **Ch 28:** Common RHEL Certificate Errors - Quick reference

**By RHEL Version:**
- **Ch 9:** RHEL 7 (legacy)
- **Ch 10:** RHEL 8 (crypto-policies!)
- **Ch 11:** RHEL 9 (modern)
- **Ch 12:** RHEL 10 (current)

**By Service:**
- **Ch 14:** Apache
- **Ch 15:** NGINX
- **Ch 16:** Postfix
- **Ch 17:** OpenLDAP
- **Ch 18:** Databases
- **Ch 19:** FreeIPA

**For Automation:**
- **Ch 22:** certmonger Mastery
- **Ch 23:** Crypto-Policies

---

## 🎓 Learning Outcomes

After completing this tutorial, you will be able to:

✅ Understand how certificates work on RHEL
✅ Configure certificates for any RHEL service
✅ Automate certificate lifecycle management
✅ **Troubleshoot any certificate issue** ⭐
✅ Handle RHEL version migrations
✅ Meet FIPS and compliance requirements
✅ Work confidently across RHEL 7, 8, 9, and 10

---

## 📊 Tutorial Statistics

- **41 Chapters** covering all main topics
- **27,000+ lines** of content
- **151 lab scripts** included
- **90+ comparison tables**
- **32 quick reference cards**
- **50+ troubleshooting procedures**

---

## 🔧 Hands-On Approach

**Every chapter includes:**
- Practical examples
- Copy-paste ready commands
- Real-world scenarios
- Troubleshooting sections
- Quick reference cards
- Production scripts

**You'll learn by DOING, not just reading!**

---

## 📝 Additional Resources

**Quick References:**
- [Troubleshooting Quick-Start](TROUBLESHOOTING-QUICK-START.md) - First aid
- [RHEL Version Cheat Sheet](RHEL-VERSION-CHEAT-SHEET.md) - Version differences
- [Learning Path Guide](LEARNING-PATH.md) - How to use this tutorial

**Documentation:**
- Each chapter has "Quick Reference Card" at the end
- Decision trees and flowcharts throughout
- Comprehensive troubleshooting in Part 05

---

## 🎯 Success Path

1. **Read** [Learning Path Guide](LEARNING-PATH.md) to choose your path
2. **Start** with Chapter 1 or jump to your area of interest
3. **Practice** on RHEL systems as you learn
4. **Reference** troubleshooting chapters when needed
5. **Master** RHEL certificate management!

---

## ⭐ What Makes This Tutorial Special

**RHEL-First Approach:**
- Not generic PKI, but RHEL-specific from sentence one
- Version-aware (covers RHEL 7, 8, 9, 10)
- Production-focused

**Troubleshooting Mastery:**
- Systematic 7-step methodology
- Common errors cataloged
- Service-specific guidance
- Emergency procedures

**Complete Coverage:**
- All RHEL versions
- All major services
- Complete automation
- Migration guidance
- FIPS/compliance

---

## 📞 How to Use

**Building the Book:**
```bash
cd /path/to/docs/en_US
mdbook-mermaid install
mdbook build
```

**Viewing Locally:**
```bash
mdbook-mermaid install
mdbook serve --open
```

**Navigating:**
- Use the sidebar for chapter navigation
- Quick reference cards at end of each chapter
- Cross-references throughout

---

## 🎊 Start Learning!

**Begin your journey:** [Chapter 1: Cryptography, PKI Structure & Fundamentals →](part-01-fundamentals/01-cryptography-pki-basics.md)

**From zero to RHEL certificate expert in 41 chapters!** 🚀

---

**Author**: Ernani Azevedo <azevedo@voipdomain.io>  
**Repository**: [github.com/ernaniaz/CertificatesTutorial](https://github.com/ernaniaz/CertificatesTutorial)  
**License**: [CC BY 4.0](../../LICENSE.md)
