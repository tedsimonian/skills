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

**Run the repo's full gate before committing, not just the files you touched.**
Typecheck, lint, format, and test as CI would run them.
Changed-file linting plus a test run misses type errors in files you did not open and formatting gates that fail the build.
*Why:* this has shipped red branches more than once.
A transpiling test runner does not typecheck.

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

## Tools

**Let the owning application author its own files.**
Where an engine or app manages binary assets or metadata coupled to them, mutate through its API or MCP toolset rather than Write/Edit, and undo through that same API rather than reverting files in git.
Hand-editing causes format drift, ID desync, and in-memory versus on-disk conflicts.
Direct file editing stays for source code, config, and docs.

**Verify that a tool write actually took effect.**
Some integrations return a success-shaped response while silently no-oping.
Read the returned payload and confirm the field changed.
Retry once with an explicit ID, then stop, report what happened, and ask me to do it manually.
Do not loop on it.

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
