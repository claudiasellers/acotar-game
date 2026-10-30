# Contract: shot requests to the Mac (transport)

Cloud containers have no GPU, so a heavy view that takes minutes in software
takes about a second on the Mac. Lanes ask the Mac for pictures through git,
the same way they hand in to the build lane. The Mac side is a plain script,
`tools/mq/shots.sh`, not an AI. It runs only on the home machine and costs no tokens.

This file covers transport: how a request gets to the Mac and how the answer comes back.
What a JSON request may ask for (cameras, checks, quality) is the layout-shots
lane's contract, `docs/contracts/shot_request.md`. Lanes use it through `.shots/request.json`.

## 1. Request

A request is a branch **`shots/req-<ID>-<n>`** whose commit is the lane's own
commit plus one extra commit that adds exactly one of:

- `.shots/request.json`: a layout-shots request. The Mac runs that commit's
  `tools/shots/take_shots.sh .shots/request.json <out_dir>`.
- `.shots/probes.txt`: any probe scene or script that is already in the commit (format in §2).

`tools/mq/shots_request.sh <ID> <n> <file>` builds and pushes it. Your own
branch is not changed, and only committed work is rendered.

Rules:
- `<ID>` is letters, digits, `. _ -` (use your lane, e.g. `woods`, `manor-aerie`); `<n>` is a number.
  The Mac notes anything else once and ignores it.
- **Immutable.** Never move or reuse a request branch; resubmit with `n+1`.
  The Mac pins the commit it first saw, and ignores a branch that has moved since.
- Branches, not tags: tag pushes from the cloud don't land reliably.

## 2. `.shots/probes.txt`

One directive per line, `#` comments. Allowed characters: letters, digits, space and `_ . , : = / + @ { } -`.

| Line | Meaning | Default |
|---|---|---|
| `from <text>` | who asked (log only) | |
| `quality look\|layout` | see "Quality tiers" below | `look` |
| `size <W>x<H>` | window size, passed as `--resolution` (look: 1920 wide or more) | `1920x1080` |
| `renderer forward_plus\|mobile\|compatibility` | `--rendering-method` (layout only) | the project's |
| `timeout <s>` | limit per shot line, max 1200 | `300` |
| `prep <res://….gd\|.tscn>` | runs headless before the shots, e.g. `res://tools/manor_estate/gen_grounds.tscn` | none |
| `shot <label> <res://….tscn\|.gd> [args…]` | one Godot run. Between 1 and 40 lines. | |

Each `shot` line runs
`Godot --path <worktree> --audio-driver Dummy --windowed --resolution W×H --position <corner> --always-on-top [--rendering-method M] <scene> -- <args>`
(a `.gd` path is run with `-s`). In args, `{out}` becomes this shot's output folder. `$SHOTS_OUT` is set as well.
Existing probes work unchanged:

```
from manor-lane
size 1920x1080
shot cottage res://tools/world_shot.tscn cottage_snow {out}/cottage_snow.png
shot menu res://tools/pause_menu_shot.tscn menu {out}/menu.png
```

**Quality tiers.** Cost is saved by batching, caching and idling. It is never saved by degrading a look shot.
- `look` (the default; use it for any art, lighting, foliage, UI or type judgement): the project's own Forward+ at its default quality settings, nothing turned down, at 1920×1080 or larger. The pictures come back as the probe wrote them, as lossless PNG at native resolution. The listener refuses a `renderer` line or a smaller size on a look request.
  Probes see `SHOTS_QUALITY=look` and should give TAA, GI and streaming a few seconds to settle before capture.
- `layout` (positions, overlaps, "is the stair there"): any renderer or size. PNGs come back as JPEG, 1280 px wide at quality 80, which is about a tenth of the size.
  Most layout checks don't need the Mac at all. Run them in the cloud with the layout-shots runner (lavapipe), or print a number instead of taking a picture.

A `request.json` is `look` unless it has `"quality": "layout"`.

