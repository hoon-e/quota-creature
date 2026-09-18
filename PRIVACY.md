# Privacy

QuotaCreature does not collect, persist, sell, sync, or transmit usage data
itself.

For each refresh it keeps these values in memory only: usage percentage,
window length, reset timestamp, and an optional secondary window. Closing the
app removes that in-memory state.

The app starts the locally installed Codex App Server over standard input and
output. That child uses the user's existing Codex login to obtain rate-limit
data according to OpenAI's services; QuotaCreature does not read or handle the
login credential. See the official [Codex App Server
documentation](https://learn.chatgpt.com/docs/app-server) for App Server
transport and authentication context.

The project contains no analytics, crash reporter, update checker, HTTP
client, WebSocket client, listener, account database, or usage-history file.
