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
| `size <W>x<H>` | window size, passed as `--resolution` | `1920x1080` |
| `renderer forward_plus\|mobile\|compatibility` | `--rendering-method` | the project's |
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

Before any shot, the Mac imports the project (`--headless --import`, kept warm between requests) and runs every `tools/generators/*.gd`, then each `prep` line, the same as `make generate`.
Batch your views: one probe that takes ten pictures in one run loads the level once.

## 3. Answer

The Mac answers every request it accepts on **`shots/res-<ID>-<n>`**: an orphan
commit (no game files) holding

```
result.txt             status line first, then one line per step
out/<label>/…          every .png .jpg .webp .txt .json .csv the shot wrote (≤15 MB each, ≤60 MB total)
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
size 1920x1080
renderer project default
prep ok 41s (<lane commit>)
shot cottage ok exit=0 3s files=1          ok | fail | timeout (exit=124)
note <why, for error/partial/skips>
answered <UTC time> after 52s
```

- `ok`: every shot exited 0. `partial`: some did. `fail`: none did. `error`: the
  request was malformed, or prep failed. The `note` says why.
- Read it with `tools/mq/shots_fetch.sh <ID> <n> [dest] [--wait <min>] [--done]`.
  Exit 3 means no answer yet: the Mac is busy, asleep, off, or the owner is playing. Nothing is lost.
- `--done` deletes your request and its answer from origin. Otherwise the Mac
  deletes its own answers after 3 days. It never deletes a request.

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
- **One request at a time**, oldest first, polled about every 90 s with `git ls-remote`.
  The Mac stays awake (`caffeinate -i -w`) while the listener runs.
- **A stuck request can't block the queue.** A hung shot is killed at its timeout.
  A request that can't be fetched, checked out or answered is retried, and given up after 5 tries.

State lives in `.git/mq/shots/`: `events.log`, `listener.log`, `seen/`, `done/`, `lock/`, `userdir/`, `work/`.
`tools/mq/shots_selftest.sh` checks all of the above in throwaway repos with a stand-in Godot.
