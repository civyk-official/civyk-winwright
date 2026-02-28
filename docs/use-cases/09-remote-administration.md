# Remote Administration

> Manage processes, services, registry, and scheduled tasks on remote Windows machines over HTTP — with enterprise-grade security.

## The Problem

Managing Windows machines remotely — restarting services, checking processes,
reading registry keys, verifying scheduled tasks — usually means RDP, PowerShell
Remoting, or vendor-specific tools. Each has its own access model and learning curve.

## How WinWright Helps

WinWright's HTTP transport (`winwright serve --port 8765`) exposes all system tools
over MCP with a five-layer security model built in. An AI agent connects remotely
and manages the machine through the same tool set used locally.

**What works today:** HTTP transport (`winwright serve --port 8765`), all system tools
accessible remotely, and JSONL audit logging.

**In development:** IP allowlist, Windows Negotiate authentication, AD group authorization,
rate limiting, per-user session limits, and TLS/HTTPS. The configuration examples below
show the planned full security setup — enable only what has shipped in your version.

## Prerequisites

- WinWright installed on the **remote** machine
- `winwright.json` configured with `permissions` for the operations you want to allow
- For authentication: both machines on the same domain (Kerberos) or workgroup (NTLM)

## Step 1 — Configure the Remote Machine

Create `winwright.json` next to the binary on the remote machine:

```json
{
  "permissions": {
    "allowShell": false,
    "allowProcessKill": true,
    "allowServiceControl": true,
    "allowRegistryWrite": false,
    "allowFileWrite": false
  },
  "remoteAccess": {
    "allowedIpRanges": ["192.168.1.0/24", "10.0.0.5"],
    "requireAuthentication": true,
    "requiredAdGroups": ["DOMAIN\\WinWrightAdmins"],
    "maxSessionsPerUser": 3,
    "enableRateLimit": true,
    "rateLimitPerMinute": 120
  },
  "audit": {
    "enabled": true,
    "retentionDays": 30
  }
}
```

**Security layers active in this config:**

| Layer | What it does |
|-------|-------------|
| R1: IP allowlist | Only `192.168.1.0/24` subnet and `10.0.0.5` can connect |
| R2: Windows Negotiate | NTLM/Kerberos auth — captures `DOMAIN\user` identity |
| R3: AD group | Caller must be in `DOMAIN\WinWrightAdmins` |
| R4: Rate limiting | 120 calls/minute per authenticated user |
| R5: Per-user limit | Max 3 concurrent sessions per user |
| Audit | Every call logged to `audit-YYYY-MM-DD.jsonl` |

## Step 2 — Start the Server on the Remote Machine

```bat
winwright serve --port 8765
```

The server starts and logs:

```text
WinWright MCP Server (HTTP)
Listening on http://0.0.0.0:8765
Authentication: Windows Negotiate
AD group required: DOMAIN\WinWrightAdmins
IP allowlist: 192.168.1.0/24, 10.0.0.5
Audit: C:\ProgramData\WinWright\logs\audit-2026-02-28.jsonl
```

## Step 3 — Configure Your MCP Client

In Claude Code or VSCode `.vscode/mcp.json`:

```json
{
  "servers": {
    "winwright-remote": {
      "type": "http",
      "url": "http://192.168.1.42:8765/mcp"
    }
  }
}
```

In Claude Desktop `claude_desktop_config.json` — HTTP servers are not supported
directly; use a local proxy or the Claude Code CLI.

## Example: Restart a Stuck Service

### Tell Your Agent

> "Check if the MyDataService Windows service is running on the remote machine.
> If it's stuck or stopped, restart it and confirm it's running again."

### Tool Sequence

#### List services matching the name

```json
ww_service_list
  { "filter": "MyDataService" }
```

Response:

```json
{
  "services": [
    { "name": "MyDataService", "displayName": "My Data Service",
      "status": "Stopped", "startType": "Automatic" }
  ]
}
```

#### Restart the service

```json
ww_service_restart
  { "name": "MyDataService" }
```

Response:

```json
{ "name": "MyDataService", "previousStatus": "Stopped", "newStatus": "Running", "durationMs": 3240 }
```

#### Confirm it's running

```json
ww_service_list
  { "filter": "MyDataService" }
```

Response:

```json
{
  "services": [
    { "name": "MyDataService", "status": "Running", "startType": "Automatic" }
  ]
}
```

#### Run a diagnostic script (requires `allowShell: true`)

```json
ww_shell
  { "command": "Get-EventLog -LogName Application -Source MyDataService -Newest 10",
    "shell": "powershell" }
```

Response:

```json
{
  "exitCode": 0,
  "stdout": "TimeGenerated   EntryType  Message\n2026-02-28 14:30 Error  Connection timeout to DB server...",
  "stderr": ""
}
```

### Audit Log Entry

Every call is recorded in `audit-2026-02-28.jsonl`:

```json
{ "ts": "2026-02-28T14:32:01Z", "tool": "ww_service_restart",
  "status": "ok", "caller": "DOMAIN\\alice", "identity": "svc-winwright",
  "durationMs": 3240 }
{ "ts": "2026-02-28T14:32:05Z", "tool": "ww_shell",
  "status": "ok", "caller": "DOMAIN\\alice", "identity": "svc-winwright",
  "params": { "command": "Get-EventLog..." }, "durationMs": 1820 }
```

`caller` = the authenticated HTTP caller. `identity` = the Windows user WinWright runs as.

## Example: Check Registry Configuration

```json
ww_registry_read
  { "key": "HKLM\\SOFTWARE\\MyApp", "value": "DatabaseServer" }
```

Response:

```json
{ "key": "HKLM\\SOFTWARE\\MyApp", "value": "DatabaseServer",
  "data": "db-server-01.corp.local", "type": "REG_SZ" }
```

## TLS Configuration

**Recommended: Use a reverse proxy** (nginx, IIS, Caddy) to terminate TLS and
proxy to `http://localhost:8765`.

**Built-in Kestrel HTTPS** (no proxy required):

```json
{
  "transport": {
    "tlsCertPath": "C:\\certs\\winwright.pfx",
    "tlsCertPassword": "${WINWRIGHT_TLS_PASSWORD}"
  }
}
```

Set `WINWRIGHT_TLS_PASSWORD` as an environment variable — never put secrets in `winwright.json`.

## Limitations

- `ww_shell`, `ww_process_kill`, `ww_service_*` are disabled by default — enable only what
  you need by setting the relevant `permissions` flags
- Kerberos requires both machines to be domain-joined; NTLM works in workgroups but
  provides weaker authentication guarantees
- Browser tools (`ww_browser_*`) require Chrome/Edge running on the **remote** machine
  with CDP enabled

---

*[Back to use cases](README.md)*
