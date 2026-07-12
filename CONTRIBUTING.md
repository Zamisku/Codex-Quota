# Contributing to Codex Quota

Thanks for helping improve Codex Quota. Contributions that strengthen privacy, parser resilience, accessibility, reliability, or macOS-native behavior are especially welcome.

## Before you start

- Search existing issues and pull requests before opening a duplicate.
- Keep changes focused. Large visual or architectural changes should start with an issue describing the user problem and intended behavior.
- Never include real access tokens, account IDs, raw quota responses, prompts, or screenshots containing personal data.
- Do not add telemetry, analytics, redirects, third-party tracking, or new network hosts without an explicit security and privacy review.

## Development setup

Requirements:

- macOS 14 or later
- Xcode 15 or later
- XcodeGen

```bash
brew install xcodegen
git clone git@github.com:Zamisku/Codex-Quota.git
cd Codex-Quota
xcodegen generate
```

`project.yml` is the source of truth. Do not make target, capability, or build-setting changes only in the generated `.xcodeproj`.

### Code signing

The checked-in signing configuration belongs to the maintainer's development team. To run a signed local build under another team, update the development team, bundle identifiers, and App Group consistently in:

- `project.yml`
- `Codex-Quota/Codex-Quota.entitlements`
- `CodexQuotaWidget/CodexQuotaWidget.entitlements`
- `Core/SharedSnapshotStore.swift`

Regenerate the project after changing these values.

## Testing

Run the CI-compatible test command:

```bash
xcodebuild \
  -project Codex-Quota.xcodeproj \
  -scheme Codex-Quota \
  -configuration Debug \
  -destination "platform=macOS,arch=$(uname -m)" \
  -derivedDataPath .build/CI \
  CODE_SIGNING_ALLOWED=NO \
  ONLY_ACTIVE_ARCH=YES \
  ARCHS="$(uname -m)" \
  test
```

For changes that affect signing, App Groups, WidgetKit registration, or installation, also run:

```bash
./scripts/build-install.sh
```

Changes to distribution or packaging should also run `./scripts/package-release.sh` and follow [docs/RELEASING.md](docs/RELEASING.md). Public releases must state their actual signing and notarization status accurately.

Parser changes should include focused regression tests using synthetic JSON fixtures. UI changes should be checked in both Small and Medium widget sizes, in light and dark appearances, and with macOS monochrome widget rendering.

## Coding guidelines

- Follow existing Swift and SwiftUI naming and formatting conventions.
- Prefer small types and explicit privacy boundaries over shared global state.
- Keep authenticated networking in the host app; the widget extension must remain sandboxed and token-free.
- Treat upstream JSON as untrusted and size-bound every response.
- Preserve stale-but-recent data only when the failure is not authentication-related.
- Add user-facing failure states instead of guessing missing quota values.
- Avoid unrelated generated-project churn in pull requests.

## Pull requests

1. Create a focused branch from `main`.
2. Make the change and add tests or validation evidence.
3. Run `git diff --check` and the test command above.
4. Fill out the pull request template completely.
5. Keep commits reviewable and explain any privacy, signing, or compatibility impact.

A pull request is ready for review when CI passes, documentation matches behavior, and no secrets or personal data are present.

## Reporting security issues

Do not open a public issue for a vulnerability involving authentication, token handling, App Groups, network boundaries, or sensitive local files. Follow [SECURITY.md](SECURITY.md) instead.
