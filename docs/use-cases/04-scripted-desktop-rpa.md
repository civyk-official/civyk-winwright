# Scripted Desktop Automation for Repeated Tasks

> Record a repetitive desktop workflow once, export it as an RPA script, and replay it on demand — no AI agent needed after the first recording.

## The Problem

Many desktop tasks follow the same steps every time: generate a report, export it to a
folder, open a second app, import the file, and email the result. Doing this daily by hand
is slow. Writing an AutoHotkey or PowerShell script for it takes development time and
breaks when the UI changes.

## How WinWright Helps

You walk through the task once with an AI agent watching. The agent records every
successful interaction as an RPA script. When the runner ships, you run the script daily
with `winwright run task.json` — no AI involved, no token cost. The recording handles the
"figure out the steps" part; the runner handles the "do it every day" part.

**What works today:** recording, in-session correction, RPA script export.

**In development:** the standalone `winwright run` script runner (CLI replay without an agent).

## Difference from Test Mode

Use Case 06 covers **test mode** — grouped test cases with pass/fail assertions for CI.
This use case covers **RPA mode** — a flat step sequence with no test cases and no assertions.
Use RPA mode when you want to automate a task, not verify an outcome.

| | RPA Mode (this guide) | Test Mode (Use Case 01) |
|---|---|---|
| Purpose | Automate a repeatable task | Verify app behaviour |
| Structure | Flat `steps[]` | `testCases[]` with grouped steps |
| Assertions | None | `ww_assert_value` embeds expected values |
| Reports | Steps passed/failed | Test case passed/failed |
| Use in CI | Yes (task replay) | Yes (regression suite) |

## Prerequisites

- WinWright configured as an MCP server in your AI agent —
  see [MCP Client Configuration](../../README.md#mcp-client-configuration) for stdio and HTTP setup
- The task involves one or more Windows apps (desktop, with UIA-accessible controls)

## Example: Daily Report Export and Import

### The Task

Every morning: open ReportingApp, export yesterday's sales report to a CSV, open
ImportTool, load the CSV, and click Process.

### 1. Tell Your Agent

> "I want to automate this daily task. Start recording, then do the following:
> Open C:\Tools\ReportingApp.exe, navigate to Sales Reports, set the date range
> to yesterday, export to C:\daily-exports\sales.csv, then open C:\Tools\ImportTool.exe,
> load that CSV, and click Process."

### 2. Tool Sequence

#### Start recording (RPA mode — no test cases)

```json
ww_record_start
  { "appId": "app-rpa1" }
```

Response:

```json
{ "started": true }
```

No `ww_test_case_start` is called. All steps go into a flat list — this is RPA mode.

#### Launch and operate the reporting app

```json
ww_launch
  { "appPath": "C:\\Tools\\ReportingApp.exe" }
```

```json
ww_click
  { "appId": "app-rpa1", "selector": "Name:Sales Reports" }
```

```json
ww_type
  { "appId": "app-rpa1", "selector": "Name:From Date",
    "text": "2026-02-27", "clearFirst": true }
```

```json
ww_type
  { "appId": "app-rpa1", "selector": "Name:To Date",
    "text": "2026-02-27", "clearFirst": true }
```

```json
ww_click
  { "appId": "app-rpa1", "selector": "Name:Export" }
```

#### Handle the file-save dialog

```json
ww_type
  { "appId": "app-rpa1", "windowId": "h-save",
    "selector": "Name:File name",
    "text": "C:\\daily-exports\\sales.csv", "clearFirst": true }
```

```json
ww_click
  { "appId": "app-rpa1", "windowId": "h-save", "selector": "Name:Save" }
```

#### Launch and operate the import tool

```json
ww_launch
  { "appPath": "C:\\Tools\\ImportTool.exe" }
```

```json
ww_click
  { "appId": "app-rpa2", "selector": "Name:Load File" }
```

```json
ww_type
  { "appId": "app-rpa2", "windowId": "h-open",
    "selector": "Name:File name",
    "text": "C:\\daily-exports\\sales.csv", "clearFirst": true }
```

```json
ww_click
  { "appId": "app-rpa2", "windowId": "h-open", "selector": "Name:Open" }
```

```json
ww_click
  { "appId": "app-rpa2", "selector": "Name:Process" }
```

### 3. Correct Any Mistakes

If a wrong step was recorded:

```json
ww_record_pop
  { "appId": "app-rpa1", "count": 1 }
```

See [Use Case 06 — Part B: Correcting a Recording](01-scripted-ci.md#part-b-correcting-a-recording)
for the full set of correction patterns (they apply equally to RPA mode).

### 4. Export the RPA Script

```json
ww_export_script
  { "appId": "app-rpa1",
    "launchPath": "C:\\Tools\\ReportingApp.exe",
    "stopRecording": true }
```

Response:

```json
{ "script": "{ ... }", "stepCount": 12, "assertionCount": 0 }
```

### 5. Save the Script File

> "Save the script to C:\scripts\daily-sales-import.json"

The agent writes the JSON content to the file (requires `allowFileWrite: true` in config).

## Exported Script Format (RPA Mode)

```json
{
  "version": "1",
  "appId": "app-rpa1",
  "mode": "rpa",
  "launchPath": "C:\\Tools\\ReportingApp.exe",
  "steps": [
    { "tool": "ww_launch",    "extra": "{\"appPath\":\"C:\\\\Tools\\\\ReportingApp.exe\"}", "timestamp": "..." },
    { "tool": "ww_click",     "selector": "Name:Sales Reports",  "timestamp": "..." },
    { "tool": "ww_type",      "selector": "Name:From Date",      "timestamp": "..." },
    { "tool": "ww_click",     "selector": "Name:Export",         "timestamp": "..." },
    { "tool": "ww_launch",    "extra": "{\"appPath\":\"C:\\\\Tools\\\\ImportTool.exe\"}", "timestamp": "..." },
    { "tool": "ww_click",     "selector": "Name:Process",        "timestamp": "..." }
  ]
}
```

Note: `mode: "rpa"` — no `testCases` array. The runner replays steps in order.

## Running the Script Daily

### Current: Ask Your Agent to Replay It

> "Replay C:\scripts\daily-sales-import.json"

The agent reads the script and executes each step. No re-learning — it follows
the recorded sequence exactly.

### Coming: Standalone Runner (In Development)

When `winwright run` ships:

```bat
winwright run C:\scripts\daily-sales-import.json
```

Pair with Windows Task Scheduler to run it every morning at 8:00 AM:

```powershell
$action = New-ScheduledTaskAction -Execute "winwright" -Argument "run C:\scripts\daily-sales-import.json"
$trigger = New-ScheduledTaskTrigger -Daily -At "08:00"
Register-ScheduledTask -TaskName "DailySalesImport" -Action $action -Trigger $trigger
```

Exit codes: `0` = all steps completed, `1` = a step failed, `2` = crash or error.

## Tips

- Record the task end-to-end in one go — include handling for any dialogs that appear
- If dates need to be dynamic (always "yesterday"), note this in your prompt:
  "When typing the date, always use yesterday's date — when replaying, compute it fresh"
  (The runner will use the date at replay time)
- Re-record when the app UI changes significantly — the recording takes 5-10 minutes and
  the result is good for months

## Limitations

- The standalone runner is in development — replay currently requires an agent
- RPA scripts don't include assertions — if you need to verify the task completed
  correctly (e.g., "confirm the Process button shows 'Done'"), use test mode instead
  (see [Use Case 06](01-scripted-ci.md))

---

*[Back to use cases](README.md)*
