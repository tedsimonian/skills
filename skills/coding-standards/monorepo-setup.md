# Monorepo Setup Guide

This guide covers the standard structure, tooling, and configuration for enterprise monorepos.

## Directory Structure

```
project-root/
├── .changeset/              # Changesets config for versioning
│   └── config.json
├── .devcontainer/           # Dev container configuration (required)
│   ├── devcontainer.json
│   └── Dockerfile
├── .github/
│   └── workflows/           # CI/CD pipelines
│       ├── ci.yml
│       ├── release.yml
│       └── deploy.yml
├── .husky/                  # Git hooks
│   ├── pre-commit
│   └── commit-msg
├── apps/                    # Deployable applications
│   ├── api-gateway/         # api-* for backend services
│   ├── api-users/
│   ├── web-docs/            # web-* for web applications
│   ├── web-dashboard/
│   └── cli-admin/           # cli-* for CLI tools
├── packages/                # Shared packages
│   ├── shared-types/        # Zod schemas (source of truth)
│   ├── ui/                  # Shared UI components
│   ├── utils/               # Shared utilities
│   └── config/              # Shared configs (optional if using root extension)
├── .env.example             # Environment variable template
├── .gitignore
├── .prettierrc
├── biome.json               # Or eslint.config.js
├── bun.lock
├── commitlint.config.js
├── lint-staged.config.js
├── package.json
├── tsconfig.json            # Root TypeScript config
├── turbo.json               # Turborepo configuration
└── README.md
```

## App Naming Convention

Apps are organized flat with prefixes indicating deployment type:

| Prefix     | Description              | Example                                   |
| ---------- | ------------------------ | ----------------------------------------- |
| `api-*`    | Backend services, APIs   | `api-gateway`, `api-auth`, `api-payments` |
| `web-*`    | Web applications, sites  | `web-docs`, `web-dashboard`, `web-admin`  |
| `cli-*`    | Command-line tools       | `cli-admin`, `cli-migrate`                |
| `worker-*` | Background workers, jobs | `worker-emails`, `worker-sync`            |
| `func-*`   | Serverless functions     | `func-webhooks`, `func-resize`            |

**Why flat structure**: Easier to find apps, simpler CI glob patterns, clear naming conveys purpose without nested folders.

## Package Dependency Rules

### Strict DAG (Directed Acyclic Graph)

Packages can only depend on packages "below" them in the hierarchy:

```
Level 3: apps/*           (can depend on any package)
Level 2: packages/ui      (can depend on types, utils)
Level 2: packages/auth    (can depend on types, utils)
Level 1: packages/utils   (can depend on types)
Level 0: packages/types   (no internal dependencies)
```

**No circular dependencies**: Enforced by tooling. If A depends on B, B cannot depend on A.

### Workspace Protocol

All internal dependencies use workspace protocol:

```json
{
  "dependencies": {
    "@repo/shared-types": "workspace:*",
    "@repo/ui": "workspace:*"
  }
}
```

**Why `workspace:*`**: Ensures you always use the local version. pnpm/yarn resolves to the actual version during publish.

### Validating Dependencies

Add to CI:

```yaml
# .github/workflows/ci.yml
- name: Check circular dependencies
  run: bunx madge --circular --extensions ts,tsx apps packages

- name: Validate package graph
  run: bunx syncpack lint
```

## Root Configuration Files

### package.json

```json
{
  "name": "project-monorepo",
  "private": true,
  "packageManager": "pnpm@9.0.0",
  "engines": {
    "node": ">=22.0.0"
  },
  "scripts": {
    "dev": "turbo dev",
    "build": "turbo build",
    "test": "turbo test",
    "lint": "turbo lint",
    "format": "prettier --write .",
    "typecheck": "turbo typecheck",
    "clean": "turbo clean && rm -rf node_modules",
    "prepare": "husky"
  },
  "devDependencies": {
    "@changesets/cli": "^2.27.0",
    "@commitlint/cli": "^19.0.0",
    "@commitlint/config-conventional": "^19.0.0",
    "husky": "^9.0.0",
    "lint-staged": "^15.0.0",
    "prettier": "^3.0.0",
    "syncpack": "^12.0.0",
    "turbo": "^2.0.0",
    "typescript": "^5.5.0"
  }
}
```

