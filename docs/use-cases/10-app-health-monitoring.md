# Application Health Monitoring

> Verify that a running app is alive, connected, and responsive — and alert when something is wrong. Pair with Windows Task Scheduler to run checks on a schedule.

## The Problem

Operations teams need to know when an app is down before users report it. Polling
a health endpoint is easy for web services, but desktop apps and Windows services
have no standard health API. Monitoring them usually requires custom scripts or
expensive APM tools.

## How WinWright Helps

An AI agent can attach to a running application, inspect its UI state, read
connection status fields, verify responsiveness, and check its associated Windows
service — all without modifying the application or adding instrumentation.

## Prerequisites

- WinWright installed on the machine running the application
- Use `winwright serve --port 8765` for scheduled/automated checks (HTTP mode)
- The app must expose status information via UIA-accessible controls

## Example: Health Check for an Order Management App

### Tell Your Agent

> "Check if OrderManager is running. If it is, verify the dashboard shows
> 'Connected' as the connection status and that the Last Sync time is within
> the last 5 minutes. Also verify the OrderManagerSvc Windows service is Running."

### Tool Sequence

#### Check if the process is running

```json
ww_process_list
  { "nameFilter": "OrderManager" }
```

Response — app is running:

```json
{
  "processes": [
    { "processId": 9820, "name": "OrderManager", "cpu": 0.4, "memoryMb": 142 }
  ]
}
```

Response — app not found:

```json
{ "processes": [] }
```

If not found, the agent reports the outage immediately.

#### Attach to the running app

```json
ww_attach
  { "processId": 9820 }
```

Response:

```json
{ "appId": "app-mon1", "processId": 9820, "mainWindowTitle": "OrderManager — Dashboard" }
```

#### Read the connection status

```json
ww_find_elements
  { "appId": "app-mon1", "selector": "AutomationId:lblConnectionStatus" }
```

```json
ww_get_value
  { "appId": "app-mon1", "selector": "AutomationId:lblConnectionStatus" }
```

Response:

```json
{ "value": "Connected", "property": "value" }
```

#### Assert the status is Connected

```json
ww_assert_value
  { "appId": "app-mon1", "selector": "AutomationId:lblConnectionStatus",
    "property": "value", "op": "eq", "expected": "Connected",
    "message": "OrderManager must show Connected status" }
```

Response:

```json
{ "passed": true, "actualValue": "Connected" }
```

#### Read the last sync time

```json
ww_get_value
  { "appId": "app-mon1", "selector": "AutomationId:lblLastSync" }
```

Response:

```json
{ "value": "2026-02-28 14:27:03", "property": "value" }
```

The agent parses the timestamp and compares it to the current time. If the sync is
more than 5 minutes ago, it flags the issue.

#### Verify the Windows service

```json
ww_service_list
  { "filter": "OrderManagerSvc" }
```

Response:

```json
{
  "services": [
    { "name": "OrderManagerSvc", "displayName": "Order Manager Service",
      "status": "Running", "startType": "Automatic" }
  ]
}
```

### Agent Report

The agent responds with a structured health report:

```text
OrderManager Health Check — 2026-02-28 14:28:05

[PASS]  Process running      PID 9820 | CPU 0.4% | Memory 142 MB
[PASS]  Connection status    Connected
[PASS]  Last sync            2026-02-28 14:27:03 (1 min ago — within threshold)
[PASS]  Windows service      OrderManagerSvc — Running (Automatic)

Overall: HEALTHY
```

If a check fails:

```text
[FAIL]  Connection status    Disconnected (expected: Connected)
        Action required: check network connectivity to order backend

Overall: UNHEALTHY — 1 check failed
```

## Scheduling Health Checks

### Option 1 — Windows Task Scheduler (stdio mode)

Create a scheduled task that runs every 5 minutes:

```powershell
$action = New-ScheduledTaskAction -Execute "claude" `
  -Argument '--print "Check OrderManager health: process, connection status, service. Alert if unhealthy." --model claude-opus-4-6'
$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 5) -Once -At (Get-Date)
Register-ScheduledTask -TaskName "WinWright-HealthCheck" -Action $action -Trigger $trigger
```

### Option 2 — HTTP Mode for Remote Monitoring

On the monitored machine:

```bat
winwright serve --port 8765
```

From a central monitoring machine, an agent (or script) connects via HTTP and runs the same
checks. See [Use Case 07 — Remote Administration](07-remote-administration.md) for the
full HTTP security setup.

### Option 3 — Pair with Alerting

Ask the agent to send an alert when checks fail:

> "If OrderManager is unhealthy, send an email to `ops@example.com` with the full report."

The agent uses the email tools available in your MCP setup (separate from WinWright)
to deliver the alert.

## Tips

- Combine process, service, and UI checks — an app can be "running" but frozen or
  showing an error state that only the UI reveals
- For apps that take time to update their status display, add:
  "Wait up to 10 seconds for the status to update before reading it"
- Read multiple status fields in one check: connection status, sync time, error count,
  queue depth — whatever the app exposes

## Limitations

- WinWright can check status fields that are visible in the UI — internal app state
  (database connections, background threads) is only visible if the app surfaces it
  in a UIA-accessible control
- Checks against a minimized or hidden window still work — UIA reads controls
  regardless of window visibility

---

*[Back to use cases](README.md)*
