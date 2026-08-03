# Authoring Workflow

Use this when creating or heavily restructuring a docs site.

## Goal

Produce a coherent docs site for the current repo, grounded in code and organized by Diataxis.

## Workflow

1. Read `source-of-truth.md` and build the project profile.
2. Audit the current docs pages and current public code surfaces.
3. Build a page inventory:
   - existing useful pages
   - missing pages
   - stale pages to rewrite or remove
4. Reclassify pages by Diataxis.
5. Design the information architecture.
6. Update the navigation config.
7. Preserve existing useful URLs where reasonable, but change misleading paths when the structure no longer fits.
8. Write or rewrite the pages.
9. Validate the docs app with the repo's real scripts.

## Recommended IA

Use these sections unless the current repo shape clearly requires otherwise:

- Tutorials
- How-To Guides
- Explanation
- Reference

Map content to them like this:

- getting started and installation pages -> Tutorials
- task pages, including extension or plugin development -> How-To Guides
- concept and architecture pages -> Explanation
- generated or hand-written API pages -> Reference
- examples catalog -> a Tutorial entrypoint plus a Reference-style catalog as needed

## Content Coverage Checklist

Adapt this to the product areas in your project profile.
A complete site usually covers:

- quick start
- installation
- the core mental model of the project
- the primary domain objects and how they relate
- an overview of any optional or pluggable packages
- per-package usage and reference
- an extension or plugin authoring workflow, if the project supports one
- runtime, rendering, or deployment concerns specific to the project
- integration surfaces the project exposes
- CLI docs, if there is a CLI
- benchmarking docs, if benchmarks are published
- API reference
- an examples catalog plus highlighted examples

Examples coverage rule:

- do not create one page per example by default
- ensure every current example is mentioned at least once through landing or catalog content
- give deeper treatment only to high-value or foundational examples

## Writing Rules

- Use current package names and current imports.
- Use the repo's package manager in every command.
- Keep snippets grounded in real exports.
- Explain caveats as present facts.
- Prefer cross-links over mixing multiple doc purposes in one page.
- Keep navigation changes compliant with the generator and conservative in shape.

## Prompt Template

Use this task framing when another agent needs to author or restructure the docs.
Fill the bracketed values from the project profile.

```text
Create or restructure the docs in `<docs-root>` as a present-state snapshot of the current repository.
Audit the current code, package entrypoints, examples, and docs pages first.
Follow Diataxis strictly, update `<nav-config-path>` when the information architecture changes,
document the real package, API, and example surfaces, and validate with the repo's documented
docs scripts (`<pkg-manager> run typecheck` and `<pkg-manager> run build` from `<docs-root>`).
```

## Review Questions

Before finishing, confirm:

- Does each page have one clear Diataxis role?
- Does the navigation reflect the real product structure?
- Are examples documented from the real example inventory and actual example code?
- Are optional package boundaries correctly separated from the core?
- Are there any stale names or ghost features left in the content?
