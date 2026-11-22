#!/usr/bin/env python3
"""Refuse a site deploy that would publish a stray installer or a broken Sparkle feed.

Allowed under site/downloads: Ember.dmg, and <version>/Ember.dmg for the one version
site/appcast.xml points at (that file must exist and match the feed's length).
"""
import pathlib
import re
import sys

site = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else 'site')
downloads = site / 'downloads'
allowed = {'Ember.dmg', '.gitkeep'}
appcast = site / 'appcast.xml'
problems = []
if appcast.exists():
    feed = appcast.read_text()
    for url, length in re.findall(r'<enclosure url="[^"]*/downloads/([^"]+)" length="(\d+)"', feed):
        allowed.add(url)
        enclosure = downloads / url
        if not enclosure.is_file():
            problems.append(f'appcast.xml points at downloads/{url}, which is missing')
        elif enclosure.stat().st_size != int(length):
            problems.append(f'downloads/{url} is {enclosure.stat().st_size} bytes; appcast.xml says {length}')
if downloads.is_dir():
    for path in sorted(p for p in downloads.rglob('*') if p.is_file()):
        name = path.relative_to(downloads).as_posix()
        if name not in allowed and path.name != '.DS_Store':
            problems.append(f'stray file would deploy: downloads/{name}')
for problem in problems:
    print(f'check-site-downloads: {problem}', file=sys.stderr)
if problems:
    sys.exit(1)
print('check-site-downloads: ok')
