#!/usr/bin/env bun

/**
 * Copyright (c) Ted Simonian
 * SPDX-License-Identifier: MIT
 */
/* eslint-disable no-console */

/**
 * Documentation Site Validator
 * Usage: bun run ./validate-docs.ts [docs-dir]
 */

import { existsSync } from 'node:fs';
import { readdir, readFile } from 'node:fs/promises';
import { extname, join } from 'node:path';
import process from 'node:process';

const REQUIRED_FILES = ['package.json', 'vocs.config.ts', 'tsconfig.json'];
const REQUIRED_DIRS = ['pages', 'public'];
const OPTIONAL_DIRS = ['scripts'];

interface PageValidation {
  brokenLinks: string[];
  file: string;
  hasDescription: boolean;
  hasFrontmatter: boolean;
  hasTitle: boolean;
}

interface ValidationResult {
  errors: string[];
  info: string[];
  passed: boolean;
  warnings: string[];
}

const red = (s: string): string => `\x1b[31m${s}\x1b[0m`;
const green = (s: string): string => `\x1b[32m${s}\x1b[0m`;
const yellow = (s: string): string => `\x1b[33m${s}\x1b[0m`;
const blue = (s: string): string => `\x1b[34m${s}\x1b[0m`;
const dim = (s: string): string => `\x1b[2m${s}\x1b[0m`;

/**
 * Extract the frontmatter from the content.
 *
 * @param content - The content to extract the frontmatter from.
 * @returns The frontmatter as a record of key-value pairs.
 */
function extractFrontmatter(content: string): Record<string, string> | null {
  const match = /^---\n([\s\S]*?)\n---/u.exec(content);

  if (!match?.[1]) return null;

  const frontmatter: Record<string, string> = {};
  const lines = match[1].split('\n');

  for (const line of lines) {
    const colonIndex = line.indexOf(':');

    if (colonIndex > 0) {
      const key = line.slice(0, colonIndex).trim();
      const value = line
        .slice(colonIndex + 1)
        .trim()
        .replace(/^["']|["']$/gu, '');

      frontmatter[key] = value;
    }
  }

  return frontmatter;
}

/**
 * Extract the links from the content.
 *
 * @param content - The content to extract the links from.
 * @returns The links as an array of strings.
 */
function extractLinks(content: string): string[] {
  const links: string[] = [];

  const markdownLinkPattern = /\[[^\]]*\]\((?<href>[^)]+)\)/gu;
  const hrefPattern = /href=["'](?<href>[^"']+)["']/gu;
  const srcPattern = /src=["'](?<src>[^"']+)["']/gu;

  for (const match of content.matchAll(markdownLinkPattern)) {
    if (match.groups?.['href']) links.push(match.groups['href']);
  }
  for (const match of content.matchAll(hrefPattern)) {
    if (match.groups?.['href']) links.push(match.groups['href']);
  }
  for (const match of content.matchAll(srcPattern)) {
    if (match.groups?.['src']) links.push(match.groups['src']);
  }

  return links;
}

/**
 * Find the files in the directory.
 *
 * @param dir - The directory to find the files in.
 * @param extensions - The extensions of the files to find.
 * @returns The files as an array of strings.
 */
async function findFiles(dir: string, extensions: string[]): Promise<string[]> {
  const files: string[] = [];

  /**
   * Walk the directory.
   *
   * @param currentDir - The current directory to walk.
   */
  async function walk(currentDir: string): Promise<void> {
    const entries = await readdir(currentDir, { withFileTypes: true });

    for (const entry of entries) {
      const fullPath = join(currentDir, entry.name);
      const isHiddenOrExcluded = entry.name.startsWith('.') || entry.name === 'node_modules' || entry.name === 'dist';

      if (entry.isDirectory() && !isHiddenOrExcluded) {
        await walk(fullPath);
      } else if (entry.isFile() && extensions.includes(extname(entry.name))) {
        files.push(fullPath);
      }
    }
  }

  await walk(dir);
  return files;
}

/**
 * Check if the link is an external or anchor link.
 *
 * @param link - The link to check.
 * @returns True if the link is an external or anchor link, false otherwise.
 */
