# Updating Spack and adding other subtrees

## Bundled Spack is source, not an installed environment

`spack/` is a subtree of [spack/spack](https://github.com/spack/spack). The parent also has `spack.yaml`, local package definitions in `icesee-spack/`, and installation-specific environments. Treat their compatibility as a reviewed change. Do not replace a functioning HPC stack with Spack's moving development branch as a routine update.

Inspect the imported revision and current local changes:

```bash
git ls-tree HEAD spack
git log --all --grep='git-subtree-dir: spack' --format=full
git diff -- spack spack.yaml icesee-spack requirements
```

The subtree trailer records the Spack upstream revision used for the import. A version string alone does not establish that all parent-side dependency changes are compatible.

## Import a reviewed Spack release

On a clean parent branch, configure the remote once:

```bash
git remote add spack-upstream https://github.com/spack/spack.git
git fetch spack-upstream --tags
git switch -c update/spack-release
git show --no-patch REVIEWED_SPACK_TAG
git subtree pull --prefix=spack spack-upstream REVIEWED_SPACK_TAG --squash
git diff --check
git diff --stat origin/main...HEAD -- spack spack.yaml icesee-spack requirements
```

Replace `REVIEWED_SPACK_TAG` with an actual release chosen for this stack. Fetches can be large; use an approved network/login-node workflow. Build and test in a separate environment when validating compatibility. Record compiler, MPI, PETSc, HDF5, Python, Firedrake and Icepack versions. Existing lockfiles, installed packages and virtual environments do not update just because the bundled source changed.

Do not edit third-party licenses, authorship, or vendored community files to match parent conventions. Parent-specific packages belong in `icesee-spack/` where practical; changes to Spack itself should be contributed upstream when appropriate.

## Add a new subtree

This is a maintainer operation for a dependency the team has agreed to vendor. The prefix must not already exist. Review licensing, size, provenance and the chosen revision first.

```bash
# Illustrative placeholders: substitute a real approved repository and tag.
git remote add dependency-upstream https://github.com/OWNER/PROJECT.git
git fetch dependency-upstream REVIEWED_TAG
git subtree add --prefix=vendor/PROJECT dependency-upstream REVIEWED_TAG --squash
```

Do not run `subtree add` again for an existing prefix; future updates use `subtree pull`. Document the prefix, authoritative upstream URL, revision/tag, import style and local deviations. Do not mix squashed and full-history imports casually.

## Full-history imports

Without `--squash`, subtree add/pull imports upstream ancestry more directly and can increase parent history size. Full-history and squash workflows are both supported by Git, but history and review expectations differ. The existing ICESEE and Spack workflows use squash imports. Follow the established convention unless a deliberate migration is reviewed.
