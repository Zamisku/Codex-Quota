# Codex Quota

<p align="center">
  <img src="docs/assets/hero-banner.png" width="1200" alt="Codex Quota native macOS quota monitor with Small and Medium widgets">
</p>

<p align="center">
  <strong>Quota at a glance. Privacy by design.</strong><br>
  A native macOS menu bar companion and WidgetKit dashboard for local Codex quota.
</p>

<p align="center">
  <a href="README.zh-CN.md">简体中文</a>
  ·
  <a href="https://github.com/Zamisku/Codex-Quota/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/Zamisku/Codex-Quota/actions/workflows/ci.yml/badge.svg"></a>
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-111111?logo=apple">
  <img alt="Swift 5" src="https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white">
  <a href="LICENSE"><img alt="Apache-2.0" src="https://img.shields.io/badge/License-Apache--2.0-blue.svg"></a>
</p>

<p align="center">
  <a href="#quick-start">Quick start</a>
  ·
  <a href="#privacy-model">Privacy</a>
  ·
  <a href="docs/ARCHITECTURE.md">Architecture</a>
  ·
  <a href="CONTRIBUTING.md">Contributing</a>
</p>

Codex Quota keeps your 5-hour and weekly quota visible before a limit interrupts your flow. The native SwiftUI host reads the existing local Codex Desktop sign-in, fetches quota information from fixed ChatGPT compatibility endpoints, and shares only a sanitized snapshot with its sandboxed widget extension. It never stores the access token in the App Group.

> [!IMPORTANT]
> Codex Quota is an unofficial community project and is not affiliated with or endorsed by OpenAI. The quota endpoints it relies on are internal compatibility endpoints, not a stable public API, and may change without notice.

## Why Codex Quota

- Native SwiftUI menu bar app with Small and Medium WidgetKit widgets.
- Displays 5-hour quota, weekly quota, reset time, plan, and reset credits when available.
- Automatic background refresh with stale-data fallback and clear failure states.
- Manual refresh from the app, menu bar, or widget deep link.
- Optional launch-at-login support through `SMAppService`.
- Universal `arm64` and `x86_64` Release builds.
- No analytics, telemetry, cookies, redirects, or third-party tracking.
- The widget is sandboxed and cannot read `~/.codex` or make authenticated network requests.

## Built for a glance

<p align="center">
  <img src="docs/assets/widget-small.png" width="300" alt="Codex Quota Small widget showing synthetic example quota data">
  &nbsp;&nbsp;
  <img src="docs/assets/widget-medium.png" width="600" alt="Codex Quota Medium widget showing synthetic example quota data">
</p>

Small shows the one number you need most. Medium adds weekly quota, reset credits, and the next reset time without turning the desktop into another dashboard. All preview values are synthetic and contain no account data.

## Requirements

- macOS 14 Sonoma or later
- Xcode 15 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- An Apple Development signing identity for local installation
- Codex Desktop already signed in, with `${CODEX_HOME:-~/.codex}/auth.json` available

## Quick start

```bash
git clone git@github.com:Zamisku/Codex-Quota.git
cd Codex-Quota
brew install xcodegen
./scripts/build-install.sh
```

The install script regenerates the Xcode project, runs tests, creates a signed Universal Release build, validates the host and widget entitlements, backs up an existing installation, removes stale duplicate widget registrations, installs to `/Applications/Codex Quota.app`, and refreshes WidgetKit.

After the host app reports that a sanitized snapshot has been shared:

1. Control-click an empty area of the desktop.
2. Choose **Edit Widgets**.
3. Search for **Codex Quota**.
4. Add the Small or Medium widget.

## Code signing

The checked-in project is configured for development Team `X9MB8SQZHF` and App Group `X9MB8SQZHF.com.Zamisku.CodexQuota.shared`. Contributors using another Apple Developer team must update all of the following together:

- `DEVELOPMENT_TEAM` and bundle identifiers in `project.yml`
- The App Group in both entitlement files
- The App Group identifier in `Core/SharedSnapshotStore.swift`

Then regenerate the project with `xcodegen generate`. See [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow.

## Privacy model

```text
~/.codex/auth.json
        │ host app only
        ▼
Fixed HTTPS quota endpoints on chatgpt.com
        │ parsed and sanitized
        ▼
ProviderSnapshot in the signed App Group
        │ no token, account ID, prompts, or raw response
        ▼
Sandboxed WidgetKit extension
```

The host reads the local Codex authentication file because macOS does not grant a sandboxed process access to it. The widget stays sandboxed and receives only bounded Codable values. See [docs/PRIVACY.md](docs/PRIVACY.md) for the complete data-flow and threat-boundary notes.

## Architecture

| Area | Responsibility |
| --- | --- |
| `Codex-Quota/` | SwiftUI host window, menu bar UI, refresh loop, launch-at-login control |
| `CodexQuotaWidget/` | Sandboxed Small and Medium WidgetKit presentation |
| `Core/` | Authentication loading, fixed-endpoint networking, defensive parsing, shared snapshot model |
| `Codex-QuotaTests/` | Parser and stale-snapshot regression tests |
| `project.yml` | XcodeGen source of truth for targets, signing, capabilities, and schemes |
| `scripts/build-install.sh` | Tested local build, verification, installation, and widget registration workflow |
| `scripts/render-promo.swift` | Reproducible AppKit compositor for README and GitHub promotional artwork |

More detail is available in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Development

Generate the project:

```bash
xcodegen generate
```

Run the CI-compatible test command without signing:

```bash
xcodebuild \
  -project Codex-Quota.xcodeproj \
  -scheme Codex-Quota \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath .build/CI \
  CODE_SIGNING_ALLOWED=NO \
  test
```

For a signed local Release build and installation, use `./scripts/build-install.sh`.

## Known limitations

- WidgetKit controls refresh scheduling; exact refresh times are not guaranteed.
- Quota response fields may change because the upstream endpoints are not public API contracts.
- The repository does not currently publish a notarized binary. Local builds use Apple Development signing and are not suitable for third-party distribution.
- Visual screenshots cannot establish full VoiceOver, keyboard, or Dynamic Type compliance; accessibility improvements are welcome.

## Community and support

- Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.
- Use [GitHub Issues](https://github.com/Zamisku/Codex-Quota/issues) for reproducible bugs and feature requests.
- Follow [SECURITY.md](SECURITY.md) for private vulnerability reports.
- See [SUPPORT.md](SUPPORT.md) for troubleshooting boundaries.
- Project changes are tracked in [CHANGELOG.md](CHANGELOG.md).

## License

Codex Quota is licensed under the [Apache License 2.0](LICENSE). Copyright notices are provided in [NOTICE](NOTICE), and third-party attribution is listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
