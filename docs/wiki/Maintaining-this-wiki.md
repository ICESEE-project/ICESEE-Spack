# Maintaining this wiki

The wiki is a separate Git repository: `ICESEE-Spack.wiki.git`. It is not the ICESEE subtree and is not updated by pulling the parent. Keep reviewed Markdown sources in the parent under `docs/wiki/`; publish those sources to the wiki after review. Wiki edits made directly on GitHub should be reconciled into the parent sources.

## Clone the initialized wiki

```bash
git clone git@github.com:ICESEE-project/ICESEE-Spack.wiki.git ../ICESEE-Spack.wiki
```

The first page must be created through GitHub before cloning a new wiki repository. Write access to the wiki is required. Wiki publishing bypasses ordinary parent pull-request checks, so review the sources before pushing.

## Publish reviewed sources

From the parent repository root, with `../ICESEE-Spack.wiki` already cloned:

```bash
git -C ../ICESEE-Spack.wiki pull --ff-only
python3 scripts/publish_wiki.py --target ../ICESEE-Spack.wiki
git -C ../ICESEE-Spack.wiki diff --check
git -C ../ICESEE-Spack.wiki diff --stat
git -C ../ICESEE-Spack.wiki diff
```

The publisher copies only the known Markdown source pages, rewrites local page links for GitHub wiki routes, and leaves unrelated wiki files in place. It refuses an unrelated target remote or existing uncommitted wiki changes. It does not commit, push, delete pages, or change repository settings. Review its output and stage the explicit page names printed by the script:

```bash
# Example page; stage every reviewed changed page you intend to publish.
git -C ../ICESEE-Spack.wiki add Home.md
git -C ../ICESEE-Spack.wiki commit -m "Update subtree documentation"
git -C ../ICESEE-Spack.wiki push
```

The repository README links to the contribution guide, security guidance, and these sources. Keep sidebar links and page filenames consistent. `_Sidebar.md` is a GitHub wiki navigation file, not a normal content page.

## Check documentation

Review local links and commands. `bash -n` can check Bash syntax but does not establish Git semantics. Subtree examples should also be exercised in temporary local repositories with sample upstream and parent histories. Never test recovery instructions against a production branch or a live research checkout.

Official references: [Git subtree manual](https://github.com/git/git/blob/master/contrib/subtree/git-subtree.adoc), [GitHub wiki editing and cloning](https://docs.github.com/en/communities/documenting-your-project-with-wikis/adding-or-editing-wiki-pages).