### turbo.json

```json
{
  "$schema": "https://turbo.build/schema.json",
  "ui": "tui",
  "globalDependencies": ["tsconfig.json", "bun.lock", "eslint.config.*"],
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "inputs": ["$TURBO_DEFAULT$", "!README.md", "!**/*.test.ts"],
      "outputs": ["dist/**", ".next/**", ".output/**"]
    },
    "dev": {
      "dependsOn": ["^build"],
      "persistent": true,
      "interruptible": true,
      "cache": false
    },
    "test": {
      "dependsOn": [],
      "outputs": ["coverage/**"],
      "cache": true
    },
    "type-check": {
      "dependsOn": ["^build"],
      "outputs": [".tsbuildinfo"]
    },
    "lint": {
      "dependsOn": [],
      "outputs": [],
      "cache": true
    },
    "clean": {
      "cache": false
    }
  }
}
```

**Key configuration decisions**:

- **Lockfile in globals**: Ensures cache invalidates when dependencies change
- **`test` has no dependencies**: Unit tests typically run against source, not built output
- **`lint` has no dependencies**: ESLint reads source directly unless using type-aware rules
- **`dev` depends on `^build`**: App dev servers need built dependency packages

For advanced Turborepo optimization (cache debugging, CI optimization, task analysis), see the [turborepo-specialist skill](../turborepo-specialist/SKILL.md).

### tsconfig.json (Root)

```json
{
  "$schema": "https://json.schemastore.org/tsconfig",
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "strict": true,
    "strictNullChecks": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "forceConsistentCasingInFileNames": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "isolatedModules": true,
    "verbatimModuleSyntax": true
  },
  "exclude": ["node_modules", "dist", ".turbo"]
}
```

**Key strict settings explained**:

- `strictNullChecks`: Forces handling of null/undefined
- `noUncheckedIndexedAccess`: Array access returns T | undefined
- `exactOptionalPropertyTypes`: Optional and undefined are different
- `verbatimModuleSyntax`: Type imports must use `import type`

### Package tsconfig.json

Each package extends root and adds its specifics:

```json
{
  "extends": "../../tsconfig.json",
  "compilerOptions": {
    "rootDir": "src",
    "outDir": "dist",
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    }
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "**/*.test.ts"]
}
```

## Dev Container Setup

Dev containers are **required** for consistent development environments.

### .devcontainer/devcontainer.json

```json
{
  "name": "Project Dev Container",
  "build": {
    "dockerfile": "Dockerfile"
  },
  "features": {
    "ghcr.io/devcontainers/features/node:1": {
      "version": "22"
    },
    "ghcr.io/devcontainers/features/docker-in-docker:2": {}
  },
  "customizations": {
    "vscode": {
      "extensions": [
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode",
        "bradlc.vscode-tailwindcss",
        "prisma.prisma",
        "GraphQL.vscode-graphql"
      ],
      "settings": {
        "editor.defaultFormatter": "esbenp.prettier-vscode",
        "editor.formatOnSave": true,
        "editor.codeActionsOnSave": {
          "source.fixAll.eslint": "explicit"
        }
      }
    }
  },
  "forwardPorts": [3000, 4000, 5432],
  "postCreateCommand": "pnpm install && pnpm build",
  "remoteUser": "node"
}
```

### .devcontainer/Dockerfile

```dockerfile
FROM mcr.microsoft.com/devcontainers/typescript-node:22

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:$PATH"

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Install global tools
RUN npm install -g turbo @changesets/cli

# Set up non-root user
USER node
WORKDIR /workspaces
```

## Git Hooks Setup

### .husky/pre-commit

```bash
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

# Run lint-staged for formatting and linting
npx lint-staged

# Check for secrets
npx gitleaks protect --staged --verbose
```

### .husky/commit-msg

```bash
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

npx --no -- commitlint --edit $1
```

### lint-staged.config.js

```javascript
export default {
  '*.{ts,tsx}': ['eslint --fix', 'prettier --write'],
  '*.{json,md,yml,yaml}': ['prettier --write'],
  '*.css': ['prettier --write'],
};
```

### commitlint.config.js

