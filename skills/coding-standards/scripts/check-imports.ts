#!/usr/bin/env bun

/**
 * Copyright (c) Ted Simonian
 * SPDX-License-Identifier: MIT
 */

import { existsSync, readFileSync } from 'node:fs';
import { dirname, relative, resolve } from 'node:path';

import { Glob } from 'bun';

const IMPORT_REGEX = /^import(?:\s+\S.*(?:[\n\r\u2028\u2029]\s*|[\t\v\f \xa0\u1680\u2000-\u200a\u202f\u205f\u3000\ufeff])|\s{2,})from\s+["']([^"']+)["']/gm;
const EXPORT_FROM_REGEX = /^export(?:\s+\S.*(?:[\n\r\u2028\u2029]\s*|[\t\v\f \xa0\u1680\u2000-\u200a\u202f\u205f\u3000\ufeff])|\s{2,})from\s+["']([^"']+)["']/gm;
const DYNAMIC_IMPORT_REGEX = /import\s*\(\s*["']([^"']+)["']\s*\)/g;

interface Violation {
  file: string;
  importPath: string;
  line: number;
  suggestion: string;
}

/**
 *
 * @param filePath
 */
function checkFile(filePath: string): Violation[] {
  const violations: Violation[] = [];
  const content = readFileSync(filePath, 'utf-8');
  const lines = content.split('\n');

  for (let lineNum = 0; lineNum < lines.length; lineNum += 1) {
    const line = lines[lineNum];

    const patterns = [IMPORT_REGEX, EXPORT_FROM_REGEX, DYNAMIC_IMPORT_REGEX];

    for (const pattern of patterns) {
      pattern.lastIndex = 0;
      let match;

      while ((match = pattern.exec(line)) !== null) {
        const importPath = match[1];

        if (needsExtension(importPath)) {
          violations.push({
            file: filePath,
            importPath,
            line: lineNum + 1,
            suggestion: `${importPath}.js`,
          });
        }
      }
    }
  }

  return violations;
}

/**
 *
 * @param importPath
 */
function isLocalImport(importPath: string): boolean {
  return importPath.startsWith('./') || importPath.startsWith('../') || importPath.startsWith('@/');
}

/**
 *
 */
async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const targetPath = args[0] || '.';
  const fixMode = args.includes('--fix');

  const absolutePath = resolve(process.cwd(), targetPath);

  if (!existsSync(absolutePath)) {
    console.error(`Path not found: ${absolutePath}`);
    process.exit(1);
  }

  const glob = new Glob('**/*.{ts,tsx}');
  const files: string[] = [];

  for await (const file of glob.scan({ absolute: true, cwd: absolutePath })) {
    if (!file.includes('node_modules') && !file.includes('.next') && !file.includes('dist')) {
      files.push(file);
    }
  }

  let totalViolations = 0;
  const allViolations: Violation[] = [];

  for (const file of files) {
    const violations = checkFile(file);

    if (violations.length > 0) {
      totalViolations += violations.length;
      allViolations.push(...violations);
    }
  }

  if (allViolations.length === 0) {
    console.log('All imports have correct .js extensions');
    process.exit(0);
  }

  console.log(`Found ${totalViolations} import(s) missing .js extension:\n`);

  for (const v of allViolations) {
    const relPath = relative(process.cwd(), v.file);

    console.log(`${relPath}:${v.line}`);
    console.log(`  ${v.importPath}  ->  ${v.suggestion}\n`);
  }

  if (fixMode) {
    console.log('\nRun \'eslint --fix\' to auto-fix these issues.');
  } else {
    console.log('\nUse --fix flag or run \'eslint --fix\' to auto-correct.');
  }

  process.exit(1);
}

/**
 *
 * @param importPath
 */
function needsExtension(importPath: string): boolean {
  if (!isLocalImport(importPath)) return false;
  if (importPath.endsWith('.js') || importPath.endsWith('.json') || importPath.endsWith('.css')) return false;
  if (importPath.endsWith('/')) return false;
  return true;
}

main();
