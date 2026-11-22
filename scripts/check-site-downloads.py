#!/usr/bin/env python3
"""Refuse a site deploy that would publish a stray installer or a broken Sparkle feed.

site/appcast.xml must exist: Sparkle clients read it, and a deploy without it removes the live feed.
Allowed under site/downloads: Ember.dmg, and the <version>/Ember.dmg files the feed's enclosures
point at (each must exist and match the feed's length).
"""
import pathlib
import sys
import urllib.parse
import xml.etree.ElementTree as ET

site = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else 'site')
downloads = site / 'downloads'
allowed = {'Ember.dmg', '.gitkeep'}
appcast = site / 'appcast.xml'
problems = []
if not appcast.is_file():
    problems.append('site/appcast.xml is missing; copy dist/appcast.xml from scripts/make-appcast-item.sh')
else:
    try:
        enclosures = ET.parse(appcast).getroot().iter('enclosure')
    except ET.ParseError as error:
        problems.append(f'appcast.xml is not valid XML: {error}')
        enclosures = []
    for enclosure_tag in enclosures:
        path = urllib.parse.urlparse(enclosure_tag.get('url', '')).path
        length = enclosure_tag.get('length', '')
        if '/downloads/' not in path or not length.isdigit():
            problems.append(f'appcast.xml enclosure needs a /downloads/ url and a length: {enclosure_tag.attrib}')
            continue
        url = path.split('/downloads/', 1)[1]
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