function isExternalOrAnchorLink(link: string): boolean {
  return link.startsWith('http') || link.startsWith('#') || link.startsWith('mailto:');
}

/**
 * Check if the link is a storybook link.
 *
 * @param link - The link to check.
 * @returns True if the link is a storybook link, false otherwise.
 */
function isStorybookLink(link: string): boolean {
  return link.includes('/storybook/');
}

/**
 * Main function to validate the documentation site.
 *
 * @returns A promise that resolves when the validation is complete.
 */
async function main(): Promise<void> {
  const docsDir = process.argv[2] ?? process.cwd();

  console.log(`\n${blue('📚 Documentation Site Validator')}\n`);
  console.log(`${dim('Directory:')} ${docsDir}\n`);

  const result: ValidationResult = { errors: [], info: [], passed: true, warnings: [] };

  console.log(dim('Checking required files...'));
  for (const file of REQUIRED_FILES) {
    if (!existsSync(join(docsDir, file))) {
      result.errors.push(`Missing required file: ${file}`);
      result.passed = false;
    }
  }

  console.log(dim('Checking directory structure...'));
  for (const dir of REQUIRED_DIRS) {
    if (!existsSync(join(docsDir, dir))) {
      result.errors.push(`Missing required directory: ${dir}/`);
      result.passed = false;
    }
  }

  for (const dir of OPTIONAL_DIRS) {
    if (!existsSync(join(docsDir, dir))) {
      result.warnings.push(`Optional directory not found: ${dir}/`);
    }
  }

  console.log(dim('Validating vocs.config.ts...'));
  const configIssues = await validateVocsConfig(docsDir);

  for (const issue of configIssues) {
    if (issue.includes('Consider')) {
      result.warnings.push(issue);
    } else {
      result.errors.push(issue);
      result.passed = false;
    }
  }

  console.log(dim('Validating package.json...'));
  const pkgIssues = await validatePackageJson(docsDir);

  for (const issue of pkgIssues) {
    result.errors.push(issue);
    result.passed = false;
  }

  console.log(dim('Validating pages...'));
  const pagesDir = join(docsDir, 'pages');

  if (existsSync(pagesDir)) {
    const pages = await findFiles(pagesDir, ['.md', '.mdx']);

    result.info.push(`Found ${pages.length} documentation pages`);

    let pagesWithoutFrontmatter = 0;
    let pagesWithoutTitle = 0;
    let pagesWithoutDescription = 0;
    let totalBrokenLinks = 0;

    for (const page of pages) {
      const validation = await validatePage(page, docsDir);

      if (!validation.hasFrontmatter) pagesWithoutFrontmatter += 1;
      if (!validation.hasTitle) pagesWithoutTitle += 1;
      if (!validation.hasDescription) pagesWithoutDescription += 1;

      for (const link of validation.brokenLinks) {
        result.warnings.push(`Broken link in ${validation.file}: ${link}`);
        totalBrokenLinks += 1;
      }
    }

    if (pagesWithoutFrontmatter > 0) result.warnings.push(`${pagesWithoutFrontmatter} pages missing frontmatter`);
    if (pagesWithoutTitle > 0) result.warnings.push(`${pagesWithoutTitle} pages missing title in frontmatter`);
    if (pagesWithoutDescription > 0) {
                                       result.warnings.push(`${pagesWithoutDescription} pages missing description in frontmatter`);
}
    if (totalBrokenLinks > 0) result.info.push(`Found ${totalBrokenLinks} potential broken internal links`);
  }

  const scriptsDir = join(docsDir, 'scripts');

  if (existsSync(scriptsDir)) {
    const hasBuildScript = existsSync(join(scriptsDir, 'build.sh'));
    const hasDevScript = existsSync(join(scriptsDir, 'dev.sh'));

    if (hasBuildScript && hasDevScript) {
      result.info.push('Docs build shell wrappers present');
    } else {
      result.warnings.push('Missing docs shell wrappers for the documented Vocs build exception');
    }
  }

  console.log(`\n${'─'.repeat(50)}\n`);

  printSection('✖ Errors:', result.errors, red);
  printSection('⚠ Warnings:', result.warnings, yellow);
  printSection('ℹ Info:', result.info, blue);

  if (result.passed) {
    console.log(`${green('✓ Validation passed')}\n`);
    process.exit(0);
  } else {
    console.log(`${red('✖ Validation failed')}\n`);
    process.exit(1);
  }
}

