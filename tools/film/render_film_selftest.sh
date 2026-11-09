#!/bin/bash
# Proves tools/film/render_film.sh renders quietly on the Mac (T088) with a
# stand-in Godot and ffmpeg: a small corner window, never on top, override.cfg
# at the full size, __CFBundleIdentifier set, and a frame measured at 1920x1080.
# It fails on the old flags (--resolution 1920x1080 --always-on-top, no cfg).
#   tools/film/render_film_selftest.sh
set -u
HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT=$(cd "$HERE/../.." && pwd -P)
[ "$(uname -s)" = Darwin ] || { echo "SKIP render_film is only quiet-by-window on macOS"; exit 0; }
T=$(cd "$(mktemp -d "${TMPDIR:-/tmp}/film-selftest.XXXXXX")" && pwd -P)
trap 'rm -f "$ROOT/override.cfg"; rm -rf "$T"' EXIT
FAILS=0
check() { if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; FAILS=$((FAILS + 1)); fi; }

mkdir -p "$T/bin/Contents/MacOS"
cat >"$T/bin/Contents/Info.plist" <<'P'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>org.godotengine.godot</string></dict></plist>
P
cat >"$T/bin/Contents/MacOS/godot" <<'G'
#!/bin/bash
echo "CALL $* | BUNDLE=${__CFBundleIdentifier:-}" >>"$FAKE_LOG"
cfg="$FAKE_ROOT/override.cfg"
[ -f "$cfg" ] && echo "CFG $(sed -n 's/^window\/size\/viewport_width=//p' "$cfg")x$(sed -n 's/^window\/size\/viewport_height=//p' "$cfg") $(sed -n 's/^window\/stretch\/mode=//p' "$cfg")" >>"$FAKE_LOG"
out=""
for a in "$@"; do [ "$prev" = --write-movie ] && out="$a"; prev="$a"; done
python3 -I - "$out" "${FAKE_FRAME:-1920x1080}" <<'PY'
import struct, sys, zlib
path, size = sys.argv[1], sys.argv[2]
w, h = map(int, size.split("x"))
def chunk(t, d):
    c = struct.pack(">I", len(d)) + t + d
    return c + struct.pack(">I", zlib.crc32(t + d))
raw = b"".join(b"\x00" + b"\x00\x00\x00" * w for _ in range(h))
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")
open(path.replace("f.png", "f00000000.png"), "wb").write(png)
PY
G
printf '#!/bin/bash\nfor a; do last="$a"; done\n: >"$last"\n' >"$T/bin/ffmpeg"
chmod +x "$T/bin/Contents/MacOS/godot" "$T/bin/ffmpeg"
export FAKE_LOG="$T/log" FAKE_ROOT="$ROOT" PATH="$T/bin:$PATH" GODOT="$T/bin/Contents/MacOS/godot"
: >"$FAKE_LOG"

bash "$HERE/render_film.sh" opening "$T/o.mp4" until=1 >"$T/run.out" 2>&1; rc=$?
check "a render succeeds" '[ $rc = 0 ]'
check "the window is small and in the corner" 'grep -q -- "--windowed --resolution 640x360 --position 40,40" "$FAKE_LOG"'
check "the window is never kept on top" '! grep -q -- "--always-on-top" "$FAKE_LOG"'
check "the old full-size window is gone" '! grep -q -- "--resolution 1920x1080" "$FAKE_LOG"'
check "the frames render at 1920x1080 through override.cfg (viewport stretch)" 'grep -q "^CFG 1920x1080 \"viewport\"" "$FAKE_LOG"'
check "the app starts in the background (__CFBundleIdentifier)" 'grep CALL "$FAKE_LOG" | grep -q "BUNDLE=org.godotengine.godot$"'
check "override.cfg is removed after the render" '[ ! -f "$ROOT/override.cfg" ]'

FAKE_FRAME=640x360 bash "$HERE/render_film.sh" opening "$T/s.mp4" until=1 >"$T/small.out" 2>&1; rc=$?
check "a frame smaller than 1920x1080 fails the render" '[ $rc != 0 ] && grep -q "frames are 640x360" "$T/small.out"'

[ "$FAILS" = 0 ] && echo "film selftest ok" || { echo "film selftest: $FAILS failed"; exit 1; }
