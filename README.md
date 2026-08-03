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

- [treehouse](https://github.com/kunchenguid/treehouse) - pooled, pre-warmed git worktrees
- [fallow](https://github.com/fallow-rs/fallow) - the commit gate, for TypeScript and JavaScript repos
- [no-mistakes](https://github.com/kunchenguid/no-mistakes) - the push gate, which validates a branch
  and opens the pull request
- [`gh`](https://cli.github.com/), authenticated, since `gh-axi` runs on top of it

Plus, inside Claude Code: the `mattpocock-skills` plugin, and the `gh-axi` and `chrome-devtools-axi`
skills in `~/.claude/skills/`.

Without them, that section of `CLAUDE.md` refers to tools the machine does not have.

## Installing

Global working agreements and voice profile. Symlink rather than copy, so this checkout stays the
one source of truth and the installed copies cannot drift out of sync:

```bash
ln -sf "$PWD/CLAUDE.md" ~/.claude/CLAUDE.md
ln -sf "$PWD/VOICE.md"  ~/VOICE.md         # CLAUDE.md references this path
```

Both links point back into this checkout, so moving or deleting it leaves them dangling and the
global config silently disappears. Keep the clone somewhere permanent.

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
