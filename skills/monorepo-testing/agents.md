# Testing Agent Instructions

> Add this content to your `CLAUDE.md` or `AGENTS.md` at the monorepo root so Claude Code and other coding agents always see these rules.

---

## Recommended CLAUDE.md / AGENTS.md Content

Copy the following into your `CLAUDE.md` (or equivalent agent instructions file) at the monorepo root:

```markdown
## Testing Standards

This monorepo follows strict testing conventions. Before writing or modifying any test, read the relevant guide in `tooling/testing-skill/` (or wherever you install the skill).

### Critical Rules - Never Violate

1. **File extension determines runtime.** `.test.ts` = Node.js, `.test.tsx` = Node.js (JSX/SSR), `.browser.test.tsx` = real Chromium browser. Never put browser tests in a `.test.tsx` file or server tests in a `.browser.test.tsx` file.

2. **Use `tests/` not `__tests__/`.** The `__tests__/` convention leaks into production bundles. All non-colocated tests go in `tests/`.

3. **Page Objects are mandatory for E2E.** Never write inline selectors in `.e2e.test.ts` files. Create a Page Object in `tests/e2e/pages/`.

4. **Integration tests use `fileParallelism: false`** when sharing a database.

5. **Root vitest.config.ts is NOT a project.** It only defines `projects` globs and root-only options (coverage, reporters). Per-package configs use `defineProject()`.

6. **Coverage options go in root config only.** They are silently ignored in project configs.

7. **E2E tests are capped at 20-30 per app.** Push edge cases to unit/integration layer.

### Quick Decision - Which Test Type?

- Pure function, no JSX → `.test.ts`
- Server-rendered JSX (SSR, email template, server component) → `.test.tsx`
- Client component (DOM events, client state, browser APIs) → `.browser.test.tsx`
- Shared UI library component → `.stories.tsx`
- Cross-boundary (DB, HTTP, queue) → `.integration.test.ts` in `tests/integration/`
- Full user flow in browser → `.e2e.test.ts` in `tests/e2e/`
- API endpoint → `.api.test.ts` in `tests/e2e/`
- Production monitoring → `.check.ts` in `monitoring/`

### Naming Conventions

- Colocated tests: `{module}.test.ts` next to `{module}.ts`
- Browser tests: `{Component}.browser.test.tsx` next to `{Component}.tsx`
- Stories: `{Component}.stories.tsx` next to `{Component}.tsx`
- Integration: `tests/integration/{feature}.integration.test.ts`
- E2E: `tests/e2e/{flow}.e2e.test.ts`
- Page Objects: `tests/e2e/pages/{page}.page.ts`

### Test Case Names

Describe observable **behavior**, not implementation:
- ❌ `it('calls fetchUser with correct ID')`
- ✅ `it('returns user data when user exists')`

### Browser Test APIs

When writing `.browser.test.tsx` files:
- Use `render()` from `vitest-browser-react`, NOT `@testing-library/react`
- Use `page.getByRole()`, NOT `screen.getByRole()`
- Use `await expect.element(locator)`, NOT `expect(element)`
- Real browser APIs are available natively - NEVER mock `matchMedia`, `IntersectionObserver`, etc.

### Config Patterns

- Single-project package: `defineProject()` with `mergeConfig(createNodeConfig(), ...)`
- Multi-project app: `defineConfig()` with `projects: [{ test: { name: 'app/unit' } }, { extends: true, test: { name: 'app/browser', browser: { enabled: true } } }]`
- Browser projects need `extends: true` to inherit parent plugins
- Storybook packages use `storybookTest()` plugin - only ONE config should contain it

### Running Tests

```bash
mise run test:unit              # All unit tests (excludes integration)
mise run test:integration       # Integration tests (needs DB)
mise run test:browser           # Storybook/browser tests
mise run test:e2e               # All E2E tests
mise run test:e2e:web           # Web app E2E only
vitest bench                    # Benchmarks
npx checkly test                # Preview Checkly checks
```

### Detailed Guides

For comprehensive reference on any testing topic, see:
- `SKILL.md` - Overview, decision flowchart, all file extensions
- `naming.md` - Complete naming conventions
- `vitest.md` - Config patterns, unit/browser/integration templates
- `storybook.md` - Story writing, addon-vitest setup
- `playwright.md` - E2E, API testing, Page Objects
- `checkly.md` - Production monitoring
- `inngest.md` - Inngest workflow testing
- `ci.md` - GitHub Actions, mise tasks, caching
- `gotchas.md` - Common pitfalls and reliability patterns
- `review.md` - Full audit checklist for reviewing test setup compliance

### Reviewing Testing Setup

When asked to "review testing", "audit tests", or "check test setup":
1. Run `bash tooling/testing-skill/scripts/audit-testing-setup.sh .`
2. Read `tooling/testing-skill/review.md` and walk through the manual checklist
3. Produce a structured report with violations (🔴), warnings (🟡), coverage gaps, and an action plan
```

---

## Placement Strategy

