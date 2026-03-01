# Scripted UI Test Automation for CI

> Record an AI session once, export a portable JSON script, and replay it in CI — zero token cost per run.

## The Problem

Running an AI agent for every CI build is expensive and non-deterministic.
AI-driven UI tests are useful during development, but CI needs fast, repeatable,
and cost-predictable test runs.

## How WinWright Helps

An AI agent explores the application once — discovers elements, executes actions,
embeds assertions — and the recording is exported as a deterministic JSON script.
The script runs in CI without an AI agent. The AI writes the test; the machine runs it.

**What works today:** recording, in-session correction, script export in test and RPA modes,
standalone CI replay via `winwright run` (no AI agent required), and selector healing via
`winwright heal` (probe broken selectors against a live UI and repair them automatically).

## Prerequisites

- WinWright configured as an MCP server in your AI agent —
  see [MCP Client Configuration](../../README.md#mcp-client-configuration) for stdio and HTTP setup
- The application under test must be launchable from a path

## Three Ways to Start a Recording

### Mode 1 — Describe Your App and Let the Agent Discover It

You describe what the app does and which screens to test. The agent launches the app,
reads the UIA element tree, plans the test cases, and records every interaction.

Tell your agent:

> "I want to create a test suite for the login and dashboard screens of this app.
> Launch C:\TestApp\EmployeeApp.exe and test: (1) login with valid credentials,
> (2) login with wrong password shows an error, (3) logout returns to login screen."

The agent plans TC-001, TC-002, TC-003, calls `ww_test_case_start` for each one,
discovers the controls through `ww_snapshot`, and records the interactions automatically.
**No selector knowledge required — the agent figures out the UI.**

### Mode 2 — Import Your Existing Manual Test Suite

If you already have manual test cases in Excel, Word, TestRail, CSV, or any
plain-text format, paste them into your prompt (or provide the file path):

> "Here are our manual test cases. Record each one as a test case in WinWright:
>
> TC-001: Login — Enter username 'admin', password 'test123', click Sign In,
> verify dashboard heading contains 'Welcome'
> TC-002: Invalid login — Enter username 'admin', password 'wrong', click Sign In,
> verify error message appears
> ..."

The agent parses the test cases from any format, calls `ww_test_case_start` with the
matching IDs and titles, navigates the app, and records each step. Your manual test
library becomes an automated script in one session.

### Mode 3 — Record an RPA Task (No Test Cases)

For repetitive workflows with no pass/fail assertions, skip `ww_test_case_start`
and record a flat step sequence. See [Use Case 04 — Scripted Desktop Automation](04-scripted-desktop-rpa.md).

## Part A: Recording a Session

### Step 1 — Start Recording

Tell your agent:

> "Start a recording session. I'm going to walk through the login flow and I want
> to export it as a reusable test script."

The agent calls:

```json
ww_record_start
  { "appId": "app-1a2b" }
```

Response:

```json
{ "started": true }
```

From this point, every successful interaction tool call (click, type, invoke, etc.)
is automatically stamped into the recording buffer.

> **What gets recorded vs not recorded:**
>
> - Recorded: every *successful* interaction (click, type, keyboard, select, set\_value)
> - Not recorded: read-only calls (snapshot, find\_elements, get\_value), failed tool calls,
>   and any call with `"record": false`

### Step 2 — Name the Test Case

Tell your agent:

> "Call this test case 'TC-001 — Login with valid credentials'."

```json
ww_test_case_start
  { "appId": "app-1a2b", "id": "TC-001", "title": "Login with valid credentials" }
```

Response:

```json
{ "id": "TC-001", "title": "Login with valid credentials" }
```

All subsequent steps are now associated with TC-001.

### Step 3 — Execute the Test

Tell your agent:

> "Launch C:\TestApp\EmployeeApp.exe, type 'admin' in the Username field and
> 'test123' in the Password field, then click Sign In."

The agent calls (each automatically recorded as TC-001 steps):

```json
ww_launch
  { "appPath": "C:\\TestApp\\EmployeeApp.exe" }
```

```json
ww_type
  { "appId": "app-1a2b", "selector": "AutomationId:txtUsername",
    "text": "admin", "clearFirst": true }
```

```json
ww_type
  { "appId": "app-1a2b", "selector": "AutomationId:txtPassword",
    "text": "test123", "clearFirst": true }
```

```json
ww_click
  { "appId": "app-1a2b", "selector": "Name:Sign In" }
```

### Step 4 — Embed an Assertion

Tell your agent:

> "Assert that the status bar at the bottom says 'Ready'."

```json
ww_assert_value
  { "appId": "app-1a2b", "selector": "Name:StatusBar",
    "property": "value", "op": "eq", "expected": "Ready",
    "message": "Status bar must show Ready after login" }
```

Response:

```json
{ "passed": true, "actualValue": "Ready", "expectedValue": "Ready", "op": "eq" }
```

Because recording is active, this assertion is **embedded into the last recorded step** —
when the script runs in CI, the runner replays the action and re-evaluates the assertion.

### Step 5 — Preview the Script Without Stopping

To check what will be exported without ending the recording:

Tell your agent: *"Show me what the script looks like so far."*

```json
ww_export_script
  { "appId": "app-1a2b", "stopRecording": false }
```

Response:

```json
{
  "script": "{ \"version\":\"1\", \"mode\":\"test\", ... }",
  "stepCount": 4,
  "assertionCount": 1
}
```

Recording is still active. You can inspect the JSON, verify the steps, and continue.

### Step 6 — Add More Test Cases

Tell your agent:

> "Now test the failed login scenario. Call it 'TC-002 — Login with wrong password'."

```json
ww_test_case_start
  { "appId": "app-1a2b", "id": "TC-002", "title": "Login with wrong password" }
```

`ww_test_case_start` automatically closes TC-001 when it opens TC-002.
All subsequent steps belong to TC-002.

### Step 7 — End the Last Test Case and Export

Tell your agent:

> "End the test case and export the full script. The app path is C:\TestApp\EmployeeApp.exe."

```json
ww_test_case_end
  { "appId": "app-1a2b" }
```

Response:

```json
{ "id": "TC-002", "stepCount": 3 }
```

```json
ww_export_script
  { "appId": "app-1a2b",
    "launchPath": "C:\\TestApp\\EmployeeApp.exe",
    "stopRecording": true }
```

Response:

```json
{
  "script": "{ ... }",
  "stepCount": 7,
  "assertionCount": 2
}
```

## Part B: Correcting a Recording

Mistakes during recording are normal. WinWright provides several correction mechanisms —
use whichever fits the situation.

### Correction 1 — Undo the Last Step

> "I accidentally clicked the wrong button. Remove the last step."

```json
ww_record_pop
  { "appId": "app-1a2b", "count": 1 }
```

Response:

```json
{ "removed": 1, "remaining": 5 }
```

### Correction 2 — Undo Multiple Steps

> "Those last three steps were wrong — I took a wrong turn."

```json
ww_record_pop
  { "appId": "app-1a2b", "count": 3 }
```

Response:

```json
{ "removed": 3, "remaining": 3 }
```

Continue from the known-good point.

### Correction 3 — Clear the Buffer and Start Over

> "The whole thing is wrong. Start fresh."

```json
ww_record_start
  { "appId": "app-1a2b" }
```

`ww_record_start` clears the buffer and all test case state. The session stays open —
you do not need to relaunch the app.

### Correction 4 — Fix a Wrong Test Case Boundary

> "I forgot to close TC-001 before starting the next scenario."

```json
ww_test_case_end
  { "appId": "app-1a2b" }
```

Then open the next case:

```json
ww_test_case_start
  { "appId": "app-1a2b", "id": "TC-002", "title": "Failed login" }
```

Note: calling `ww_test_case_start` with a new ID **automatically** closes the previous
test case — so `ww_test_case_end` is only needed when you want explicit control over timing.

### Correction 5 — Prevent Recording an Exploratory Click

Before the click:

> "Click the Settings panel to see what's inside it, but don't record this step."

The agent calls:

```json
ww_click
  { "appId": "app-1a2b", "selector": "Name:Settings", "record": false }
```

`"record": false` suppresses auto-recording for that specific call. No pop needed.

### Correction 6 — Fix a Bad Assertion

> "The assertion I embedded has the wrong expected value — it should be 'Logged in', not 'Ready'."

Pop the last step (which had the assertion embedded):

```json
ww_record_pop
  { "appId": "app-1a2b", "count": 1 }
```

Redo the action that should trigger the assertion (so it gets recorded again):

```json
ww_click
  { "appId": "app-1a2b", "selector": "Name:Sign In" }
```

Now embed the corrected assertion:

```json
ww_assert_value
  { "appId": "app-1a2b", "selector": "Name:StatusBar",
    "property": "value", "op": "eq", "expected": "Logged in" }
```

### Correction 7 — Preview Before Committing

Never sure if the recording is right? Export without stopping to inspect:

```json
ww_export_script
  { "appId": "app-1a2b", "stopRecording": false }
```

Parse the returned JSON, verify the `testCases` and `steps`, then continue or correct.
This is especially useful before a long test case — verify the first few steps are right
before recording the rest.

## Part C: Exported Script Format

### Test Mode (when test cases were used)

```json
{
  "version": "1",
  "appId": "app-1a2b",
  "mode": "test",
  "launchPath": "C:\\TestApp\\EmployeeApp.exe",
  "runConfig": {
    "captureScreenshots": true,
    "continueOnFailure": false
  },
  "testCases": [
    {
      "id": "TC-001",
      "title": "Login with valid credentials",
      "steps": [
        {
          "tool": "ww_type",
          "selector": "AutomationId:txtUsername",
          "extra": "{\"text\":\"admin\",\"clearFirst\":true}",
          "timestamp": "2026-02-28T14:10:01Z"
        },
        {
          "tool": "ww_type",
          "selector": "AutomationId:txtPassword",
          "extra": "{\"text\":\"test123\",\"clearFirst\":true}",
          "timestamp": "2026-02-28T14:10:02Z"
        },
        {
          "tool": "ww_click",
          "selector": "Name:Sign In",
          "timestamp": "2026-02-28T14:10:03Z",
          "assertion": {
            "type": "assert",
            "selector": "Name:StatusBar",
            "property": "value",
            "op": "eq",
            "expected": "Ready",
            "message": "Status bar must show Ready after login"
          }
        }
      ]
    },
    {
      "id": "TC-002",
      "title": "Login with wrong password",
      "steps": [ "..." ]
    }
  ]
}
```

> **Screenshot evidence:** with `captureScreenshots: true` in `runConfig` (or `--screenshots`
> on the CLI), the runner saves a screenshot before each step and on every failure.
> Files are named `step_NNN_before.png` and `step_NNN_fail.png`. Override the output
> directory with `--screenshots-dir ./evidence` or by setting `screenshotDir` in `runConfig`.

### RPA Mode (no test cases — flat step list)

When no `ww_test_case_start` was called, the script exports with a flat `steps[]`:

```json
{
  "version": "1",
  "appId": "app-1a2b",
  "mode": "rpa",
  "launchPath": "C:\\MyTask\\app.exe",
  "steps": [
    { "tool": "ww_click",  "selector": "Name:New Report",   "timestamp": "..." },
    { "tool": "ww_type",   "selector": "Name:Description",  "timestamp": "..." },
    { "tool": "ww_click",  "selector": "Name:Submit",       "timestamp": "..." }
  ]
}
```

RPA mode has no assertions and no test case grouping. The runner replays steps in order.

## Part D: CI Replay

### Run Via Agent (Always Available)

The exported JSON is a portable artifact. Ask your agent to replay it:

> "Replay this script file: C:\scripts\login-suite.json"

The agent reads the JSON, reconstructs the steps, and executes them.

### Standalone Runner (Available Now)

Drop the script into your pipeline — no AI agent, no token cost:

```yaml
# Azure DevOps / GitHub Actions example
- name: Run UI regression
  run: winwright run login-suite.json --format junit --output test-results.xml

# With screenshot evidence captured on each failure:
- name: Run UI regression with evidence
  run: winwright run login-suite.json --format junit --output test-results.xml --screenshots --screenshots-dir ./evidence

# Exit codes: 0 = all pass | 1 = assertion failures | 2 = error/crash
```

The runner executes steps directly using the WinWright automation engine.

**Text mode output (default):**

```text
WinWright Script Runner — login-suite.json
==========================================
[PASS]   TC-001  2.3s  Login with valid credentials
[FAIL]   TC-002  1.1s  Login with wrong password
         Step 2: ww_assert_value #lblError contains 'Username or password incorrect'
         Expected: contains 'Username or password incorrect' | Actual: ''
         Evidence: TC-002_fail.png
==========================================
Results: 1 passed, 1 failed (2 total)  |  Duration: 3.4s
```

**JUnit XML output (`--format junit`, for CI dashboards):**

```xml
<testsuite name="login-suite.json" tests="2" failures="1" errors="0" time="3.4">
  <testcase name="TC-001 — Login with valid credentials" time="2.3" />
  <testcase name="TC-002 — Login with wrong password" time="1.1">
    <failure message="Assertion failed: #lblError contains 'Username or password incorrect'">
      Step 2: ww_assert_value selector=#lblError
      Expected: contains 'Username or password incorrect'
      Actual:   ''
      Screenshot: TC-002_fail.png
    </failure>
  </testcase>
</testsuite>
```

## Part E: Selector Resilience and Healing

Scripts can break when the app UI changes between releases. WinWright addresses this
at three levels, from automatic to agent-assisted.

### Layer 1 — Robust Selector Syntax (Available Now)

At record time, prefer stable selectors. Priority order:

| Selector | Stability | Example |
|----------|-----------|---------|
| `AutomationId:txtUsername` | Most stable — survives label renames | WPF with `x:Name` or `AutomationProperties.AutomationId` |
| `Name:Sign In` | Stable when the button label doesn't change | Use when no AutomationId is set |
| `ControlType:Button` + other constraints | Fragile — position-dependent | Avoid when possible |

Prefer `AutomationId` for everything you can. If the developer set it, use it.

### Layer 2 — Fingerprint Fallback Chain

When a step's primary selector fails at runtime, the runner automatically tries
fallback selectors derived from a **fingerprint** captured at record time:

```text
Attempt 1  Primary selector as recorded   "#btnLogin"
Attempt 2  AutomationId shorthand         "#btnLogin"  (e.g. via "#{automationId}")
Attempt 3  Name + ControlType             [name="Login"][controlType="Button"]
Attempt 4  Name alone                     Name=Login
```

If any fallback succeeds, the runner logs `[HEALED]` to stderr — visible but not fatal.
Healing is always logged because a renamed button may signal a real business logic change.

### Layer 3 — Selector Heal Pass

When the UI changes significantly and selector fallbacks also fail, run:

```bash
winwright heal my-suite.json \
  --app "C:\MyApp\MyApp.exe" \
  --output my-suite-v2.json
```

The healer:

1. Launches the app (or attaches to a running process via `--pid`)
2. For each step that carries a selector: probes it with the live UI tree to check whether
   it still resolves
3. For any broken selector: performs fuzzy matching across all visible elements using
   AutomationId similarity (Levenshtein) and Name similarity (Jaccard token overlap)
4. Assigns one of four outcomes per step:
   - **Ok** — selector still works; no change
   - **Healed** — a match above the confidence threshold (default 0.70) was found;
     selector updated automatically
   - **Suggested** — best match is above 0.40 but below 0.70; candidates listed for
     human review
   - **Unresolvable** — no similar element found; manual intervention required
5. Writes the healed script to `--output` and prints a summary to stderr

Steps marked **Suggested** or **Unresolvable** require a human decision — they may
represent genuine workflow changes, not just renamed controls.

The same healing logic is also available as an MCP tool (`ww_heal_script`) so an AI agent
can repair a specific script interactively without a full command-line pass.

## Tips

- Record with a real, representative run — the agent should complete the full user flow,
  not just click through the fastest path
- Use `ww_test_case_start` for every distinct user scenario — reports are at the test case level
- Use `ww_export_script stopRecording=false` mid-session to inspect the script before committing
- Use `AutomationId` selectors wherever possible — they survive label renames and layout changes
- Keep test cases focused: one scenario per test case makes failures easier to diagnose

## Limitations

- The fingerprint fallback schema and runner-side fallback chain (Layer 2) are implemented;
  MCP tool handlers do not yet populate fingerprint fields at record time, so recorded scripts
  currently carry no fingerprint data — the fallback chain activates automatically once tool
  handlers are updated to pass element properties to `Record()`
- `winwright heal` probes selectors against a live running application — the target app
  must be running and reachable during the heal pass
- `ww_assert_value` is the only supported assertion type; complex multi-element or
  cross-window assertions require custom logic in the MCP session

---

*[Back to use cases](README.md)*
