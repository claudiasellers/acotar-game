# ACOTAR: The Spring Court

The owner plays the game, types what they want changed, and keeps typing. Lane
workers make the changes side by side and a script merges them. Nobody merges by
hand, and `main` always passes its gate.

## If you're the session the owner is typing to, you're the lead

You never do the work and never wait for it.

**At the start:** check whether another lead session is already open; only one
owns the lanes. Run `tools/mq/setup_lanes.sh`, then `tools/mq/status.sh`. Spawn
the lane workers as an agent team if that's available, otherwise as named
background subagents (`.claude/agents/lane-worker.md`). Put any open tasks from
`tools/mq/task.sh list` back on the list.

**Standing rule from the owner:** whenever a lane is free and an open T task has
its deps met, dispatch it immediately, Sonnet for routine, Opus for hard, without
waiting for the owner. Check on every monitor event and whenever a worker
finishes. Only stop to ask the owner for permission denials, destructive steps, or
design choices.

**For every request:**
- Make one task per separate change with `tools/mq/task.sh add "<request>"`, in
  the owner's words plus what you know: where it is, which files, what done
  looks like.
- Reply in a line or two right away so they can keep going.
- Things touching the same character, screen or file go in one task or get a
  dependency, so two workers never edit one file.
- If it's a question, just answer it. Don't act on it: "why isn't this on main?"
  isn't "put it on main."
- If it's unclear and costly to guess wrong, ask one short question.

**While the team works:** tell the owner each thing submitted and each thing
merged, unprompted, as it lands. Watch `.git/mq/events.log` for events; don't
poll on a timer. On `REJECTED`, make a follow-up task and say so in one line.

**Before saying anything is in the game,** check it's in `origin/main`:
`git fetch origin && git merge-base --is-ancestor <sha> origin/main`.

**Never:** edit code in the primary folder, commit to `main`, push, or merge by
hand.

Routine lane workers use Sonnet; only hard tasks use Opus. Record the choice
with `tools/mq/task.sh set <id> model sonnet|opus`. The build, cleanup and shots
lanes are plain bash and use no model. Start fresh workers at natural seams, with a short handover note. A message
to a busy worker queues until its turn ends, so don't say a worker has heard
something until you've checked. A worker waiting silently looks exactly like a
worker working: workers end their turn to ask for a decision.

## If you're a lane worker

Follow `.claude/agents/lane-worker.md`.

## If you're a cloud session

You can't reach the home machine, so git carries the messages. Never run
`submit.sh` or start a build lane.

1. Finish on your own branch with `origin/main` merged in, and push.
2. Push a branch at that exact commit: `git push origin <commit>:refs/heads/lead/ready-<TASK-ID>-<n>`.
   This is the main form. Tags can also work (`ready/<TASK-ID>-<n>`), but tags
   pushed from the cloud don't land reliably.
3. Fetch the answer, a tag on the same commit:
   `merged/<TASK-ID>-<n>` means it's in `origin/main`; `rejected/<TASK-ID>-<n>` is
   annotated with why, what to do and the end of the failing log. Neither yet
   means it's waiting or the machine is off. Nothing is lost.

Never move or reuse a ready name. A resubmission takes the next number.

## How the layout works

| Where | What |
|---|---|
| `.lanes/lane1..4` | one task at a time, on `laneN/<name>` from `origin/main` |
| `.lanes/build` | always a detached HEAD; only the build lane touches it |
| `.lanes/cleanup` | where the cleanup loop runs, detached; nothing is built here |
| `.lanes/shots-lane` | where the shot listener runs; `.lanes/shots` is its render worktree |
| the repo folder | for playing, on `main` tracking `origin/main`; only `make update` moves it |
| `.git/mq/` | queue state, shared by every worktree, never committed |

`origin/main` is the truth. The build lane lands a batch by pushing it, with no
force: a rejected push means someone got there first, so the batch goes round
again on the new `origin/main` and nobody is rejected. It never writes the local
`main`, and with `MQ_PUSH=0` it holds the queue because nothing can land.

The build lane and the cleanup loop run from `.git/mq/bin/`, a copy that changes
only when a change to `tools/mq/` merges. No loop runs in the play folder.
`setup_lanes.sh --start` starts all three and moves any on old code or in the
wrong folder. The shots listener starts once `shots.sh` is on `main`.
See `tools/mq/` and `tools/mq/selftest.sh` for the rules they keep.
`.git/mq/config` holds `MQ_HOME_MACHINE=1`, which exists only on the Mac mini.

## Things that are true about this project

- Godot 4.7.2, typed GDScript. Run it through `tools/mq/godot.sh <args>`, never
  the bare engine: that gives it a scratch data folder, no window and no audio.
  Godot is not on PATH in scripts; `godot` is only a zsh alias.
- Parse check: `tools/mq/parse.sh [files]`.
- One test: `tools/mq/godot.sh -s addons/gut/gut_cmdln.gd -gconfig= -gexit -gtest=res://tests/unit/test_clock.gd`.
- World smoke: `tools/mq/godot.sh -s tools/world_smoke.gd`, about 3.5 minutes. The
  build lane runs it; a lane shouldn't.
- The gate is `tools/mq/gate.conf`. Test files are found at run time, so adding
  one needs no gate edit. The whole gate takes about 4 minutes at 4 jobs.
- Built files are recipes in `tools/mq/generated.conf`, rebuilt by
  `tools/mq/levels.sh ensure`. The terrain bake takes about 14 minutes and is
  cached in `.git/levelcache/`. Never commit or hand-edit built files, including
  anything under `_generated/` or `world/shared/terrain/data/`.
- No Git LFS. Binaries go in plain git, because cloud sessions can't upload to the
  LFS endpoint (see `.gitattributes`). Keep each file under 50 MB.
- Heavy screenshots from the cloud go to the Mac's GPU: `docs/SHOTS.md`.
- Style and lane rules: `docs/LANES.md`, `docs/contracts/`.
