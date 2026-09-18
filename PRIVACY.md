# Privacy

QuotaCreature does not collect, persist, sell, sync, or transmit usage data
itself.

For each refresh it keeps these values in memory only: usage percentage,
window length, reset timestamp, an optional secondary window, or a monthly
credit limit. Closing the app removes that in-memory state.

For creature motion, it temporarily keeps only the previous percentage, reset
timestamp, and sample time. The next accepted reading replaces that sample; it
is not a usage history.

If the user enables the monthly-reset reminder, the app stores only that
preference and the reset timestamp already scheduled in macOS UserDefaults.
This prevents duplicate local notifications. It does not store account IDs,
credit amounts, token amounts, or usage history.

The app starts the locally installed Codex App Server over standard input and
output. That child uses the user's existing Codex login to obtain rate-limit
data according to OpenAI's services; QuotaCreature does not read or handle the
login credential. See the official [Codex App Server
documentation](https://learn.chatgpt.com/docs/app-server) for App Server
transport and authentication context.

Claude Code support is in Beta. The app may detect a local Claude executable,
but does not persist its path, account, usage number, or credential. It does
not run Claude or read Claude sessions, logs, configuration, or auth files.

The project contains no analytics, crash reporter, update checker, HTTP
client, WebSocket client, listener, account database, or usage-history file.
