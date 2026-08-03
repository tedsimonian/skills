# Docs Source Of Truth

Read this first for every docs task.
Its job is to replace assumptions with facts discovered from the repository.

## Build The Project Profile

Before writing anything, establish these facts and keep them in front of you for the rest of the task.
If a fact cannot be determined from the repo, ask rather than guess.

| Fact | How to find it |
|------|----------------|
| Docs site root | Look for `docs/`, `apps/docs/`, `website/`, or `site/`. Confirm by finding the generator config inside it. |
| Generator | The docs app `package.json` dependencies, plus the config filename: `vocs.config.ts`, `docusaurus.config.js`, `astro.config.mjs` with Starlight, `.vitepress/config.ts`, `theme.config.tsx` for Nextra, `mint.json` for Mintlify. |
| Navigation config | The generator config file, or a dedicated sidebar file it imports. |
| Pages directory | The generator's convention, usually `pages/`, `docs/`, or `src/content/docs/`. |
| Package manager | The lockfile at the repo root: `bun.lockb`, `pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`. |
| Docs scripts | The `scripts` block of the docs app `package.json`. Use these verbatim. |
| Build exceptions | The docs app `README.md`, and any wrapper script the build script points at. |
| Public packages | Workspace globs in the root `package.json` or `pnpm-workspace.yaml`, filtered to packages that are not marked private. |
| Public API entrypoints | Each public package's `exports` or `main` field, and the files those point at. |
| Example inventory | An examples manifest if one exists, otherwise the `examples/` directory listing plus each example's README. |

## Primary Files To Read

Adapt these to the profile you just built.

- `README.md`
- `AGENTS.md` or `CLAUDE.md` if present
- the generator config file
- the docs app `README.md`
- all current pages under the pages directory
- each public package `package.json`
- each public package entrypoint
- the example manifest or examples directory
- package READMEs when they carry user-facing behavior or caveats
- source directories for any CLI, tooling, or benchmarking area the docs site exposes

## Authoritative API Sources

Use exported entrypoints as the reference source, not prose.
Resolve each public package's `exports` map to real files and read those.
Subpath exports each define their own public surface and each need documenting.

Prefer exports over prose if they conflict.

## Documentation Model

Use Diataxis rigorously:

- Tutorials: guided, happy-path, learning-oriented
- How-to guides: goal-driven, task-oriented
- Explanation: conceptual, architectural, "why"
- Reference: exact factual lookup material

Keep each page dominated by one role.
Split mixed pages when needed.

## Snapshot Rule

Write docs as the current state of the codebase.

Do not describe history unless:

- the current public API still exposes a deprecated or compatibility surface
- a code comment or JSDoc explicitly marks an alias, deprecation, or compatibility layer

Avoid historical framing such as:

- "previously"
- "formerly"
- "used to"
- "after the refactor"

Unless the source explicitly requires that context.

## Topics To Track Carefully

These are the areas where docs drift fastest in any repo.
Check each one against the code every time.

- package names and install commands
- import paths, including subpath entrypoints
- module or plugin inventory, when the project has a pluggable surface
- boundaries between core and optional packages
- worker, server, or runtime-specific setup when those pages are in scope
- integration or protocol surfaces the project exposes
- CLI and benchmarking docs if the current site exposes them
- example coverage against the real example inventory
- the current sidebar and top navigation structure
- build and runtime exceptions documented in the docs app README

## Navigation Constraints

- Prefer the navigation primitives already used in the generator config.
- Preserve stable links where reasonable.
- Do not keep stale section names or dead links just to avoid path churn.
- Do not assume arbitrarily deep nested sidebars unless the generator clearly supports them.

## When To Update Navigation

Update the navigation config when any of these change:

- top-level docs sections
- page inventory
- section names
- a new major product area
- a removed product area
- example grouping that should become navigable

Do not leave orphaned pages or dead links.
