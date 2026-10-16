# Export local ICESEE edits without exporting the parent

Edit `ICESEE/...` in the parent, then create a standalone history with `git subtree split`. Never push the parent branch directly to the ICESEE repository.

## Commit only the intended source

```bash
git status --short --branch
git diff -- ICESEE
# Example: replace this path with the files you actually changed.
git add ICESEE/applications/icepack_model/examples/idealized_pig/_icepack_native.py
git diff --cached --check
git diff --cached
git commit -m "Describe the concrete ICESEE change"
```

Keep parent installer/documentation changes in separate commits where practical. Review data files, notebooks, and logs before staging. Preserve author credits and licensing.

## Split and inspect

Use a new local export branch name for each distinct review:

```bash
git fetch icesee main
git subtree split --prefix=ICESEE --branch export/pig-fix
git ls-tree --name-only export/pig-fix
git merge-base --is-ancestor icesee/main export/pig-fix
git rev-list --left-right --count icesee/main...export/pig-fix
git diff --stat icesee/main export/pig-fix
git diff --check icesee/main export/pig-fix
```

A successful ancestor check means this export contains the fetched upstream main. The left count should be zero in that case. If it fails, stop: integrate/review newer upstream main through the parent subtree, resolve conflicts, test, commit, and split again under a new export name. Do not force-push to bypass the check. In unusual histories a split may require maintainer review even when file contents match.

The export has files such as `applications/` and `src/` at its root, not an enclosing `ICESEE/`. Parent-only files must not appear as changes in the upstream PR. An upstream project may itself have a README or scripts directory; compare the diff instead of banning generic filenames.

## Publish using explicit, nonempty source refs

With direct branch-write permission:

```bash
git push icesee refs/heads/export/pig-fix:refs/heads/pig-fix
```

If updating an existing feature branch, fetch it and verify that its commits are retained before the push:

```bash
git fetch icesee pig-fix
git merge-base --is-ancestor icesee/pig-fix export/pig-fix
```

If that check fails, someone else's changes need integration. Do not overwrite the feature branch.

For contributors using an ICESEE fork, first create that fork on GitHub, then configure its actual URL:

```bash
git remote add icesee-fork git@github.com:YOUR_GITHUB_USER/ICESEE.git
git push icesee-fork refs/heads/export/pig-fix:refs/heads/pig-fix
```

Open a PR against `ICESEE-project/ICESEE:main`. A parent fork and an ICESEE fork are separate repositories. Use the matching fork for each push.

## Variable-safe pushes

An empty source in `source:destination` means branch deletion. Prefer literal refs as above. If automation requires variables, use a fail-fast Bash block and mandatory expansion:

```bash
bash <<'BASH'
set -euo pipefail
EXPORT_BRANCH=export/pig-fix
: "${EXPORT_BRANCH:?Missing export branch}"
git show-ref --verify "refs/heads/${EXPORT_BRANCH:?}"
git merge-base --is-ancestor icesee/main "$EXPORT_BRANCH"
git push icesee "refs/heads/${EXPORT_BRANCH:?}:refs/heads/pig-fix"
BASH
```

Never continue with a push after an earlier command fails or a result file fails to load. Do not execute the last line separately with unset variables.

## Bring the merged change back to the parent

After the upstream ICESEE PR actually merges, fetch and pull ICESEE main into a clean parent review branch using `git subtree pull --prefix=ICESEE icesee main --squash`. Resolve any duplication/conflicts through normal review, test, then open a parent PR. Preserve subtree trailers. Advanced options such as `--rejoin`, `--onto`, and `--ignore-joins` should be used only with an understood history-repair plan.
