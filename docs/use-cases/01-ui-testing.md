# AI-Powered UI Testing

> Test WinForms and WPF applications using plain-language instructions — no brittle selectors to maintain.

## The Problem

Traditional UI testing relies on hard-coded selectors — XPath, AutomationId, control paths.
When the UI changes (a button moves, a panel gets renamed, a new dialog appears), tests break.
Maintaining selectors across releases is tedious, and selector-based tests can't handle
unexpected dialogs or layout changes.

## How WinWright Helps

An AI agent uses `ww_find_elements` to discover controls by name, type, or content — not
by fixed paths. It reads the live element tree, decides what to click and where to type,
and asserts values using `ww_assert_value`. When the UI changes, the agent adapts.

## Prerequisites

- WinWright installed and configured as an MCP server (see [Quick Start](README.md#quick-start))
- The application under test must be a WinForms, WPF, or Win32 app with UIA-accessible controls

## Example: Test a WPF Login Flow

### 1. Start WinWright

```bash
winwright mcp
```

### 2. Tell Your Agent

> "Test the login page. Launch C:\TestApp\EmployeeApp.exe, enter username 'admin' and
> password 'test123' in the login form, click Sign In, then verify the dashboard heading
> contains 'Welcome'."

### 3. Tool Sequence

The agent calls these tools in order:

#### Launch the app

```json
ww_launch
  { "appPath": "C:\\TestApp\\EmployeeApp.exe" }
```

Response:

```json
{ "appId": "app-1a2b", "processId": 14820, "mainWindowTitle": "Employee Portal - Login" }
```

#### Take a snapshot to read the current UI

```json
ww_snapshot
  { "appId": "app-1a2b" }
```

Response (abridged):

```json
{
  "root": {
    "name": "Employee Portal - Login", "role": "Window",
    "children": [
      { "name": "Username", "role": "Edit", "automationId": "txtUsername" },
      { "name": "Password", "role": "Edit", "automationId": "txtPassword" },
      { "name": "Sign In", "role": "Button", "automationId": "btnSignIn" }
    ]
  }
}
```

#### Type username

```json
ww_type
  { "appId": "app-1a2b", "selector": "AutomationId:txtUsername",
    "text": "admin", "clearFirst": true }
```

Response:

```json
{ "success": true, "characterCount": 5 }
```

#### Type password

```json
ww_type
  { "appId": "app-1a2b", "selector": "AutomationId:txtPassword",
    "text": "test123", "clearFirst": true }
```

Response:

```json
{ "success": true, "characterCount": 7 }
```

#### Click Sign In

```json
ww_click
  { "appId": "app-1a2b", "selector": "Name:Sign In" }
```

Response:

```json
{ "success": true, "method": "InvokePattern" }
```

#### Wait for the dashboard to load

```json
ww_wait_for
  { "appId": "app-1a2b", "selector": "Name:Dashboard Heading", "timeoutMs": 5000 }
```

Response:

```json
{ "found": true, "elapsedMs": 1240 }
```

#### Assert the welcome heading

```json
ww_assert_value
  { "appId": "app-1a2b", "selector": "Name:Dashboard Heading",
    "op": "contains", "expected": "Welcome" }
```

Response:

```json
{ "passed": true, "actualValue": "Welcome, Admin", "expectedValue": "Welcome", "op": "contains" }
```

#### Capture a screenshot for the test report

```json
ww_screenshot
  { "appId": "app-1a2b" }
```

Response:

```json
{ "format": "png", "dataBase64": "iVBORw0KGgo..." }
```

### 4. Result

The agent reports:

> Login test passed. The dashboard loaded and the heading shows 'Welcome, Admin'.
> Screenshot captured.

## Configuration

No additional configuration required for UI testing. The default `winwright.json` allows
all read and click operations.

## Tips

- Use `ww_snapshot` before describing what to do — it gives the agent a full picture of
  what controls are visible right now
- If an element is inside a tab or collapsed panel, tell your agent: "expand the Settings panel
  first, then find the Theme dropdown"
- For timing-sensitive apps, add "wait for the dashboard to load before asserting" to your prompt
- `ww_assert_value` supports operators: `eq`, `contains`, `startsWith`, `regex`, `notEmpty`

## Limitations

- Apps that render everything on a custom canvas (no UIA tree) cannot be tested this way —
  use `ww_screenshot` and image analysis instead
- The agent works best when element names match visible labels; apps with poor
  accessibility (no `AutomationId`, no `Name` on controls) may require more descriptive prompts

---

*[Back to use cases](README.md)*
