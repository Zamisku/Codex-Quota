# Security Policy

## Supported versions

Security fixes are applied to the latest code on `main` and, when practical, to the most recent release line.

| Version | Supported |
| --- | --- |
| Latest `main` / latest release | Yes |
| Older releases | Best effort |

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub's **Report a vulnerability** / private security advisory flow for this repository. If private reporting is unavailable, contact the maintainer through the repository owner's GitHub profile before sharing technical details.

Do not include real Codex access tokens, `auth.json`, account IDs, raw API responses, prompts, or unrelated personal information. Use synthetic examples whenever possible.

Useful reports include:

- A clear description of the impact and affected component
- Reproduction steps using sanitized data
- macOS, Xcode, and Codex Quota versions
- Whether the issue affects the host app, widget extension, App Group, or install script
- A proposed mitigation, if known

You should receive an acknowledgement within seven days. Please allow time for validation and a coordinated fix before public disclosure.

## Security boundaries

- The host app reads the local Codex authentication file and is intentionally not sandboxed.
- The widget extension is sandboxed and must not read authentication files or perform authenticated networking.
- Access tokens are used only in memory for fixed HTTPS requests to `chatgpt.com`.
- The App Group stores a sanitized, size-bounded `ProviderSnapshot` only.
- Redirects, cookies, caches, credential persistence, telemetry, and analytics are disabled.

Changes that weaken these boundaries require explicit review.
