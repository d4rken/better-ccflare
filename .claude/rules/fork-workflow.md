# Fork Workflow Rule

## When this rule applies

Any time you're fixing a bug, adding a feature, or making any change to the code in this repo (`d4rken/better-ccflare`), which is a fork of `tombii/better-ccflare` upstream.

This rule decides:
- Which branch to base new work on
- Whether to open an upstream PR
- How to merge into local `main` so the fix is usable immediately
- How to reconcile local history when upstream eventually lands (or rejects) the PR

This rule is in addition to (not a replacement for) the constraints in `CLAUDE.md`. Lint/typecheck/format, the `inline-worker.ts` exclusion, the "never bump version manually" rule, and all other repo rules still apply.

## Two lanes

Before starting, decide which lane the change belongs to:

| Lane | Branch prefix | Base branch | PR upstream? | When to use |
|------|---------------|-------------|--------------|-------------|
| **Upstream-bound** | `fix/*`, `feat/*` | `upstream/main` | Yes | Any general bug fix or improvement that should also benefit `tombii/better-ccflare`. Default lane. |
| **Fork-only** | `fork/*` | `origin/main` | No | Personal/fork-specific behavior, opinionated changes the user has explicitly said don't go upstream, or changes upstream has rejected that you want to keep locally. |

If unsure, ask the user which lane before starting. Default assumption is upstream-bound.

## Procedure A — Upstream-bound fix

Run these commands in order. Substitute `<name>` with a kebab-case short identifier (e.g., `oauth-refresh-race`).

```bash
# 1. Start from upstream/main (never from origin/main)
git fetch upstream
git checkout -b fix/<name> upstream/main

# 2. Code the fix and tests. Follow TDD per CLAUDE.md.

# 3. Verify (mandatory, per CLAUDE.md "After Code Changes")
bun run lint && bun run typecheck && bun run format

# 4. Commit using a recognized prefix (fix:|bug:|resolve:|feat:|add:|new:|security:|improve:|enhance:|update:|refactor:)
git add <specific files>            # never `git add .`
git commit -m "fix: <subject>"

# 5. Push branch to origin
git push -u origin fix/<name>

# 6. Open upstream PR
gh pr create --repo tombii/better-ccflare --base main --head d4rken:fix/<name>

# 7. Merge into local main with --no-ff (the merge commit is the undo handle)
git checkout main
git pull --ff-only
git merge --no-ff fix/<name> -m "Merge fix/<name>"
git push origin main
```

After step 7, the fix is in local `main` and immediately usable. Releasing to npm is separate — trigger the manual `Manual Release` workflow when ready.

Record the merge SHA from step 7 — you'll need it later for reconciliation. (`git log -1 --format=%H main` right after the merge.)

## Procedure B — Fork-only fix

```bash
# 1. Start from origin/main (NOT upstream/main)
git checkout main
git pull --ff-only
git checkout -b fork/<name>

# 2. Code the fix and tests.

# 3. Verify
bun run lint && bun run typecheck && bun run format

# 4. Commit
git add <specific files>
git commit -m "fix: <subject>"

# 5. (Optional) Push branch for backup
git push -u origin fork/<name>

# 6. Merge into local main with --no-ff
git checkout main
git merge --no-ff fork/<name> -m "Merge fork/<name>"
git push origin main
```

Never open an upstream PR for a `fork/*` branch.

## Procedure C — Reconciling after upstream advances

Always start on a clean `main`. Commit or stash local changes first.

### C.1 — Upstream merged your PR with identical SHAs (fast-forward case)

```bash
git fetch upstream
git merge upstream/main   # fast-forwards cleanly
```

### C.2 — Upstream squashed your PR (different SHA, same diff)

Revert your local merge first, then accept upstream's squash:

```bash
git fetch upstream
git revert -m 1 <merge-commit-sha>
git merge upstream/main
git push origin main
```

History will show: `Merge fix/X` → `Revert "Merge fix/X"` → `<upstream squash>`. Noisier but accurate.

**Faster alternative (only safe if no unrelated work landed on main since the merge):**

```bash
git reset --hard <merge-base-sha>     # the commit immediately before your merge
git fetch upstream && git merge upstream/main
git push --force-with-lease origin main   # requires confirming with user — force-push is destructive
```

Confirm with the user before force-pushing. Default to the slower revert+merge path unless the user has explicitly approved force-push for this case.

### C.3 — Upstream rejected the PR

```bash
git revert -m 1 <merge-commit-sha>
git push origin main
```

The fix is gone from `main`. If the user wants to keep it as fork-only, recreate it on a `fork/<name>` branch and run Procedure B.

### C.4 — Upstream asked for changes on the PR

Push updates to the same `fix/<name>` branch (the upstream PR auto-updates). Then update local `main`:

```bash
git checkout main
git revert -m 1 <old-merge-sha>
git merge --no-ff fix/<name> -m "Merge fix/<name> (updated)"
git push origin main
```

### C.5 — Upstream advanced past you with unrelated commits (fork-only branch still ahead)

```bash
git fetch upstream
git merge upstream/main   # creates a merge commit; fork-only commits remain on top
```

Resolve conflicts in the merge commit if upstream touched the same files. This produces the only "permanent" divergence the workflow accepts — fork-only commits stay on `main` indefinitely.

## Hard constraints

- **NEVER** branch `fix/*` off `origin/main`. Always off `upstream/main`. Stale base = noisy PR upstream.
- **NEVER** branch `fork/*` off `upstream/main`. Always off `origin/main`.
- **ALWAYS** use `--no-ff` when merging a topic branch into `main`. The merge commit is the only thing that makes reverts and reconciliation tractable.
- **NEVER** open an upstream PR for a `fork/*` branch.
- **NEVER** `git push --force` (or `--force-with-lease`) to `origin/main` without explicit user confirmation for that specific operation. This applies even if the user has approved force-push in past sessions.
- **NEVER** bump the version manually (per `CLAUDE.md`). Use the `Manual Release` workflow dispatch.
- **ALWAYS** run `bun run lint && bun run typecheck && bun run format` before merging to `main` (per `CLAUDE.md`).
- **NEVER** include `packages/proxy/src/inline-worker.ts` in commits (per `CLAUDE.md`).
- **ALWAYS** use `git add <specific files>` rather than `git add .` (per `CLAUDE.md`).

## Quick decision tree

```
New change requested
├── Should it benefit upstream too?
│   ├── Yes → Procedure A (fix/*, branch from upstream/main, PR upstream, merge to main)
│   └── No → Procedure B (fork/*, branch from origin/main, no PR, merge to main)
└── Upstream just advanced or merged my PR?
    └── Procedure C, pick the matching sub-case (C.1–C.5)
```

## Related references

- `CLAUDE.md` — general repo rules, lint/typecheck/format requirement, file exclusions, commit prefixes
- `.github/workflows/release-dispatch.yml` — the manual release workflow (use this to ship)
- `.github/workflows/release.yml` — builds binaries when a `v*` tag is pushed (triggered by the dispatch workflow)
