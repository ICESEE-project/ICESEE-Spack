# Fetch, review, and update the ICESEE subtree

These examples run in the **ICESEE-Spack root**, on a clean review branch. Stop at the first error. Pick new branch names if the examples already exist locally.

## 1. Verify the layout and remote

```bash
git rev-parse --show-toplevel
git status --short --branch
git ls-tree HEAD ICESEE
git remote -v
```

The prefix must be a tracked `040000 tree`. A clean working tree is required for the merge; preserve local work before continuing. Configure the ICESEE remote once per clone:

```bash
git remote add icesee https://github.com/ICESEE-project/ICESEE.git
```

If it already exists, use `git remote get-url icesee` and verify it points to ICESEE rather than ICESEE-Spack. Use the SSH URL if write access is required and your SSH authentication is configured.

## 2. Fetch without changing source

```bash
git fetch icesee main
git log -5 --oneline icesee/main
git log --all --grep='git-subtree-dir: ICESEE' --format=full
```

Fetch downloads upstream changes. It does not update `ICESEE/`. The latest subtree trailer identifies an earlier imported upstream revision. Compare that revision with the proposed upstream revision when reviewing upstream history. Do not assume `git log HEAD..icesee/main` measures a squash-imported subtree's freshness: parent and upstream ancestry differ.

## 3. Create a parent review branch and pull the subtree

First update parent main from the correct parent remote using the everyday workflow. Then:

```bash
git switch -c update/icesee-main
# Record the parent commit printed here for later comparison:
git rev-parse HEAD
git subtree pull --prefix=ICESEE icesee main --squash
git diff --check
git log -3 --oneline
git diff --stat origin/main...HEAD -- ICESEE
```

For fork contributors, compare against `upstream/main` rather than `origin/main` if that is the authoritative parent baseline. Existing committed parent-side ICESEE edits participate in the merge; conflicting lines require review, not wholesale replacement of `ICESEE/`.

Run relevant tests, review the full diff, and publish the **parent branch to the parent repository**:

```bash
git push --set-upstream origin update/icesee-main
```

Open an ICESEE-Spack PR. Importing ICESEE changes does not itself publish local ICESEE edits back to upstream.

## Update from a reviewed ICESEE feature branch

```bash
git fetch icesee REVIEWED_FEATURE_BRANCH
git subtree pull --prefix=ICESEE icesee REVIEWED_FEATURE_BRANCH --squash
```

Replace the placeholder with the branch the team agreed to integrate. Verify its commits and review status first. A branch can exist without having been merged to `main`; do not describe it as a main update until that merge has happened.

## Pin an exact reviewed revision

Fetch the branch or tag containing the desired revision, then merge that revision under the prefix:

```bash
git fetch icesee main
git show --no-patch REVIEWED_ICESEE_COMMIT
git subtree merge --prefix=ICESEE --squash REVIEWED_ICESEE_COMMIT
```

Replace `REVIEWED_ICESEE_COMMIT` with the verified commit ID. This avoids a moving branch advancing between review and merge. Record the upstream ID, parent before/after IDs, local deviations, and validation in the parent PR.

## After a parent PR merges

Update your parent main normally. Other users need only pull the parent to receive its recorded subtree contents. A standalone ICESEE user instead fetches/pulls from the ICESEE repository. Those are different checkouts and different remotes.
