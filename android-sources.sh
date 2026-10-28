#!/usr/bin/env bash
# Archive the exact default-flavor third-party sources used by media_kit Android.
set -euo pipefail
root=$PWD/android-corresponding-source
mkdir -p "$root"
git clone --depth 1 --branch v1.1.7 https://github.com/media-kit/libmpv-android-video-build.git "$root/recipe"
cd "$root/recipe/buildscripts"
mkdir -p deps
clone() {
 local name=$1 url=$2 ref=$3
 git init -q "deps/$name"
 git -C "deps/$name" remote add origin "$url"
 git -C "deps/$name" fetch -q --depth 1 origin "$ref"
 git -C "deps/$name" checkout -q FETCH_HEAD
 git -C "deps/$name" submodule update --init --recursive --depth 1
 git -C "deps/$name" rev-parse HEAD >> "$root/SOURCE-REVISIONS.txt"
}
clone mbedtls https://github.com/Mbed-TLS/mbedtls.git v3.4.0
clone dav1d https://code.videolan.org/videolan/dav1d.git 1.2.0
clone libxml2 https://gitlab.gnome.org/GNOME/libxml2.git v2.10.3
clone ffmpeg https://github.com/FFmpeg/FFmpeg.git n6.0
clone freetype https://gitlab.freedesktop.org/freetype/freetype.git VER-2-13-0
clone fribidi https://github.com/fribidi/fribidi.git v1.0.12
clone harfbuzz https://github.com/harfbuzz/harfbuzz.git 7.2.0
clone libass https://github.com/libass/libass.git 0.17.1
clone mpv https://github.com/mpv-player/mpv.git 78d43740f52db817d98bcf24fb30a76ab6fa13ff
clone media-kit-android-helper https://github.com/media-kit/media-kit-android-helper.git 42054e5d479f39ccbb0ae604862e2bcaf59b74c2
# Preserve both pristine sources and the exact patches/build instructions. The
# patches are applied by the documented build, as in the original release CI.
cat > "$root/README.txt" <<'TXT'
Corresponding source for media-kit default Android libmpv v1.1.7, recipe commit
fe8c3ac1a91c09aa6fb1deccbc833f1bafa54768. No application source is included.
The recipe/buildscripts directory contains pinned dependencies, patches, NDK
version and the build scripts. Follow recipe/.github/workflows/build.yaml,
default flavor, to apply patches and rebuild/replace the shared libmpv.so.
mpv uses -Dgpl=false; FFmpeg uses --disable-gpl --disable-nonfree
--enable-version3 (LGPLv3). See each component's license. App licenses do not
restrict modification/replacement or reverse engineering for debugging these
LGPL components, as required by their licenses.
TXT
cd "$root"
python3 - <<'PY'
from pathlib import Path
files = []
for component in (Path('recipe/buildscripts/deps')).iterdir():
 for name in ['LICENSE', 'LICENSE.md', 'LICENSE.LGPL', 'COPYING', 'COPYING.LIB',
              'COPYING.LGPLv3', 'COPYING.LGPLv2.1', 'COPYING.LESSERv3', 'LICENSE.TXT',
              'docs/FTL.TXT', 'Copyright', 'COPYRIGHT']:
  p=component/name
  if p.is_file(): files.append('\n==== '+component.name+'/'+name+' ====\n'+p.read_text(errors='replace'))
Path('ANDROID-NOTICES.txt').write_text(Path('README.txt').read_text()+''.join(files))
PY
mkdir -p ../out
cp ANDROID-NOTICES.txt ../out/
tar --exclude=.git -cJf ../out/android-libmpv-v1.1.7-sources.tar.xz .
(cd ../out && sha256sum android-* > ANDROID-SHA256SUMS)
