# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for marketing versions.

## [Unreleased]

No user-facing changes yet.

## [2.2.0] - 2026-07-14

### Added

- Added lightweight GitHub Star links to the host window, menu bar, and project documentation.

### Changed

- Made weekly quota the current default presentation while automatically restoring the short-window UI whenever the service returns one again.
- Classified quota windows by duration before legacy field names, and accepted weekly-only, short-only, and dual-window responses.
- Updated the host, menu bar, widgets, bilingual documentation, and promotional artwork for adaptive quota windows.

## [2.1.0] - 2026-07-13

### Added

- Prebuilt Universal macOS ZIP and drag-to-install DMG release artifacts.
- A one-command installer that verifies SHA-256, code signatures, bundle identifiers, and widget contents before replacing an existing installation.
- A reproducible packaging script and a Developer ID signing/notarization GitHub Actions workflow.
- Maintainer documentation for producing and publishing release assets.

### Changed

- Reworked the English and Simplified Chinese READMEs around downloading and running the app; Xcode setup is now clearly contributor-only.
- Replaced the source-build troubleshooting path with reinstalling the latest prebuilt release.

### Security

- Release installation refuses checksum, code-signature, bundle-identifier, or package-layout mismatches.
- Production automation refuses to publish an artifact as notarized when Developer ID credentials or Gatekeeper approval are missing.

## [2.0.0] - 2026-07-13

### Added

- Native SwiftUI host app and menu bar status item.
- Small and Medium WidgetKit widgets for 5-hour and weekly quota.
- Reset-time, plan, reset-credit, stale-state, and failure-state presentation.
- Optional launch-at-login support.
- Defensive quota response parser with regression tests.
- Signed Universal Release build and local installation workflow.
- GitHub Actions CI, issue forms, pull request template, security policy, contribution guide, support guide, and bilingual project documentation.

### Changed

- Improved light/dark text contrast and macOS monochrome widget rendering.
- Moved widget content to system-provided margins for rounded-corner safety.
- Made the install script remove stale duplicate App and Widget registrations before refreshing WidgetKit.

### Security

- Kept token access and authenticated networking out of the sandboxed widget extension.
- Stored only a sanitized snapshot in the App Group.

[Unreleased]: https://github.com/Zamisku/Codex-Quota/compare/v2.2.0...HEAD
[2.2.0]: https://github.com/Zamisku/Codex-Quota/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/Zamisku/Codex-Quota/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/Zamisku/Codex-Quota/releases/tag/v2.0.0
