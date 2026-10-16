# How Git subtrees work

A subtree places the files of another repository under a directory in a parent repository. Here the parent is **ICESEE-Spack**, and `ICESEE/` and `spack/` are subtree prefixes. Prefix names are case-sensitive.

```text
ICESEE-Spack/             parent repository and .git directory
├── ICESEE/               ICESEE source, tracked by the parent
├── spack/                bundled Spack source, tracked by the parent
├── icesee-spack/          local Spack packages
├── scripts/
└── docs/
```

There is no separate `ICESEE/.git` in a normal subtree checkout. `git status` inside `ICESEE/` still reports the parent repository. Source files come with a normal clone; there is no submodule initialization step.

## Files, history, and remotes

The parent records the exact subtree contents in its own commits. A subtree update merges new contents under a prefix. A split reconstructs a branch containing just that prefix, with its files at the repository root, suitable for the upstream repository.

With `--squash`, an incoming upstream update is represented by a compact snapshot commit plus the parent merge rather than importing every upstream commit into the parent ancestry. Commit messages retain `git-subtree-dir` and `git-subtree-split` trailers. Preserve those messages: Git uses them when finding previous imports. Squashing does not remove the bundled files, local edits, or upstream's own history. A split's commit IDs can differ from the parent IDs.

Remotes are local clone settings; they are not carried to another person's clone. A suggested map is:

| Remote | Repository | Used for |
| --- | --- | --- |
| `origin` | Your ICESEE-Spack fork or the official parent | Parent branches and PRs |
| `upstream` | Official ICESEE-Spack, when origin is a fork | Updating your fork |
| `icesee` | Official ICESEE | ICESEE subtree imports and exports |
| `icesee-fork` | Your ICESEE fork | Upstream contributions without direct write access |
| `spack-upstream` | Official Spack | Reviewed dependency imports |

Run `git remote -v` before assuming a remote's purpose.

## Subtree versus submodule versus environment

| Property | Subtree | Submodule |
| --- | --- | --- |
| Parent stores | Actual files and subtree history metadata | A commit pointer (gitlink) |
| Tree mode | `040000 tree` for the directory | `160000 commit` |
| Normal clone | Includes source files | Usually needs submodule initialization |
| Update | `git subtree pull --prefix=...` | Submodule-specific checkout/update |
| Export local edits | `git subtree split` | Commit in the nested repository |

Inspect this checkout:

```bash
git rev-parse --show-toplevel
git ls-tree HEAD ICESEE spack
git log --all --grep='git-subtree-dir: ICESEE' --format=full
```

A Python virtual environment, Spack environment, local cache, or dataset directory is not a subtree merely because it is inside the checkout. Updating `ICESEE/` changes source; updating `spack/` changes the package manager's source. Neither automatically changes already-installed libraries.

## Understand the commands

| Command | Changes files in the working tree? | Purpose |
| --- | --- | --- |
| `git fetch icesee` | No | Download objects and refresh tracking refs |
| `git pull --ff-only` on parent main | Yes | Update the whole parent, including recorded subtree files |
| `git subtree pull --prefix=ICESEE icesee main --squash` | Yes | Integrate newer ICESEE upstream into the parent prefix |
| `git subtree split --prefix=ICESEE --branch export-name` | No source edits | Create a standalone ICESEE history branch |
| `git push icesee source:destination` | No local source edits | Publish a branch to ICESEE |

Do not use plain `git pull icesee main` from the parent. It does not apply the `ICESEE/` prefix. Do not check out an ICESEE upstream branch as the parent branch: it can replace the parent layout with a standalone ICESEE checkout.

Reference: [Git's official subtree manual](https://github.com/git/git/blob/master/contrib/subtree/git-subtree.adoc).
