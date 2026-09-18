# -*- coding: utf-8 -*-
import os
import stat
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPTS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'scripts')
sys.path.insert(0, SCRIPTS_DIR)

from check_remote_base import check_remote_base


class RemoteBaseGuardTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.remote = os.path.join(self.temp_dir, 'remote.git')
        self.local = os.path.join(self.temp_dir, 'local')
        self.other = os.path.join(self.temp_dir, 'other')
        self.git('init', '--bare', '--initial-branch=main', self.remote)
        self.git('clone', self.remote, self.local)
        self.configure(self.local)
        self.write_and_commit(self.local, 'initial.txt', 'initial\n', 'initial')
        self.git('-C', self.local, 'push', 'origin', 'main')
        self.git('clone', self.remote, self.other)
        self.configure(self.other)

    def tearDown(self):
        shutil.rmtree(self.temp_dir, onexc=self.remove_readonly)

    @staticmethod
    def remove_readonly(func, path, exc_info):
        os.chmod(path, stat.S_IWRITE)
        func(path)

    def git(self, *args):
        return subprocess.run(['git'] + list(args), check=True, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, text=True)

    def configure(self, repo):
        self.git('-C', repo, 'config', 'user.name', 'Test User')
        self.git('-C', repo, 'config', 'user.email', 'test@example.com')

    def write_and_commit(self, repo, name, content, message):
        with open(os.path.join(repo, name), 'w', encoding='utf-8', newline='') as fh:
            fh.write(content)
        self.git('-C', repo, 'add', name)
        self.git('-C', repo, 'commit', '-m', message)

    def test_accepts_head_that_contains_fetched_remote_main(self):
        result = check_remote_base(self.local)

        self.assertTrue(result.ok)
        self.assertIn('origin/main', result.message)

    def test_blocks_when_remote_main_has_commit_local_head_lacks(self):
        self.write_and_commit(self.other, 'remote.txt', 'remote\n', 'remote advance')
        self.git('-C', self.other, 'push', 'origin', 'main')

        result = check_remote_base(self.local)

        self.assertFalse(result.ok)
        self.assertIn('git rebase origin/main', result.message)

    def test_blocks_when_remote_tracking_reference_is_missing_without_fetch(self):
        self.git('-C', self.local, 'update-ref', '-d', 'refs/remotes/origin/main')

        result = check_remote_base(self.local, fetch=False)

        self.assertFalse(result.ok)
        self.assertIn('refs/remotes/origin/main', result.message)


if __name__ == '__main__':
    unittest.main()
