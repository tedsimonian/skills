# Vocs Documentation Site Setup

Build a documentation site with Vocs, integrated with Storybook for live component previews, and deployed to GitHub Pages.

---

## Quick Reference

### Tech Stack

| Component             | Technology                | Version |
| --------------------- | ------------------------- | ------- |
| Static Site Generator | [Vocs](https://vocs.dev/) | 1.4.x   |
| UI Framework          | React                     | 19.x    |
| Component Demos       | Storybook                 | 8.x     |
| Build Tool            | Vite                      | 6.x     |
| Runtime               | Node.js                   | 22.x    |
| Package Manager       | Bun                       | 1.3.x   |

### Commands

```bash
# Development
bun run dev          # Start Vocs dev server
bun run preview      # Preview production build

# Build
bun run build        # Build full

# Validation
bun run type-check   # TypeScript validation
```

---

## Directory Structure

```
docs/
├── package.json          # Dependencies (vocs, react)
├── vocs.config.ts        # Site configuration
├── tsconfig.json         # TypeScript config
├── pages/
│   ├── index.md          # Home page
│   ├── getting-started.md
│   └── components/       # Component documentation
│       ├── button.mdx
│       └── ...
└── public/
    ├── logo.svg
    ├── favicon.ico
    ├── assets/           # Images and other content related assets
    └── storybook/        # Built Storybook (generated)
```

---

## Setup Guide

### Step 1: Initialize Package

```json
{
  "name": "@yourorg/docs",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "bun run build:storybook && bun run build:vocs",
    "build:storybook": "<command-or-script-that-builds-and-copies-storybook-static-to-public-folder>",
    "build:vocs": "vocs build",
    "dev": "vocs dev",
    "preview": "vocs preview",
    "type-check": "tsc --noEmit"
  },
  "dependencies": {
    "react": "19.0.0",
    "react-dom": "19.0.0",
    "vocs": "1.4.1"
  },
  "devDependencies": {
    "@types/react": "19.0.2",
    "typescript": "5.9.3"
  }
}
```

### Step 2: Configure Vocs

```typescript
// vocs.config.ts
import { defineConfig } from 'vocs';

export default defineConfig({
  // Base path for subdirectory hosting (GitHub Pages)
  basePath: process.env.VOCS_BASE_PATH ?? '',

  // Link validation
  checkDeadlinks: 'warn', // 'warn' | 'error' | false

  // Site metadata
  title: 'My Documentation',
  description: 'Documentation for my project',
  logoUrl: '/logo.svg',
  iconUrl: '/favicon.ico',

  // Root directory (where pages/ and public/ live)
  rootDir: '.',

  // Navigation
  sidebar: [
    {
      text: 'Getting Started',
      items: [
        { link: '/', text: 'Welcome' },
        { link: '/getting-started', text: 'Quick Start' },
      ],
    },
    {
      text: 'Components',
      collapsed: true,
      items: [{ link: '/components/button', text: 'Button' }],
    },
  ],

  topNav: [
    { link: '/', text: 'Guide' },
    { link: '/storybook/index.html', text: 'Storybook' },
  ],

  // Theme
  theme: {
    accentColor: '#00DDB3',
  },

  // Vite config
  vite: {
    server: {
      port: 5174,
    },
  },
});
```

### Step 3: Configure TypeScript

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["DOM", "DOM.Iterable", "ES2022"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "skipLibCheck": true
  },
  "include": ["**/*.ts", "**/*.tsx", "**/*.md", "**/*.mdx"],
  "exclude": ["node_modules", "dist"]
}
```

---

## Known Issues & Resolutions

### Issue 1: Base Path

**Symptom**: Assets and links broken when deployed to a subdirectory.

**Cause**: Vocs needs to know the base path for asset URLs.

**Resolution**: Set `VOCS_BASE_PATH` environment variable in CI:

```yaml
- name: Build Vocs docs
  run: bun run build
  env:
    VOCS_BASE_PATH: /docs-name
```

---

## Storybook Integration

### Embedding Storybook Previews

Use iframes to embed Storybook stories in documentation:

```mdx
## Preview

<iframe src="/storybook/iframe.html?id=components-button--default&viewMode=story" width="100%" height="300"></iframe>
```

### Story ID Format

Story IDs follow the pattern: `category-componentname--storyname`

Examples:

- `components-button--default`
- `layout-grid--responsive`
- `interactive-modal--with-form`

### Build Pipeline

1. Build Storybook to `apps/<do/public/storybook/`
2. Build Vocs (which copies `public/` to `dist/`)
3. Result: `docs/dist/storybook/` contains full Storybook

---

## GitHub Actions Workflow

```yaml
name: Documentation Site

on:
  push:
    branches: [main]
    paths:
      - 'docs/**'
      - '.github/workflows/docs.yml'
  pull_request:
    branches: [main]
    paths:
      - 'docs/**'
  workflow_dispatch:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

env:
  BUN_VERSION: 1.3.5
  NODE_VERSION: 22

jobs:
  build:
    name: Build Documentation
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: oven-sh/setup-bun@v2
        with:
          bun-version: ${{ env.BUN_VERSION }}

      # Node.js required for Vocs build (vanilla-extract)
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}

      - name: Install dependencies
        run: bun install --frozen-lockfile

      - name: Build Storybook
        working-directory: apps/website
        run: bun run build-storybook --output-dir ../../docs/public/storybook

      - name: Build Vocs docs
        run: bun run build:docs
        env:
          VOCS_BASE_PATH: /your-repo-name

      - name: Upload build artifacts
        uses: actions/upload-pages-artifact@v3
        with:
          path: docs/dist

  deploy:
    name: Deploy to GitHub Pages
    needs: build
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    permissions:
      pages: write
      id-token: write
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

---

## GitHub Pages Configuration

### Repository Settings

1. Go to **Settings** → **Pages**
2. Set **Source** to "GitHub Actions"
3. The workflow handles deployment automatically

### Custom Domain (Optional)

1. Add `CNAME` file to `docs/public/` with your domain
2. Configure DNS with your provider
3. Enable HTTPS in repository settings

### Base Path Considerations

| Hosting       | `VOCS_BASE_PATH` | URL                                |
| ------------- | ---------------- | ---------------------------------- |
| Root domain   | `''` (empty)     | `https://yourdomain.com/`          |
| Subdirectory  | `/repo-name`     | `https://org.github.io/repo-name/` |
| Custom domain | `''` (empty)     | `https://docs.yourdomain.com/`     |

---

## Boundaries

### Always Do

- Use Node.js wrapper scripts for Vocs commands (Bun incompatibility)
- Build Storybook before Vocs for full builds
- Set `VOCS_BASE_PATH` for GitHub Pages subdirectory deployments
- Use `checkDeadlinks: 'warn'` during development

### Ask First

- Changing sidebar structure (may break navigation)
- Adding new top-level pages (need sidebar entry)
- Modifying theme colors (brand consistency)

### Never Do

- Use `checkDeadlinks: 'error'` during Vocs-only builds

---

## Validation Checklist

Before deployment:

- [ ] `bun run type-check` passes
- [ ] `bun run build:full` completes without errors
- [ ] Storybook embeds load correctly in preview
- [ ] Navigation links work
- [ ] `VOCS_BASE_PATH` is set correctly for target environment
- [ ] No dead link warnings for internal links