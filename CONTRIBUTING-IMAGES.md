# Contributing Images to the Certificates Tutorial

Thank you for your interest in contributing diagrams and visual aids to the PKI & Digital Certificates Tutorial!

## Overview

This tutorial uses **52 SVG diagrams** to help visualize PKI and certificate management concepts. Images are stored per locale in `docs/<LOCALE>/images/` (e.g., `docs/en_US/images/`, `docs/pt_BR/images/`, `docs/es_ES/images/`) and follow consistent style guidelines.

## Before You Start

1. Check existing diagrams in `docs/<LOCALE>/images/` for style reference
2. Review the naming conventions below
3. Ensure your contribution fills a gap or improves existing content

## Image Requirements

### Format

- **Primary**: SVG (Scalable Vector Graphics)
  - Scalable to any resolution
  - Editable with vector tools
  - Small file size
  - Text remains selectable

- **Secondary**: PNG (only for screenshots or complex renders)
  - Minimum 1920x1080 for full diagrams
  - 300 DPI for print quality

- **Avoid**: JPEG (lossy compression unsuitable for diagrams)

### File Naming

```
part-[PART_NUMBER]-[DESCRIPTION].svg
appendix-[LETTER]-[DESCRIPTION].svg

Examples:
- part-01-symmetric-vs-asymmetric.svg
- part-03-apache-ssl-flow.svg
- part-05-troubleshooting-7-steps.svg
- appendix-A-cert-manager-architecture.svg
```

### Diagram Categories

| Part | Topic | Example Files |
|------|-------|---------------|
| Part 01 | Fundamentals | `part-01-x509-structure.svg`, `part-01-rhel-trust-hierarchy.svg` |
| Part 02 | Version-Specific | `part-02-rhel-versions-timeline.svg` |
| Part 03 | Services | `part-03-apache-ssl-flow.svg`, `part-03-nginx-ssl-flow.svg` |
| Part 04 | Automation | `part-04-certmonger-architecture.svg` |
| Part 05 | Troubleshooting | `part-05-diagnostic-flowchart.svg` |
| Part 06 | Migration | `part-06-migration-checklist-flow.svg` |
| Part 07 | Security | `part-07-fips-architecture.svg` |
| Appendices | Advanced | `appendix-A-cert-manager-architecture.svg` |

### Dimensions

- **Standard diagram**: 1000x700 pixels (viewBox)
- **Wide diagrams**: 1000x800 pixels
- **Tall diagrams**: 1000x900 pixels
- **Cheat sheets**: 1000x750 pixels

## Style Guidelines

### Color Palette (Colorblind-Friendly)

```css
/* Primary Colors */
--blue: #1976D2;      /* Headers, primary elements, secure connections */
--green: #388E3C;     /* Success, valid certificates, secure */
--orange: #F57C00;    /* Warnings, pending, decisions */
--red: #E53935;       /* Errors, expired, revoked */
--purple: #7B1FA2;    /* Special, HashiCorp Vault, advanced */
--teal: #00ACC1;      /* Services, OpenLDAP, secondary elements */

/* Backgrounds */
--light-blue: #E3F2FD;
--light-green: #E8F5E9;   /* Success states */
--light-green-alt: #D4EDDA;
--light-orange: #FFF3E0;
--light-orange-alt: #FFF3CD;
--light-red: #FFEBEE;
--light-pink: #FCE4EC;
--light-gray: #FAFAFA;
--light-cyan: #E0F7FA;
--light-purple: #E1BEE7;

/* Text */
--dark-text: #333333;
--medium-text: #555555;
--light-text: #666666;

/* Borders */
--border: #BDBDBD;
--border-dark: #9E9E9E;
```

### Typography