**Before the shots, nothing is rebuilt that doesn't need to be:**
- Import: the render worktree starts from the play folder's `.godot` (a zero-copy APFS clone). `--import` runs only when an importable file (art, models, audio, fonts, `.import`) changed since the last import.
- Generated content (`tools/mq/shots_generated.conf`: terrain bake, woods cache, manor scatter) is cached by the git ids of each generator's input files.
  A build that `make update` already made in the play folder is adopted read-only, so a lane whose change doesn't touch those inputs never rebuilds them.
  A change to an input rebuilds that one generator once; the last three builds per generator are kept.
  **Add your generator to that file when you add one**, with its inputs regex. An unlisted `tools/generators/*.gd` still runs, uncached, on every request.
- `prep` lines run every time.
- **Same code and same request** (the request commit's tree) already answered `ok`: the earlier answer is sent again with nothing rendered.

Batch your views: one probe that takes ten pictures in one run loads the level and warms up once. Each `shot` line is one Godot launch.

## 3. Answer

The Mac answers every request it accepts on **`shots/res-<ID>-<n>`**: an orphan
commit (no game files) holding

```
result.txt             status line first, then one line per step
out/<label>/…          every .png .jpg .webp .txt .json .csv the shot wrote (≤15 MB each, ≤60 MB total;
                       layout PNGs arrive as .jpg)
logs/<label>.log       Godot's output for that shot (prints such as draw calls land here)
logs/prep.log          import and generators
probes.txt | request.json   what was asked
```

`result.txt`:

```
status ok|partial|fail|error
request <ID>-<n>
commit <sha of the request commit>
machine <host>
godot <version>
quality look
size 1920x1080
renderer project default
prep ok 4s: import skipped (no art changed), terrain cached, woods cached, manor cached
shot cottage ok exit=0 3s files=1          ok | fail | timeout (exit=124)
note <why, for error/partial/skips>
answered <UTC time> after 52s
```

- `ok`: every shot exited 0. `partial`: some did. `fail`: none did. `error`: the
  request was malformed, or prep failed. The `note` says why.
- Read it with `tools/mq/shots_fetch.sh <ID> <n> [dest] [--wait <min>] [--done]`.
  Exit 3 means no answer yet: the Mac is busy, asleep, off, or the owner is playing. Nothing is lost.
- `--done` deletes your request and its answer from origin. Otherwise the Mac
  deletes its own answers after 1 day. It never deletes a request. Answers are orphan commits (pictures and logs only), so they never enter `main`'s history.

## 4. What the Mac guarantees

- **Home machine only.** It runs only where `.git/mq/config` has `MQ_HOME_MACHINE=1`
  (read from the file, never the environment). Anywhere else it refuses (`SHOT LISTENER REFUSED`).
- **Reads requests, writes results.** It pushes only `shots/res-*` and deletes only
  answers it pushed itself. It never touches `main`, the play folder, or any other branch.
- **Renders in its own worktree**, `.lanes/shots` (locked, git-excluded, `.gdignore`d), checked out
  detached at the request commit. Godot's import cache is kept warm there.
- **Never sees the owner's save.** Every Godot run gets a scratch `user://` (`HOME`/`XDG_*` point
  into `.git/mq/shots/userdir`, wiped before each run except shader caches). Audio is the Dummy driver.
- **The owner's game comes first.** While a Godot game is running (`make play`, or Play
  from the editor), requests wait.
- **One request at a time**, oldest first. When idle it does nothing but one `git ls-remote` a minute.
  The Mac stays awake (`caffeinate -i -w`) while the listener runs.
- **A stuck request can't block the queue.** A hung shot is killed at its timeout.
  A request that can't be fetched, checked out or answered is retried, and given up after 5 tries.

- **Fetches only the delta.** The Mac's clone already has `main`, so a request fetch brings only the lane's new commits. The worktree checkout rewrites only the changed files.

State lives in `.git/mq/shots/`: `events.log`, `listener.log`, `seen/`, `done/`, `bytree/`, `gencache/`, `lock/`, `userdir/`, `work/`.
`tools/mq/shots_selftest.sh` checks all of the above in throwaway repos with a stand-in Godot.
