#!/usr/bin/env bash
set -euo pipefail
test "${GITLAB_CI:-}" = true
test "${CI_SERVER_URL:-}" = https://gitlab.com
bash build.sh
python3 verify.py dist
"$TARGET-gcc-posix" -O2 -Idist/include smoke/smoke.c -o dist/smoke.exe -Lwork/prefix/lib -lmpv
cp smoke/clip.mp4 dist/
wine="$(command -v wine64 || echo /usr/lib/wine/wine64)"
(cd dist && "$wine" smoke.exe)
rm -f -- dist/smoke.exe dist/clip.mp4
name="libmpv-lgpl-$CI_COMMIT_REF_SLUG-x86_64"
mkdir -p out
(cd dist && zip -qr9 "../out/$name.zip" .)
cp sources/sources.tar.xz "out/$name-sources.tar.xz"
python3 - <<'PY'
import hashlib,json,pathlib
files=[dict(name=p.name,sha256=hashlib.sha256(p.read_bytes()).hexdigest(),size=p.stat().st_size)
       for p in pathlib.Path('dist').glob('*.dll')]
pathlib.Path('out/WINDOWS-LIBRARIES.json').write_text(json.dumps(files,indent=2))
PY
(cd out && sha256sum * > SHA256SUMS)
if [[ -n "${CI_COMMIT_TAG:-}" ]]; then
  test "${CI_COMMIT_REF_PROTECTED:-}" = true
  python3 tools/ci/publish_gitlab.py
fi
