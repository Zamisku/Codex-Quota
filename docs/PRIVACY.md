# Privacy and Data Handling

Codex Quota is designed to expose the minimum information required for a local quota widget. It does not provide a cloud service and does not send data to the project maintainers.

## Data accessed

The host application may read:

- `${CODEX_HOME:-~/.codex}/auth.json`
- The Codex access token needed for a quota request
- The optional ChatGPT account identifier used by the upstream service
- Quota response fields returned by the fixed endpoints

The widget extension cannot read the authentication file.

## Network destinations

Authenticated requests are restricted to these fixed HTTPS URLs:

- `https://chatgpt.com/backend-api/wham/usage`
- `https://chatgpt.com/backend-api/wham/rate-limit-reset-credits`

The URL session rejects redirects and disables cookies, cache storage, and credential persistence. The application contains no analytics, crash-reporting SDK, advertising SDK, or project-operated telemetry endpoint.

## Data stored

The signed App Group stores a bounded encoded `ProviderSnapshot` containing quota percentages, reset information, plan label, reset-credit metadata, update time, and a typed status.

It does **not** store:

- Access tokens or refresh tokens
- Account identifiers
- The full authentication file
- Prompts or chat history
- Raw quota responses
- Browser cookies
- Device analytics or usage telemetry

The token remains in memory only long enough to construct authenticated requests.

## Process boundaries

### Host app

The host app is not sandboxed because it must read the local Codex authentication file outside its own container. This is the project's largest local privilege and should remain narrowly scoped to authentication loading.

### Widget extension

The WidgetKit extension enables App Sandbox. It receives only the App Group entitlement and contains neither `AuthLoader` nor `CodexQuotaService`. A compromise or bug in widget presentation should therefore not expose the local authentication file through normal extension capabilities.

## Retention

The App Group snapshot is replaced atomically on successful host updates. A recent successful snapshot may be retained and marked stale during a transient network or service failure. Authentication failures replace the visible state rather than presenting old data as current.

Uninstalling the application may not automatically remove every App Group container created by macOS. Users who need complete local cleanup can remove the app and its associated App Group container after confirming no other build uses it.

## User controls

Users can:

- Quit the host app to stop active refreshes
- Disable launch at login
- Remove the desktop widget
- Uninstall the application
- Remove the App Group data manually if complete cleanup is required

The application never redeems reset credits or modifies the Codex account.

## Upstream compatibility risk

The quota endpoints are internal compatibility interfaces rather than public API contracts. The parser intentionally fails closed when required fields cannot be recognized. A changed upstream response may make data unavailable until the project is updated.

## Reporting concerns

Privacy and security concerns should be reported privately as described in [../SECURITY.md](../SECURITY.md). Never include a real token, authentication file, account ID, prompt, or raw response in a report.
