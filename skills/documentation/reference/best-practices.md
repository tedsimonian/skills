# Documentation Best Practices

Use this only after the repo-specific workflow references.
This file is for prose and structure quality, not for deciding product truth.

## Write For The Current Repo

- Prefer source exports over README prose when they conflict.
- Prefer current package names and current imports.
- Prefer deleting stale claims over qualifying them with history.
- Describe caveats as present facts.

## Keep Diataxis Clean

- Tutorials:
  - one outcome
  - one guided path
  - minimal branching
- How-to guides:
  - start with the task
  - keep prerequisites explicit
  - link out instead of explaining everything inline
- Explanation:
  - focus on mental models and boundaries
  - use diagrams only when they reduce confusion
- Reference:
  - organize around real exports and package surfaces
  - avoid tutorial prose

## Keep Examples Faithful

- Use the repo's package manager in every command.
- Keep code samples aligned with real exports.
- Use actual package names from the repo.
- Do not invent example outputs or support levels.
- Prefer catalog coverage plus selected deep dives over shallow one-page-per-example sprawl.

## Prefer Present-Tense Snapshot Language

Write in the present tense about what the project does now:

- "<Project> exposes..."
- "The adapter package provides..."
- "Use this page when..."

Avoid:

- "used to"
- "formerly"
- "after the refactor"
- "the old API"

Unless the live code explicitly marks a compatibility or deprecated surface.

## Keep Pages Readable

- Keep frontmatter accurate and specific.
- Use descriptive link text, not "click here".
- Keep headings task-shaped or concept-shaped.
- Prefer short runnable snippets over long speculative samples.
- Put each full sentence on its own line in the source.
  It keeps diffs reviewable sentence by sentence.
- Avoid em-dashes.
  Use a comma, colon, parentheses, or a separate sentence.