### Option A: Inline in CLAUDE.md (Recommended)

Copy the "Critical Rules" and "Quick Decision" sections directly into your `CLAUDE.md`. This ensures Claude Code always sees them without needing to read additional files. Link to the full skill files for detailed reference.

```markdown
# CLAUDE.md

## ... (other project instructions)

## Testing Standards

(paste the content above)

## Detailed Testing Guides

For in-depth reference, read the relevant file in `tooling/testing-skill/`:
- [SKILL.md](./tooling/testing-skill/SKILL.md) - Entry point and overview
- [vitest.md](./tooling/testing-skill/vitest.md) - Vitest configuration and templates
- ... (etc.)
```

### Option B: Reference via File Link

If your `CLAUDE.md` is already long, reference the skill:

```markdown
# CLAUDE.md

## Testing

**Before writing any test file, read `tooling/testing-skill/SKILL.md`.**

Key rules:
- File extension determines runtime: `.test.ts` (Node), `.browser.test.tsx` (browser)
- Use `tests/` not `__tests__/`
- E2E tests must use Page Objects
- Integration tests: `fileParallelism: false` with shared DB
- See `tooling/testing-skill/` for complete guides
```

### Option C: .cursor/rules or .github/copilot-instructions.md

For Cursor or GitHub Copilot, create a rule file:

```markdown
# .cursor/rules/testing.md (or .github/copilot-instructions.md)

When creating or modifying test files in this monorepo:
1. Check the file extension matches the test type (see tooling/testing-skill/naming.md)
2. Use the correct test runner APIs for the environment
3. Follow Page Object pattern for E2E tests
4. Place integration tests in tests/integration/, not colocated
5. Read tooling/testing-skill/SKILL.md for the complete decision flowchart
```

---

## Installing the Skill

Copy the skill directory into your monorepo:

```bash
# From monorepo root
cp -r /path/to/monorepo-testing tooling/testing-skill

# Or as a specific location
mkdir -p .claude/skills
cp -r /path/to/monorepo-testing .claude/skills/testing
```

Make scripts executable:
```bash
chmod +x tooling/testing-skill/scripts/*.sh
```

---

## Claude Code Slash Command: `/review-testing`

Add this to `.claude/commands/review-testing.md` to register a slash command that triggers a full testing standards review:

```markdown
---
description: Audit the repo's testing setup against monorepo testing standards
---

Perform a thorough review of the testing setup in this repository.

## Instructions

1. Read `tooling/testing-skill/review.md` for the complete review methodology.

2. Run the automated audit script:
   ```bash
   bash tooling/testing-skill/scripts/audit-testing-setup.sh .
   ```

3. Review the script output. For each violation or warning, note the check ID and details.

4. Walk through the manual checklist in review.md, focusing on sections relevant to the packages in this repo. For each package/app:
   - Identify its type (server-utils, UI lib, GraphQL API, full-stack app, CLI, SPA)
   - Check which test types it should have (see the matrix in SKILL.md)
   - Verify configs follow the correct pattern for that type (see vitest.md)
   - Check test quality: naming, isolation, mocking patterns

5. Perform the coverage gap analysis: for each package, does it have the right test types at the right layers?

6. Produce a structured report in this format:

   ```
   # Testing Setup Review - [Repo Name]

   **Date:** [today]
   **Scope:** [what was reviewed]

   ## Summary
   - 🔴 Violations: X
   - 🟡 Warnings: Y
   - 🟢 Compliant: Z
   - 💡 Suggestions: W

   ## Critical Issues (🔴)
   [list with check IDs, file locations, and fix guidance]

   ## Warnings (🟡)
   [list]

   ## Coverage Gaps
   [per-package table showing which test types exist vs expected]

   ## Recommended Action Plan
   [prioritized list of fixes]
   ```

$ARGUMENTS
```

### Using the Command

Once installed, type `/review-testing` in Claude Code to trigger it. Optionally pass a path to scope the review:

```
/review-testing
/review-testing packages/api-users
/review-testing apps/web
```

---

## Alternative: CLAUDE.md Review Trigger

If you don't use slash commands, add this to your `CLAUDE.md` instead:

```markdown
### Testing Review Command

When I ask you to "review testing", "audit tests", "check test setup", or similar:

1. Read `tooling/testing-skill/review.md`
2. Run `bash tooling/testing-skill/scripts/audit-testing-setup.sh .`
3. Walk through the manual checklist for each package
4. Produce the structured report format defined in review.md Phase 4
```

---

## Alternative: Cursor Rules

For Cursor, add to `.cursor/rules/testing-review.md`:

```markdown
When the user asks to review or audit the testing setup:

1. Run the audit script: `bash tooling/testing-skill/scripts/audit-testing-setup.sh .`
2. Read `tooling/testing-skill/review.md` for the full manual checklist
3. Check each package against the test type matrix in `tooling/testing-skill/SKILL.md`
4. Produce a structured report with violations (🔴), warnings (🟡), and an action plan
```
