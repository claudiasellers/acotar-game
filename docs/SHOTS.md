# Taking screenshots on the Mac (how-to for lanes)

Cloud renders are software renders, so a heavy view can take 7 minutes or more.
Send it to the Mac instead, where it takes seconds. The contract is
[contracts/shots.md](contracts/shots.md).

## From a cloud lane

1. Commit and push your work. Only committed work is rendered.
2. Write a request. Either use a layout-shots JSON (see `contracts/shot_request.md`), or list probe runs:

   ```
   # /tmp/shots.txt
   from woods-lane
   quality look
   shot falls res://tools/world_shot.tscn border_falls {out}/falls.png
   ```

   `quality look` (the default) is the real game look, as full-size lossless PNG. Use it for anything you judge by eye.
   `quality layout` is for "is it in the right place". It returns small JPEGs and allows `size 640x360` and `renderer compatibility`,
   but most layout checks are cheaper in the cloud with the layout-shots runner, or as a printed number.

3. Send it with a new number each time:

   ```
   tools/mq/shots_request.sh woods 1 /tmp/shots.txt
   ```

4. Do other work. When you need the pictures:

   ```
   tools/mq/shots_fetch.sh woods 1                  # exit 3 = no answer yet
   tools/mq/shots_fetch.sh woods 1 --wait 10        # or wait up to 10 minutes
   ```

   Look at `out/<label>/*.png` and `result.txt`. When you're finished, run
   `tools/mq/shots_fetch.sh woods 1 --done` to delete both branches.

Tips:
- Put all your views in one probe run, so the level loads once. Each `shot` line starts Godot from scratch.
- If the question is a number (a position, an overlap, a count), print it from the probe instead of taking a picture.
  The probe's output comes back in `logs/<label>.log`.
- No answer usually means the Mac is asleep or the owner is playing. Keep working.
  Don't resubmit the same request; nothing is lost.
- Generated content (terrain bake, woods cache) comes from the build queue's cache (`tools/mq/levels.sh`, `generated.conf`)
  and is rebuilt only when its inputs change. If you add a generator, add a line to `generated.conf`. Generators not listed there,
  such as the manor scatter today, need a `prep` line.
- Sending the identical commit and request twice costs nothing: the Mac resends the first answer.

## On the Mac (owner, once)

From the game folder, paste:

```
make update && mkdir -p .git/mq && (grep -qx MQ_HOME_MACHINE=1 .git/mq/config 2>/dev/null || echo MQ_HOME_MACHINE=1 >> .git/mq/config) && defaults write org.godotengine.godot NSAppSleepDisabled -bool YES && tools/mq/shots.sh --check && tools/mq/shots.sh --start
```

After that:

| Command | |
|---|---|
| `tools/mq/shots.sh --status` | running? last few requests |
| `tools/mq/shots.sh --stop` / `--start` | stop or start the listener (it does not restart after a reboot) |
| `tail -f .git/mq/shots/events.log` | watch it work |

A small window flashes up in the top-left corner while a picture is taken. The listener
holds requests while your game is running, and it keeps the Mac awake while it runs.
