default:
	@just --list

dev:
	swift build
	swift run UVManager

preview-empty-tools:
	swift build
	fixture_dir="$PWD/.build/fixtures/uv-empty-tools"; \
	rm -rf "$fixture_dir"; \
	mkdir -p "$fixture_dir/tools" "$fixture_dir/bin" "$fixture_dir/cache"; \
	osascript -e 'tell application id "com.anthonywu.uvmanager" to quit' >/dev/null 2>&1 || true; \
	pkill -f "$PWD/.build/.*/debug/UVManager" >/dev/null 2>&1 || true; \
	launchctl setenv UV_TOOL_DIR "$fixture_dir/tools"; \
	launchctl setenv UV_TOOL_BIN_DIR "$fixture_dir/bin"; \
	launchctl setenv UV_CACHE_DIR "$fixture_dir/cache"; \
	open -n "$PWD/.build/debug/UVManager"; \
	sleep 1; \
	launchctl unsetenv UV_TOOL_DIR; \
	launchctl unsetenv UV_TOOL_BIN_DIR; \
	launchctl unsetenv UV_CACHE_DIR; \
	echo "Launched UV Manager with empty uv tool fixture at $fixture_dir"

release:
	./build_release.sh

format:
	swift-format format --in-place --recursive UVManager/

lint:
	swiftlint lint --fix UVManager/

release-draft version="0.5.0" summary="UV system info, cache maintenance, and sidebar navigation" target="":
	release_version='{{version}}'; \
	release_version="${release_version#version=}"; \
	release_summary='{{summary}}'; \
	release_summary="${release_summary#summary=}"; \
	release_target='{{target}}'; \
	release_target="${release_target#target=}"; \
	if [ -z "${release_target}" ]; then release_target="$(git branch --show-current)"; fi; \
	if [ -z "${release_target}" ]; then release_target="$(git rev-parse HEAD)"; fi; \
	dmg_file="release/UV Manager-${release_version}.dmg"; \
	notes_file="release/notes/v${release_version}.md"; \
	test -f "${dmg_file}" || { echo "Missing DMG: ${dmg_file}" >&2; exit 1; }; \
	test -f "${notes_file}" || { echo "Missing release notes: ${notes_file}" >&2; exit 1; }; \
	gh release create "v${release_version}" \
		"${dmg_file}#UV Manager-${release_version}.dmg" \
		--repo anthonywu/swift-uv-manager \
		--target "${release_target}" \
		--title "v${release_version} – ${release_summary}" \
		--notes-file "${notes_file}" \
		--draft
