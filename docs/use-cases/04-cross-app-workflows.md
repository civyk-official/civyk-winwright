# Cross-App Workflows

> Automate workflows that span desktop apps and browser in a single session — read from an ERP, submit to a web portal, download the PDF.

## The Problem

Real work spans multiple applications. You read an invoice number from your accounting
software, look it up in a web portal, download a PDF, and attach it to an email.
Each app has its own interface. No single automation tool covers desktop and browser
in one session without complex integration.

## How WinWright Helps

WinWright runs desktop and browser tools in the same MCP session. The agent reads
a value from a desktop app, switches to Chrome or Edge, navigates a web page, fills
a form, and returns to the desktop — all in one conversation.

## Prerequisites

- WinWright installed and configured as an MCP server
- For the browser phase: Chrome or Edge launched with remote debugging enabled.

  ```bat
  chrome.exe --remote-debugging-port=9222 --user-data-dir=C:\Temp\cdp-profile
  ```

- The desktop app must be running (use `ww_attach`) or launchable (use `ww_launch`)

## Example: Get an Order from ERP and Download Its Invoice from the Supplier Portal

### 1. Start WinWright

```bash
winwright mcp
```

### 2. Tell Your Agent

> "Get order #ORD-4821 from our ERP system and download its invoice PDF from the
> supplier portal at `https://portal.example.com`. The ERP is already running as PID 7640."

### 3. Tool Sequence

#### Phase 1 — Desktop: Read from the ERP

**Attach to the running ERP:**

```json
ww_attach
  { "processId": 7640 }
```

Response:

```json
{ "appId": "app-erp1", "processId": 7640, "mainWindowTitle": "OrderManager ERP" }
```

**Navigate to the order search:**

```json
ww_click
  { "appId": "app-erp1", "selector": "Name:Orders" }
```

**Type the order ID in the search box:**

```json
ww_type
  { "appId": "app-erp1", "selector": "Name:Order Search",
    "text": "ORD-4821", "clearFirst": true, "sendEnter": true }
```

**Read the supplier invoice reference from the detail panel:**

```json
ww_get_value
  { "appId": "app-erp1", "selector": "Name:Supplier Invoice Ref" }
```

Response:

```json
{ "value": "SUP-INV-9934-2026", "property": "value" }
```

The agent now has the supplier invoice reference it needs for the portal.

#### Phase 2 — Browser: Download from the Supplier Portal

**Connect to Chrome (already running with debugging port):**

```json
ww_browser_connect
  { "debugPort": 9222 }
```

Response:

```json
{ "connected": true, "targets": 2, "activeTarget": "New Tab - Chrome" }
```

**Navigate to the supplier portal:**

```json
ww_browser_navigate
  { "url": "https://portal.example.com/invoices" }
```

Response:

```json
{ "navigated": true, "title": "Supplier Portal — Invoices", "url": "https://portal.example.com/invoices" }
```

**Find and fill the invoice search field:**

```json
ww_browser_find
  { "selector": "#invoiceSearch" }
```

```json
ww_browser_type
  { "selector": "#invoiceSearch", "text": "SUP-INV-9934-2026", "clearFirst": true }
```

**Click Search:**

```json
ww_browser_click
  { "selector": "button[type='submit']" }
```

**Find the download link:**

```json
ww_browser_find
  { "selector": "a[href$='.pdf']" }
```

Response:

```json
{ "found": true, "text": "Download Invoice PDF", "href": "/invoices/SUP-INV-9934-2026.pdf" }
```

**Click Download:**

```json
ww_browser_click
  { "selector": "a[href$='.pdf']" }
```

**Screenshot the confirmation:**

```json
ww_browser_screenshot
  { }
```

### 4. Result

The agent reports:

> Order ORD-4821 located in ERP. Supplier invoice reference: SUP-INV-9934-2026.
> PDF download started from the supplier portal.
> Screenshot shows "Download complete" confirmation.

## Tips

- Both `app-erp1` (desktop) and the browser share the same WinWright session —
  switching between them is just a matter of which tool you call
- If the browser opens a file-save dialog, WinWright can handle it:
  see [Use Case 08 — Dialog Handling](08-dialog-handling.md)
- You can interleave desktop and browser steps freely:
  "Read the customer email from the ERP, open Gmail in Chrome, and draft an email to that address"

## Limitations

- Chrome or Edge must be launched **before** WinWright connects — you cannot start the
  browser from WinWright (use `ww_shell` with `allowShell: true` if you need to)
- Firefox is not supported (no Chrome DevTools Protocol)
- Authenticated web sessions must already be logged in — WinWright does not manage
  browser cookies or credentials

---

*[Back to use cases](README.md)*
