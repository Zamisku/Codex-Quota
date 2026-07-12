# Architecture

Codex Quota separates authentication and networking from widget presentation. The host app is the only process that reads local Codex credentials; the widget extension consumes a sanitized snapshot through a signed App Group.

## Component map

```text
┌─────────────────────────────────────────────────────────────┐
│ Host app: Codex Quota                                       │
│                                                             │
│  AuthLoader ──► CodexQuotaService ──► QuotaResponseParser   │
│      │                 │                       │              │
│ ~/.codex/auth.json     │ fixed HTTPS hosts     │ bounded JSON │
│                        ▼                       ▼              │
│                    ProviderSnapshot ◄──── HostModel          │
│                              │                              │
└──────────────────────────────┼──────────────────────────────┘
                               │ signed App Group
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ Sandboxed Widget Extension                                  │
│                                                             │
│ SharedSnapshotStore ──► TimelineProvider ──► Small / Medium │
└─────────────────────────────────────────────────────────────┘
```

## Host application

`Codex-Quota/Codex_QuotaApp.swift` owns the SwiftUI window, menu bar extra, URL handling, and application lifecycle. The custom `codexquota://refresh` URL lets a widget open the host and request an immediate refresh.

`Codex-Quota/HostModel.swift` coordinates:

- Initial and periodic quota refreshes
- Recent-snapshot fallback for non-authentication failures
- App Group persistence
- Widget timeline reload requests
- Launch-at-login state through `SMAppService`

The default host refresh cadence is 15 minutes. Authentication and rate-limit failures back off to 30 minutes. Widget timeline reload requests are throttled unless the user explicitly refreshes or the status changes.

## Authentication loading

`Core/AuthLoader.swift` resolves `${CODEX_HOME:-~/.codex}/auth.json`, applies input-size limits, validates the expected structure, and returns only the access token and optional account identifier needed for a request.

The authentication file is never copied into the App Group. The host app is intentionally not sandboxed because a sandboxed process cannot directly read the user's Codex configuration directory.

## Networking

`Core/CodexQuotaService.swift` uses an ephemeral `URLSession` configured with:

- Fixed `https://chatgpt.com` hosts
- Redirect rejection
- No cookies, URL cache, or credential storage
- Short request and resource timeouts
- A 1 MiB response limit
- No telemetry or analytics endpoints

The usage request is required. The reset-credit request is optional so a failure there does not hide otherwise valid quota information.

## Defensive parsing

`Core/QuotaResponseParser.swift` accepts a bounded set of known response spellings and shapes. It normalizes percentage and ratio representations, rejects booleans as numeric values, and requires a valid short quota window.

When the response cannot be interpreted safely, the parser returns a typed failure instead of inventing values. Parser behavior is covered by synthetic fixtures in `Codex-QuotaTests/QuotaResponseParserTests.swift`.

## Shared snapshot

`Core/Models.swift` defines the `ProviderSnapshot` shared by the host and widget. It contains only:

- Plan label, when available
- Normalized quota windows and reset dates
- Reset-credit counts and expirations
- Update time
- Status and typed failure reason

`Core/SharedSnapshotStore.swift` encodes this model into the signed App Group with size limits and atomic replacement. Tokens, account identifiers, prompts, chat history, and raw network responses are excluded by construction.

## Widget extension

`CodexQuotaWidget/CodexQuotaWidget.swift` defines a static WidgetKit configuration with Small and Medium families. The extension:

- Runs inside App Sandbox
- Reads only the shared snapshot
- Has no authentication loader
- Has no quota networking client
- Marks old successful snapshots stale after 45 minutes
- Uses system widget margins for rounded-corner and desktop-size adaptation
- Supports standard macOS full-color and monochrome widget rendering

## Build configuration

`project.yml` is the source of truth for XcodeGen. It defines the host app, widget extension, tests, entitlements, embedded extension, Universal architectures, and shared scheme.

The checked-in `.xcodeproj` is generated for convenience. Changes to targets, capabilities, or signing should be made in `project.yml` first and then regenerated.

`scripts/build-install.sh` performs the complete local release path: project generation, tests, Universal Release build, bundle and entitlement checks, safe backup, installation, stale registration cleanup, WidgetKit refresh, and launch.

## Failure behavior

| Failure | User-visible behavior |
| --- | --- |
| Login file missing or invalid | Signed-out state; no old authenticated value is presented as current |
| 401/403 | Login-expired state |
| 429 | Rate-limited state with slower retry |
| Network or service failure | Recent valid data may remain visible as stale |
| Unknown response shape | Typed response-changed failure; values are not guessed |
| App Group write failure | Host displays a signing/capability diagnostic |

## Design constraints

- Keep token-bearing logic in the host target only.
- Keep the widget target sandboxed.
- Keep endpoint allowlists explicit.
- Keep response and persistence sizes bounded.
- Treat stale and signed-out states differently.
- Preserve system widget margins and verify both supported families in the real WidgetKit host.
