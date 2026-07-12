# Support

## Where to ask

- Use GitHub Issues for reproducible Codex Quota bugs and focused feature requests.
- Use a private security advisory for authentication, token, sandbox, or sensitive-data issues.
- Use Apple or OpenAI support channels for problems that are not caused by this project.

## Before opening an issue

1. Confirm macOS 14 or later is installed.
2. Confirm Codex Desktop is signed in.
3. Launch `/Applications/Codex Quota.app` and use **Check and refresh**.
4. Run the one-command installer from the README to reinstall the latest prebuilt release if the widget still shows an older layout.
5. If Finder blocks the current unnotarized build, Control-click the app, choose **Open**, and confirm once.
6. Search existing issues.

Include the following in a bug report:

- macOS version and Mac architecture
- Codex Quota marketing version and build number
- Small or Medium widget family
- Expected and actual behavior
- Minimal reproduction steps
- Sanitized logs or screenshots

Never attach `~/.codex/auth.json`, tokens, account IDs, raw quota responses, prompts, or unrelated system logs.

## Project boundaries

The maintainers cannot guarantee availability or stability of the upstream internal quota endpoints, exact WidgetKit refresh timing, Apple signing services, or third-party Codex Desktop behavior. Reports are still useful when Codex Quota can improve its fallback, error message, or compatibility handling.
