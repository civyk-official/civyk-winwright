# Legacy App Data Extraction

> Read data from enterprise apps with no API — grids, labels, and multi-page reports — and export it as structured output.

## The Problem

Enterprise apps — ERP systems, medical records, government portals, internal
line-of-business tools — often have no API and no export feature. Data is locked
behind a GUI that was built 15 years ago. Getting data out means manual copy-paste
or expensive vendor integrations.

## How WinWright Helps

If Windows UI Automation can see a control, WinWright can read its value. The AI
agent navigates the app, reads grids row by row, extracts text from labels and fields,
and structures the output. No API needed — just the running application.

## Prerequisites

- WinWright configured as an MCP server in your AI agent —
  see [MCP Client Configuration](../../README.md#mcp-client-configuration) for stdio and HTTP setup
- The target app must be running (use `ww_attach` to connect without launching)
- The data grid or table must be UIA-accessible (most WinForms DataGridView, ListView,
  and WPF DataGrid controls are)

## Example: Extract 5,000 Invoices from a WinForms App

### 1. Tell Your Agent

> "Connect to the running Invoicing app (PID 14320) and extract all invoices from
> July 2025 into a table with columns: Date, Invoice Number, Amount, Status.
> The list is paginated — keep reading pages until there are no more."

### 2. Tool Sequence

#### Attach to the running app

```json
ww_attach
  { "processId": 14320 }
```

Response:

```json
{ "appId": "app-5e6f", "processId": 14320, "mainWindowTitle": "Invoicing System v4.2" }
```

#### Find the data grid

```json
ww_query
  { "appId": "app-5e6f", "selector": "type=DataGrid" }
```

Response:

```json
{
  "elements": [
    { "handleId": "h-7a8b", "name": "Invoice List", "automationId": "grdInvoices",
      "controlType": "DataGrid", "bounds": { "x": 10, "y": 80, "width": 980, "height": 620 } }
  ],
  "count": 1
}
```

#### Read the first batch of rows

```json
ww_get_table_data
  { "appId": "app-5e6f", "handleId": "h-7a8b",
    "columns": ["Date", "Invoice No", "Amount", "Status"],
    "rowFrom": 0, "rowTo": 199 }
```

Response:

```json
{
  "columns": ["Date", "Invoice No", "Amount", "Status"],
  "rows": [
    ["2025-07-01", "INV-10042", "1250.00", "Paid"],
    ["2025-07-01", "INV-10043", "890.50",  "Pending"],
    ["2025-07-02", "INV-10044", "3400.00", "Paid"]
  ],
  "totalRowCount": 5000,
  "isVirtualized": true,
  "truncated": true
}
```

The agent sees `truncated: true` and `totalRowCount: 5000` — it knows to paginate.

#### Navigate to the next page

```json
ww_click
  { "appId": "app-5e6f", "selector": "Name:Next Page" }
```

Response:

```json
{ "success": true }
```

#### Read the next batch

```json
ww_get_table_data
  { "appId": "app-5e6f", "handleId": "h-7a8b",
    "columns": ["Date", "Invoice No", "Amount", "Status"],
    "rowFrom": 0, "rowTo": 199 }
```

The agent repeats this pattern — click Next, read 200 rows — until it has all 5,000 rows.

### 3. Result

The agent assembles the data and responds:

> Extracted 5,000 invoices from July 2025 across 25 pages.
>
> | Date | Invoice No | Amount | Status |
> |------|-----------|--------|--------|
> | 2025-07-01 | INV-10042 | 1250.00 | Paid |
> | 2025-07-01 | INV-10043 | 890.50 | Pending |
> | ... | ... | ... | ... |
>
> Summary: 3,847 Paid, 1,153 Pending. Total: $4,821,340.50

The agent can write this to a file if `allowFileWrite` is enabled:

> "Save the extracted data as C:\exports\invoices-july-2025.csv"

## Extracting from Labels and Fields

For apps that display data in individual fields (not grids):

```json
ww_get_value
  { "appId": "app-5e6f", "selector": "Name:Invoice Number" }
```

Response:

```json
{ "value": "INV-10042", "property": "value" }
```

Tell your agent: "Read all the fields in the Invoice Details panel and return them as a table."
The agent calls `ww_query` to discover all controls, then `ww_get_value` on each.

## Tips

- Tell the agent the total number of records if you know it — it can plan the pagination loop
- For tree views, say: "expand each top-level node and read all child items"
- If the app filters by date range, describe the filter steps: "set the From Date to 2025-07-01
  and To Date to 2025-07-31, then click Apply before extracting"

## Limitations

- Controls rendered as images or custom-drawn without UIA peers cannot be read — use
  `ww_screenshot` and ask the agent to extract data from the image
- Very large extractions (50,000+ rows) are slow through UIA — batch reads help, but
  a direct database connection is faster if available

---

*[Back to use cases](README.md)*
