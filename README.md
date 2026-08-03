# skills

My portable AI-coding setup: a global `CLAUDE.md` of working agreements, and the reusable Claude
Code skills I want available across projects.

## Contents

```
CLAUDE.md      global working agreements, applied to every project
VOICE.md       how I write, for anything posted under my name
skills/
  coding-standards/    TypeScript/ESM house style, ESLint, monorepo layout, service layer,
                       security, TanStack Start, Playwright  (12 files)
  documentation/       generator-agnostic docs operating manual: repo-truth discovery,
                       Diataxis authoring and maintenance workflows, README templates,
                       MDX component docs, Vocs setup, validate-docs script  (10 files)
  monorepo-testing/    Vitest, Playwright, Storybook, Checkly, Inngest, CI, naming, gotchas,
                       plus four scaffold scripts  (16 files)
```

The `documentation` skill starts by discovering the project profile (docs root, generator,
package manager, public packages) rather than assuming a layout, so it works with Vocs,
Docusaurus, Nextra, Starlight, VitePress, Mintlify, or a plain Markdown tree.

## Installing

Global working agreements and voice profile:

```bash
cp CLAUDE.md ~/.claude/CLAUDE.md
cp VOICE.md  ~/VOICE.md            # CLAUDE.md references this path
```

Skills, either globally or into a single repo:

```bash
cp -r skills/* ~/.claude/skills/          # every project
cp -r skills/* /path/to/repo/.claude/skills/   # one project
```

## About CLAUDE.md

It was compiled by auditing the per-project agent memory files across equity-agent, necromaster,
necromaster-unreal, project-boardgame, plugin-figma, plugin-aftereffects, and toolkit-js. A rule
earned its place if it recurred across unrelated projects or was stated as a standing preference.
Project-specific detail stays in each repo's own CLAUDE.md, which wins on conflict.
