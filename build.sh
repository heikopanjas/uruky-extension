#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

XCODEPROJ="UrukyForSafari.xcodeproj"
SCHEME="UrukyForSafari"
BUILD_DIR=".build"
DEVELOPMENT_TEAM="8J2G689FCZ"
APP_NAME="Uruky for Safari"
APP_BUNDLE_ID="com.panjas.UrukyForSafari"
INSTALLED_APP="/Applications/${APP_NAME}.app"
DIST_DIR="$BUILD_DIR/Distribution"
# notarytool keychain profile holding the App Store Connect API key; create it
# once with `xcrun notarytool store-credentials` (see README.md)
NOTARIZE_PROFILE="${NOTARIZE_PROFILE:-Panjas-Notarize}"

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
  install                 Build a Release macOS app, install it to /Applications, and open it
  install-ios [device name]
                          Build a Release app for a paired physical iOS/iPadOS
                          device and install it. Omit the device name when
                          exactly one device is paired.
  notarize                Archive a Developer ID signed macOS app, notarize and
                          staple it, and zip it for distribution into
                          $DIST_DIR (keychain profile: \$NOTARIZE_PROFILE,
                          default Panjas-Notarize)
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
		-destination 'platform=macOS' \
		-allowProvisioningUpdates \
		DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" build
}

build_ios() {
	ensure_project
	local config
	config=$(configuration_for "${1:-debug}")
	# Generic destination: builds against the iOS Simulator SDK without
	# requiring a specific runtime/device pair to exist, since the installed
	# simulator lineup changes with every Xcode version.
	xcodebuild -project "$XCODEPROJ" -scheme "$SCHEME" \
		-configuration "$config" \
		-derivedDataPath "$BUILD_DIR" \
		-destination 'generic/platform=iOS Simulator' \
		-allowProvisioningUpdates \
		DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" build
}

# Locates a paired physical iOS/iPadOS device by name (or the only one paired,
# if the name is omitted). Prints "<xcodebuild-udid>\t<devicectl-identifier>\t<name>"
# on success. `devicectl`'s own identifier does not match the udid xcodebuild
# expects in `-destination id=...` -- hardwareProperties.udid is the one that does.
find_ios_device() {
	local wanted="${1:-}"
	local list_json
	list_json=$(mktemp)
	trap 'rm -f "$list_json"' RETURN

	xcrun devicectl list devices --json-output "$list_json" >/dev/null

	python3 - "$list_json" "$wanted" <<'PY'
import json
import sys

path, wanted = sys.argv[1], sys.argv[2]
devices = json.load(open(path))["result"]["devices"]
paired = [
    d for d in devices
    if d["connectionProperties"]["pairingState"] == "paired"
    and d["hardwareProperties"]["reality"] == "physical"
]

if wanted:
    matches = [d for d in paired if d["deviceProperties"]["name"].lower() == wanted.lower()]
else:
    matches = paired

if len(matches) == 1:
    d = matches[0]
    print(f"{d['hardwareProperties']['udid']}\t{d['identifier']}\t{d['deviceProperties']['name']}")
elif not paired:
    sys.exit("error: no paired iOS/iPadOS devices found -- pair one in Xcode first")
elif wanted:
    sys.exit(f"error: no paired device named '{wanted}' (available: "
              f"{', '.join(d['deviceProperties']['name'] for d in paired)})")
else:
    sys.exit("error: multiple paired devices, specify one: "
              f"{', '.join(d['deviceProperties']['name'] for d in paired)}")
PY
}

install() {
	ensure_project
	local config
	config=$(configuration_for "release")
	xcodebuild -project "$XCODEPROJ" -scheme "$SCHEME" \
		-configuration "$config" \
		-derivedDataPath "$BUILD_DIR" \
		-destination 'platform=macOS' \
		-allowProvisioningUpdates \
		DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" build

	local built_app="$BUILD_DIR/Products/$config/${APP_NAME}.app"
	[[ -d "$built_app" ]] || {
		echo "error: build did not produce $built_app" >&2
		exit 1
	}

	rm -rf "$INSTALLED_APP"
	cp -R "$built_app" "$INSTALLED_APP"
	open "$INSTALLED_APP"
}

install_ios() {
	ensure_project
	local device
	device=$(find_ios_device "${1:-}") || {
		echo "$device" >&2
		exit 1
	}
	local xcode_udid devicectl_id device_name
	IFS=$'\t' read -r xcode_udid devicectl_id device_name <<<"$device"
	echo "Installing to $device_name..."

	local config="Release"
	xcodebuild -project "$XCODEPROJ" -scheme "$SCHEME" \
		-configuration "$config" \
		-derivedDataPath "$BUILD_DIR" \
		-destination "id=$xcode_udid" \
		-allowProvisioningUpdates \
		DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" build

	local built_app="$BUILD_DIR/Products/${config}-iphoneos/${APP_NAME}.app"
	[[ -d "$built_app" ]] || {
		echo "error: build did not produce $built_app" >&2
		exit 1
	}

	xcrun devicectl device install app --device "$devicectl_id" "$built_app"
	xcrun devicectl device process launch --device "$devicectl_id" "$APP_BUNDLE_ID"
}

notarize() {
	ensure_project
	local archive="$DIST_DIR/${APP_NAME}.xcarchive"
	local export_dir="$DIST_DIR/Export"
	local app="$export_dir/${APP_NAME}.app"
	local submission="$DIST_DIR/${APP_NAME// /-}-notarization.zip"
	local result="$DIST_DIR/notarization.json"
	rm -rf "$DIST_DIR"
	mkdir -p "$DIST_DIR"

	xcodebuild archive -project "$XCODEPROJ" -scheme "$SCHEME" \
		-configuration Release \
		-derivedDataPath "$BUILD_DIR" \
		-destination 'generic/platform=macOS' \
		-archivePath "$archive" \
		-allowProvisioningUpdates \
		DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"

	# Re-signs the app and the embedded extension with the Developer ID
	# Application certificate (exportOptions.plist).
	xcodebuild -exportArchive \
		-archivePath "$archive" \
		-exportPath "$export_dir" \
		-exportOptionsPlist exportOptions.plist

	ditto -c -k --keepParent "$app" "$submission"
	# Judge the outcome by the reported status, not the exit code, so a
	# rejection still prints Apple's log of what failed.
	xcrun notarytool submit "$submission" --keychain-profile "$NOTARIZE_PROFILE" \
		--wait --output-format json >"$result" || true
	local id status
	read -r id status < <(python3 -c 'import json, sys
r = json.load(open(sys.argv[1]))
print(r.get("id", "-"), r.get("status", "-"))' "$result" 2>/dev/null || echo "- -")
	if [[ "$status" != "Accepted" ]]; then
		echo "error: notarization failed (status: $status)" >&2
		cat "$result" >&2
		[[ "$id" == "-" ]] || xcrun notarytool log "$id" --keychain-profile "$NOTARIZE_PROFILE" >&2
		exit 1
	fi

	xcrun stapler staple "$app"
	codesign --verify --deep --strict --verbose=2 "$app"
	spctl --assess --type execute --verbose=2 "$app"

	local version
	version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app/Contents/Info.plist")
	local zip="$DIST_DIR/${APP_NAME// /-}-${version}.zip"
	ditto -c -k --keepParent "$app" "$zip"
	rm -f "$submission" "$result"
	echo "Distributable: $zip"
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
install) install ;;
install-ios) install_ios "${2:-}" ;;
notarize) notarize ;;
clean) clean ;;
*)
	usage
	exit 1
	;;
esac
