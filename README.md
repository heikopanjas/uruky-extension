# Startpage for Safari

A Safari web extension that routes searches to [Startpage](https://www.startpage.com),
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

Set `DEVELOPMENT_TEAM` in `project.yml` before archiving. For local development
you can leave it blank and let Xcode sign to run locally.

After building and running once, enable the extension in Safari's settings,
then set Safari's own search engine to DuckDuckGo or Ecosia and enable only
that engine in the extension's options page.

## The fundamental limitation

Safari has no API for adding a custom search engine, and has not had one in
twenty-odd years. Every extension that claims to change your Safari search
engine — Kagi's, Qwant's, xSearch — works by the same mechanism:

1. You type a query in the address bar.
2. Safari sends it to whichever engine it is configured to use.
3. The extension intercepts that navigation and rewrites it to Startpage.

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
which requires host permission for the *target* URL. `startpage.com` is in
`host_permissions` for exactly this reason — remove it and the fallback starts
silently failing to navigate.

### Regex constraints

`regexFilter` uses an RE2-style engine: **no lookahead, no backreferences in
the pattern**. That is why the "any preceding query parameters" case is written
as `(?:.*&)?` rather than a negative lookahead. The captured group is still
percent-encoded in the source URL, so it substitutes into Startpage's `query=`
without re-encoding.

`regexSubstitution` requires **Safari 17+**. Do not lower the deployment target
below that.

## Startpage specifics

Startpage encodes user preferences in an opaque `prfe` token, obtainable from
`startpage.com/do/settings`. The options page accepts it and appends it to the
redirect target, which makes preferences survive Private Browsing where the
settings cookie does not.

**This is not theoretical — it happens, and it is not fixable from extension
code.** Startpage's block page is `/sp/captcha-block`, and it carries a `bi=`
parameter naming the network category it flagged — `iCloud+Private+Relay` for
a Private Relay connection, `TELE` (the user's own ISP, Deutsche Telekom) with
Private Relay off. Same search, same browser, same extension, different
network label, same block. That rules out the redirect mechanism, referrers,
cookies, and session state entirely: this is Startpage's server-side
IP/network-reputation scoring, made against the network the request comes
from, not against how the request was constructed. A manually-typed search
into Startpage's own search box would hit the same wall.

An earlier attempt made the fallback visit the homepage before searching, on
the working theory that a missing session was the trigger — that was reverted
once the `bi=` evidence ruled it out. There is currently no mitigation
available for the actual cause: if Startpage flags the network you're on,
you'll see `/sp/captcha-block` regardless of which engine you typed your
search into or how it got redirected.

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
container app's (`com.panjas.StartpageForSafari.Extension`). Get this wrong and
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
- Icons in `Extension/Resources/images/` are generated placeholders.
