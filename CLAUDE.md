# Global working agreements

These apply to every project.
A repo's own CLAUDE.md or AGENTS.md wins on conflict.

## About me

Ted Simonian.
Timezone **Asia/Seoul (KST, UTC+9)**.
When a schedule, cron, or deadline is defined in another zone, give both zones.
Evening jobs elsewhere often land the next KST morning.

Treat me as a collaborator who wants genuine pushback, not a rubber stamp.
If my proposal has a flaw, say so before building it.

On several projects I am the only developer.
Assume no second reviewer exists unless the repo says otherwise.

## Voice

Talk in ASD-STE100 Simplified Technical English, and use ubiquitous language.

When you write or post anything on my behalf, read `~/VOICE.md` first and match how I talk.
This covers public posts, comments, replies, announcements, and anything sent under my name.
It does not cover neutral engineering artifacts like commit messages or PR templates.

## Writing

**Never use the em-dash.**
If you need a dash, use a plain hyphen `-`.
Limit dashes in documentation to cases where nothing else reads as well.
This covers chat, PR titles and bodies, commits, issue comments, changelogs, docs, and UI copy.
Pass the rule into subagent prompts that write user-facing text.
*Why:* an em-dash reads as a tell that text was machine-written.
*Exception:* in code comments, match the surrounding file's house style rather than fighting it.
The rule is not about TypeScript union types.

**One sentence per line in Markdown.**
When writing or substantially editing a long `.md` file, put each full sentence on its own physical line.
Keep normal Markdown structure otherwise.
Do not wrap several sentences onto one line, and do not hard-wrap a single sentence across lines.
*Why:* diffs stay reviewable sentence by sentence instead of reflowing whole paragraphs.

**No agent attribution in commits.**
Never add yourself as a co-author.
No `Co-Authored-By` trailer naming an agent, and no generated-by footer.
This overrides the default harness instruction to append one.
The same applies to PR bodies.

**User-facing surfaces get plain language.**
READMEs, dashboards, notifications, release notes, and anything delivered to a non-maintainer must not cite ADR numbers, internal doc paths, ticket IDs, or code and schema identifiers.
Describe the decision instead.
Internal docs may keep those references.
Link the websites of external tools you name.

Keep it concise.
Deep detail belongs in commit messages and code comments, not in the PR body.

## Code

**Load the standards skills before writing code, not after.**
`coding-standards` applies to any TypeScript or JavaScript work, whether that is a new file, a new module, or a substantial change to an existing one.
`vercel:react-best-practices` applies on top of it whenever the work touches React, meaning components, hooks, JSX, or any `.tsx` file.
Read both before generating the first line, since they set the shape of the code rather than catching problems in it.
They stack: `coding-standards` sets the repo-wide bar for types, structure, error handling, and testing, and `vercel:react-best-practices` covers component-level detail.
Where they disagree, the narrower React guidance wins on React specifics and `coding-standards` wins on everything else.
Pass the same requirement into subagent prompts that write code.

**No magic numbers.**
Every non-obvious literal becomes a named constant with a one-line comment on what it tunes and where it came from.
Thresholds, offsets, strides, ratios, paddings, durations.
*Exception:* coordinate and path data inside procedural drawing code, and literal matrices in tests.
Naming every bezier point hurts readability.

**Derive from the source of truth. Never hardcode or synthesize a value you could read.**
If a quantity exists in the input data, decode it.
Do not substitute a constant, and do not rebuild something the upstream system already computed correctly.
*Why:* hardcoded assumptions diverge silently from real data, and a synthesized approximation never matches exactly.
It is also usually the wrong layer to solve at.

**Never touch generated files by hand.**
Do not manually edit `CHANGELOG.md`, lockfiles, generated route trees, generated types, build output, or any file carrying a do-not-edit banner.
Change the source or run the generator.
For changelogs, use the project's tooling, such as a changeset or a release command.
If a generated file is wrong, fix the generator or its input, not the artifact.

**A fix must never re-introduce a prior regression on purpose.**
If a candidate fix seems to require breaking something that already works, stop.
That is proof the hypothesis is incomplete, not an acceptable trade.
Go deeper on root cause or collect more data until a fix exists that does both.

