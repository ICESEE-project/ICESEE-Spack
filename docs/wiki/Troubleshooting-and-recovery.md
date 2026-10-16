# Troubleshooting and recovery

Start by inspecting state. Do not repair an uncertain history with a force-push or by deleting the subtree.

```bash
git status --short --branch
git remote -v
git branch -vv
git worktree list
git ls-tree HEAD ICESEE spack
git reflog -15
```

## Git says subtree is not a command

`git subtree` is shipped as a Git contrib helper and is not installed by every Git package. Test with `git subtree -h`. Ask the system administrator for the supported Git package, or use the official Git project's subtree helper matching a suitable Git installation. On PACE, prefer a site-supported module or a reviewed user-local installation; do not replace the shared system Git. The earlier repair used a reviewed standard helper in its private review directory. Use the [official subtree manual](https://github.com/git/git/blob/master/contrib/subtree/git-subtree.adoc) rather than an arbitrary downloaded shell script.

## Dirty checkout

An update must not overwrite uncommitted research work. Review `git diff` and `git diff --cached`. Commit intended source on a named branch, or create a separate worktree for the update. Stashing tracked files is another option after review, but avoid `git stash -u` over a large installation: it can sweep up datasets and environments. A plain patch does not back up untracked files.

## Merge conflicts during subtree pull

```bash
git status
git diff --name-only --diff-filter=U
git diff --cc -- ICESEE
```

Review both versions and the relevant upstream change. Edit each conflicted file, stage only resolved files, run checks, and complete the merge:

```bash
# Replace these example filenames with the actual conflicted files.
git add ICESEE/path/to/resolved_file.py
git diff --cached --check
git commit
```

The merge commit message contains subtree metadata; preserve it. To abandon an active merge, `git merge --abort` attempts to restore the pre-merge state. First save any conflict-resolution work you want to retain. Abort is not a remedy for an already-completed merge; review a revert or a new repair branch instead.

## Wrong layout or an upstream branch checked out in the parent

A standalone ICESEE branch has `applications/` and `src/` at its root. The parent has those beneath `ICESEE/` plus installer files. Preserve all local work and inspect reflog/branches. Build an isolated worktree from a verified parent ref:

```bash
git fetch origin main
git worktree add -b repair/parent-layout ../ICESEE-Spack-layout-repair origin/main
```

Apply only reviewed changes to the correct prefix in the new worktree. Do not copy entire old directories over new upstream source, and do not hard-reset the active research installation.

## Existing export branch name

`subtree split --branch` can refuse a branch that points elsewhere. Use a fresh export branch name. Do not delete a branch until you have checked whether it contains unpublished work.

## Non-fast-forward push

Fetch the destination, compare both sides and integrate the missing work through the correct subtree workflow. A rejection is evidence of different history, not permission to force-push.

## Accidentally deleted remote branch

A push like `:feature-name` deletes the destination branch. If the correct local branch still exists, verify its commit and publish an explicit source ref:

```bash
git show-ref --verify refs/heads/feature-name
git log -1 --oneline refs/heads/feature-name
git push icesee refs/heads/feature-name:refs/heads/feature-name
```

Use the correct remote and actual branch name. If the local branch is missing, inspect reflogs and collaborator clones before attempting recovery. Never invent a commit ID or use an empty shell variable in the source ref.

## Authentication and wiki errors

`Repository not found` may mean a wrong URL, missing permissions, or an uninitialized wiki repository. Test SSH with the same host/account configuration used for your normal repository. Never paste private keys, tokens or credential-bearing URLs into issue reports. A GitHub wiki's first page must be created on GitHub before cloning its `.wiki.git` repository.
