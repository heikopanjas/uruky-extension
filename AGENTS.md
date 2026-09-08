# Project Instructions for AI Coding Agents

**Last updated:** 2026-09-08

<!-- {preamble} -->

# ⚠️ Before You Start

Run `/init-session` at the beginning of each new session, OR read this entire file before proceeding.

**DO NOT** make code changes or commits until you have done one of the above.

<!-- {mission} -->

## Mission Statement

Startpage for Safari is a Safari Web Extension (macOS + iOS) that rewrites searches
made through Safari's configured search engine so they go to Startpage.com instead.
Safari has no API for adding a custom search engine, so the extension intercepts and
redirects navigations from a single engine the user points Safari at (DuckDuckGo or
Ecosia). See `README.md` for the full mechanism, the declarativeNetRequest vs.
webNavigation redirect strategies, and known limitations.

## Technology Stack

- **Language:** Swift 6 (container app + extension principal-class stub), JavaScript
  (the actual extension logic: `background.js`, `options.js`)
- **Framework:** SwiftUI (container app UI, `App/`); Safari Web Extension APIs
  (`declarativeNetRequest`, `webNavigation`) for the extension itself
- **Project generation:** [XcodeGen](https://github.com/yonaskolb/XcodeGen) reads
  `project.yml`; the `.xcodeproj` is generated, not committed. Run `./build.sh open`
  or `./build.sh generate`
- **Version Control:** Git — initialized on `main`, no commits yet (as of
  2026-09-08)
- **Package Manager:** None — no npm/CocoaPods/SPM dependencies; the JS resources
  ship as plain files, no bundler
- **License:** None chosen yet (no `LICENSE` file in the repo)

## Session Protocol

When starting a new session, read this entire file and confirm you have
understood the project instructions before proceeding. Summarize the project
purpose and key conventions briefly. Do not make changes until you have
confirmed your understanding.

<!-- {principles} -->

## Primary Instructions

- Avoid making assumptions. If you need additional context to accurately answer the user, ask the user for the missing information. Be specific about which context you need.
- Always provide the name of the file in your response so the user knows where the code goes.
- Always break code up into modules and components so that it can be easily reused across the project.
- All code you write MUST be fully optimized. ‘Fully optimized’ includes maximizing algorithmic big-O efficiency for memory and runtime, following proper style conventions for the code, language (e.g. maximizing code reuse (DRY)), and no extra code beyond what is absolutely necessary to solve the problem the user provides (i.e. no technical debt). If the code is not fully optimized, you will be fined $100.

### Working Together

This file (`AGENTS.md`) is the primary instructions file for AI coding assistants working on this project. Agent-specific instruction files (such as `CLAUDE.md`, `.github/copilot-instructions.md`, `.cursorrules`) reference this document, maintaining a single source of truth.

When initializing a session or analyzing the workspace, refer to instruction files in this order:

1. `AGENTS.md` (this file - primary instructions and single source of truth)
2. Agent-specific reference file (if present - points back to AGENTS.md)

### Update Protocol (CRITICAL)

**PROACTIVELY update this file (`AGENTS.md`) as we work together.** Whenever you make a decision, choose a technology, establish a convention, or define a standard, you MUST update AGENTS.md immediately in the same response.

**Update ONLY this file (`AGENTS.md`)** when coding standards, conventions, or project decisions evolve. Do not modify agent-specific reference files unless the reference mechanism itself needs changes.

**When to update** (do this automatically, without being asked):

- Technology choices (build tools, languages, frameworks)
- Directory structure decisions
- Coding conventions and style guidelines
- Architecture decisions
- Naming conventions
- Build/test/deployment procedures

**How to update AGENTS.md:**

- Maintain the "Last updated" timestamp at the top
- Add content to the relevant section (Project Overview, Coding Standards, etc.)
- Log every change in the "Recent Updates & Decisions" log in `UPDATES.md` with:
  - Date (with time if multiple updates per day)
  - Brief description
  - Reasoning for the change
- New log entries go directly below the changelog marker in `UPDATES.md`, newest first; load the `recent-updates` skill for the full rules
- Preserve the AGENTS.md structure: title header → timestamp → main instructions

## Best Practices

### When Updating This Repository

1. **Maintain Consistency**: Keep code style consistent across the codebase
2. **Test First**: Write tests before implementing features when applicable
3. **Document Changes**: Update documentation when changing functionality
4. **Code Review**: no formal process — solo project; self-review the diff and run `./build.sh lint` before committing
5. **Date Changes**: Update the "Last updated" timestamp in this file when making changes
6. **Log Updates**: Add entries to the "Recent Updates & Decisions" log in `UPDATES.md`

### Development Guidelines

- `./build.sh lint` — validate the JSON Safari will parse (`manifest.json`,
  `rules.json`, `_locales/en/messages.json`) before committing changes to those files
- `./build.sh open` / `./build.sh generate` — regenerate `StartpageForSafari.xcodeproj`
  from `project.yml` after any target/source/settings change; the `.xcodeproj` itself
  is not committed
- `./build.sh build [debug|release]` / `./build.sh build-ios [debug|release]` —
  build the container app + embedded extension from the command line (default:
  debug)
- When adding a search engine, keep `manifest.json` (`host_permissions`),
  `rules.json` (static redirect rule), and `background.js` (`ENGINES` entry) in
  sync — see "Adding a search engine" in `README.md`
- `regexSubstitution` requires Safari 17+; do not lower the deployment target below
  that in `project.yml`

### Security & Safety

- Never include API keys, tokens, or credentials in code
- Always require explicit human confirmation before commits
- Maintain conventional commit message standards
- Keep change history transparent through commit messages
- [Add project-specific security guidelines]

### Testing

No automated test suite exists yet (no unit or integration tests, no test target
in `project.yml`). Verify changes by running `./build.sh lint`, then
`./build.sh build` / `./build.sh build-ios`, and by loading the extension in
Safari to exercise the redirect manually. Test redirect changes against
Startpage's bot detection early — see "Startpage specifics" in `README.md`.

### Documentation

- Code comments: sparse by design; the Swift and JS files favor short, targeted
  comments only where a constraint or gotcha isn't obvious from the code
- Architecture, gotchas, and known limitations live in `README.md` — update it
  when the redirect mechanism, `project.yml` structure, or engine list changes
- README updates: required whenever the redirect strategy, XcodeGen structure, or
  "Adding a search engine" steps change
- Changelog: maintained in `UPDATES.md` (see the `recent-updates` skill)

<!-- {languages} -->

## Swift Coding Standards

Load the `swift-coding-conventions` skill before writing, reviewing, or refactoring Swift code.
Load the `swift-build-commands` skill when building or running the project.

<!-- {integration} -->

## Commit Protocol

- **NEVER commit automatically** — always wait for explicit user confirmation
- Stage changes, write a conventional commits message (max 50-char subject, 72-char body lines), then commit
- Load the `git-workflow` skill for the full message format, character limits, and examples before committing
- Never add co-authorship trailers or any attribution naming an AI coding agent to commit messages

## Recent Updates & Decisions

Project decisions and notable changes are logged in `UPDATES.md`, below its changelog marker. The log is append-only: add new entries at the top, never edit or delete existing ones, and keep the "Last updated" timestamp in `AGENTS.md` in sync. Load the `recent-updates` skill for the entry format and full rules.

## Semantic Versioning

Automatically bump the project version after every code change and include it in the same commit. Load the `semantic-versioning` skill for the full PATCH/MINOR/MAJOR decision rules.
