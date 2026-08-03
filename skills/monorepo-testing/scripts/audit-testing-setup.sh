#!/usr/bin/env bash
# audit-testing-setup.sh - Automated audit of monorepo testing standards compliance
# Usage: ./audit-testing-setup.sh <repo-root> [--json]
#
# Checks ~30 machine-detectable violations and produces a structured report.
# Pair with REVIEW.md for the full manual review checklist.

set -euo pipefail

ROOT="${1:?Usage: audit-testing-setup.sh <repo-root> [--json]}"
JSON_MODE="${2:-}"
ROOT=$(cd "$ROOT" && pwd)

# ─── Counters ───
VIOLATIONS=0
WARNINGS=0
OK=0
SUGGESTIONS=0

# ─── Output helpers ───
violation() { ((VIOLATIONS++)) || true; echo "  🔴 VIOLATION [$1] $2"; }
warning()   { ((WARNINGS++))   || true; echo "  🟡 WARNING   [$1] $2"; }
ok()        { ((OK++))         || true; echo "  🟢 OK        [$1] $2"; }
suggest()   { ((SUGGESTIONS++)) || true; echo "  💡 SUGGEST   [$1] $2"; }

cd "$ROOT"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║       Monorepo Testing Standards Audit                  ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Root: $ROOT"
echo "║  Date: $(date -Iseconds)"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ═══════════════════════════════════════════════════════════════
echo "── 1. FILE NAMING & ORGANIZATION ──"
# ═══════════════════════════════════════════════════════════════

# N1: No __tests__ directories
TESTS_DIRS=$(find . -type d -name '__tests__' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null || true)
if [ -n "$TESTS_DIRS" ]; then
  violation "N1" "__tests__/ directories found (use tests/ instead):"
  echo "$TESTS_DIRS" | sed 's/^/       /'
else
  ok "N1" "No __tests__/ directories"
fi

# N2: No .spec. files
SPEC_FILES=$(find . -name '*.spec.*' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null || true)
if [ -n "$SPEC_FILES" ]; then
  COUNT=$(echo "$SPEC_FILES" | wc -l | tr -d ' ')
  violation "N2" "$COUNT .spec.* files found (use .test.* convention):"
  echo "$SPEC_FILES" | head -10 | sed 's/^/       /'
  [ "$COUNT" -gt 10 ] && echo "       ... and $((COUNT - 10)) more"
else
  ok "N2" "No .spec.* files"
fi

# N3: Integration tests not in src/
INTEG_IN_SRC=$(find . -path '*/src/*.integration.test.ts' -not -path '*/node_modules/*' 2>/dev/null || true)
if [ -n "$INTEG_IN_SRC" ]; then
  violation "N4" "Integration tests found inside src/ (move to tests/integration/):"
  echo "$INTEG_IN_SRC" | sed 's/^/       /'
else
  ok "N4" "No integration tests misplaced in src/"
fi

# N5: E2E tests not in src/
E2E_IN_SRC=$(find . -path '*/src/*.e2e.test.ts' -not -path '*/node_modules/*' 2>/dev/null || true)
if [ -n "$E2E_IN_SRC" ]; then
  violation "N5" "E2E tests found inside src/ (move to tests/e2e/):"
  echo "$E2E_IN_SRC" | sed 's/^/       /'
else
  ok "N5" "No E2E tests misplaced in src/"
fi

echo ""

# ═══════════════════════════════════════════════════════════════
echo "── 2. VITEST CONFIGURATION ──"
# ═══════════════════════════════════════════════════════════════

# V1: Every package/app has vitest.config.ts
MISSING_VITEST_CONFIGS=""
for dir in packages/*/  apps/*/; do
  [ ! -d "$dir" ] && continue
  pkg_name=$(basename "$dir")
  # Skip packages that are just types/config (likely don't need tests)
  if [ -f "${dir}vitest.config.ts" ] || [ -f "${dir}vitest.config.mts" ]; then
    continue
  fi
  # Check if it has any source files
  if find "$dir" -name '*.ts' -o -name '*.tsx' 2>/dev/null | grep -q -v node_modules; then
    MISSING_VITEST_CONFIGS="${MISSING_VITEST_CONFIGS}${dir}\n"
  fi
