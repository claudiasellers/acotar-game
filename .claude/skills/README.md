# Vendored Godot skills

Wherever these skills disagree with CLAUDE.md or plans/engineering-rules.md, ours win (for example: the project keeps its EventBus and autoloads despite the pack's "no signal bus, no UI manager" advice).

Copied from https://github.com/MindsMaster/godot-claude-code-skills at commit
e78c7df014e56ac766a15aff46bd689ff40b8cc8 (2026-11-19), MIT licence (GODOT_SKILLS_LICENSE).
Every API name and GDScript example in it is checked against Godot 4.7.2 in its CI.

Left out because this project is 3D GDScript only: godot-2d, godot-csharp, godot-multiplayer.
The files are unchanged otherwise. The skill text is in Chinese; code and identifiers are English.

Project rules win over these skills where they differ:
- Godot is already at /root/tools/godot. Never download Godot (ignore the curl snippet in
  godot-headless-testing/references/ci-and-frameworks.md).
- Testing follows R10 (only your system's GUT files, test once on the final version).
- project.godot, autoloads, the input map and core/ stay owned by the story/core lane (R14).

To update: re-copy the same folders from a newer commit and change the commit above.
