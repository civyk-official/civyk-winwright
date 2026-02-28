# Accessibility Auditing

> Traverse the full UIA element tree, check WCAG-relevant properties, and generate a structured compliance report — without opening Inspect.exe.

## The Problem

Windows applications must be accessible — screen readers depend on UIA properties
like `Name`, `Role`, and `KeyboardShortcut` being set correctly. Manual auditing is slow:
open the app, inspect each control, check properties one by one. No existing tool
generates a structured report automatically.

## How WinWright Helps

WinWright exposes the full UIA element tree. An AI agent traverses every control,
checks for missing names, unlabelled buttons, empty tooltips, and broken keyboard
navigation paths, then generates a structured report of findings.

## Prerequisites

- WinWright installed and configured as an MCP server
- The app to audit must be running or launchable

## Example: Audit a WPF Employee App

### 1. Start WinWright

```bash
winwright mcp
```

### 2. Tell Your Agent

> "Check this app for accessibility issues: unlabelled buttons, empty text field labels,
> and controls unreachable by keyboard. Launch C:\TestApp\EmployeeApp.exe.
> Give me a structured report of issues found."

### 3. Tool Sequence

#### Launch the app

```json
ww_launch
  { "appPath": "C:\\TestApp\\EmployeeApp.exe" }
```

Response:

```json
{ "appId": "app-a1b2", "processId": 18320, "mainWindowTitle": "Employee Portal" }
```

#### Capture the full element tree

```json
ww_snapshot
  { "appId": "app-a1b2", "includeValues": true, "maxElements": 500 }
```

This returns the full tree with `name`, `controlType`, `automationId`, `isKeyboardFocusable`,
`isEnabled`, and `isVisible` for every element.

#### Find all buttons and check for missing names

```json
ww_find_elements
  { "appId": "app-a1b2", "controlType": "Button" }
```

Response:

```json
{
  "elements": [
    { "handleId": "h-c1", "name": "Sign In",    "automationId": "btnSignIn",  "isKeyboardFocusable": true },
    { "handleId": "h-c2", "name": "",           "automationId": "btnOptions", "isKeyboardFocusable": true },
    { "handleId": "h-c3", "name": "Cancel",     "automationId": "btnCancel",  "isKeyboardFocusable": true },
    { "handleId": "h-c4", "name": "",           "automationId": "",           "isKeyboardFocusable": false }
  ],
  "count": 4
}
```

The agent identifies:

- `h-c2`: button with `automationId="btnOptions"` but empty `Name` — **missing label**
- `h-c4`: button with no `Name`, no `AutomationId`, and `isKeyboardFocusable: false` — **inaccessible**

#### Find all edit controls and check for labels

```json
ww_find_elements
  { "appId": "app-a1b2", "controlType": "Edit" }
```

Response:

```json
{
  "elements": [
    { "handleId": "h-d1", "name": "Username", "automationId": "txtUsername" },
    { "handleId": "h-d2", "name": "",         "automationId": "txtPassword" },
    { "handleId": "h-d3", "name": "",         "automationId": "txtSearch" }
  ]
}
```

The agent flags `txtPassword` and `txtSearch` — both have empty `Name` properties.
Screen readers cannot announce what these fields are for.

#### Test keyboard navigation (tab order)

```json
ww_keyboard
  { "appId": "app-a1b2", "keys": ["Tab"] }
```

```json
ww_get_focused_element
  { "appId": "app-a1b2" }
```

Response:

```json
{ "name": "Username", "controlType": "Edit", "automationId": "txtUsername" }
```

The agent presses Tab repeatedly and calls `ww_get_focused_element` after each press to
trace the tab order. If an interactive control is skipped (focus jumps over it),
it is flagged as keyboard-unreachable.

### 4. Agent Output

The agent produces a structured report:

```text
Accessibility Audit — Employee Portal
======================================

ISSUES FOUND: 5

[HIGH] Unlabelled button: automationId="btnOptions"
       Control type: Button | Name: (empty) | IsKeyboardFocusable: true
       Fix: Set AutomationProperties.Name="Options" in XAML

[CRITICAL] Inaccessible button: no Name, no AutomationId
           Control type: Button | IsKeyboardFocusable: false
           Fix: Add AutomationId, set Name, ensure IsTabStop=true

[MEDIUM] Edit field missing label: automationId="txtPassword"
         Name is empty — screen readers cannot announce field purpose
         Fix: Set AutomationProperties.LabeledBy or AutomationProperties.Name

[MEDIUM] Edit field missing label: automationId="txtSearch"
         Same issue as txtPassword

[LOW] Tab order inconsistency: Cancel button (btnCancel) is reached before
      the Search field (txtSearch) in the tab sequence
      Recommend: review TabIndex values

PASSED: 3 buttons labelled, 1 of 4 edit fields labelled
```

## Tips

- Run the audit on every main screen of the app — send: "Now navigate to the Reports
  tab and audit that screen too"
- For image controls, check the `Name` property — it serves as alt text for screen readers
- After fixing issues, re-run the audit with the same prompt to verify improvements

## Limitations

- WinWright reads what UIA exposes — controls invisible to UIA (custom-drawn without
  automation peers) will not appear in the tree
- Color contrast and visual spacing checks require screenshots + image analysis,
  not UIA properties

---

*[Back to use cases](README.md)*
