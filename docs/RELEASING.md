# Release guide

Codex Quota publishes a Universal macOS app in two user-facing formats:

- `Codex-Quota-macOS-universal.dmg` for drag-and-drop installation.
- `Codex-Quota-macOS-universal.zip` for the verified one-command installer.

`SHA256SUMS` covers both artifacts. Asset names remain stable so the README and installer can always target GitHub's `/releases/latest/download/` URLs.

## Local packaging

Maintainers can create an artifact from the currently configured signing identity:

```bash
./scripts/package-release.sh
```

The script regenerates the Xcode project, runs tests, builds a Universal Release app, checks bundle identifiers, architectures, entitlements, bundled licenses, Hardened Runtime, and code signatures, then creates the ZIP, DMG, and checksums under `.build/release/`.

An Apple Development-signed build is useful for local validation and can be shared as an explicitly unnotarized fallback. It will not pass Gatekeeper assessment and must never be described as notarized.

## Notarized GitHub release

The manual **Release** GitHub Actions workflow performs the production path:

1. Checks out an existing version tag.
2. Runs the unsigned CI test suite.
3. Imports a Developer ID Application certificate into a temporary keychain.
4. Archives and exports the app with Hardened Runtime.
5. Submits the app and DMG to Apple's notary service and staples the tickets.
6. Publishes the DMG, ZIP, and SHA-256 checksums to the matching GitHub Release.

Configure these GitHub Actions secrets before running the workflow:

| Secret | Purpose |
| --- | --- |
| `APPLE_TEAM_ID` | Apple Developer team identifier used by both targets and the App Group |
| `DEVELOPER_ID_P12_BASE64` | Base64-encoded Developer ID Application certificate and private key |
| `DEVELOPER_ID_P12_PASSWORD` | Password protecting the exported PKCS#12 file |
| `ASC_KEY_ID` | App Store Connect API key identifier |
| `ASC_ISSUER_ID` | App Store Connect API issuer identifier |
| `ASC_API_KEY_P8` | Raw contents of the App Store Connect `.p8` private key |
| `HOST_PROVISIONING_PROFILE_BASE64` | Optional Developer ID provisioning profile for the host App ID |
| `WIDGET_PROVISIONING_PROFILE_BASE64` | Optional Developer ID provisioning profile for the widget App ID |

The provisioning profile secrets are needed when automatic provisioning cannot download profiles containing the App Group entitlement.

## Version checklist

1. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`.
2. Move user-facing entries from **Unreleased** into a dated changelog section.
3. Run `./scripts/package-release.sh` locally and inspect both mounted DMG contents and the extracted ZIP.
4. Commit the release preparation.
5. Create and push an annotated `vX.Y.Z` tag.
6. Run the **Release** workflow with that tag after production signing secrets are configured.
7. Verify the direct latest-download URLs and install once on a clean macOS user account.

The production workflow deliberately fails when notarization credentials are missing or Gatekeeper rejects the final app. This prevents an unsigned artifact from being presented as a frictionless release.
