# How lanes work

Every lane (thread) follows these rules. The full plan is the project's build plan doc.

## Branches and the build lane

1. Work on your own branch, `lane/<topic>` (for example `lane/chemistry-hearth`). Never commit to `main`.
2. Before handing off, run the import and the tests headless and make sure they pass.
3. Message the build lane thread ("Build and merge game changes") with the branch name and a one-line summary.
4. The build lane imports the project, runs the tests and an export build. If everything passes it merges to `main` and tells you. If anything fails it sends back what failed and why; fix it on the same branch and hand it back.

## Ownership

Each lane owns its folders (core/, world/, systems/ + data/, creatures/, characters/ + art/, dialogue and audio). Change another lane's files only through a handoff to that lane, except for small fixes you call out in your summary.

## Blender

Only the art lane opens Blender on the user's Mac, one `.blend` at a time. Other lanes request assets from the art lane. Bulk assets (procedural plants, rocks, generic props) are made with headless Blender in the cloud.

## Story flags

Gameplay only raises flags through `ActionTrigger`. Flag names come from the root design doc where it names them (`wolf_killed`, `suriel_bound`, ...). New flags go in the phase data and are mentioned in your handoff summary.

## Clean up when you are done (standing rule)

When your work is merged or dropped, delete everything you used and no longer need: worktrees, merged or abandoned branches (local and remote), build and export outputs, the `.godot/` import cache, downloaded binaries and archives, temp files, and any scratch files on the user's Mac. Storage is a budget.