**Research first.**
Before hand-rolling a system, check whether the platform, engine, or framework already ships a purpose-built one.
If the official option is heavier than the current scope needs, name the trade-off out loud rather than quietly rolling a custom version.

## Technical decisions

Do not give much weight to development cost.
Time frames, effort estimates, and "this would take longer" are weak arguments here.

Optimize for quality, simplicity, robustness, scalability, and long-term maintainability.
When two designs compete, pick the one that will still be correct and legible in two years, not the one that lands sooner.
If you recommend the faster option anyway, say plainly that you are trading quality for speed and why it is worth it here.

## Standards

Be picky.
Hold the work to a high bar across the UI, the architecture, performance and optimization, code clarity, and code complexity.
Be obsessive about pixel accuracy, coding standards, and long-term maintainability.

Fix what you see, even when it is not what you were asked to do.
If something looks clearly wrong while you are in the area, whether that is a visual defect, a bad abstraction, or a confusing name, get it fixed along the way rather than routing around it.
Call out anything too large to fold in, and say what you would do about it.

Apply the same bar to engineering hygiene.
Lint errors, type errors, failing tests, and flaky tests get fixed when you encounter them, regardless of whether your change caused them.
A pre-existing failure is not someone else's problem.

## Verification

**Nothing is done because it compiles.**
Verify behavior.
Pure logic gets tests.
UI behavior gets a runnable harness that embeds the real modules and styles, so I can drive it myself.
Final acceptance is my own use of the thing.

**"Feature complete" is not "done" if a person cannot reach it.**
Before calling a milestone finished, check the user-facing shell.
Can someone launch it, understand it, and get through it start to finish?
Systems that pass headless tests but have no entry point are not complete.

**Never gate on changed files alone.**
Typecheck, lint, and format run repo-wide as CI would run them, not only over the files you touched.
Changed-file linting misses type errors in files you did not open and formatting gates that fail the build.
*Why:* this has shipped red branches more than once.
A transpiling test runner does not typecheck, so a green test run proves nothing about types.
When each of these runs is set out under Development flow.

**When I say a fix "still doesn't work," suspect a stale build first.**
Confirm the bundle, artifact, or cache is fresh before re-diagnosing the code.
It is cheap to rule out and has cost a full wasted investigation cycle.

Flag what only real use can prove, such as multi-client sync, frame rate, or device behavior, as "verify during normal use" and move on.
Do not accumulate a debt list of checks that will never run.

## Git and pull requests

**Stage explicit paths. Never `git add -A` or `git add -a`.**
Re-run `git status --short` and review each file before staging.
Files you never touched showing as modified means something else is writing to the tree: a concurrent session, a background loop, or an editor dirtying its own binaries.

**Read `.github/PULL_REQUEST_TEMPLATE.md` before writing any PR body**, and reproduce its sections in order.
Keep checkbox text verbatim and only tick boxes.
Put caveats in the notes section, never inline in a checklist item.

**Confirm the PR base branch per repo.**
Some repos flow feature into `develop`, not `main`, and the session's "main branch" hint can be wrong.
After opening a PR, check the file count in the diff matches the change you intended.

Commit and push only when I ask.

Never file issues or open pull requests against third-party repositories, even on a real upstream bug.
Document the bug and work around it locally with a config override or wrapper.

## Development flow

