# Deployment Guide

This guide covers various methods to deploy the PKI & Digital Certificates Tutorial online.

---

## Table of Contents

1. [GitHub Pages Deployment (Recommended)](#github-pages-deployment-recommended)
2. [Netlify](#netlify)
3. [Vercel](#vercel)
4. [Self-Hosted (Apache/NGINX)](#self-hosted-apachenginx)
5. [AWS S3 Static Website](#aws-s3-static-website)
6. [Azure Static Web Apps](#azure-static-web-apps)

---

## 🚀 GitHub Pages Deployment (Recommended)

GitHub Pages offers free hosting with automatic deployment via GitHub Actions.

### Prerequisites

- GitHub account
- Repository created on GitHub
- Git installed locally

### Setup Steps

#### 1. Push to GitHub

If you haven't already created a repository:

```bash
cd Certificates\ Tutorial

# Initialize git (if not already initialized)
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: PKI & Digital Certificates Tutorial"

# Add your GitHub repository as remote
git remote add origin https://github.com/ernaniaz/CertificatesTutorial.git

# Push to GitHub
git push -u origin main
```

#### 2. Enable GitHub Pages

1. Go to your repository on GitHub
2. Click **Settings** → **Pages** (in left sidebar)
3. Under **Source**, select **GitHub Actions**
4. Save changes

#### 3. Trigger Deployment

The GitHub Actions workflow (`.github/workflows/deploy.yml`) will automatically:
- Install mdBook and mdbook-mermaid
- Build the tutorial from Markdown sources
- Deploy to GitHub Pages

**Trigger the workflow:**

- **Automatically:** Any push to `main` or `master` branch
- **Manually:** Go to Actions tab → "Deploy to GitHub Pages" → "Run workflow"

#### 4. Access Your Tutorial

After deployment completes (usually 2-5 minutes):

**Your tutorial will be available at:**
```
https://ernaniaz.github.io/CertificatesTutorial/en_US/
```

### 🔧 Configuration

#### Custom Domain

To use a custom domain (e.g., `pki-tutorial.example.com`):

1. Create a tracked `CNAME` file in `docs/` so the build/deploy pipeline copies it into the published output:
   ```bash
   echo "pki-tutorial.example.com" > docs/CNAME
   ```

2. In GitHub Settings → Pages:
   - Enter your custom domain
   - Enable "Enforce HTTPS"

3. Add DNS records at your domain registrar:
   ```
   Type: CNAME
   Name: pki-tutorial (or @)
   Value: ernaniaz.github.io
   ```

#### Update Repository URL in book.toml

Edit `docs/<LANGUAGE>/book.toml`:

```toml
[output.html]
git-repository-url = "https://github.com/ernaniaz/CertificatesTutorial"
git-repository-icon = "fab-github"
```

Then rebuild and push.

### 📊 Monitoring Deployment

#### Check Deployment Status

1. Go to **Actions** tab in your GitHub repository
2. Click on the latest "Deploy to GitHub Pages" workflow
3. View logs for each step:
   - ✅ Checkout
   - ✅ Install mdBook
   - ✅ Build book
   - ✅ Deploy

#### Troubleshooting

**Deployment fails:**
- Check Actions logs for error messages
- Verify each language `book.toml` is valid (e.g., `docs/en_US/book.toml`)
- Ensure all Markdown files have valid syntax

**Pages not updating:**
- Clear browser cache
- Wait 5-10 minutes for CDN propagation
- Check that workflow completed successfully

**404 errors:**
- Verify files exist in `docs/book/` after build
- Check file paths in `SUMMARY.md` are correct
- Ensure branch name matches workflow trigger (main/master)

### 🔄 Continuous Deployment

Once set up, every push to the main branch will:

1. Trigger GitHub Actions workflow
2. Build fresh HTML from Markdown
3. Deploy updated content to GitHub Pages
4. Site updates automatically within minutes

### 🌍 Multi-language Support

The current setup supports all three languages automatically:

- English: `https://ernaniaz.github.io/CertificatesTutorial/en_US/part-01-fundamentals/01-cryptography-pki-basics.html`
- Spanish: `https://ernaniaz.github.io/CertificatesTutorial/es_ES/part-01-fundamentals/01-cryptography-pki-basics.html`
- Portuguese: `https://ernaniaz.github.io/CertificatesTutorial/pt_BR/part-01-fundamentals/01-cryptography-pki-basics.html`

To serve all languages, the workflow builds all versions and publishes the combined output.

The source landing page is tracked at `docs/index.html` and the build/deploy pipeline copies it to `docs/book/index.html`. It provides:

- Links to all three language editions (English, Spanish, Portuguese)
- An automatic redirect to the English edition after 5 seconds (`<meta http-equiv="refresh" content="5;url=en_US/">`)

No manual HTML creation is required. After running `cd docs && ./build-all.sh`, verify that `docs/book/index.html` is present alongside the `en_US/`, `es_ES/`, and `pt_BR/` directories.

### 🔒 Private Repository Option

If you want to keep the repository private but still deploy:

**Option 1: GitHub Pages (Public Site Only)**
- Free tier requires public repository for Pages
- Paid GitHub Pro/Team allows private repos with Pages

**Option 2: Self-hosted**
- Build locally: `cd docs && ./build-all.sh`
- Deploy `docs/book/` to any web server (Apache, NGINX, S3, etc.)
- No GitHub Pages needed

**Option 3: Netlify/Vercel (Private Repo)**
- Both support private repositories
- Connect your GitHub repo
- Build command: `cd docs && ./build-all.sh`
- Publish directory: `docs/book`

---

## Netlify

Netlify offers drag-and-drop deployment and continuous deployment from Git.

### Method 1: Drag and Drop

1. Build the book locally:
   ```bash
   cd docs
   ./build-all.sh
   ```

2. Go to [https://app.netlify.com/drop](https://app.netlify.com/drop)

3. Drag the `docs/book/` folder to the upload area

4. Your site will be live at `https://random-name.netlify.app`

### Method 2: Git Integration

1. Push your repository to GitHub/GitLab/Bitbucket

2. Go to [Netlify](https://netlify.com) and click **Add new site**

3. Connect your Git provider

4. Configure build settings:
   - **Build command:**
     ```bash
     curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y &&
     source $HOME/.cargo/env &&
     cargo install mdbook mdbook-mermaid &&
     cd docs &&
     ./build-all.sh
     ```
   - **Publish directory:** `docs/book/`

5. Click **Deploy site**

### Custom Domain on Netlify

1. Go to **Site settings** → **Domain management**
2. Click **Add custom domain**
3. Follow DNS configuration instructions

---

## Vercel

Vercel specializes in static sites and offers great performance.

### Deploy with Vercel

1. Push your repository to GitHub

2. Go to [Vercel](https://vercel.com) and import your repository

3. Configure project:
   - **Framework Preset:** Other
   - **Build Command:**
     ```bash
     curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y &&
     source $HOME/.cargo/env &&
     cargo install mdbook mdbook-mermaid &&
     cd docs &&
     ./build-all.sh
     ```
   - **Output Directory:** `docs/book/`

4. Click **Deploy**

5. Your site will be live at `https://your-project.vercel.app`

---

## Self-Hosted (Apache/NGINX)

Deploy on your own server.

### Option 1: Apache

```bash
# Build the book
cd docs
./build-all.sh

# Copy to Apache document root
sudo cp -r book/ /var/www/html/pki-tutorial/

# Create Apache config
sudo tee /etc/httpd/conf.d/pki-tutorial.conf <<EOF
<VirtualHost *:80>
    ServerName pki.example.com
    DocumentRoot /var/www/html/pki-tutorial

    <Directory /var/www/html/pki-tutorial>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    ErrorLog /var/log/httpd/pki-tutorial-error.log
    CustomLog /var/log/httpd/pki-tutorial-access.log combined
</VirtualHost>
EOF

# Restart Apache
sudo systemctl restart httpd
```

### Option 2: NGINX

```bash
# Build the book
cd docs
./build-all.sh

# Copy to NGINX document root
sudo cp -r book/ /usr/share/nginx/html/pki-tutorial/

# Create NGINX config
sudo tee /etc/nginx/conf.d/pki-tutorial.conf <<EOF
server {
    listen 80;
    server_name pki.example.com;

    root /usr/share/nginx/html/pki-tutorial;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    access_log /var/log/nginx/pki-tutorial-access.log;
    error_log /var/log/nginx/pki-tutorial-error.log;
}
EOF

# Test and restart NGINX
sudo nginx -t
sudo systemctl restart nginx
```

### Adding HTTPS (Let's Encrypt)

```bash
# Install certbot
sudo dnf install certbot python3-certbot-apache  # For Apache
# OR
sudo dnf install certbot python3-certbot-nginx   # For NGINX

# Obtain certificate
sudo certbot --apache -d pki.example.com         # For Apache
# OR
sudo certbot --nginx -d pki.example.com          # For NGINX

# Certbot will automatically configure HTTPS
```

---

## AWS S3 Static Website

Host on AWS S3 with CloudFront for global CDN.

### Setup Steps

```bash
# Build the book
cd docs
./build-all.sh

# Install AWS CLI (if not installed)
pip install awscli

# Configure AWS credentials
aws configure

# Create S3 bucket
aws s3 mb s3://pki-tutorial-bucket

# Enable static website hosting
aws s3 website s3://pki-tutorial-bucket \
    --index-document index.html \
    --error-document 404.html

# Set bucket policy for public read
cat > bucket-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::pki-tutorial-bucket/*"
        }
    ]
}
EOF

aws s3api put-bucket-policy \
    --bucket pki-tutorial-bucket \
    --policy file://bucket-policy.json

# Upload book
aws s3 sync book/ s3://pki-tutorial-bucket/ \
    --delete \
    --cache-control max-age=3600

# Get website URL
echo "Website: http://pki-tutorial-bucket.s3-website-us-east-1.amazonaws.com"
```

The root `404.html` is generated from the tracked `docs/404.html` file when you run `cd docs && ./build-all.sh`.

### Adding CloudFront CDN

1. Go to AWS CloudFront console
2. Create distribution with S3 bucket as origin
3. Configure SSL certificate (use ACM for free certificate)
4. Point your domain to CloudFront distribution

---

## Azure Static Web Apps

Deploy on Microsoft Azure. This tutorial is built with mdBook, so Azure cannot infer a working build from `--app-location "docs"` alone. You must either upload a pre-built site or customize the GitHub Actions workflow Azure creates.

### Method 1: Upload a pre-built site (simplest)

1. Build locally:
   ```bash
   cd docs
   ./build-all.sh
   ```

2. Create the Static Web App in the Azure Portal and choose **Other** as the deployment source, or use the Azure CLI with `--source ""` and deploy the artifact manually.

3. Upload the contents of `docs/book/` (including `index.html`, `404.html`, and the `en_US/`, `es_ES/`, and `pt_BR/` directories).

### Method 2: GitHub integration with a custom build workflow

1. Install Azure CLI (if needed):
   ```bash
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   az login
   ```

2. Create the Static Web App linked to your GitHub repository. In the Azure Portal, set:
   - **App location:** `/` (repository root)
   - **Output location:** `docs/book`
   - **App build command:** leave empty for now; Azure will generate a workflow file you must edit

3. Edit the generated `.github/workflows/azure-static-web-apps-*.yml` workflow. Replace the default build with the same toolchain used by this repository:
   ```yaml
   - name: Setup Rust
     uses: dtolnay/rust-toolchain@stable

   - name: Install mdBook
     run: |
       cargo install mdbook mdbook-mermaid

   - name: Build book
     run: |
       cd docs
       ./build-all.sh
   ```

4. Keep `app_location: "/"` and `output_location: "docs/book"` in the workflow so Azure publishes the combined multi-language output.

> **Note:** Do not rely on `az staticwebapp create ... --app-location "docs" --output-location "book"` as a one-shot setup. That path assumes Azure can build the app automatically; mdBook requires the custom Rust/mdbook build shown above.

---

## Deployment Checklist

Before deploying:

- [ ] All chapters completed and reviewed
- [ ] All links working (build and check for warnings)
- [ ] Images loading correctly
- [ ] Mermaid diagrams rendering
- [ ] No broken internal links
- [ ] SUMMARY.md is up to date
- [ ] All languages built successfully (if multi-language)
- [ ] 404 page configured (if applicable)
- [ ] Analytics configured (if desired)
- [ ] Domain name configured (if applicable)
- [ ] HTTPS enabled (for production)

---

## Post-Deployment

### Monitor Traffic

**Google Analytics:**
Add to `book.toml`:
```toml
[output.html]
google-analytics = "UA-XXXXX-X"
```

**Plausible Analytics (Privacy-friendly):**
Add custom JavaScript in theme.

### Update Content

```bash
# Make changes to markdown files
vim docs/en_US/part-XX/chapter.md

# Rebuild
cd docs && ./build-all.sh

# Deploy (depends on your deployment method)
# GitHub Pages: git push
# Netlify/Vercel: git push (auto-deploy)
# Self-hosted: rsync or scp to server
# S3: aws s3 sync
```

---

## Troubleshooting Deployment

### GitHub Pages 404 Error

- Verify GitHub Pages is enabled in repository settings
- Check that workflow completed successfully
- Ensure `index.html` exists in published directory

### Netlify Build Fails

- Check build logs in Netlify dashboard
- Verify build command is correct
- Ensure all dependencies are installed in build command

### Custom Domain Not Working

- Verify DNS records are correctly configured
- Wait for DNS propagation (can take up to 48 hours)
- Check domain registrar settings

### HTTPS Certificate Errors

- Renew Let's Encrypt certificate: `sudo certbot renew`
- Check certificate expiration: `openssl s_client -connect domain.com:443 | openssl x509 -noout -dates`

---

## Cost Comparison

| Platform | Free Tier | Cost (Paid) | Best For |
|----------|-----------|-------------|----------|
| **GitHub Pages** | Unlimited public repos | Free | Open source projects |
| **Netlify** | 100 GB/month | $19/month | Small to medium sites |
| **Vercel** | 100 GB/month | $20/month | High-performance sites |
| **AWS S3** | 5 GB storage (12 months) | ~$0.50-5/month | Scalable, enterprise |
| **Azure** | 100 GB/month | Variable | Microsoft ecosystem |
| **Self-Hosted** | Server cost only | $5-50/month | Full control |

---

## Recommended Setup

**For Open Source:**
- GitHub Pages (free, automatic deployment)

**For Production:**
- Vercel or Netlify (easy setup, great performance)
- AWS S3 + CloudFront (scalable, global CDN)

**For Corporate/Internal:**
- Self-hosted (full control, security)

## 🎉 Success!

Once deployed, share your tutorial URL:

```
🌐 Complete PKI & Digital Certificates Tutorial
📚 https://ernaniaz.github.io/CertificatesTutorial/

Available in English, Spanish, and Portuguese
41 comprehensive chapters | 50+ diagrams | Production-ready
```

---

**Need help?** Check the main [README.md](README.md) or GitHub Actions logs for troubleshooting.
