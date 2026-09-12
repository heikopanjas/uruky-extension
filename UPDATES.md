# Recent Updates & Decisions

This file is the append-only log of project decisions and notable changes, maintained by coding agents following the `recent-updates` skill. Everything below the marker line is user-owned history: slopctl never overwrites it during init or merge.

<!-- {changelog} -->

### 2026-09-12 (v1.3.1, add install/install-ios build.sh commands)

- added `./build.sh install` (Release build, copied to `/Applications`,
  launched) and `./build.sh install-ios [device name]` (Release build
  installed and launched on a paired physical device via `xcrun devicectl`),
  so the app can be built and deployed for personal daily use entirely from
  the command line, without opening Xcode
- pinned `DEVELOPMENT_TEAM=8J2G689FCZ` and added `-allowProvisioningUpdates`
  on every `xcodebuild` invocation in `build.sh` (`build`, `build-ios`,
  `install`, `install-ios`), after finding the local Debug build was signing
  with a different local identity than `project.yml`'s declared team even
  though the resulting `TeamIdentifier` matched -- making the intended team
  explicit at the command line removes any ambiguity
- fixed `build-ios`'s hardcoded `iPhone 16` simulator destination, which no
  longer exists in the current Xcode's simulator list and made the command
  fail outright; switched to the generic `platform=iOS Simulator` destination,
  which builds without depending on any specific runtime being installed