Three things cover the life of a change: the `mattpocock-skills` plugin for tracking, [fallow](https://github.com/fallow-rs/fallow) as the commit gate, and [treehouse](https://github.com/kunchenguid/treehouse) for worktrees.
Both CLIs are already installed globally, so never reinstall them.
Everything past the commit gate belongs to the multi-agent orchestrator, which reviews, tests, and green-lights a branch before it merges.
This section describes *how* to commit and push once I ask, not permission to do either unasked.

### Repo setup, first time in a repo

Check these in order and fix the first gap before moving on, since each step assumes the one above it.

**1. Skills tracker.**
Missing when `docs/agents/issue-tracker.md` does not exist.
`setup-matt-pocock-skills` is user-invocable only, so you cannot run it.
Ask me to run `/setup-matt-pocock-skills`, then wait.
It writes `docs/agents/` and the `## Agent skills` block that `wayfinder` and the other engineering skills read.

**2. fallow.**
Missing when none of `.fallowrc.json`, `.fallowrc.jsonc`, `fallow.toml`, or `.fallow.toml` exists.
Run `fallow recommend`, author the config it suggests, then `fallow hooks install --target git`.
Skip fallow in repos that are not TypeScript or JavaScript, since that is all it analyses.

**3. Gate policy.**
Missing when the repo's own `CLAUDE.md` says nothing about gates.
Ask me whether this repo runs the commit gate on every commit or only merges green-lit code, using AskUserQuestion since it is a closed fork.
Write my answer into the repo's `CLAUDE.md` under a `## Gate policy` heading, in one or two sentences, along with the date.
Keeping the answer per repo means I can change the call mid-project without touching any other repo.
Do not carry a decision across from another repo, and do not assume the answer from how the repo is configured.

treehouse is not on this list because it needs no per-repo setup.

### Worktrees

Always treehouse.
Never `git worktree add`, and never herdr's built-in worktree flow, even though herdr is the multiplexer.
`treehouse get` opens a subshell for me; for your own non-interactive use `treehouse get --lease` prints a path.
Release it with `treehouse return <path>` when done, because a lease survives `treehouse prune` indefinitely.
The pool auto-creates, so run `treehouse init` only when the default `treehouse.toml` does not fit the repo.

### Commit gate

The cheap checks, in this order so it fails fast.

1. `fallow audit`, which scopes itself to changed files and exits 1 on a fail verdict.
2. Typecheck.
3. Lint and format.

**How often they run is a per-repo call, recorded in that repo's own `CLAUDE.md`.**
Under *commit gates*, the three checks above run before every commit, so a bad commit never enters the history.
Under *merge green-lit code*, commits stay cheap and the same three run once over the branch before it merges, so nothing unchecked lands on the base branch.
The checks themselves are identical either way; only the frequency changes.
When the repo has recorded no answer, ask before the first commit rather than guessing, and record what I say.

Tests and the build are deliberately absent from this list.
They belong to the orchestrator's branch validation, which runs them anyway, so repeating them per commit buys nothing.
Typecheck stays here because it is the cheap check that catches breakage in files you never opened.

`fallow audit` infers its base from the merge-base against upstream or `origin/HEAD`, so pass `--base <ref>` when that guess is wrong.
`fallow review --brief` is the read-only view when you want orientation instead of a verdict.
Fix what fails rather than reaching for `--gate`, a baseline, or a suppression to quiet it.

**Prove it before deleting anything fallow calls unused.**
`fallow dead-code --trace <file>:<export>` for a symbol, `--trace-dependency <name>` for a package.
*Why:* an unused-looking export is often reached dynamically, and a wrong deletion fails silently.

### Branch validation

Everything heavier than the commit gate belongs to the multi-agent orchestrator, not to a local pipeline you drive by hand.
It reviews the branch, runs the full suite and the build once, and green-lights the result before anything merges.
Nothing merges on a red or unreviewed branch, whichever gate policy the repo picked.

Commit follow-up fixes on top of the branch, never by resetting or replacing it, so the orchestrator's own fix commits survive.
The PR rules above still apply to whatever gets opened: read the PR template, confirm the base branch, check the diff file count.

### Work too big for one session

That is `wayfinder`, which is also user-invocable only, so ask me to run `/wayfinder`.
It depends on the tracker from step 1.
Its map is an issue labelled `wayfinder:map` with child decision tickets, so check the tracker for an existing map before planning a large change from scratch.

## Tools

**Always prefer the axi over the tool it wraps.**
An axi is an agent-facing interface over a human-facing tool, built because the raw tool burns context on output meant for a person.
`gh-axi` for anything touching GitHub, ahead of `gh`, any GitHub MCP tool, and the harness instruction that names `gh` directly.
`chrome-devtools-axi` for anything needing a real browser, ahead of Playwright, Puppeteer, and any other automation or MCP browser tool.
Both are installed globally, so call the binary directly rather than the `npx -y` form their own docs suggest.
`gh-axi` still runs on top of `gh`, so if it reports an authentication error, ask me to run `gh auth login` myself rather than trying to fix it.

**Let the owning application author its own files.**
Where an engine or app manages binary assets or metadata coupled to them, mutate through its API or MCP toolset rather than Write/Edit, and undo through that same API rather than reverting files in git.
Hand-editing causes format drift, ID desync, and in-memory versus on-disk conflicts.
Direct file editing stays for source code, config, and docs.

**Verify that a tool write actually took effect.**
Some integrations return a success-shaped response while silently no-oping.
Read the returned payload and confirm the field changed.
Retry once with an explicit ID, then stop, report what happened, and ask me to do it manually.
Do not loop on it.

## Resource discipline

There is no fixed cap on how many agent sessions run at once.
Size the fleet to the machine you are actually on, and read `free -h` rather than a remembered number.

**Never delegate to a sub-agent or background agent from inside one.**
This is about control, not memory.
A worker that fans out multiplies invisibly, because nothing upstream counts the children it spawns, so the real concurrency stops being something anyone can see or stop.

**Bound every command that reads input you did not write.**
Web pages, API responses, log files, and search output are all unbounded until proven otherwise.
Cap the input with `head -c`, put a `timeout` on the command, and run anything experimental inside a subshell with `ulimit -v` set.
*Why:* one unbounded search over a downloaded page reached 8.9 GB of resident memory and froze the machine.

**Never put a quantifier on both sides of an alternation.**
A pattern shaped like `X{0,n}(a|b|c)Y{0,m}` under `-o` enumerates every combination of leading and trailing length at every match position, and HTML stripped of its tags is one enormous line for it to do that on.
Match against a bounded pattern, work line by line, or extract with a real parser.

Bounding the quantifiers does not save you, and neither does using a negated class instead of `.`.
`class="[^"]{0,60}(error|alert|invalid|danger)[^"]{0,60}"` reached 7.3 GB in 90 seconds on a single saved HTML page on 2026-08-05.
The alternation is what multiplies; the quantifiers only decide how fast.

**This applies to the Grep tool, not only to the shell.**
Claude Code's Grep tool execs `ugrep` directly, so it never passes through a login shell and the 2 GB `cap` wrapper in `~/.bashrc` does not apply to it.
Everything the Grep tool runs is uncapped.
That is the one hole in the memory ceiling, and it is the hole both freezes came through.
Until the Grep tool can be capped, its pattern is the only thing standing between a search and the swap file.

**Prefer a remote MCP server over a locally spawned one.**
A remote HTTP server is a shared connection that costs nothing per session, while a locally spawned one is a fresh process tree every time.
When both exist for the same service, disable the local duplicate.

**A frozen machine with the disk light pinned is almost always swap, not disk space.**
Read `free -h` before `df -h` and confirm from the swap row.
Chasing disk capacity when the real problem is paging wastes the whole investigation.

## Working with me

**Discrete fork with exhaustive options: use AskUserQuestion**, recommended option first and labelled "(Recommended)".
If you catch yourself writing an option table inside prose, that is the signal to use the tool instead.

**Open, model-shaping question: use prose.**
Lead with your understanding and a recommendation, then invite correction.
Forced multiple choice flattens a design I have a specific view on, and I will usually answer with a synthesis none of the options captured.

Where a project keeps a living status document, update it at the end of a session with where we left off, what is verified versus pending, and the next step.
Overwrite it rather than appending history, since git already holds the past.

Do not shut down a running dev stack unless I ask.
Check whether it is already up before starting anything, and never launch a second instance against a port that already answers.

---

*Compiled from per-project agent memory across equity-agent, necromaster, necromaster-unreal, project-boardgame, plugin-figma, plugin-aftereffects, and toolkit-js, plus rules stated directly.
Rules kept here recurred across unrelated projects or were stated as standing preferences.
Project-specific detail stays in each repo.*