done
if [ -n "$MISSING_VITEST_CONFIGS" ]; then
  warning "V1" "Packages/apps without vitest.config.ts:"
  echo -e "$MISSING_VITEST_CONFIGS" | grep -v '^$' | sed 's/^/       /'
else
  ok "V1" "All packages/apps have vitest.config.ts"
fi

# V2: Root config has projects array
if [ -f "vitest.config.ts" ] || [ -f "vitest.config.mts" ]; then
  ROOT_CFG=$(cat vitest.config.ts vitest.config.mts 2>/dev/null || true)
  if echo "$ROOT_CFG" | grep -q 'projects'; then
    ok "V2" "Root vitest config has projects array"
  else
    violation "V2" "Root vitest.config.ts missing projects array"
  fi
else
  warning "V2" "No root vitest.config.ts found"
fi

# V4: Coverage config only in root
COVERAGE_IN_PROJECTS=$(grep -rl 'coverage' packages/*/vitest.config.* apps/*/vitest.config.* 2>/dev/null | grep -v node_modules || true)
if [ -n "$COVERAGE_IN_PROJECTS" ]; then
  violation "V4" "Coverage config found in non-root vitest configs (move to root only):"
  echo "$COVERAGE_IN_PROJECTS" | sed 's/^/       /'
else
  ok "V4" "Coverage config is root-only"
fi

# V15: storybookTest() in multiple configs
STORYBOOK_CONFIGS=$(grep -rl 'storybookTest' packages/*/vitest.config.* apps/*/vitest.config.* 2>/dev/null | grep -v node_modules || true)
SB_COUNT=$(echo "$STORYBOOK_CONFIGS" | grep -c '.' 2>/dev/null || echo "0")
if [ "$SB_COUNT" -gt 1 ]; then
  violation "V15" "storybookTest() plugin found in $SB_COUNT configs (must be exactly 1):"
  echo "$STORYBOOK_CONFIGS" | sed 's/^/       /'
elif [ "$SB_COUNT" -eq 1 ]; then
  ok "V15" "storybookTest() in exactly one config"
fi

echo ""

# ═══════════════════════════════════════════════════════════════
echo "── 3. PLAYWRIGHT CONFIGURATION ──"
# ═══════════════════════════════════════════════════════════════

