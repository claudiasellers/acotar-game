# ACOTAR: The Spring Court. For the Mac (Apple silicon, macOS).
#   make update   pull the latest origin/main, make sure Godot is here, rebuild generated content
#   make play     run the game (its output goes to .tools/play.log)
#   make setup    install the git pre-push hook (checks lead/ready-* pushes for missing .uid files)
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

.PHONY: setup play update clean godot pull generate bake import

setup:
	@tools/mq/install_hooks.sh

play: godot bake import
	@echo "Starting the game. This terminal stays busy until you quit the game. Log: .tools/play.log"
	@"$(GODOT)" --path . >.tools/play.log 2>&1; rc=$$?; \
	if [ $$rc -ne 0 ]; then echo "The game stopped with exit code $$rc. Log: .tools/play.log"; fi; exit $$rc

update: pull godot generate bake import
	@echo "Up to date. Godot $(GODOT_VERSION) in $(GODOT_DIR)."

pull:
	@before=$$(git rev-parse HEAD); \
	branch=$$(git rev-parse --abbrev-ref HEAD); \
	if [ "$$branch" != "main" ]; then echo "On '$$branch', not main: skipping the pull."; exit 0; fi; \
	git fetch --quiet origin || { echo "Pull failed: could not reach origin. Nothing was changed."; exit 1; }; \
	git merge --quiet --ff-only origin/main || { echo "Pull failed: local edits or commits are in the way of origin/main. Nothing was changed."; exit 1; }; \
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
	@tools/mq/class_cache.sh stale >/dev/null || $(MAKE) --no-print-directory import
	@tools/mq/levels.sh ensure

bake: generate

# Incremental, so cheap when little changed. Every class_name must be in
# Godot's class cache afterwards, or scripts naming it fail to parse (F42, F47).
import: godot
	@mkdir -p .tools; "$(GODOT)" --headless --path . --import >.tools/import.log 2>&1; rc=$$?; \
	if [ $$rc -ne 0 ]; then echo "Godot's import failed (exit $$rc). Log: .tools/import.log"; exit $$rc; fi; \
	if ! missing=$$(tools/mq/class_cache.sh stale); then \
		echo "The import finished but Godot's class cache still lacks:"; echo "$$missing" | head -10; \
		echo "Log: .tools/import.log"; exit 1; fi

clean:
	@rm -rf .godot; find . -type d -name _generated -prune -not -path './.git/*' -exec rm -rf {} +; \
	echo "Removed the import cache and generated content. Godot stays in .tools/ (delete it to free ~200 MB)."
