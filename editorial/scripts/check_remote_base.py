# -*- coding: utf-8 -*-
"""阻止在未吸收远程 main 基准时提交或推送。"""
import os
import subprocess
import sys
from dataclasses import dataclass

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gu_tools import PsArgs, REPO_ROOT, print_console


@dataclass
class CheckResult:
    ok: bool
    message: str


def run_git(repo_root, *args):
    return subprocess.run(
        ['git', '-C', repo_root] + list(args),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding='utf-8',
        errors='replace',
    )


def command_error(action, proc):
    detail = (proc.stderr or proc.stdout).strip()
    return CheckResult(False, '{0} failed{1}'.format(
        action, ': {0}'.format(detail) if detail else '.'))


def check_remote_base(repo_root, remote='origin', branch='main', fetch=True, run=None):
    """确认远程跟踪分支是 HEAD 的祖先；失败时返回可直接执行的修复建议。"""
    repo_root = os.path.abspath(repo_root)
    run = run or run_git
    remote_ref = 'refs/remotes/{0}/{1}'.format(remote, branch)
    display_ref = '{0}/{1}'.format(remote, branch)

    if fetch:
        proc = run(repo_root, 'fetch', remote, branch)
        if proc.returncode != 0:
            return command_error('Cannot fetch {0}'.format(display_ref), proc)

    head = run(repo_root, 'rev-parse', '--verify', 'HEAD')
    if head.returncode != 0:
        return command_error('Cannot resolve HEAD', head)

    tracked = run(repo_root, 'rev-parse', '--verify', remote_ref)
    if tracked.returncode != 0:
        return CheckResult(False, 'Missing remote-tracking reference {0}. Run: git fetch {1} {2}'.format(
            remote_ref, remote, branch))

    ancestor = run(repo_root, 'merge-base', '--is-ancestor', remote_ref, 'HEAD')
    if ancestor.returncode == 0:
        return CheckResult(True, 'Remote baseline {0} is included in HEAD.'.format(display_ref))
    if ancestor.returncode == 1:
        return CheckResult(False, 'HEAD does not include {0}. Before committing or pushing, run: git rebase {0}'.format(
            display_ref))
    return command_error('Cannot compare HEAD with {0}'.format(display_ref), ancestor)


def main():
    args = PsArgs(specs=[
        ('RepoRoot', 'string'),
        ('Remote', 'string'),
        ('Branch', 'string'),
        ('NoFetch', 'bool'),
    ], defaults={
        'RepoRoot': REPO_ROOT,
        'Remote': 'origin',
        'Branch': 'main',
        'NoFetch': False,
    })
    result = check_remote_base(
        args.get('RepoRoot'),
        remote=args.get('Remote'),
        branch=args.get('Branch'),
        fetch=not args.get('NoFetch'),
    )
    print_console(result.message, stream=None if result.ok else sys.stderr)
    return 0 if result.ok else 1


if __name__ == '__main__':
    raise SystemExit(main())
