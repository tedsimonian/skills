# skills

My portable AI-coding setup: a global `CLAUDE.md` of working agreements, and the reusable Claude
Code skills I want available across projects.

## Contents

```
CLAUDE.md      global working agreements, applied to every project
VOICE.md       how I write, for anything posted under my name
skills/
  coding-standards/    framework-agnostic TypeScript and React standards: strict typing,
                       ESM, React patterns, error handling, service layer, security,
                       ESLint playbook, monorepo layout  (10 files)
  documentation/       generator-agnostic docs operating manual: repo-truth discovery,
                       Diataxis authoring and maintenance workflows, README templates,
                       MDX component docs, Vocs setup, validate-docs script  (10 files)
  monorepo-testing/    Vitest, Playwright, Storybook, Checkly, Inngest, CI, naming, gotchas,
                       plus four scaffold scripts  (16 files)
```

The `documentation` skill starts by discovering the project profile (docs root, generator,
package manager, public packages) rather than assuming a layout, so it works with Vocs,
Docusaurus, Nextra, Starlight, VitePress, Mintlify, or a plain Markdown tree.

## Prerequisites

`CLAUDE.md` describes a development flow that assumes these are installed globally:

- [treehouse](https://github.com/kunchenguid/treehouse) - pooled, pre-warmed git worktrees, used for
  every worktree the flow creates
- [fallow](https://github.com/fallow-rs/fallow) - the commit gate, for TypeScript and JavaScript repos
- [`gh`](https://cli.github.com/), authenticated, since `gh-axi` runs on top of it

Plus, inside Claude Code: the `mattpocock-skills` plugin for issue tracking, and the `gh-axi` and
`chrome-devtools-axi` skills in `~/.claude/skills/`.

Everything heavier than the commit gate belongs to the multi-agent orchestrator, which reviews,
tests, and green-lights a branch before it merges. That is not a tool you install here.

Without the list above, that section of `CLAUDE.md` refers to tools the machine does not have.

## Installing

Global working agreements and voice profile. Symlink rather than copy, so this checkout stays the
one source of truth and the installed copies cannot drift out of sync:

```bash
ln -sf "$PWD/CLAUDE.md" ~/.claude/CLAUDE.md
ln -sf "$PWD/VOICE.md"  ~/VOICE.md         # CLAUDE.md references this path
```

Both links point back into this checkout, so moving or deleting it leaves them dangling and the
global config silently disappears. Keep the clone somewhere permanent.

Skills, either globally or into a single repo.
Globally, symlink for the same reason as above, so an edit here reaches every project at once:

```bash
for s in skills/*/; do ln -sfn "$PWD/${s%/}" ~/.claude/skills/; done   # every project
```

Re-running the command is safe, because with a directory as the destination `-f` replaces each link in place.
The `-n` only matters if you name the link explicitly, where `ln -sf src ~/.claude/skills/alpha` would follow an existing `alpha` link and create `alpha/alpha` inside its target.

Into a single repo, copy instead, so the skill is committed alongside the code it governs and
survives for anyone who clones that repo without this one:

```bash
cp -r skills/coding-standards /path/to/repo/.claude/skills/   # one project
```

## About CLAUDE.md

It was compiled by auditing the per-project agent memory files across equity-agent, necromaster,
necromaster-unreal, project-boardgame, plugin-figma, plugin-aftereffects, and toolkit-js. A rule
earned its place if it recurred across unrelated projects or was stated as a standing preference.
Project-specific detail stays in each repo's own CLAUDE.md, which wins on conflict.
