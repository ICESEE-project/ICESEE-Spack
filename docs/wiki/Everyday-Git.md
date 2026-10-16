# Everyday Git for ICESEE-Spack users

## Clone the parent

```bash
git clone https://github.com/ICESEE-project/ICESEE-Spack.git
cd ICESEE-Spack
git status --short --branch
git ls-tree HEAD ICESEE spack
```

You already have bundled source. Installation is a separate step: follow the version-selection and installer instructions in the repository README. Avoid mixing libraries from incompatible Firedrake/PETSc tracks.

## Fetch is inspection; pull updates your branch

For a clean checkout on `main`:

```bash
git switch main
git fetch origin
git log --oneline HEAD..origin/main
git diff --stat HEAD..origin/main
git pull --ff-only origin main
```

`--ff-only` stops if your branch has diverged; inspect your local commits instead of forcing a reset. A parent pull brings in subtree versions already recorded in the parent. It does not independently fetch the newest ICESEE or Spack source. To import newer upstream ICESEE, use [the subtree update workflow](Updating-ICESEE.md).

## Working with a fork

If `origin` is your fork, add the official parent once:

```bash
git remote add upstream https://github.com/ICESEE-project/ICESEE-Spack.git
git fetch upstream
git switch main
git merge --ff-only upstream/main
git push origin main
```

Check an existing remote with `git remote get-url upstream` rather than adding it again. Local branches, remote-tracking refs, and branches actually on the server can differ:

```bash
git branch -vv
git branch -r
git ls-remote --heads origin
```

## Make a change on a new branch

From an up-to-date, clean parent checkout:

```bash
git switch -c docs/subtree-example
# Edit the relevant files.
git diff --check
git diff
# Stage explicit filenames after review.
git add docs/subtrees.md
git commit -m "Clarify subtree update workflow"
git push --set-upstream origin docs/subtree-example
```

Commit source changes separately from generated files and local installation state. Do not use `git add .` in a large HPC checkout with untracked datasets or installations.

## Worktrees and installed environments

A worktree is a separate directory sharing the same Git object database. It permits isolated review without replacing the source files used by existing jobs:

```bash
git fetch origin
git worktree add -b review/icesee-update ../ICESEE-Spack-review origin/main
cd ../ICESEE-Spack-review
```

A worktree does not copy untracked inputs, installed environments, or caches. Its `.git` is a file; that is normal. Source and installation roots can be supplied separately on PACE. Do not switch a live job's source checkout while the job is using it.

## Releases

```bash
git fetch origin --tags
git tag --list
git switch --detach REVIEWED_RELEASE_TAG
```

Replace `REVIEWED_RELEASE_TAG` with an existing, reviewed tag. A detached checkout is useful for reproducing a release; create a branch before making changes. Choosing a tag changes source files, not an existing environment's installed dependencies.
