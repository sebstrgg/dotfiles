#!/usr/bin/env python3
"""Manage only Claude's statusline key, its link and the macOS keeper."""
import argparse
import filecmp
import json
import os
from pathlib import Path
import pwd
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
HOME = Path.home()
STATUS = {'type': 'command', 'command': '~/.claude/statusline.sh', 'padding': 2}
LABEL = 'com.sebastian.claude-window-keeper'


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
    parser.add_argument('--reload', action='store_true')
    args = parser.parse_args()
    settings = HOME / '.claude/settings.json'
    current = json.loads(settings.read_text()) if settings.exists() else {}
    expected = {**current, 'statusLine': STATUS}
    links = [('claude/statusline.sh', '.claude/statusline.sh')]
    if sys.platform == 'darwin':
        links.append(('bin/claude-window-keeper', '.local/bin/claude-window-keeper'))
    plist = HOME / 'Library/LaunchAgents' / (LABEL + '.plist')
    source = ROOT / 'launchd' / plist.name
    live = HOME.resolve() == Path(pwd.getpwuid(os.getuid()).pw_dir).resolve()
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
        if sys.platform == 'darwin':
            (HOME / 'Library/Logs').mkdir(parents=True, exist_ok=True)
            write(plist, source.read_text())
            if args.reload and live:
                domain = f'gui/{os.getuid()}'
                subprocess.run(['launchctl', 'bootout', domain, str(plist)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                subprocess.run(['launchctl', 'bootstrap', domain, str(plist)], check=True)
        return 0
    good = settings.is_file() and not settings.is_symlink() and current == expected
    for src, dst in links:
        target = HOME / dst
        good &= target.is_symlink() and target.resolve() == ROOT / src
    if sys.platform == 'darwin':
        good &= plist.is_file() and not plist.is_symlink() and plist.read_bytes() == source.read_bytes()
        if live:
            good &= subprocess.run(['launchctl', 'print', f'gui/{os.getuid()}/{LABEL}'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    print(('OK' if good else 'FAIL') + ': Claude statusline key/link and platform keeper')
    return 0 if good else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.CalledProcessError):
        # App settings can contain credentials; never print their values.
        sys.exit('Could not manage Claude dotfiles; check settings.json and file access.')