```css
/* Titles */
.title {
    font-family: Arial, sans-serif;
    font-size: 22px;
    font-weight: bold;
    fill: #333;
}

/* Section headers */
.section-title {
    font-family: Arial, sans-serif;
    font-size: 14px;
    font-weight: bold;
}

/* Body text */
.label {
    font-family: Arial, sans-serif;
    font-size: 12px;
    fill: #333;
}

/* Small text */
.small {
    font-family: Arial, sans-serif;
    font-size: 10px;
    fill: #555;
}

/* Code/technical/commands */
.code {
    font-family: 'Courier New', monospace;
    font-size: 9px;
    fill: #333;
}

/* Minimum font size: 9px (for accessibility) */
```

### Layout Principles

1. **Clear hierarchy**: Title → Sections → Details
2. **Consistent spacing**: Use multiples of 10px
3. **Left-to-right flow**: For processes and workflows
4. **Top-to-bottom flow**: For hierarchies and certificate chains

### SVG Structure Template

```xml
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 700" width="1000" height="700">
  <defs>
    <style>
      .title { font-family: Arial, sans-serif; font-size: 22px; font-weight: bold; fill: #333; }
      .section-title { font-family: Arial, sans-serif; font-size: 14px; font-weight: bold; fill: #333; }
      .label { font-family: Arial, sans-serif; font-size: 12px; fill: #333; }
      .small { font-family: Arial, sans-serif; font-size: 10px; fill: #555; }
      .code { font-family: 'Courier New', monospace; font-size: 9px; fill: #333; }
      .arrow { stroke: #1976D2; stroke-width: 2; fill: none; marker-end: url(#arrowhead); }
    </style>
    <marker id="arrowhead" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto">
      <polygon points="0 0, 10 3, 0 6" fill="#1976D2" />
    </marker>
  </defs>

  <!-- Title -->
  <text x="500" y="30" text-anchor="middle" class="title">Diagram Title</text>

  <!-- Content groups -->
  <g id="section-1">
    <!-- Section content -->
  </g>
</svg>
```

## Diagram Types

### 1. Architecture Diagrams

Show system components and their relationships.

- Use boxes for components (CAs, services, trust stores)
- Arrows for certificate/key flow
- Color-code by security level or type
- Include legends when needed

**Examples**: `part-01-rhel-trust-hierarchy.svg`, `part-04-certmonger-architecture.svg`

### 2. Flowcharts

Show processes and decision points.

- Rectangles for actions
- Diamonds for decisions (validity checks, error conditions)
- Ovals for start/end
- Arrows with labels
- Color-code: green (success), orange (warning), red (error)

**Examples**: `part-05-diagnostic-flowchart.svg`, `part-06-migration-checklist-flow.svg`

### 3. Certificate Chain Diagrams

Show trust relationships.

- Root CA at top
- Intermediate CAs in middle
- End-entity certificates at bottom
- Clear arrow direction showing signing
- Include validity indicators

**Examples**: `part-01-x509-structure.svg`, `part-01-rhel-trust-hierarchy.svg`

### 4. Comparison Matrices

Compare tools, algorithms, or features.

- Header row with clear labels
- Consistent cell sizing
- Use colors for quick scanning (green=yes, red=no, orange=partial)
- Include legend

**Examples**: `part-02-compatibility-matrix.svg`, `part-05-common-errors-matrix.svg`

### 5. Service Flow Diagrams

Show TLS handshakes and certificate flows.

- Client on left, server on right
- Arrows showing request/response
- Include port numbers and protocols
- Show certificate validation steps

**Examples**: `part-03-apache-ssl-flow.svg`, `part-03-postfix-tls-flow.svg`

### 6. Timeline/Sequence Diagrams

Show events over time (renewals, migrations).

- Left-to-right or top-to-bottom
- Clear time/phase markers
- Distinct colors for different phases
- Annotations for key events

**Examples**: `part-02-rhel-versions-timeline.svg`, `part-04-renewal-process.svg`

## Creating Diagrams

### Recommended Tools

