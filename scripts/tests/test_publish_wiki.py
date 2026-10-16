"""Protect the wiki publisher's destination and non-destructive behavior."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'publish_wiki.py'


class WikiPublisherTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='icesee-wiki-test-')
        self.addCleanup(self.temporary.cleanup)
        self.target = Path(self.temporary.name)
        self.git('init', '-q')
        self.git('remote', 'add', 'origin', 'git@github.com:ICESEE-project/ICESEE-Spack.wiki.git')
        (self.target / 'Existing.md').write_text('An unrelated page.\n')
        self.git('add', 'Existing.md')
        self.git('-c', 'user.name=Documentation Fixture', '-c', 'user.email=test@example.invalid',
                 'commit', '-qm', 'Initialize test wiki')

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.target), *args], text=True).strip()

    def publish(self, *args):
        return subprocess.run([sys.executable, str(SCRIPT), '--target', str(self.target), *args],
                              text=True, capture_output=True)

    def test_copy_rewrites_page_links_and_preserves_unrelated_pages(self):
        before = self.git('rev-parse', 'HEAD')
        result = self.publish()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('(Subtree-basics)', (self.target / 'Home.md').read_text())
        self.assertNotIn('(Subtree-basics.md)', (self.target / 'Home.md').read_text())
        self.assertEqual((self.target / 'Existing.md').read_text(), 'An unrelated page.\n')
        self.assertEqual(self.git('rev-parse', 'HEAD'), before)

    def test_wrong_remote_is_refused(self):
        self.git('remote', 'set-url', 'origin', 'https://example.invalid/unrelated.git')
        result = self.publish()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.target / 'Home.md').exists())

    def test_dirty_target_is_refused(self):
        (self.target / 'Unpublished.md').write_text('Uncommitted work.\n')
        result = self.publish()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.target / 'Home.md').exists())

    def test_dry_run_does_not_write(self):
        result = self.publish('--dry-run')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.target / 'Home.md').exists())
        self.assertEqual(self.git('status', '--porcelain'), '')


if __name__ == '__main__':
    unittest.main()
