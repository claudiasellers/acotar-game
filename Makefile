# ACOTAR: The Spring Court. For the Mac (Apple silicon, macOS).
#   make update   pull the latest origin/main, fetch art (LFS), make sure Godot is here, rebuild generated content
#   make play     run the game (its output goes to .tools/play.log)
#   make clean    free disk: delete Godot's import cache and generated content
#
# Godot lives in .tools/ (git-ignored). Generated content is built by
# tools/mq/levels.sh from tools/mq/generated.conf into git-ignored folders
# (engineering rule R15) and cached in .git/levelcache, so a build the gate
# already made is copied, not rebuilt. A full terrain bake takes about 15
# minutes, only on a cache miss.

GODOT_VERSION := 4.7.2
GODOT_DIR     := .tools/godot-$(GODOT_VERSION)
GODOT         := $(GODOT_DIR)/Godot.app/Contents/MacOS/Godot
GODOT_URL     := https://github.com/godotengine/godot/releases/download/$(GODOT_VERSION)-stable/Godot_v$(GODOT_VERSION)-stable_macos.universal.zip

.PHONY: play update clean godot pull generate bake import

play: godot bake
	@test -d .godot || $(MAKE) --no-print-directory import
	@"$(GODOT)" --path . >.tools/play.log 2>&1

update: pull godot generate bake import
	@echo "Up to date. Godot $(GODOT_VERSION) in $(GODOT_DIR)."

pull:
	@before=$$(git rev-parse HEAD); \
	branch=$$(git rev-parse --abbrev-ref HEAD); \
	if [ "$$branch" != "main" ]; then echo "On '$$branch', not main: skipping the pull."; exit 0; fi; \
	git fetch --quiet origin || { echo "Pull failed: could not reach origin. Nothing was changed."; exit 1; }; \
	git merge --quiet --ff-only origin/main || { echo "Pull failed: local edits or commits are in the way of origin/main. Nothing was changed."; exit 1; }; \
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

# Without baked terrain the game bakes at launch and looks frozen for minutes,
# so play runs this too. Fast when the cache has the build.
generate: godot
	@tools/mq/levels.sh ensure

bake: generate

import: godot
	@"$(GODOT)" --headless --path . --import >/dev/null 2>&1 || true

clean:
	@rm -rf .godot; find . -type d -name _generated -prune -not -path './.git/*' -exec rm -rf {} +; \
	echo "Removed the import cache and generated content. Godot stays in .tools/ (delete it to free ~200 MB)."
