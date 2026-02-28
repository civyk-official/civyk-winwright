# Autonomous Desktop Automation

> Automate repetitive Windows tasks using plain-language instructions — no scripts to write or maintain.

## The Problem

Repetitive desktop tasks — filling forms, copying data between apps, clicking through
multi-step workflows — eat hours. Traditional automation (AutoHotkey, Power Automate)
requires scripting every step upfront. When the workflow changes, the script breaks.

## How WinWright Helps

An AI agent sees the screen through `ww_snapshot`, understands the current state, and
decides what to do next. It launches apps, navigates menus, types into fields, clicks
buttons, and verifies results — all through natural conversation.

## Prerequisites

- WinWright installed and configured as an MCP server
- The target app must expose its controls via Windows UI Automation (most WinForms, WPF,
  and Win32 apps do)

## Example: Fill a Monthly Expense Report

### 1. Start WinWright

```bash
winwright mcp
```

### 2. Tell Your Agent

> "Open the expense report app at C:\Finance\ExpenseApp.exe. Fill in: date = today,
> amount = 120.50, category = Travel, description = 'Client meeting taxi'. Then submit
> the report and take a screenshot of the confirmation."

### 3. Tool Sequence

#### Launch the app

```json
ww_launch
  { "appPath": "C:\\Finance\\ExpenseApp.exe" }
```

Response:

```json
{ "appId": "app-3c4d", "processId": 9240, "mainWindowTitle": "Expense Report Manager" }
```

#### Read the current UI state

```json
ww_snapshot
  { "appId": "app-3c4d" }
```

Response (abridged):

```json
{
  "root": {
    "name": "Expense Report Manager", "role": "Window",
    "children": [
      { "name": "New Report", "role": "Button" },
      { "name": "Reports List", "role": "DataGrid" }
    ]
  }
}
```

#### Click New Report

```json
ww_click
  { "appId": "app-3c4d", "selector": "Name:New Report" }
```

Response:

```json
{ "success": true }
```

#### Read the form

```json
ww_snapshot
  { "appId": "app-3c4d" }
```

Response (abridged):

```json
{
  "children": [
    { "name": "Date", "role": "Edit", "automationId": "txtDate" },
    { "name": "Amount", "role": "Edit", "automationId": "txtAmount" },
    { "name": "Category", "role": "ComboBox", "automationId": "cmbCategory" },
    { "name": "Description", "role": "Edit", "automationId": "txtDescription" },
    { "name": "Submit", "role": "Button" }
  ]
}
```

#### Fill the date field

```json
ww_type
  { "appId": "app-3c4d", "selector": "AutomationId:txtDate",
    "text": "2026-02-28", "clearFirst": true }
```

Response:

```json
{ "success": true, "characterCount": 10 }
```

#### Fill the amount

```json
ww_type
  { "appId": "app-3c4d", "selector": "AutomationId:txtAmount",
    "text": "120.50", "clearFirst": true }
```

Response:

```json
{ "success": true, "characterCount": 6 }
```

#### Select a category from the combo box

```json
ww_select
  { "appId": "app-3c4d", "selector": "AutomationId:cmbCategory", "value": "Travel" }
```

Response:

```json
{ "success": true, "selectedValue": "Travel" }
```

#### Fill the description

```json
ww_type
  { "appId": "app-3c4d", "selector": "AutomationId:txtDescription",
    "text": "Client meeting taxi", "clearFirst": true }
```

Response:

```json
{ "success": true, "characterCount": 19 }
```

#### Submit the form

```json
ww_click
  { "appId": "app-3c4d", "selector": "Name:Submit" }
```

Response:

```json
{ "success": true }
```

#### Capture the confirmation

```json
ww_screenshot
  { "appId": "app-3c4d" }
```

### 4. Result

The agent reports:

> Expense report submitted. Date: 2026-02-28, Amount: 120.50, Category: Travel.
> Confirmation screen captured — report ID #EXP-20260228-0042 shown.

## Tips

- If the app shows a confirmation dialog, add "handle any dialogs that appear" to your prompt.
  See [Use Case 08 — Dialog Handling](08-dialog-handling.md) for patterns.
- For dropdown lists that don't respond to `ww_select`, try: "click the Category dropdown, then
  click Travel in the list that appears"
- `ww_snapshot` returns the current element tree — calling it before acting helps the agent
  locate controls even when the form layout changes between versions

## Limitations

- Some admin operations (registry, services, process kill) are disabled by default;
  enable them in `winwright.json` if needed
- Controls that respond only to mouse hover (not keyboard) may need `ww_mouse_move` first

---

*[Back to use cases](README.md)*