- `find_ios_device` (new helper in `build.sh`) resolves a paired device by
  name via `xcrun devicectl list devices --json-output`, using
  `hardwareProperties.udid` for the `xcodebuild -destination id=...` value
  (not `devicectl`'s own `identifier`, which is a different ID space) and the
  top-level `identifier` for the `devicectl device install/launch` calls
- verified end-to-end: `install` produced a correctly-signed
  (`TeamIdentifier=8J2G689FCZ`) app in `/Applications`; `install-ios` built,
  installed, and launched on a paired device
- rationale: user asked for a command-line release path for both platforms
  for their own daily use, and confirmed `8J2G689FCZ` as the correct team ID
- version bump: 1.3.0 to 1.3.1 (PATCH - build tooling/deployment procedure
  only, no change to the extension's own behavior)

### 2026-09-12 (v1.3.0, switch destination engine to Uruky)

- redirect destination changed from Startpage to Uruky
  (`https://uruky.com/search?q=...`) across `rules.json`, `background.js`, and
  `manifest.json`'s `host_permissions`
- renamed the `prfe` setting to `i` (background.js, options.js, options.html)
  to match Uruky's private-search query parameter; kept it a
  `browser.storage.local`-only runtime setting, never written into
  `rules.json`/`background.js`, so the user's personal `i` token never lands
  in git history
- rebranded user-visible strings project-wide: `messages.json`
  (extensionName/extensionDescription), `options.html`, `App/ContentView.swift`,
  `App/SetupInstructions.swift`, `project.yml`'s `PRODUCT_NAME`/
  `CFBundleDisplayName` settings, and `Extension/Info.plist`; renamed
  `App/StartpageApp.swift` to `App/UrukyApp.swift` (struct `StartpageApp` to
  `UrukyApp`)
- rewrote README.md's "Startpage specifics" section as "Uruky specifics":
  documented the `i` token and noted no Uruky-specific bot-detection behavior
  is known yet, unlike the previous Startpage integration
- kept `PRODUCT_BUNDLE_IDENTIFIER` (`com.panjas.StartpageForSafari[.Extension]`),
  the `project.yml` target/scheme names, and the generated `.xcodeproj`
  filename unchanged, per user's explicit choice to scope the rebrand to
  user-visible strings only
- rationale: user asked to switch to Uruky as "more willing to cooperate" than
  Startpage; flagged the private `i` token as credential-like before writing
  any code, and the user confirmed keeping it out of committed files and
  doing a full display-name rebrand
- version bump: 1.2.4 to 1.3.0 (MINOR - destination engine changed and a
  settings key renamed, but the extension's structure and public behavior
  otherwise stayed backward compatible)

### 2026-09-08 (v1.2.4, connect GitHub remote)

- user created the remote repo at
  https://github.com/heikopanjas/startpage-extension; added it as `origin`
  (SSH: `git@github.com:heikopanjas/startpage-extension.git`, matching
  `gh`'s configured protocol) and pushed `main`
- GitHub's repo creation added an MIT `LICENSE`; rebased the local history
  onto it before pushing, and updated AGENTS.md's tech stack section (License:
  MIT, Version Control: remote URL) to match
- rationale: keep AGENTS.md's stated project state accurate now that the repo
  has a remote and a chosen license
- version bump: 1.2.3 to 1.2.4 (PATCH - repo/license setup, no source change)

### 2026-09-08 (v1.2.3, revert the homepage warm-up)

- reverted `background.js`'s fallback to a single `tabs.update()` straight to
  the search URL, removing `pendingFallbackSearch`, the `onCompleted`
  listener, and the `tabs.onRemoved` cleanup added in v1.2.0
- rationale: the warm-up was written on the theory that a missing session
  triggered Startpage's block; the `bi=` evidence in v1.2.2 confirmed the
  real cause is network/IP reputation, which the warm-up can't address, so it
  was only adding a visible extra page load with no benefit. User asked to
  revert now that it's confirmed dead weight
- updated README.md to describe the fallback as it now stands and note the
  warm-up attempt in past tense rather than as current behavior
- verified: `node --check background.js`, `./build.sh lint`, and
  `./build.sh build` all pass after the revert
- version bump: 1.2.2 to 1.2.3 (PATCH - revert, net code removal, no new
  functionality)

### 2026-09-08 (v1.2.2, root cause found: Startpage blocks by network reputation)

- user shared the actual `/sp/captcha-block` URL Startpage redirects to, which
  carries a `bi=` parameter naming the flagged network category: first
  `iCloud+Private+Relay`, then `TELE` (their own ISP, Deutsche Telekom) after
  disabling Private Relay and retesting — same search, same block, different
  network label
- this rules out everything extension-side: redirect mechanism (dNR vs
  fallback), referrers, cookies, and session state were all already
  eliminated as suspects; the `bi=` evidence confirms Startpage's block is
  server-side IP/network-reputation scoring against the network the request
  originates from, not anything about how the request was built or submitted
- rewrote README.md's "Startpage specifics" section to state the confirmed
  cause plainly instead of listing it as an open, chaseable problem; noted
  the fallback's homepage warm-up (added in v1.2.0 on a since-ruled-out
  theory) is harmless but does not address the actual cause
- rationale: keep AGENTS.md/README.md honest about what is and isn't fixable
  by this codebase, now that the actual mechanism is known rather than
  inferred
- version bump: 1.2.1 to 1.2.2 (PATCH - documentation update only, no code
  change)

### 2026-09-08 (v1.2.1, confirmed: homepage warm-up does not fix the block)

- user tested the v1.2.0 homepage warm-up mitigation: the homepage loads
  briefly, then the block still fires immediately after navigating to the
  search — so a missing session/cookies was not the (or not the only) trigger
- decision: stop chasing this with further guesses (a delay before the search
  navigation was considered and explicitly declined by the user). The
  homepage warm-up code stays as-is since it's not worse than searching cold,
  but is not claimed to fix anything
- updated README.md's "Startpage specifics" section to state plainly that
  this is confirmed unsolved, not a bug to keep debugging — Startpage's
  detection signal isn't observable from outside their service
- rationale: further mitigation attempts would be guessing at an opaque
  external system with no way to verify hypotheses locally; better to be
  honest about the limitation than add more unproven complexity to
  background.js
- version bump: 1.2.0 to 1.2.1 (PATCH - documentation update only, no code
  change)

### 2026-09-08 (v1.2.0, fallback warms up a Startpage session before searching)

- confirmed with the user: direct navigation to startpage.com works, but
  every extension-triggered search (dNR and the just-fixed fallback both)
  gets a hard refusal page from Startpage's bot detection — this rules out an
  IP-level block and points at the request pattern itself: jumping straight
  to `/sp/search?query=…` cold, with no prior session, on every search
- changed the fallback in `background.js`: `onBeforeNavigate` now navigates
  the tab to `https://www.startpage.com/` first (via a new
  `pendingFallbackSearch` map keyed by tabId) and only navigates to the
  actual search URL once `onNavigation.onCompleted` fires for that homepage
  load; added `tabs.onRemoved` cleanup so a closed tab can't leave a stale
  pending entry
- rationale: this is the best mitigation available from extension code —
  establishing cookies/session before the search request, closer to what a
  real visit looks like — but it is NOT confirmed to fix the block, since dNR
  has no equivalent two-step option and Startpage's exact detection signal is
  unknown; documented as unconfirmed in README.md rather than claimed as fixed
- verified: `./build.sh lint` and `node --check background.js` pass, and
  `./build.sh build` succeeds; actual redirect behavior needs testing by the
  user in Safari
- version bump: 1.1.4 to 1.2.0 (MINOR - new fallback navigation behavior,
  backward-compatible: default dNR path and existing settings are unchanged)

### 2026-09-08 (v1.1.4, fix broken webNavigation fallback toggle)

- added `*://*.startpage.com/*` to `host_permissions` in `manifest.json`
- rationale: user reported the options page's "Use the compatibility redirect"
  toggle did nothing. Root cause: the fallback path calls
  `browser.tabs.update(tabId, { url })` directly in `background.js` to
  navigate to Startpage, and that call requires host permission for the
  *destination* URL — which `startpage.com` never had. The default dNR path
  worked regardless because a browser-level network redirect isn't gated by
  extension host permissions the same way. Documented the distinction in
  README.md so a future change to `STARTPAGE_ENDPOINT` doesn't reintroduce this
  - after installing this build, Safari will likely need the extension
  re-approved in Settings > Extensions since `host_permissions` changed
- version bump: 1.1.3 to 1.1.4 (PATCH - bug fix, no new functionality)

### 2026-09-08 (v1.1.3, fix local debug build: signing team and Info.plist)

- set `DEVELOPMENT_TEAM: "8J2G689FCZ"` in `project.yml`, sourced from the
  user's `../senor-particle` project (`exportOptions.plist` and
  `senor-particle.xcodeproj/project.pbxproj` both confirm the ID) — command-line
  `xcodebuild` (unlike the Xcode GUI) fails without an explicit team even for
  local debug builds
