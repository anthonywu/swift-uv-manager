default:
	@just --list

dev:
	swift build
	swift run UVManager

release:
	./build_release.sh

release-draft version="0.4.0":
	gh release create "v{{version}}" \
		"release/UV Manager-{{version}}.dmg#UV Manager-{{version}}.dmg" \
		--repo anthonywu/swift-uv-manager \
		--target "$(git rev-parse HEAD)" \
		--title "UV Manager v{{version}}" \
		--notes-file "release/notes/v{{version}}.md" \
		--draft
