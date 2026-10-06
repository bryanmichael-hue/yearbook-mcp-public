"""Run the installer's actual Perl guard on real symlink/directory fixtures.

Non-root test ownership is passed to the guard; the production invocation pins
UID 0. These tests do not substitute for the eventual on-Uno install/readback.
"""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('uno-discovery-refresh-20261006.sh').read_text()
GUARD = SCRIPT.split("<<'YB_UNO_PREFLIGHT'\n", 1)[1].split('\nYB_UNO_PREFLIGHT', 1)[0]


class UnoPreflight(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='yb-uno-preflight-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        self.physical = self.root/'export/local'
        self.docroot = self.physical/'apache/htdocs'
        for p in (self.docroot/'for-ai-agents', self.docroot/'.well-known', self.root/'usr'):
            p.mkdir(parents=True, mode=0o755)
        self.alias = self.root/'usr/local'
        self.alias.symlink_to(self.physical)
        self.paths = [self.root, self.root/'export', self.physical,
                      self.physical/'apache', self.docroot,
                      self.docroot/'for-ai-agents', self.docroot/'.well-known', self.root/'usr']
        for p in self.paths:
            p.chmod(0o755)

    def run_guard(self, owner=None):
        return subprocess.run(['/usr/bin/perl', '-', str(os.getuid() if owner is None else owner),
                               str(self.alias), str(self.physical), *map(str, self.paths)],
                              input=GUARD, text=True, capture_output=True)

    def test_observed_alias_passes_without_modification(self):
        before = [(p.lstat().st_mode, p.lstat().st_uid) for p in self.paths]
        result = self.run_guard()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('UNO_PREFLIGHT_OK', result.stdout)
        self.assertEqual(before, [(p.lstat().st_mode, p.lstat().st_uid) for p in self.paths])
        self.assertTrue(self.alias.is_symlink())

    def test_old_blanket_symlink_check_reproduces_failure(self):
        result = subprocess.run(['/bin/ksh', '-c', 'test -d "$1" && test ! -L "$1"',
                                 'preflight', str(self.alias)])
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.run_guard().returncode, 0)

    def test_wrong_alias_refused(self):
        self.alias.unlink()
        self.alias.symlink_to(self.root/'elsewhere')
        self.assertIn('unexpected alias', self.run_guard().stderr)

    def test_writable_ancestor_refused_without_repair(self):
        self.physical.chmod(0o775)
        result = self.run_guard()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('writable ancestry', result.stderr)
        self.assertEqual(self.physical.stat().st_mode & 0o777, 0o775)

    def test_unexpected_owner_refused(self):
        self.assertNotEqual(self.run_guard(os.getuid()+1).returncode, 0)

    def test_other_symlink_still_refused(self):
        p = self.docroot/'for-ai-agents'
        p.rmdir()
        p.symlink_to(self.docroot/'.well-known')
        result = self.run_guard()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('not a physical directory', result.stderr)

    def test_production_owner_and_path_are_fixed(self):
        self.assertIn('/usr/bin/perl - 0 /usr/local /export/local', SCRIPT)
        self.assertIn('D=/export/local/apache/htdocs\n', SCRIPT)
        self.assertLess(SCRIPT.index('YB_UNO_PREFLIGHT\n'), SCRIPT.index('mkdir -m 0700 "$W"'))


if __name__ == '__main__':
    unittest.main()
