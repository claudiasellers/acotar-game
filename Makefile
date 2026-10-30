# ACOTAR: The Spring Court. For the Mac (Apple silicon, macOS).
#   make update   pull the latest main, fetch art (LFS), make sure Godot is here, rebuild generated content
#   make play     run the game (its output goes to .tools/play.log)
#   make clean    free disk: delete Godot's import cache and generated content
#
# Godot lives in .tools/ (git-ignored). Generators are tools/generators/*.gd;
# they write into _generated/ folders (git-ignored, engineering rule R15).
# Terrain is baked to world/shared/terrain/data/ (git-ignored) only when the
# height or terrain scripts change: a full bake takes about 15 minutes.

GODOT_VERSION := 4.7.2
GODOT_DIR     := .tools/godot-$(GODOT_VERSION)
GODOT         := $(GODOT_DIR)/Godot.app/Contents/MacOS/Godot
GODOT_URL     := https://github.com/godotengine/godot/releases/download/$(GODOT_VERSION)-stable/Godot_v$(GODOT_VERSION)-stable_macos.universal.zip
TERRAIN_DIR   := world/shared/terrain/data
TERRAIN_STAMP := .tools/terrain-baked.stamp

.PHONY: play update clean godot pull generate bake import

play: godot bake
	@test -d .godot || $(MAKE) --no-print-directory import
	@"$(GODOT)" --path . >.tools/play.log 2>&1

update: pull godot generate bake import
	@echo "Up to date. Godot $(GODOT_VERSION) in $(GODOT_DIR)."

pull:
	@before=$$(git rev-parse HEAD); \
	branch=$$(git rev-parse --abbrev-ref HEAD); \
	if [ "$$branch" != "HEAD" ]; then echo "On branch '$$branch', not the detached play folder: skipping the pull."; exit 0; fi; \
	git fetch --quiet origin main && git checkout --quiet --detach origin/main || { echo "Pull failed (local changes?). Nothing was changed."; exit 1; }; \
	if command -v git-lfs >/dev/null 2>&1; then git lfs pull >/dev/null; else echo "git-lfs is missing (brew install git-lfs): art files may be pointers."; fi; \
	after=$$(git rev-parse HEAD); \
	if [ "$$before" = "$$after" ]; then echo "No new changes."; \
	else echo "New since last update: $$(git rev-list --count $$before..$$after) commits"; \
	git log --format='  - %s' $$before..$$after | head -15; fi

# Downloads Godot only if it is missing or reports a different version.
godot:
	@if "$(GODOT)" --version 2>/dev/null | grep -q '^$(GODOT_VERSION)\.stable'; then exit 0; fi; \
	echo "Fetching Godot $(GODOT_VERSION) for macOS..."; \
	rm -rf "$(GODOT_DIR)" && mkdir -p "$(GODOT_DIR)" && \
	curl -fsSL -o "$(GODOT_DIR)/godot.zip" "$(GODOT_URL)" && \
	unzip -q "$(GODOT_DIR)/godot.zip" -d "$(GODOT_DIR)" && rm "$(GODOT_DIR)/godot.zip" && \
	xattr -dr com.apple.quarantine "$(GODOT_DIR)/Godot.app" 2>/dev/null; \
	"$(GODOT)" --version | grep -q '^$(GODOT_VERSION)\.stable' || { echo "Godot download failed."; exit 1; }; \
	echo "Godot $(GODOT_VERSION) ready."

generate: godot
	@n=0; for g in tools/generators/*.gd; do \
		[ -f "$$g" ] || continue; n=$$((n + 1)); \
		"$(GODOT)" --headless --path . -s "$$g" >/dev/null 2>&1 || { echo "Generator failed: $$g"; exit 1; }; \
	done; \
	[ "$$n" = "0" ] || echo "Regenerated content ($$n generators)."

# Without baked data the game bakes at launch and looks frozen for minutes.
bake: godot
	@stale=$$(find world \( -name '*height*.gd' -o -name '*terrain*.gd' -o -name 'world_map.gd' \) -newer "$(TERRAIN_STAMP)" 2>/dev/null | head -1); \
	if [ -f "$(TERRAIN_STAMP)" ] && [ -z "$$stale" ] && [ -n "$$(ls -A "$(TERRAIN_DIR)" 2>/dev/null)" ]; then exit 0; fi; \
	echo "Baking terrain (about 15 minutes, only when the terrain changes)..."; \
	"$(GODOT)" --headless --path . -s world/shared/terrain/bake_terrain.gd >/dev/null 2>&1 || { echo "Terrain bake failed."; exit 1; }; \
	touch "$(TERRAIN_STAMP)"; echo "Terrain baked."

import: godot
	@"$(GODOT)" --headless --path . --import >/dev/null 2>&1 || true

clean:
	@rm -rf .godot; find . -type d -name _generated -prune -not -path './.git/*' -exec rm -rf {} +; \
	echo "Removed the import cache and generated content. Godot stays in .tools/ (delete it to free ~200 MB)."
