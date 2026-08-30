---
name: upstream-sync
description: Safely merge the upstream remote's default branch into this fork's default branch using a dedicated worktree, an immediate merge commit, and hash-ancestry verification. Use when asked to sync or merge upstream, reflect upstream changes into master, or update the fork from upstream.
---

# Upstream sync

Merge `upstream/<default-branch>` into the fork's default branch (for example `master` on a fork whose `origin` is a mirror and whose `upstream` is the canonical repository).

## Why this procedure exists

An in-progress merge (`.git/MERGE_HEAD` plus a staged index) lives in the shared working tree and is fragile: other agents, IDEs, hooks, `git stash`, or `git reset` can clear it at any moment. Never stage a merge and leave it uncommitted in the main checkout. Do all merge work inside a dedicated worktree and move the main checkout only once, by fast-forward.

## Non-negotiable rules

- Record the target hash before starting; verify by hash ancestry, never by commit counts or diff sizes.
- Never leave an uncommitted merge state in the main checkout.
- Commit in the worktree immediately after the merge resolves; do not pause with `--no-commit`.
- Never push without an explicit user request.
- Do not drop any stash created during the flow until ancestry verification passes on the default branch.
- Re-run the ancestry check immediately before reporting success; external state can change between steps.

## 1. Pre-checks (in the main checkout, before touching anything)

```bash
git remote -v                                  # confirm origin and upstream exist
git fetch upstream
DEFAULT_BRANCH=master                          # adjust if the fork's default branch differs
TARGET=$(git rev-parse upstream/$DEFAULT_BRANCH)
echo "target: $TARGET"                         # record this; it is the source of truth
git status --short                             # know what is dirty before deciding anything
test ! -f .git/MERGE_HEAD && echo "no merge in progress"
git rev-list --count $DEFAULT_BRANCH..upstream/$DEFAULT_BRANCH   # commits to pull in
git rev-list --count upstream/$DEFAULT_BRANCH..$DEFAULT_BRANCH   # local-only commits that must survive
```

If an interrupted merge or staged merge state already exists in the main checkout, do not blindly stash it. Inspect it first (`git log --oneline -1 MERGE_HEAD`, staged diff summary), compare its target against the current `TARGET`, summarize the finding, and ask the user whether to stash-abort or commit it before proceeding.

If the fork has local-only commits, expect a merge commit (never fast-forward over them).

## 2. Create the dedicated worktree

The default branch is checked out in the main checkout, so the worktree needs a temporary branch:

```bash
git worktree add ../<repo>-worktrees/upstream-sync -b sync/upstream-${TARGET:0:8} $DEFAULT_BRANCH
cd ../<repo>-worktrees/upstream-sync
```

Use the repository's worktree convention if one exists (for herdr: `../herdr-worktrees/<task-slug>`).

## 3. Merge, verify, and commit in one continuous flow

```bash
git merge upstream/$DEFAULT_BRANCH
```

- Clean merge: git creates the merge commit immediately. Do not add intermediate steps between merge and verification.
- Conflicts: resolve them, `git add` the resolutions, and `git commit --no-edit` right away. Do not leave the worktree with an unresolved index between tool calls.

Verify in the worktree before anything else:

```bash
git merge-base --is-ancestor $TARGET HEAD && echo "OK: target included" || echo "NG"
git diff --name-only --diff-filter=U           # must print nothing
```

If the project has a standard check command (for herdr: `just check`), run it in the worktree unless the user explicitly accepts narrower validation.

## 4. Fast-forward the main checkout

```bash
cd <main-checkout>
git status --short                             # local changes to merge-touched files will block the ff
git merge --ff-only sync/upstream-${TARGET:0:8}
```

`--ff-only` is the safety catch: the sync branch must be a descendant of the default branch. If it is refused, the default branch advanced since the worktree was created; redo step 2 from the new tip instead of forcing a merge of the sync branch.

Final verification, on the default branch itself:

```bash
git merge-base --is-ancestor $TARGET $DEFAULT_BRANCH && echo "OK: merged" || echo "NG"
git log --oneline -1
```

## 5. Cleanup (only after step 4 verification passes)

```bash
git worktree remove ../<repo>-worktrees/upstream-sync
git branch -d sync/upstream-${TARGET:0:8}
```

If any stash was created during this flow (for example to clear an interrupted merge), show the user the stash list and confirm before dropping. Never drop a stash that predates the session.

## Report

State clearly:

- The target hash and the merge commit hash produced.
- Conflicts encountered and how they were resolved.
- Validation run (`just check` or equivalent) and its result.
- The final ancestry check result on the default branch.
- Cleanup status, including any stash kept for the user.

If push was requested, push only the default branch to `origin` and report the remote hash.