```javascript
export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      [
        'feat', // New feature
        'fix', // Bug fix
        'docs', // Documentation
        'style', // Formatting (no code change)
        'refactor', // Code change (no feature/fix)
        'perf', // Performance improvement
        'test', // Adding tests
        'chore', // Maintenance
        'ci', // CI configuration
        'revert', // Revert previous commit
      ],
    ],
    'scope-empty': [2, 'never'], // Scope is required
    'subject-case': [2, 'always', 'lower-case'],
  },
};
```

## Versioning with Changesets

### .changeset/config.json

```json
{
  "$schema": "https://unpkg.com/@changesets/config@3.0.0/schema.json",
  "changelog": "@changesets/cli/changelog",
  "commit": false,
  "fixed": [],
  "linked": [],
  "access": "restricted",
  "baseBranch": "main",
  "updateInternalDependencies": "patch",
  "ignore": []
}
```

**Independent versioning**: Each package has its own version. When you make changes:

```bash
# Create a changeset
pnpm changeset

# Select packages that changed
# Choose version bump (patch/minor/major)
# Write description

# Commit the changeset file
git add .changeset/*.md
git commit -m "chore(release): add changeset"
```

## Creating New Packages

### App Package Template

```bash
# Create new web app
mkdir -p apps/web-newapp/src
```

**apps/web-newapp/package.json**:

```json
{
  "name": "@repo/web-newapp",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite dev",
    "build": "vite build",
    "preview": "vite preview",
    "typecheck": "tsc --noEmit",
    "lint": "eslint src",
    "test": "vitest run"
  },
  "dependencies": {
    "@repo/shared-types": "workspace:*",
    "@repo/ui": "workspace:*"
  }
}
```

### Shared Package Template

```bash
mkdir -p packages/newpackage/src
```

**packages/newpackage/package.json**:

```json
{
  "name": "@repo/newpackage",
  "version": "0.0.0",
  "type": "module",
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "import": "./dist/index.js"
    }
  },
  "files": ["dist"],
  "scripts": {
    "build": "tsup src/index.ts --format esm --dts",
    "dev": "tsup src/index.ts --format esm --dts --watch",
    "typecheck": "tsc --noEmit",
    "lint": "eslint src",
    "test": "vitest run"
  },
  "dependencies": {
    "@repo/shared-types": "workspace:*"
  }
}
```

## CI/CD Setup

### .github/workflows/ci.yml

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v3
        with:
          version: 9

      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: 'pnpm'

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Build packages
        run: pnpm build

      - name: Typecheck
        run: pnpm typecheck

      - name: Lint
        run: pnpm lint

      - name: Test
        run: pnpm test

      - name: Check circular dependencies
        run: bunx madge --circular --extensions ts,tsx apps packages

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Check for secrets
        uses: gitleaks/gitleaks-action@v2

      - name: Dependency audit
        run: pnpm audit --audit-level=high
```

### .github/workflows/release.yml

```yaml
name: Release

on:
  push:
    branches: [main]

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v3
        with:
          version: 9

      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: 'pnpm'

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Build
        run: pnpm build

      - name: Create Release PR or Publish
        uses: changesets/action@v1
        with:
          publish: pnpm changeset publish
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

## Environment Variables

### .env.example

```bash
# App Configuration
NODE_ENV=development
PORT=3000

# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/db

# External Services
# Get these from vault in production
GITHUB_TOKEN=
SENTRY_DSN=

# Feature Flags (LaunchDarkly)
LAUNCHDARKLY_SDK_KEY=
```

**Rules**:

- `.env.example` committed with placeholder values
- Real `.env` is gitignored
- Production secrets come from secrets manager (AWS Secrets Manager, GCP Secret Manager)
- Never commit actual secrets

## Validating Setup

Run these checks to validate a new monorepo setup:

```bash
# 1. Dependencies install cleanly
pnpm install

# 2. All packages build
pnpm build

# 3. Types are correct
pnpm typecheck

# 4. No circular dependencies
bunx madge --circular --extensions ts,tsx apps packages

# 5. Consistent dependency versions
bunx syncpack lint

# 6. Git hooks work
git commit --allow-empty -m "test: verify hooks"

# 7. Dev container builds
docker build -f .devcontainer/Dockerfile .
```