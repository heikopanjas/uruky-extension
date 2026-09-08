#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

XCODEPROJ="StartpageForSafari.xcodeproj"
SCHEME="StartpageForSafari"
BUILD_DIR=".build"

usage() {
	cat <<EOF
Usage: $0 <command> [debug|release]

Commands:
  generate                Regenerate the Xcode project from project.yml
  open                    Regenerate (if needed) and open the project in Xcode
  lint                    Validate the JSON Safari will parse
  build [debug|release]   Build the macOS app + embedded extension (default: debug)
  build-ios [debug|release]
                          Build for iOS Simulator (default: debug)
  clean                   Remove the generated project and build artifacts
EOF
}

generate() {
	xcodegen generate
}

# Mirrors the Makefile's "$(XCODEPROJ): project.yml" prerequisite: regenerate
# only when the project is missing or project.yml is newer.
ensure_project() {
	if [[ ! -d "$XCODEPROJ" || project.yml -nt "$XCODEPROJ" ]]; then
		generate
	fi
}

open_project() {
	ensure_project
	open "$XCODEPROJ"
}

lint() {
	local files=(
		Extension/Resources/manifest.json
		Extension/Resources/rules.json
		Extension/Resources/_locales/en/messages.json
	)
	for f in "${files[@]}"; do
		python3 -m json.tool "$f" >/dev/null && echo "ok   $f"
	done
}

configuration_for() {
	case "${1:-debug}" in
	debug) echo "Debug" ;;
	release) echo "Release" ;;
	*)
		echo "error: unknown configuration '$1' (expected debug or release)" >&2
		exit 1
		;;
	esac
}

build() {
	ensure_project
	local config
	config=$(configuration_for "${1:-debug}")
	xcodebuild -project "$XCODEPROJ" -scheme "$SCHEME" \
		-configuration "$config" \
		-derivedDataPath "$BUILD_DIR" \
		-destination 'platform=macOS' build
}

build_ios() {
	ensure_project
	local config
	config=$(configuration_for "${1:-debug}")
	xcodebuild -project "$XCODEPROJ" -scheme "$SCHEME" \
		-configuration "$config" \
		-derivedDataPath "$BUILD_DIR" \
		-destination 'platform=iOS Simulator,name=iPhone 16' build
}

clean() {
	rm -rf "$XCODEPROJ" "$BUILD_DIR"
}

case "${1:-}" in
generate) generate ;;
open) open_project ;;
lint) lint ;;
build) build "${2:-debug}" ;;
build-ios) build_ios "${2:-debug}" ;;
clean) clean ;;
*)
	usage
	exit 1
	;;
esac
