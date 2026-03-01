# Dialog and Modal Handling

> Detect unexpected dialogs after every click, handle Save/Discard confirmations, file-save prompts, and MessageBox popups — without breaking the automation flow.

## The Problem

Automated workflows break when unexpected dialogs appear. A "Save changes?" confirmation
after clicking a menu item, a "File already exists — overwrite?" prompt, or a
validation MessageBox — all block the UI until dismissed. Traditional scripts that
don't account for these popups simply hang.

## How WinWright Helps

After each action, the agent can check whether a new modal window appeared. When
detected, it reads the dialog's content and buttons, and clicks the right one.
WinWright handles UIA-based dialogs (WPF, WinForms) and Win32 MessageBox popups.

## Prerequisites

- WinWright configured as an MCP server in your AI agent —
  see [MCP Client Configuration](../../README.md#mcp-client-configuration) for stdio and HTTP setup
- The target app and its dialogs must be UIA-accessible

## Pattern 1 — Detect and Handle Confirmation Dialogs

### Tell Your Agent

> "Edit the customer record for 'Acme Corp': change the contact name to 'John Smith'
> and save. Handle any confirmation dialogs that appear."

### Tool Sequence

#### Open the customer record

```json
ww_query
  { "appId": "app-1a2b", "selector": "Name:Acme Corp" }
```

```json
ww_double_click
  { "appId": "app-1a2b", "selector": "Name:Acme Corp" }
```

#### Edit the contact name

```json
ww_type
  { "appId": "app-1a2b", "selector": "Name:Contact Name",
    "text": "John Smith", "clearFirst": true }
```

#### Click Save

```json
ww_click
  { "appId": "app-1a2b", "selector": "Name:Save" }
```

#### Check if a dialog appeared

After any click that might trigger a dialog, the agent calls:

```json
ww_query
  { "appId": "app-1a2b", "selector": "type=Window" }
```

Response — dialog detected:

```json
{
  "elements": [
    { "handleId": "h-dlg1", "name": "Confirm Save",
      "controlType": "Window", "isModal": true }
  ]
}
```

#### Read the dialog content

```json
ww_snapshot
  { "appId": "app-1a2b", "windowId": "h-dlg1" }
```

Response:

```json
{
  "root": {
    "name": "Confirm Save", "role": "Window",
    "children": [
      { "name": "Save changes to Acme Corp?", "role": "Text" },
      { "name": "Save",    "role": "Button" },
      { "name": "Discard", "role": "Button" },
      { "name": "Cancel",  "role": "Button" }
    ]
  }
}
```

#### Click the right button

```json
ww_click
  { "appId": "app-1a2b", "windowId": "h-dlg1", "selector": "Name:Save" }
```

Response:

```json
{ "success": true }
```

The dialog closes and the record is saved.

## Pattern 2 — Handle a File-Save Dialog

### Tell Your Agent

> "Export the report to C:\reports\q1-2026.xlsx. Handle the file-save dialog."

After the export menu click triggers the save dialog:

```json
ww_query
  { "appId": "app-1a2b", "selector": "type=Window" }
```

Response:

```json
{ "elements": [{ "handleId": "h-save", "name": "Save As", "controlType": "Window" }] }
```

#### Type the file path

```json
ww_type
  { "appId": "app-1a2b", "windowId": "h-save",
    "selector": "Name:File name",
    "text": "C:\\reports\\q1-2026.xlsx", "clearFirst": true }
```

#### Click Save

```json
ww_click
  { "appId": "app-1a2b", "windowId": "h-save", "selector": "Name:Save" }
```

#### Handle the "file already exists" overwrite prompt (if it appears)

```json
ww_query
  { "appId": "app-1a2b", "selector": "type=Window" }
```

```json
ww_click
  { "appId": "app-1a2b", "windowId": "h-overwrite", "selector": "Name:Yes" }
```

## Pattern 3 — Handle Win32 MessageBox Popups

Some WinForms apps show `MessageBox.Show()` which is a Win32 dialog — not accessible
via standard UIA tree traversal. WinWright handles this automatically:

```json
ww_handle_message_box
  { "appId": "app-1a2b", "button": "OK" }
```

Response:

```json
{ "handled": true, "buttonClicked": "OK", "messageText": "Operation completed successfully." }
```

Supported buttons: `OK`, `Cancel`, `Yes`, `No`, `Abort`, `Retry`, `Ignore`.

## Pattern 4 — Proactive Dialog Waiting

When you know a dialog is coming (e.g., after clicking Delete):

```json
ww_wait_for_dialog
  { "appId": "app-1a2b", "timeoutMs": 5000 }
```

Response:

```json
{ "found": true, "windowId": "h-dlg2", "title": "Confirm Delete", "elapsedMs": 340 }
```

This is more reliable than polling with `ww_query` — it waits for the dialog
to appear rather than checking immediately.

## Telling Your Agent to Handle Dialogs Automatically

Add this to any automation prompt:

> "Handle any confirmation dialogs that appear. If asked to Save or Discard, choose Save.
> If asked Yes or No about overwriting, choose Yes. Dismiss any error popups with OK."

The agent will apply this policy throughout the session without being reminded for each step.

## Tips

- Scope dialog searches with `windowId` to avoid confusing the main window with the dialog
- For apps that show many dialogs, list the expected ones in your prompt: "There may be
  a 'License agreement' dialog on first run — accept it and continue"
- `ww_expect_dialog` can be used to assert that a specific dialog appeared (useful in test
  recordings as a verification step)

## Limitations

- Custom-drawn dialog overlays that do not create a separate Win32 window (in-canvas popups)
  are not detectable via `ww_query` — use `ww_screenshot` and ask the agent to describe
  what it sees
- Some protected system dialogs (UAC elevation prompts) cannot be interacted with via UIA

---

*[Back to use cases](README.md)*
