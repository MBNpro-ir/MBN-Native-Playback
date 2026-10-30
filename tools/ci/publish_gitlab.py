"""Publish verified third-party binaries with complete LGPL sources."""
import json
import os
from pathlib import Path
import subprocess
import urllib.request

if (os.environ.get('GITLAB_CI') != 'true' or os.environ.get('CI_SERVER_URL') != 'https://gitlab.com'
        or os.environ.get('CI_COMMIT_REF_PROTECTED') != 'true' or not os.environ.get('CI_COMMIT_TAG', '').startswith('mpv-')):
    raise SystemExit('Only protected native version tags may publish')
subprocess.run(['sha256sum', '--check', 'SHA256SUMS'], cwd='out', check=True)
files = list(Path('out').iterdir())
if len([p for p in files if p.name.endswith('-sources.tar.xz')]) != 1:
    raise ValueError('Complete corresponding LGPL sources are mandatory')
base = 'https://gitlab.com/api/v4/projects/' + str(int(os.environ['CI_PROJECT_ID']))
prefix = '/packages/generic/native/' + os.environ['CI_COMMIT_SHA'] + '/'
links = []
for path in files:
    with path.open('rb') as source:
        request = urllib.request.Request(base + prefix + path.name, data=source, method='PUT', headers={
            'JOB-TOKEN': os.environ['CI_JOB_TOKEN'], 'Content-Type': 'application/octet-stream',
            'Content-Length': str(path.stat().st_size)})
        with urllib.request.urlopen(request, timeout=900) as response:
            if response.status != 201: raise ValueError('Native package upload failed')
    links.append({'name': path.name, 'url': base + prefix + path.name, 'link_type': 'package'})
notes = ('LGPL libmpv and FFmpeg built from pinned sources. License verification and native seek/frame smoke tests passed.\n\n'
         'Complete dependency sources, recipes, licenses, binary inventory and SHA256 checksums accompany this release.\n\n' +
         Path('dist/BUILDINFO.txt').read_text())
request = urllib.request.Request(base + '/releases', data=json.dumps({
    'tag_name': os.environ['CI_COMMIT_TAG'], 'ref': os.environ['CI_COMMIT_SHA'],
    'name': os.environ['CI_COMMIT_TAG'], 'description': notes, 'assets': {'links': links}}).encode(),
    headers={'JOB-TOKEN': os.environ['CI_JOB_TOKEN'], 'Content-Type': 'application/json'})
with urllib.request.urlopen(request, timeout=90) as response:
    print('NATIVE_GITLAB_RELEASE_PUBLISHED', response.status)
