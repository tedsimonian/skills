# Maintenance Workflow

Use this when docs already exist and code changes may have made them stale.

## Goal

Update the docs so they match the current repository exactly, without historical narration unless the live code explicitly exposes deprecated or compatibility surfaces.

## Workflow

1. Read `source-of-truth.md` and build the project profile.
2. Audit current docs against current code.
3. Build a docs-impact inventory:
   - new things to document
   - removed things to remove
   - renamed things to rewrite
   - reorganized things that require nav or IA changes
   - changed examples
   - deprecated or compatibility surfaces still exposed publicly
4. Update pages and navigation.
5. Preserve stable paths where reasonable, but do not keep misleading URLs or groupings.
6. Remove stale content rather than layering history on top of it.
7. Validate the docs app with the repo's real scripts.

## Snapshot Rules

Write only what is true now.

Do not mention older states unless the current source explicitly supports one of these:

- deprecated API
- compatibility alias
- transitional export
- explicit backwards-compatibility note in code or JSDoc

If a capability is partial, describe its current limitations directly.
Do not tell a refactor story.

## What To Audit Every Time

- the navigation config
- current docs pages under the pages directory
- package exports and manifests
- the example inventory
- package and docs app READMEs where relevant
- source directories for any CLI, tooling, or benchmarking area the docs site exposes

## Mandatory Drift Checks

Check for:

- wrong package names
- wrong import paths
- added or removed packages, plugins, or modules
- stale public API names
- outdated code snippets
- old example counts or example labels
- CLI or benchmarking pages that no longer match the code
- stale sidebar links
- orphaned pages no longer reachable from navigation
- concept pages that no longer match the architecture
- reference pages that still mention removed exports
- examples no longer mentioned anywhere after additions or renames
- install or run commands using the wrong package manager

## Prompt Template

Use this task framing when another agent needs to maintain the docs after code changes.
Fill the bracketed values from the project profile.

```text
Update the docs in `<docs-root>` to match the current codebase exactly.
Audit current docs against current package exports, entrypoints, examples, and docs config.
Treat the documentation as a present-state snapshot, not a history lesson.
Only mention deprecated or backwards-compatible behavior when the current public API or code
comments explicitly mark it.
Update `<nav-config-path>` if the information architecture or page inventory changed, then
validate with the repo's documented docs scripts (`<pkg-manager> run typecheck` and
`<pkg-manager> run build` from `<docs-root>`).
```

## Completion Checklist

- All touched pages still fit their Diataxis role
- New public surfaces are documented
- Removed surfaces are removed from docs
- Examples docs match current example inventory
- Navigation has no dead links
- No unsupported historical language remains
