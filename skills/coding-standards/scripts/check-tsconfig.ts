#!/usr/bin/env bun

/**
 * Copyright (c) Ted Simonian
 * SPDX-License-Identifier: MIT
 */

/**
 * TSConfig Validator
 *
 * Validates that tsconfig.json has the recommended settings
 * for enterprise-grade TypeScript development.
 *
 * Usage:
 *   bun run .claude/skills/coding-standards/scripts/check-tsconfig.ts [path/to/tsconfig.json]
 *
 * Exit codes:
 *   0 - All checks passed
 *   1 - Missing or incorrect settings found
 */

import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

interface TsConfig {
  compilerOptions?: Record<string, unknown>;
  exclude?: string[];
  extends?: string;
  include?: string[];
}

interface ValidationResult {
  actual: unknown;
  expected: unknown;
  reason: string;
  setting: string;
  severity: 'error' | 'warning';
}

// Required settings with reasons
const REQUIRED_SETTINGS: Array<{
  expected: unknown;
  path: string;
  reason: string;
  severity: 'error' | 'warning';
}> = [
  {
    expected: true,
    path: 'compilerOptions.strict',
    reason: 'Enables all strict type-checking options',
    severity: 'error',
  },
  {
    expected: true,
    path: 'compilerOptions.noUncheckedIndexedAccess',
    reason: 'Prevents undefined array access bugs',
    severity: 'warning',
  },
  {
    expected: true,
    path: 'compilerOptions.verbatimModuleSyntax',
    reason: 'Enforces explicit type-only imports and correct ESM syntax',
    severity: 'error',
  },
  {
    expected: ['NodeNext', 'Bundler'],
    path: 'compilerOptions.moduleResolution',
    reason: 'Required for proper ESM resolution',
    severity: 'error',
  },
  {
    expected: ['NodeNext', 'ESNext', 'ES2022'],
    path: 'compilerOptions.module',
    reason: 'Enables ESM module output',
    severity: 'error',
  },
  {
    expected: ['ES2022', 'ES2023', 'ESNext'],
    path: 'compilerOptions.target',
    reason: 'Modern target for optimal output',
    severity: 'warning',
  },
  {
    expected: true,
    path: 'compilerOptions.skipLibCheck',
    reason: 'Improves compilation performance',
    severity: 'warning',
  },
  {
    expected: [true, undefined],
    path: 'compilerOptions.noEmit',
    reason: 'Usually true for bundler-based builds (Vite/Bun)',
    severity: 'warning',
  },
];

/**
 *
 * @param obj
 * @param path
 */
function getNestedValue(obj: unknown, path: string): unknown {
  const parts = path.split('.');
  let current: unknown = obj;

  for (const part of parts) {
    if (current === null || current === undefined) {
      return undefined;
    }
    if (typeof current === 'object') {
      current = (current as Record<string, unknown>)[part];
    } else {
      return undefined;
    }
  }

  return current;
}

/**
 *
 * @param configPath
 */
function loadTsConfig(configPath: string): TsConfig | null {
  if (!existsSync(configPath)) {
    console.error(`\x1b[31mError: tsconfig.json not found at ${configPath}\x1b[0m`);
    return null;
  }

  try {
    const content = readFileSync(configPath, 'utf-8');
    // Remove JSON comments (// and /* */)
    const cleaned = content
      .replace(/\/\/.*$/gm, '')
      .replace(/\/\*[\S\s]*?\*\//g, '');

    return JSON.parse(cleaned);
  } catch (error) {
    console.error(`\x1b[31mError parsing tsconfig.json: ${error}\x1b[0m`);
    return null;
  }
}

/**
 *
 */
function main(): void {
  const configPath = process.argv[2] || './tsconfig.json';
  const resolvedPath = resolve(process.cwd(), configPath);

  console.log(`\x1b[1mValidating: ${resolvedPath}\x1b[0m`);

  const config = loadTsConfig(resolvedPath);

  if (!config) {
    process.exit(1);
  }

  const resolvedConfig = resolveExtends(config, resolvedPath);
  const results = validateConfig(resolvedConfig);

  printResults(results);

  const hasErrors = results.some((r) => r.severity === 'error');

  process.exit(hasErrors ? 1 : 0);
}

/**
 *
 * @param results
 */
function printResults(results: ValidationResult[]): void {
  const errors = results.filter((r) => r.severity === 'error');
  const warnings = results.filter((r) => r.severity === 'warning');

  if (results.length === 0) {
    console.log('\x1b[32m✓ All tsconfig settings are valid!\x1b[0m');
    return;
  }

  console.log('\n\x1b[1mTSConfig Validation Results\x1b[0m\n');

  if (errors.length > 0) {
    console.log('\x1b[31m✖ Errors (must fix):\x1b[0m\n');
    for (const error of errors) {
      const expected = Array.isArray(error.expected)
        ? `one of [${error.expected.join(', ')}]`
        : JSON.stringify(error.expected);

      console.log(`  \x1b[31m${error.setting}\x1b[0m`);
      console.log(`    Expected: ${expected}`);
      console.log(`    Actual:   ${JSON.stringify(error.actual)}`);
      console.log(`    Reason:   ${error.reason}\n`);
    }
  }

  if (warnings.length > 0) {
    console.log('\x1b[33m⚠ Warnings (recommended):\x1b[0m\n');
    for (const warning of warnings) {
      const expected = Array.isArray(warning.expected)
        ? `one of [${warning.expected.join(', ')}]`
        : JSON.stringify(warning.expected);

      console.log(`  \x1b[33m${warning.setting}\x1b[0m`);
      console.log(`    Expected: ${expected}`);
      console.log(`    Actual:   ${JSON.stringify(warning.actual)}`);
      console.log(`    Reason:   ${warning.reason}\n`);
    }
  }

  console.log(`\nSummary: ${errors.length} error(s), ${warnings.length} warning(s)`);
}

/**
 *
 * @param config
 * @param configPath
 */
function resolveExtends(config: TsConfig, configPath: string): TsConfig {
  if (!config.extends) {
    return config;
  }

  const baseConfigPath = resolve(dirname(configPath), config.extends);
  const baseConfig = loadTsConfig(
    baseConfigPath.endsWith('.json') ? baseConfigPath : `${baseConfigPath}.json`,
  );

  if (!baseConfig) {
    console.warn(`\x1b[33mWarning: Could not resolve extends: ${config.extends}\x1b[0m`);
    return config;
  }

  // Recursively resolve base config
  const resolvedBase = resolveExtends(baseConfig, baseConfigPath);

  // Merge: current config overrides base
  return {
    ...resolvedBase,
    ...config,
    compilerOptions: {
      ...resolvedBase.compilerOptions,
      ...config.compilerOptions,
    },
  };
}

/**
 *
 * @param config
 */
function validateConfig(config: TsConfig): ValidationResult[] {
  const results: ValidationResult[] = [];

  for (const rule of REQUIRED_SETTINGS) {
    const actual = getNestedValue(config, rule.path);
    const expectedValues = Array.isArray(rule.expected) ? rule.expected : [rule.expected];

    const isValid = expectedValues.some((expected) => actual === expected);

    if (!isValid) {
      results.push({
        actual,
        expected: rule.expected,
        reason: rule.reason,
        setting: rule.path,
        severity: rule.severity,
      });
    }
  }

  return results;
}

main();
