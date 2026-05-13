# `.claude/rules/`

Project-specific rules Claude follows when working in this repo. Each file describes a workflow or constraint that's too detailed to put inline in `CLAUDE.md`. `CLAUDE.md` itself contains short pointers to the rules in this directory.

| Rule | When it applies |
|------|-----------------|
| [`fork-workflow.md`](fork-workflow.md) | Any bug fix or change to fork code, with optional upstream PR to `tombii/better-ccflare`. Covers branch conventions, the `--no-ff` merge pattern, and post-upstream-merge reconciliation. |
