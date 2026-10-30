# How lanes work

Every lane (thread) follows these rules. The full plan is the project's build plan doc.

## Branches and the build lane

1. Work on your own branch: `laneN/<topic>` on the home machine, `lane/<topic>` in the cloud. Never commit to `main`.
2. Before handing off, run the import headless and **only the tests directly related to what you changed** (for example `godot --headless -s addons/gut/gut_cmdln.gd -gconfig= -gexit -gtest=res://tests/unit/test_phase_data.gd`). Never run the full suite in a feature lane.
3. Every task starts with a written definition of done. Stop when it is met; do not keep retesting or polishing details.
4. Screenshots only at milestones. Work in code and numbers otherwise.
5. Hand off through the queue, never by hand. Lanes on the home machine run `tools/mq/submit.sh HEAD <task>`. Cloud sessions merge `origin/main` in, push `lead/ready-<TASK>-<n>` at the finished commit, and read the answer from the tag `merged/<TASK>-<n>` or `rejected/<TASK>-<n>`. A resubmission takes the next number. See `CLAUDE.md`.
6. The build lane is a script on the home machine. It takes everything waiting as one batch, runs **the full gate** (it is the only thing that does) and pushes to `origin/main`, the only `main` the queue reads or moves. If a change fails it is rejected with the reason; fix it and submit again.

## Screenshots

Heavy renders go to the Mac's GPU, not the cloud's software renderer: push a request with `tools/mq/shots_request.sh` and read the pictures with `tools/mq/shots_fetch.sh`. How-to: [SHOTS.md](SHOTS.md); contract: [contracts/shots.md](contracts/shots.md).

## Ownership

Each lane owns its folders (core/, world/, systems/ + data/, creatures/, characters/ + art/, dialogue and audio). Change another lane's files only through a handoff to that lane, except for small fixes you call out in your summary.

## Blender

Only the art lane opens Blender on the user's Mac, one `.blend` at a time. Other lanes request assets from the art lane. Bulk assets (procedural plants, rocks, generic props) are made with headless Blender in the cloud.

## Story flags

Gameplay only raises flags through `ActionTrigger`. Flag names come from the root design doc where it names them (`wolf_killed`, `suriel_bound`, ...). New flags go in the phase data and are mentioned in your handoff summary.

## Clean up when you are done (standing rule)

When your work is merged or dropped, delete everything you used and no longer need: worktrees, merged or abandoned branches (local and remote), build and export outputs, the `.godot/` import cache, downloaded binaries and archives, temp files, and any scratch files on the user's Mac. Storage is a budget.