for dir in apps/*/; do
  [ ! -d "$dir" ] && continue
  app_name=$(basename "$dir")

  # Check if app has E2E tests
  E2E_COUNT=$(find "$dir" -name '*.e2e.test.ts' -not -path '*/node_modules/*' 2>/dev/null | wc -l | tr -d ' ')
  API_COUNT=$(find "$dir" -name '*.api.test.ts' -not -path '*/node_modules/*' 2>/dev/null | wc -l | tr -d ' ')
  TOTAL_E2E=$((E2E_COUNT + API_COUNT))

  if [ "$TOTAL_E2E" -eq 0 ]; then
    continue
  fi

  echo "  ── App: $app_name ($E2E_COUNT e2e + $API_COUNT api tests) ──"

  # P1: Has playwright config
  if [ -f "${dir}playwright.config.ts" ]; then
    PW_CFG=$(cat "${dir}playwright.config.ts")

    # P2: forbidOnly
    if echo "$PW_CFG" | grep -q 'forbidOnly'; then
      ok "P2" "forbidOnly is set"
    else
      violation "P2" "Missing forbidOnly in playwright config"
    fi

    # P3: workers
    if echo "$PW_CFG" | grep -q 'workers.*CI'; then
      ok "P3" "CI workers limit is set"
    else
      warning "P3" "Missing CI workers limit"
    fi

    # P7: playwright/.auth in gitignore
    if [ -f "${dir}.gitignore" ] && grep -q 'playwright/.auth' "${dir}.gitignore" 2>/dev/null; then
      ok "P7" "playwright/.auth/ is gitignored"
    elif [ -f ".gitignore" ] && grep -q 'playwright/.auth' .gitignore 2>/dev/null; then
      ok "P7" "playwright/.auth/ is gitignored (root)"
    else
      violation "P7" "playwright/.auth/ not in .gitignore"
    fi
  else
    violation "P1" "Missing playwright.config.ts but has $TOTAL_E2E E2E/API test files"
  fi

  # P8: E2E count
  if [ "$E2E_COUNT" -gt 30 ]; then
    warning "P8" "$E2E_COUNT E2E tests (recommended max: 30) - push edge cases to unit/integration"
  fi
done

echo ""

# ═══════════════════════════════════════════════════════════════
echo "── 4. PAGE OBJECTS ──"
# ═══════════════════════════════════════════════════════════════

# E1: E2E test files should import from pages/
E2E_FILES=$(find . -name '*.e2e.test.ts' -not -path '*/node_modules/*' 2>/dev/null || true)
NO_PAGE_OBJECT=0
if [ -n "$E2E_FILES" ]; then
  while IFS= read -r f; do
    if ! grep -q 'from.*\.page' "$f" 2>/dev/null && ! grep -q 'from.*pages/' "$f" 2>/dev/null; then
      ((NO_PAGE_OBJECT++)) || true
      [ "$NO_PAGE_OBJECT" -le 5 ] && echo "       $f"
    fi
  done <<< "$E2E_FILES"
fi
if [ "$NO_PAGE_OBJECT" -gt 0 ]; then
  violation "E1" "$NO_PAGE_OBJECT E2E test file(s) don't import Page Objects"
else
  ok "E1" "All E2E test files use Page Objects (or no E2E tests exist)"
fi

# E2: Page Objects should not contain expect()
PAGE_OBJECTS=$(find . -name '*.page.ts' -not -path '*/node_modules/*' 2>/dev/null || true)
PO_WITH_ASSERT=0
if [ -n "$PAGE_OBJECTS" ]; then
  while IFS= read -r f; do
    if grep -q 'expect(' "$f" 2>/dev/null; then
      ((PO_WITH_ASSERT++)) || true
      echo "       $f"
    fi
  done <<< "$PAGE_OBJECTS"
fi
if [ "$PO_WITH_ASSERT" -gt 0 ]; then
  violation "E2" "$PO_WITH_ASSERT Page Object(s) contain assertions (expect)"
else
  ok "E2" "Page Objects are assertion-free"
fi

echo ""

# ═══════════════════════════════════════════════════════════════
echo "── 5. BROWSER TEST PATTERNS ──"
# ═══════════════════════════════════════════════════════════════

BROWSER_TESTS=$(find . -name '*.browser.test.tsx' -not -path '*/node_modules/*' 2>/dev/null || true)

if [ -n "$BROWSER_TESTS" ]; then
  # Q8: No @testing-library/react in browser tests
  TL_IMPORTS=$(grep -rl '@testing-library/react' $(echo "$BROWSER_TESTS") 2>/dev/null || true)
  if [ -n "$TL_IMPORTS" ]; then
    COUNT=$(echo "$TL_IMPORTS" | wc -l | tr -d ' ')
    violation "Q8" "$COUNT browser test file(s) import @testing-library/react (use vitest-browser-react):"
    echo "$TL_IMPORTS" | head -5 | sed 's/^/       /'
  else
    ok "Q8" "No @testing-library/react in browser tests"
  fi

  # Q9: No screen.getByRole in browser tests
  SCREEN_USAGE=$(grep -rl 'screen\.getBy\|screen\.findBy\|screen\.queryBy' $(echo "$BROWSER_TESTS") 2>/dev/null || true)
  if [ -n "$SCREEN_USAGE" ]; then
    COUNT=$(echo "$SCREEN_USAGE" | wc -l | tr -d ' ')
    violation "Q9" "$COUNT browser test file(s) use screen.getBy* (use page.getBy*):"
    echo "$SCREEN_USAGE" | head -5 | sed 's/^/       /'
  else
    ok "Q9" "No screen.getBy* in browser tests"
  fi
else
  echo "  (no .browser.test.tsx files found - skipping browser pattern checks)"
fi

echo ""

# ═══════════════════════════════════════════════════════════════
echo "── 6. STORYBOOK SETUP ──"
# ═══════════════════════════════════════════════════════════════

STORYBOOK_DIRS=$(find . -maxdepth 3 -type d -name '.storybook' -not -path '*/node_modules/*' 2>/dev/null || true)
if [ -n "$STORYBOOK_DIRS" ]; then
  while IFS= read -r sb_dir; do
    pkg_dir=$(dirname "$sb_dir")
    pkg_name=$(basename "$pkg_dir")
    echo "  ── Package: $pkg_name ──"

    # S1: vitest.setup.ts exists
    if [ -f "$sb_dir/vitest.setup.ts" ]; then
      if grep -q 'setProjectAnnotations' "$sb_dir/vitest.setup.ts" 2>/dev/null; then
        ok "S1" "vitest.setup.ts with setProjectAnnotations"
      else
        warning "S1" "vitest.setup.ts exists but missing setProjectAnnotations"
      fi
    else
      violation "S1" "Missing .storybook/vitest.setup.ts"
    fi
  done <<< "$STORYBOOK_DIRS"
else
  echo "  (no .storybook/ directories found - skipping)"
fi

echo ""

# ═══════════════════════════════════════════════════════════════
echo "── 7. MISE / TASK RUNNER ──"
# ═══════════════════════════════════════════════════════════════

if [ -f "mise.toml" ]; then
  MISE_CFG=$(cat mise.toml)

  # M1: env._.path
  if echo "$MISE_CFG" | grep -q '_.path.*node_modules/.bin'; then
    ok "M1" "mise.toml has env._.path with node_modules/.bin"
  else
    violation "M1" "mise.toml missing env._.path = ['./node_modules/.bin']"
  fi

  # M4: No persistent on test tasks
  if echo "$MISE_CFG" | grep -A2 'tasks.*test' | grep -q 'persistent.*true'; then
    violation "M4" "Test task has persistent = true (will hang mise)"
  else
    ok "M4" "No persistent flag on test tasks"
  fi
else
  warning "M1" "No root mise.toml found"
fi

echo ""

# ═══════════════════════════════════════════════════════════════
echo "── 8. TYPESCRIPT CONFIGURATION ──"
# ═══════════════════════════════════════════════════════════════

# T1: tsconfig.build.json excludes test files
BUILD_CONFIGS=$(find . -name 'tsconfig.build.json' -not -path '*/node_modules/*' 2>/dev/null || true)
if [ -n "$BUILD_CONFIGS" ]; then
  MISSING_EXCLUDE=0
  while IFS= read -r cfg; do
    if ! grep -q '\.test\.' "$cfg" 2>/dev/null; then
      ((MISSING_EXCLUDE++)) || true
      [ "$MISSING_EXCLUDE" -le 5 ] && echo "       $cfg"
    fi
  done <<< "$BUILD_CONFIGS"
  if [ "$MISSING_EXCLUDE" -gt 0 ]; then
    violation "T1" "$MISSING_EXCLUDE tsconfig.build.json file(s) don't exclude *.test.* files"
  else
    ok "T1" "All tsconfig.build.json exclude test files"
  fi
else
  warning "T1" "No tsconfig.build.json files found"
fi

echo ""

# ═══════════════════════════════════════════════════════════════
echo "── 9. .GITIGNORE ──"
# ═══════════════════════════════════════════════════════════════

if [ -f ".gitignore" ]; then
  GI=$(cat .gitignore)
  check_gitignore() {
    local pattern="$1" label="$2" id="$3"
    if echo "$GI" | grep -q "$pattern"; then
      ok "$id" "$label is ignored"
    else
      violation "$id" "$label not in .gitignore"
    fi
  }
  check_gitignore "coverage" "coverage/" "G1"
  check_gitignore "test-results" "test-results/" "G2"
  check_gitignore "playwright-report" "playwright-report/" "G3"
  check_gitignore "playwright.*auth\|playwright/.auth" "playwright/.auth/" "G4"
  check_gitignore "storybook-static" "storybook-static/" "G5"
else
  violation "G0" "No root .gitignore found"
fi

echo ""

# ═══════════════════════════════════════════════════════════════
echo "── 10. TEST INVENTORY ──"
# ═══════════════════════════════════════════════════════════════

count_files() {
  find . -name "$1" -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | wc -l | tr -d ' '
}

UNIT_TS=$(count_files '*.test.ts')
UNIT_TSX=$(count_files '*.test.tsx')
BROWSER=$(count_files '*.browser.test.tsx')
STORIES=$(count_files '*.stories.tsx')
INTEGRATION=$(count_files '*.integration.test.ts')
E2E=$(count_files '*.e2e.test.ts')
API=$(count_files '*.api.test.ts')
CONTRACTS=$(count_files '*.contract.ts')
BENCHMARKS=$(count_files '*.bench.ts')
CHECKS=$(count_files '*.check.ts')
BROWSER_CHECKS=$(count_files '*.browser.check.ts')

echo "  Unit tests (.test.ts):           $UNIT_TS"
echo "  Server JSX tests (.test.tsx):     $UNIT_TSX"
echo "  Browser tests (.browser.test.tsx): $BROWSER"
echo "  Stories (.stories.tsx):            $STORIES"
echo "  Integration (.integration.test.ts):$INTEGRATION"
echo "  E2E (.e2e.test.ts):               $E2E"
echo "  API tests (.api.test.ts):          $API"
echo "  Contracts (.contract.ts):          $CONTRACTS"
echo "  Benchmarks (.bench.ts):            $BENCHMARKS"
echo "  Checkly API (.check.ts):           $CHECKS"
echo "  Checkly browser (.browser.check.ts):$BROWSER_CHECKS"
echo ""

TOTAL=$((UNIT_TS + UNIT_TSX + BROWSER + STORIES + INTEGRATION + E2E + API + CONTRACTS + BENCHMARKS + CHECKS + BROWSER_CHECKS))
echo "  Total test-related files:          $TOTAL"

echo ""

# ═══════════════════════════════════════════════════════════════
echo "── 11. PER-PACKAGE COVERAGE GAP ──"
# ═══════════════════════════════════════════════════════════════

for dir in packages/*/ apps/*/; do
  [ ! -d "$dir" ] && continue
  pkg_name=$(basename "$dir")
  parent=$(basename "$(dirname "$dir")")

  u=$(find "$dir" -name '*.test.ts' -not -path '*/node_modules/*' 2>/dev/null | wc -l | tr -d ' ')
  ut=$(find "$dir" -name '*.test.tsx' -not -path '*/node_modules/*' 2>/dev/null | wc -l | tr -d ' ')
  b=$(find "$dir" -name '*.browser.test.tsx' -not -path '*/node_modules/*' 2>/dev/null | wc -l | tr -d ' ')
  s=$(find "$dir" -name '*.stories.tsx' -not -path '*/node_modules/*' 2>/dev/null | wc -l | tr -d ' ')
  i=$(find "$dir" -name '*.integration.test.ts' -not -path '*/node_modules/*' 2>/dev/null | wc -l | tr -d ' ')
  e=$(find "$dir" -name '*.e2e.test.ts' -not -path '*/node_modules/*' 2>/dev/null | wc -l | tr -d ' ')
  c=$(find "$dir" -name '*.contract.ts' -not -path '*/node_modules/*' 2>/dev/null | wc -l | tr -d ' ')

  total=$((u + ut + b + s + i + e + c))
  [ "$total" -eq 0 ] && [ ! -f "${dir}vitest.config.ts" ] && continue

  printf "  %-30s unit=%-3s tsx=%-3s browser=%-3s story=%-3s integ=%-3s e2e=%-3s contract=%-3s\n" \
    "$parent/$pkg_name" "$u" "$ut" "$b" "$s" "$i" "$e" "$c"
done

echo ""

# ═══════════════════════════════════════════════════════════════
echo "══════════════════════════════════════════════════════════"
echo "  SUMMARY"
echo "══════════════════════════════════════════════════════════"
echo "  🔴 Violations:  $VIOLATIONS"
echo "  🟡 Warnings:    $WARNINGS"
echo "  🟢 OK:          $OK"
echo "  💡 Suggestions: $SUGGESTIONS"
echo ""

if [ "$VIOLATIONS" -gt 0 ]; then
  echo "  ⚠  $VIOLATIONS violation(s) found. See REVIEW.md for fix guidance."
  exit 1
else
  echo "  ✅ No violations detected by automated scan."
  echo "  ℹ  Run the manual review checklist in REVIEW.md for full coverage."
  exit 0
fi