- added `GENERATE_INFOPLIST_FILE: YES` to the `StartpageForSafari` app target;
  it had no `info:` block and no checked-in Info.plist, so codesigning failed
  with "Cannot code sign because the target does not have an Info.plist file"
- fixed `Extension`'s `info.properties` in `project.yml`: XcodeGen was writing
  a physical `Extension/Info.plist` with `CFBundleShortVersionString`/
  `CFBundleVersion` hardcoded to `1.0`/`1` rather than tracking
  `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`, so the appex's version drifted
  from the container app's on every version bump (Xcode warned "must match
  that of its containing parent app") — now set to `$(MARKETING_VERSION)` /
  `$(CURRENT_PROJECT_VERSION)`
- rationale: user asked to run a debug build; these were the two blockers hit
  along the way, both pre-existing project.yml gaps unrelated to prior changes
- verified: `./build.sh clean && ./build.sh build` succeeds cleanly with no
  warnings, embedding and signing the extension into the app
- version bump: 1.1.2 to 1.1.3 (PATCH - build config fixes, no source change)

### 2026-09-08 (v1.1.2, build output moves to .build)

- `build.sh`'s `build` and `build-ios` now pass `-derivedDataPath .build` to
  `xcodebuild`, so build products actually land in a local `.build/` dir
  instead of the default `~/Library/Developer/Xcode/DerivedData`
- `clean` now removes `.build` instead of the (never-actually-produced) `build`
  and `DerivedData` directories
- `.gitignore` updated: `build/` and `DerivedData/` replaced with `.build/`
- rationale: user asked to standardize the build output directory as `.build`
  (the Swift Package Manager convention); the old `build`/`DerivedData` entries
  were vestigial since xcodebuild was never told to use them
- verified: `./build.sh build` populates `.build/Products/Debug/...` and
  `git status` doesn't list it; the build itself fails on code signing
  (no `DEVELOPMENT_TEAM` set), which is pre-existing and unrelated
- version bump: 1.1.1 to 1.1.2 (PATCH - build tooling change, no source change)

### 2026-09-08 (v1.1.1, add .gitignore)

- added `.gitignore` covering `StartpageForSafari.xcodeproj/` (XcodeGen output,
  never committed per README.md), `build/`, `DerivedData/`, `xcuserdata/`, and
  `*.xcuserstate`
- `.DS_Store` is already covered by the user's global `~/.config/git/ignore`,
  so it's left out of this file to avoid duplicating that rule
- rationale: the repo was just initialized with no `.gitignore`, so a local
  `./build.sh generate` or build would leave generated/user-specific files
  showing as untracked
- verified: `./build.sh generate` followed by `git status --short` no longer
  lists the generated `.xcodeproj`
- version bump: 1.1.0 to 1.1.1 (PATCH - repo hygiene, no functional change)

### 2026-09-08 (v1.1.0, replace Makefile with build.sh)

- removed `Makefile`; added `build.sh` covering the same `generate`/`open`/
  `lint`/`build`/`build-ios`/`clean` operations, plus a new `[debug|release]`
  configuration argument on `build` and `build-ios` (via `xcodebuild
  -configuration`) that the Makefile didn't expose
- updated all `make <target>` references in README.md and AGENTS.md to
  `./build.sh <target>`
- rationale: user asked to replace the Makefile with a shell script and wanted
  explicit release-vs-debug build support for the extension
- version bump: 1.0.2 to 1.1.0 (MINOR - new release/debug build capability,
  backward-compatible command surface)

### 2026-09-08 (v1.0.2, git repo initialized)

- updated AGENTS.md's Version Control note: git is now initialized on `main`
  (no commits yet), replacing the earlier "not yet initialized" note
- rationale: keep AGENTS.md's stated project state accurate after the user
  initialized the repo
- version bump: 1.0.1 to 1.0.2 (PATCH - documentation-only update)

### 2026-09-08 (v1.0.1, fill in AGENTS.md project details)

- replaced AGENTS.md's generic template placeholders (mission statement, tech
  stack, dev guidelines, testing, documentation, code review) with the actual
  project details, sourced from README.md, project.yml, and the Makefile
- rationale: AGENTS.md was still the unfilled scaffold from initial setup, so
  agents had no reliable project-specific instructions to work from
- noted that this workspace has no `.git` directory yet, and that no LICENSE
  file exists
- version bump: 1.0 to 1.0.1 (PATCH - documentation-only update)

### 2025-10-05 (v0.1.0, initial setup)

- initial AGENTS.md setup
- established core coding standards and conventions
- defined repository structure and governance principles
