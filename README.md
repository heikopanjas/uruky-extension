# Uruky for Safari

A Safari web extension that routes searches to [Uruky](https://uruky.com),
built the same way the Kagi and Qwant extensions are, because Safari leaves no
other option. Project structure is defined in `project.yml` and generated with
[XcodeGen](https://github.com/yonaskolb/XcodeGen) — the `.xcodeproj` is not
committed.

## Getting started

```sh
brew install xcodegen
./build.sh lint          # validate the JSON Safari will parse
./build.sh open          # generate the project and open it in Xcode
```

`project.yml` sets `DEVELOPMENT_TEAM` to a real team ID already, and every
`xcodebuild` invocation in `build.sh` passes it explicitly with
`-allowProvisioningUpdates`, so builds don't depend on whichever identity
Xcode's automatic signing happens to pick locally.

### Installing for daily use, without opening Xcode

```sh
./build.sh install              # Release build -> /Applications, then launched
./build.sh install-ios           # Release build -> a paired physical device
./build.sh install-ios "iPhone"  # ...or a named one, if more than one is paired
```

After building and running once (via `install`/`install-ios` above, or by
running from Xcode), enable the extension in Safari's settings, then set
Safari's own search engine to DuckDuckGo or Ecosia and enable only that
engine in the extension's options page.

### Distributing the macOS app outside the App Store

```sh
./build.sh notarize   # -> .build/Distribution/Uruky-for-Safari-<version>.zip
```

This archives a Release build, exports it signed with the team's Developer
ID Application certificate (`exportOptions.plist`, manual signing; the
entitlements are sandbox-only, so no provisioning profiles are needed),
notarizes it, staples the ticket, verifies it with `codesign` and `spctl`,
and zips the stapled app with `ditto`. If Apple rejects the upload, the
script prints the notarization log and stops.

Notarization authenticates with the team's App Store Connect API key,
stored in the `notarytool` keychain profile `Panjas-Notarize`, which is
shared by all of the team's Developer ID projects. Override it with
`NOTARIZE_PROFILE=<profile> ./build.sh notarize`, the same variable those
projects' build scripts use. The submission is uploaded as
`Uruky-for-Safari-notarization.zip`, so it is identifiable in
`xcrun notarytool history`. On a new machine, create the profile once from
the API key (App Store Connect, Users and Access, Integrations):

```sh
xcrun notarytool store-credentials Panjas-Notarize \
  --key /path/to/AuthKey_<KEY_ID>.p8 --key-id <KEY_ID> --issuer <ISSUER_ID>
```

Notarization requires the hardened runtime on every executable,
which is why `ENABLE_HARDENED_RUNTIME` sits in `project.yml`'s base settings
rather than on the App target only: the embedded `.appex` needs it too.

## The fundamental limitation

Safari has no API for adding a custom search engine, and has not had one in
twenty-odd years. Every extension that claims to change your Safari search
engine — Kagi's, Qwant's, xSearch — works by the same mechanism:

1. You type a query in the address bar.
2. Safari sends it to whichever engine it is configured to use.
3. The extension intercepts that navigation and rewrites it to Uruky.

Two consequences follow, and neither can be engineered away:

- **The origin engine sees something.** The redirect fires before the response
  comes back, but a connection is initiated. Kagi's own App Store listing says
  the same thing.
- **Address-bar suggestions cannot be intercepted at all.** Those requests are
  made by Safari itself, outside the extension's reach. Safari will also keep
  saying "Search Google" in the address bar.

The mitigation is to point Safari at an engine you do not mind leaking to and
redirect only that one. That is why the options page defaults to encouraging a
single-engine setup rather than intercepting everything.

## How the redirect works

Two mechanisms are implemented, and only one is active at a time.

**declarativeNetRequest (default).** Redirect rules with `regexFilter` +
`regexSubstitution`, so the rewrite happens in the networking layer without
extension code seeing individual requests. `rules.json` is a static ruleset
that covers the window before the service worker has ever started;
`background.js` then installs equivalent dynamic rules built from user settings
and disables the static set.

**webNavigation + tabs.update (opt-in fallback).** Slower, with a visible flash
of the origin engine. It exists because dNR redirect has broken across Safari
releases before — there are reports of Safari 26 turning redirect rules into a
"This webpage was reloaded because a problem occurred" loop. Kagi ships the
same toggle for the same reason. Users switch to it from the options page.

Unlike the dNR path (a browser-level network redirect, no permission check on
the destination), `tabs.update()` is extension JS navigating a tab directly,
which requires host permission for the *target* URL. `uruky.com` is in
`host_permissions` for exactly this reason — remove it and the fallback starts
silently failing to navigate.

### Regex constraints

`regexFilter` uses an RE2-style engine: **no lookahead, no backreferences in
the pattern**. That is why the "any preceding query parameters" case is written
as `(?:.*&)?` rather than a negative lookahead. The captured group is still
percent-encoded in the source URL, so it substitutes into Uruky's `q=`
without re-encoding.

`regexSubstitution` requires **Safari 17+**. Do not lower the deployment target
below that.

## Uruky specifics

Uruky's private search URL carries a personal `i` token
(`uruky.com/search?q=...&i=...`), tied to the account it was issued to. The
options page accepts it and appends it to the redirect target, which makes
personalized search survive Private Browsing where a settings cookie does
not. Treat this value like a credential: it is deliberately kept out of
`rules.json`/`background.js` and stored only in `browser.storage.local`, so it
is never committed to source control.

No Uruky-specific bot-detection or block-page behavior is known yet. Update
this section if that changes.

## XcodeGen gotchas encoded in project.yml

Three things in `project.yml` look odd and are deliberate:

**Resource subdirectories use `type: folder`.** XcodeGen adds a directory in
`sources` as a group of individual file references, and Xcode's Copy Bundle
Resources phase flattens those into the bundle root — so `_locales/en/messages.json`
would arrive as `messages.json` and the extension would fail to load. Folder
references preserve structure. Do *not* apply `type: folder` to `Resources/`
itself, or everything lands one level too deep at `Resources/Resources/manifest.json`,
which fails the same way.

**Deployment targets are raw build settings.** `options.deploymentTarget` is
currently ignored for targets using `supportedDestinations` (XcodeGen issue
#1577), so `MACOSX_DEPLOYMENT_TARGET` and `IPHONEOS_DEPLOYMENT_TARGET` are set
directly. Check whether that has been fixed in your XcodeGen version and switch
to the clean syntax if so.

**Entitlements paths are SDK-conditional.** `com.apple.security.app-sandbox` is
macOS-only and does not belong in an iOS appex, but a multiplatform target has
one entitlements setting. `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]` and friends
split it.

Also note the extension's bundle identifier must be a prefix-extension of the
container app's (`com.panjas.UrukyForSafari.Extension`). Get this wrong and
Safari silently refuses to load the extension with no useful error.

## Adding a search engine

Three places, and they must stay consistent:

1. `Extension/Resources/manifest.json` — add the host to `host_permissions`.
   dNR rules only apply to hosts you hold permission for.
2. `Extension/Resources/rules.json` — add a static redirect rule.
3. `Extension/Resources/background.js` — add an entry to `ENGINES` with both
   the `regex` (for dNR) and `host`/`path`/`param` (for the fallback path).
   Add the display label to `ENGINE_LABELS` in `options.js`.

Google ccTLDs are enumerated individually in `host_permissions`; the shipped
list covers the common European ones. Add yours if searches from
`google.<something-else>` are not being redirected.

## Known refinements not yet done

- The Google vertical exception only matches `tbm=`. Google's newer `udm=`
  parameter is not excluded, because `udm=14` is plain web search and RE2 has
  no negative lookahead to express "udm but not 14". Two separate allow rules
  would do it.
- No native messaging. `SafariWebExtensionHandler` is a stub that exists only
  because Info.plist requires a principal class.

## Icon

One design serves both the container app and the Safari extension: an
eggshell keycap from an old IBM keyboard, seen from above and slightly from
the bottom left, with a lowercase "u" in Go Mono Bold (a monospaced slab
serif) centered on the cap. In dark mode the cap turns dark gray with an
eggshell legend.

**App icon.** `App/AppIcon.icon` is an Icon Composer document (Xcode 26+).
The background fill (an automatic gradient) is the keycap's base color;
three layer SVGs in `Assets/`, all drawn on the full 1024×1024 canvas, sit
on top: `walls.svg` (four translucent black/white facets from the canvas
edges to the top surface, lit from the upper left: back lightest, front
darkest; being overlays, they work unchanged in every appearance),
`top.svg` (the dished top surface, a rounded rect with its own gradient,
offset up and right so the front and left walls are widest, which sets the
viewing angle) and `legend.svg` (the "u", scaled with the top surface). The legend is the glyph outline as a path, extracted from Go Mono Bold
with CoreText (`CTFontCreatePathForGlyph`), so rendering doesn't depend on
the font being installed. Go fonts are BSD-licensed. `icon.json` overrides
colors for the dark and tinted appearances; clear is derived by the system.
XcodeGen adds the `.icon` as a resource of the App target and
`ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` in `project.yml` points at it.
There is no `AppIcon.appiconset`: at build time `actool` compiles the
`.icon` into the Liquid Glass icon for macOS 26+ / iOS 26+ *and* the flat
fallbacks for older deployment targets, a squircle-masked, shadowed
`AppIcon.icns` for macOS 14/15 and opaque PNGs for iOS 17–25. Edit the SVGs
directly or open the `.icon` in Icon Composer (Xcode → Open Developer Tool).

Two Icon Composer gotchas:

- Use filled shapes only. A `stroke` with `fill="none"` renders as a solid
  fill (an earlier draft's stroked ring came out as a disk).
- A layer's SVG colors only apply where `icon.json` sets no
  `fill-specializations` for that appearance. Tinted (and clear) map
  luminance to the tint, so a light cap top with a dark legend comes out as a
  bright tile with the legend invisible; both layers need explicit tinted
  fills: dark cap top, white legend.

**Extension icons.** `Extension/Resources/images/icon-*.png` (referenced
from `manifest.json`) are rendered from the app icon:

```sh
./design/generate-icons.sh
```

It exports the macOS tile with Icon Composer's bundled `ictool`, insets it
into Apple's macOS template (~824×824 tile centered in 1024×1024) with a soft
drop shadow so the light tile stays visible on white backgrounds, and resizes
to 48–512 px. Requires Xcode 26+ and `magick` (ImageMagick).
