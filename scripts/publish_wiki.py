#!/usr/bin/env python3
"""Validate reviewed wiki sources and copy them into an initialized wiki clone."""
import argparse
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'docs' / 'wiki'
LINK = re.compile(r'(\]\()([^\s)]+)(\))')
ALLOWED_ORIGINS = {
    'git@github.com:ICESEE-project/ICESEE-Spack.wiki.git',
    'https://github.com/ICESEE-project/ICESEE-Spack.wiki.git',
    'ssh://git@github.com/ICESEE-project/ICESEE-Spack.wiki.git',
}


def git(directory, *args):
    return subprocess.check_output(['git', '-C', str(directory), *args], text=True).strip()


def sources():
    pages = sorted(SOURCE.glob('*.md'))
    if not pages or not (SOURCE / 'Home.md').is_file():
        raise ValueError('Missing wiki source pages or Home.md')
    for page in pages:
        if page.is_symlink():
            raise ValueError(f'Wiki source must be a regular file: {page}')
        for _, href, _ in LINK.findall(page.read_text()):
            if '://' in href or href.startswith(('#', 'mailto:')):
                continue
            name = href.split('#', 1)[0]
            target = (page.parent / name).resolve()
            if target.parent != SOURCE.resolve() or target.suffix != '.md' or not target.is_file():
                raise ValueError(f'Invalid local wiki link in {page.name}: {href}')
    return pages


def wiki_markup(text):
    def route(match):
        before, href, after = match.groups()
        name, marker, anchor = href.partition('#')
        if '://' not in href and not href.startswith(('mailto:', '#')) and name.endswith('.md'):
            href = name[:-3] + (marker + anchor if marker else '')
        return before + href + after
    return LINK.sub(route, text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Validate sources only; no target or writes')
    parser.add_argument('--target', type=Path, help='Existing clean ICESEE-Spack.wiki Git clone')
    parser.add_argument('--dry-run', action='store_true', help='Validate target and show files without copying')
    args = parser.parse_args()
    try:
        pages = sources()
        if args.check:
            print(f'Wiki source links validated: {len(pages)} Markdown files.')
            return
        if args.target is None:
            parser.error('--target is required unless --check is used')
        target = args.target.resolve(strict=True)
        if Path(git(target, 'rev-parse', '--show-toplevel')).resolve() != target:
            raise ValueError('Target must be the root of the wiki clone')
        if target == ROOT or ROOT in target.parents or target in ROOT.parents:
            raise ValueError('Wiki target must be separate from the parent source checkout')
        if git(target, 'remote', 'get-url', 'origin') not in ALLOWED_ORIGINS:
            raise ValueError('Target origin is not the ICESEE-Spack wiki repository')
        if git(target, 'status', '--porcelain'):
            raise ValueError('Target wiki has uncommitted changes; review them before publishing')
        for page in pages:
            destination = target / page.name
            if destination.is_symlink():
                raise ValueError(f'Refusing target symlink: {destination}')
        for page in pages:
            print(page.name)
            if not args.dry_run:
                (target / page.name).write_text(wiki_markup(page.read_text()))
        print('No commits, pushes, or deletions performed.')
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, f'Wiki publication stopped: {error}\n')


if __name__ == '__main__':
    main()
