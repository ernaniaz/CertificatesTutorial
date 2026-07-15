# Appendix E: PKI Policy Theory

## Policies, Baselines & Audits

## 1. Why Policies Matter

Policies formalise *how* certificates may be issued and used, ensuring consistency and legal defensibility.

## 2. Baseline Requirements (CAB Forum)

Requirements that publicly-trusted CAs must follow, including:

* Domain validation methods
* Key sizes ≥ 2048-bit RSA / 256-bit ECC
* Maximum validity 398 days

## 3. Certificate Policy (CP) vs CPS

| Document | Audience | Content |
|----------|----------|---------|
| CP | Relying parties | What assurance the PKI provides |
| CPS | Auditors, operators | *How* the CA meets the CP |

## 4. Audits & Compliance

* **WebTrust / ETSI** audits for public CAs.
* Internal PKIs may align with NIST SP 800-53 or ISO 27001.

## 5. RHEL Case Study

RHEL’s `certmonger` can automatically renew host certificates in accordance with enterprise CP/CPS guidelines.