**Free:**
- [draw.io](https://app.diagrams.net/) - Web-based, exports SVG
- [Inkscape](https://inkscape.org/) - Full vector editor
- [Excalidraw](https://excalidraw.com/) - Hand-drawn style

**Commercial:**
- Adobe Illustrator
- Affinity Designer
- Sketch (macOS)

**Code-based:**
- Hand-coded SVG (recommended for consistency)
- [Mermaid](https://mermaid.js.org/) (for initial prototypes)
- [PlantUML](https://plantuml.com/)

### Hand-Coding SVG Tips

1. Use a text editor with XML/SVG support
2. Start from an existing diagram as template
3. Use `<defs>` for reusable styles and markers
4. Group related elements with `<g>`
5. Use meaningful IDs for elements
6. Test in multiple browsers
7. Validate XML structure

## Submission Process

### 1. Fork and Clone

```bash
git clone https://github.com/ernaniaz/CertificatesTutorial.git
cd CertificatesTutorial
```

### 2. Create Branch

```bash
git checkout -b add-diagram-part-XX-description
```

### 3. Add Your Diagram

Place in all locale image folders:
```bash
# English (primary)
docs/en_US/images/part-XX-your-diagram.svg

# Translated versions
docs/pt_BR/images/part-XX-your-diagram.svg
docs/es_ES/images/part-XX-your-diagram.svg
```

### 4. Update Markdown

Add image reference to the appropriate chapter:
```markdown
Image example -> ../images/part-XX-your-diagram.svg
```

### 5. Test

- Open SVG in browser
- Check all text is readable
- Verify colors are distinguishable
- Test at different zoom levels
- Verify markdown renders correctly

### 6. Commit and Push

```bash
git add docs/en_US/images/part-XX-your-diagram.svg
git add docs/pt_BR/images/part-XX-your-diagram.svg
git add docs/es_ES/images/part-XX-your-diagram.svg
git add docs/en_US/part-XX-chapter/chapter-file.md

git commit -m "Add diagram: part-XX-your-diagram"
git push origin add-diagram-part-XX-description
```

### 7. Create Pull Request

Include:
- Description of the diagram
- Which chapter(s) it supports
- Screenshot preview

## Quality Checklist

Before submitting, verify:

- [ ] SVG format with proper XML declaration
- [ ] Follows naming convention (`part-XX-description.svg`)
- [ ] Uses standard color palette
- [ ] Minimum 9px font size
- [ ] No embedded raster images
- [ ] Text is actual text (not paths)
- [ ] Tested in Chrome, Firefox, Safari
- [ ] Added to all 3 locale folders
- [ ] Referenced in appropriate markdown file
- [ ] No copyrighted content

## Localization

Each locale maintains its own complete images folder:

```
docs/en_US/images/    # English (primary/source)
docs/pt_BR/images/    # Portuguese (Brazil)
docs/es_ES/images/    # Spanish (Spain)
```

Diagrams needing translation for pt_BR and es_ES:

1. Flowcharts with decision text
2. Troubleshooting guides
3. Migration checklists
4. Quick reference guides

When contributing localized diagrams:
- Use the same filename as the English version
- Translate all visible text elements
- Maintain the same layout and structure

## Technical Diagrams (Minimal Translation)

Many technical diagrams can be mostly language-neutral:
- Certificate structures (X.509 fields)
- TLS handshake flows
- Command examples (keep English commands)
- Architecture diagrams

Translate only:
- Titles
- Section headers
- Descriptive labels

Keep in original language:
- Command syntax
- File paths
- Technical terms (CA, CSR, PEM, DER)

## Getting Help

- **Questions**: Open a GitHub Discussion
- **Issues**: File a GitHub Issue
- **Style questions**: Reference existing diagrams in `docs/en_US/images/`

## Recognition

Contributors are recognized in:
- Repository README
- Image metadata (if desired)
- Release notes

---

Thank you for helping make PKI and certificate concepts more accessible through visual learning!

*Last updated: 2025-12-03*
