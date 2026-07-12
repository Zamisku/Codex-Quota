## Summary

Describe the user-facing problem and the change that solves it.

## Validation

- [ ] `xcodegen generate`
- [ ] CI-compatible `xcodebuild ... CODE_SIGNING_ALLOWED=NO test`
- [ ] Signed local build/install, when signing or WidgetKit behavior changed
- [ ] Small and Medium widgets checked, when UI changed
- [ ] Light, dark, and macOS monochrome widget appearances checked, when UI changed

## Privacy and security

- [ ] No tokens, account IDs, raw quota responses, prompts, personal screenshots, or unrelated logs are included
- [ ] Authenticated networking remains in the host app
- [ ] The widget remains sandboxed and token-free
- [ ] New hosts, persisted fields, or entitlements are documented and justified

## Notes

List compatibility concerns, screenshots using synthetic data, or follow-up work.
