# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for marketing versions.

## [Unreleased]

### Added

- GitHub Actions CI, issue forms, pull request template, security policy, contribution guide, support guide, and bilingual project documentation.

## [2.0.0] - 2026-07-13

### Added

- Native SwiftUI host app and menu bar status item.
- Small and Medium WidgetKit widgets for 5-hour and weekly quota.
- Reset-time, plan, reset-credit, stale-state, and failure-state presentation.
- Optional launch-at-login support.
- Defensive quota response parser with regression tests.
- Signed Universal Release build and local installation workflow.

### Changed

- Improved light/dark text contrast and macOS monochrome widget rendering.
- Moved widget content to system-provided margins for rounded-corner safety.
- Made the install script remove stale duplicate App and Widget registrations before refreshing WidgetKit.

### Security

- Kept token access and authenticated networking out of the sandboxed widget extension.
- Stored only a sanitized snapshot in the App Group.

[Unreleased]: https://github.com/Zamisku/Codex-Quota/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/Zamisku/Codex-Quota/releases/tag/v2.0.0