/**
 * Print a section of items.
 *
 * @param title - The title of the section.
 * @param items - The items to print.
 * @param colorFn - The function to color the section.
 */
function printSection(title: string, items: string[], colorFn: (s: string) => string): void {
  if (items.length === 0) return;
  console.log(colorFn(title));
  for (const item of items) console.log(`  ${colorFn('•')} ${item}`);
  console.log();
}

/**
 * Validate the package.json file.
 *
 * @param docsDir - The directory to validate the package.json file in.
 * @returns The issues as an array of strings.
 */
async function validatePackageJson(docsDir: string): Promise<string[]> {
  const pkgPath = join(docsDir, 'package.json');
  const issues: string[] = [];

  if (!existsSync(pkgPath)) return ['package.json not found'];

  const content = await readFile(pkgPath, 'utf-8');
  const pkg = JSON.parse(content) as {
    dependencies: Record<string, string>;
    devDependencies: Record<string, string>;
    scripts?: Record<string, string> | undefined;
  };
  const deps = { ...pkg.dependencies, ...pkg.devDependencies };

  if (!deps['vocs']) issues.push('Missing vocs dependency');

  const requiredScripts = ['dev', 'build'];

  for (const script of requiredScripts) {
    if (!pkg.scripts?.[script]) issues.push(`Missing "${script}" script`);
  }

  return issues;
}

/**
 * Validate the page.
 *
 * @param filePath - The path to the page to validate.
 * @param docsDir - The directory to validate the page in.
 * @returns The validation result.
 */
async function validatePage(filePath: string, docsDir: string): Promise<PageValidation> {
  const content = await readFile(filePath, 'utf-8');
  const frontmatter = extractFrontmatter(content);
  const links = extractLinks(content);
  const brokenLinks: string[] = [];

  for (const link of links) {
    if (isExternalOrAnchorLink(link) || isStorybookLink(link)) continue;

    if (link.startsWith('/')) {
      const basePath = join(docsDir, 'pages', link.replace(/\/$/u, ''));
      const possiblePaths = [
        `${basePath}.md`,
        `${basePath}.mdx`,
        join(basePath, 'index.md'),
        join(docsDir, 'public', link),
      ];

      const exists = possiblePaths.some((p) => existsSync(p));

      if (!exists) brokenLinks.push(link);
    }
  }

  return {
    brokenLinks,
    file: filePath.replace(`${docsDir}/`, ''),
    hasDescription: frontmatter?.['description'] !== undefined,
    hasFrontmatter: frontmatter !== null,
    hasTitle: frontmatter?.['title'] !== undefined,
  };
}

/**
 * Validate the vocs.config.ts file.
 *
 * @param docsDir - The directory to validate the vocs.config.ts file in.
 * @returns The issues as an array of strings.
 */
async function validateVocsConfig(docsDir: string): Promise<string[]> {
  const configPath = join(docsDir, 'vocs.config.ts');
  const issues: string[] = [];

  if (!existsSync(configPath)) return ['vocs.config.ts not found'];

  const content = await readFile(configPath, 'utf-8');

  if (!content.includes('title:')) issues.push('Missing title in vocs.config.ts');
  if (!content.includes('sidebar:')) issues.push('Missing sidebar configuration');
  if (!content.includes('basePath:') && !content.includes('VOCS_BASE_PATH')) {
    issues.push('Consider adding basePath for GitHub Pages deployment');
  }

  return issues;
}

main().catch((error: unknown) => {
  if (error instanceof Error) {
    console.error(red('Error:'), error.message);
  } else {
    console.error(red('Error:'), 'Unknown error');
  }

  process.exit(1);
});
