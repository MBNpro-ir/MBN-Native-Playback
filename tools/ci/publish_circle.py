"""Publish the tested native core together with all required LGPL sources."""
import os
from pathlib import Path
import re
import subprocess

if (os.environ.get('CIRCLECI') != 'true' or os.environ.get('CIRCLE_BRANCH') != 'main'
        or os.environ.get('CIRCLE_PULL_REQUEST')
        or os.environ.get('CIRCLE_PROJECT_ID') != 'e768ed54-5765-4133-909f-58ae9a626c28'
        or os.environ.get('MBN_PUBLISH_PRODUCTION') != 'true'):
    raise SystemExit('Trusted native release job required')
commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
if commit != os.environ['CIRCLE_SHA1']:
    raise ValueError('Native source differs from pipeline commit')
subprocess.run(['sha256sum', '--check', 'SHA256SUMS'], cwd='out', check=True)
files = list(Path('out').iterdir())
if len([p for p in files if p.name.endswith('-sources.tar.xz')]) != 1:
    raise ValueError('Complete corresponding LGPL sources are mandatory')
version = next(line.split('=', 1)[1].strip().strip('\"\'') for line in Path('versions.env').read_text().splitlines()
               if line.startswith('MPV_TAG='))
if not re.fullmatch(r'[A-Za-z0-9_.-]+', version):
    raise ValueError('Unexpected pinned native version')
tag = 'mpv-' + version.lstrip('v') + '-' + commit[:12]
notes = Path('out/RELEASE_NOTES.txt')
notes.write_text('Pinned LGPL libmpv/FFmpeg. License verification and native seek/frame smoke tests passed.\n'
                 'Complete sources, recipes, licenses and checksums accompany this build.\n\n'
                 + Path('dist/BUILDINFO.txt').read_text())
subprocess.run(['gh', 'release', 'create', tag, *[str(p) for p in files],
                '--repo', 'MBNpro-ir/MBN-Native-Playback', '--target', commit, '--latest=false',
                '--notes-file', str(notes)], check=True)
