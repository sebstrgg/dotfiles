#!/usr/bin/env python3
"""Manage only Claude's statusline key and its link."""
import argparse
import filecmp
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
HOME = Path.home()
STATUS = {'type': 'command', 'command': '~/.claude/statusline.sh', 'padding': 2}


def backup(path):
    if path.exists() or path.is_symlink():
        target = HOME / '.local/state/dotfiles/backups' / (str(path.relative_to(HOME)) + '.' + str(time.time_ns()))
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target, follow_symlinks=False)
        if not path.is_symlink() and not filecmp.cmp(path, target, shallow=False):
            raise OSError("Backup verification failed")


def write(path, content):
    if path.is_file() and not path.is_symlink() and path.read_text() == content:
        return
    backup(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(content)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('install', 'check'))
    args = parser.parse_args()
    settings = HOME / '.claude/settings.json'
    current = json.loads(settings.read_text()) if settings.exists() else {}
    expected = {**current, 'statusLine': STATUS}
    links = [('claude/statusline.sh', '.claude/statusline.sh')]
    if args.command == 'install':
        write(settings, json.dumps(expected, indent=2) + '\n')
        for src, dst in links:
            target = HOME / dst
            if target.is_symlink() and target.resolve() == ROOT / src:
                continue
            backup(target)
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.exists() or target.is_symlink():
                target.unlink()
            target.symlink_to(ROOT / src)
        return 0
    good = settings.is_file() and not settings.is_symlink() and current == expected
    for src, dst in links:
        target = HOME / dst
        good &= target.is_symlink() and target.resolve() == ROOT / src
    print(('OK' if good else 'FAIL') + ': Claude statusline key and link')
    return 0 if good else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError):
        # App settings can contain credentials; never print their values.
        sys.exit('Could not manage Claude dotfiles; check settings.json and file access.')
