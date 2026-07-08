# Setting Up GitHub Pages for TradingGuru

## Quick Setup (5 minutes)

### Step 1: Create GitHub Repository

1. Go to https://github.com/new
2. Repository name: `TradingGuru`
3. Keep it **private** (recommended)
4. **Do NOT** initialize with README, .gitignore, or license
5. Click "Create repository"

### Step 2: Push to GitHub

```bash
cd /Users/kamauagg/workspace/TradingGuru
git add docs/ PRIVACY_POLICY.md TERMS_OF_SERVICE.md APP_STORE_LISTING.md GITHUB_PAGES_SETUP.md
git commit -m "Add App Store support materials"
git remote add origin https://github.com/aggarka/TradingGuru.git
git branch -M main
git push -u origin main
```

### Step 3: Enable GitHub Pages

1. Go to https://github.com/aggarka/TradingGuru
2. Click **Settings** → **Pages** (in left sidebar)
3. Under "Source", select **Deploy from a branch**
4. Select **main** branch and **/docs** folder
5. Click **Save**

### Step 4: Your URLs

After a few minutes, your site will be live at:
- **Support**: `https://aggarka.github.io/TradingGuru/`
- **Privacy**: `https://aggarka.github.io/TradingGuru/privacy.html`
- **Terms**: `https://aggarka.github.io/TradingGuru/terms.html`

---

## App Store Connect URLs

When filling out App Store Connect, use:

| Field | URL |
|-------|-----|
| Support URL | `https://aggarka.github.io/TradingGuru/` |
| Privacy Policy URL | `https://aggarka.github.io/TradingGuru/privacy.html` |
| Marketing URL (optional) | `https://aggarka.github.io/TradingGuru/` |

---

## Testing Locally

To preview the site before publishing:
```bash
cd /Users/kamauagg/workspace/TradingGuru/docs
python3 -m http.server 8000
```
Then open: http://localhost:8000
