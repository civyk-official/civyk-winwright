# Bulk Data Validation

> Drive an app through 50+ records automatically, compare each displayed value against a reference table, and get a pass/fail summary with discrepancy details.

## The Problem

QA and finance teams regularly need to verify that an application displays the correct
values for a large set of inputs — pricing checks, tax calculations, inventory levels,
or order totals. Doing this manually for 50 or 500 records is slow and error-prone.
Writing a traditional automation script for each app is costly.

## How WinWright Helps

You provide the reference data (CSV, table, or paste it directly). The agent
iterates through each row: enters the search key, reads the displayed value, and
compares it against the expected value. It produces a structured pass/fail report
with the actual values for every discrepancy.

## Prerequisites

- WinWright configured as an MCP server in your AI agent —
  see [MCP Client Configuration](../../README.md#mcp-client-configuration) for stdio and HTTP setup
- The target app must be running or launchable
- Your reference data: a CSV, spreadsheet, or list of key-value pairs

## Example: Validate Prices for 50 Products

### 1. Tell Your Agent

> "I'll give you a CSV of product codes and expected prices. For each one, search for
> the product in the PricingApp, read the displayed price, and tell me if it matches.
> The app is running at PID 21440. Here's the data:
>
> PROD-001, 29.99
> PROD-002, 14.50
> PROD-003, 89.00
> ... (50 rows)"

### 2. Tool Sequence

The agent parses the CSV and enters a loop — for each product code:

#### Attach to the running app (once)

```json
ww_attach
  { "processId": 21440 }
```

Response:

```json
{ "appId": "app-7g8h", "processId": 21440, "mainWindowTitle": "PricingApp v3" }
```

#### For each product row — search by product code

```json
ww_type
  { "appId": "app-7g8h", "selector": "AutomationId:txtSearch",
    "text": "PROD-001", "clearFirst": true, "sendEnter": true }
```

#### Wait for the result to load

```json
ww_wait
  { "mode": "value", "appId": "app-7g8h", "selector": "AutomationId:lblPrice",
    "op": "notEmpty", "timeoutMs": 3000 }
```

#### Assert the displayed price matches the expected value

```json
ww_assert_value
  { "appId": "app-7g8h", "selector": "AutomationId:lblPrice",
    "property": "value", "op": "eq", "expected": "29.99",
    "message": "PROD-001 price mismatch" }
```

Response — pass:

```json
{ "passed": true, "actualValue": "29.99", "expectedValue": "29.99", "op": "eq" }
```

Response — fail:

```json
{ "passed": false, "actualValue": "32.50", "expectedValue": "29.99", "op": "eq",
  "failMessage": "PROD-001 price mismatch" }
```

The agent collects every result and moves to the next row.

### 3. Result

After all 50 products, the agent reports:

```text
Bulk Validation Complete — 50 products checked

PASSED: 47
FAILED: 3

Discrepancies:
  PROD-001  Expected: 29.99  Actual: 32.50  ← price increase not reflected
  PROD-031  Expected: 89.00  Actual: 0.00   ← price missing (product inactive?)
  PROD-044  Expected: 12.75  Actual: 12.99  ← rounding difference

Recommendation: review PROD-001 (possible pricing error) and PROD-031 (inactive product).
```

## Scaling to Larger Data Sets

For 500+ records, the same pattern works but takes longer:

- Tell the agent to batch in groups of 50 and report progress after each batch
- For apps with a search-and-page pattern (results appear on a new screen each time),
  include navigation instructions: "After reading the price, press Escape to go back
  to the search form before entering the next code"
- If the app has a grid view that shows multiple products at once, use `ww_get_table_data`
  instead of searching one by one (see [Use Case 03 — Data Extraction](03-data-extraction.md))

## Recording the Validation as a Test Script

You can record the bulk validation as a test script with one test case per product:

> "Start a recording session, then validate these products and record each one as a
> separate test case: TC-PROD-001, TC-PROD-002, ..."

The agent calls `ww_record(action="test_case_start")` for each product, records the search and assert steps,
then calls `ww_record(action="test_case_end")`. The exported script can be replayed in CI to verify prices
after every release (see [Use Case 01 — Scripted UI Test Automation for CI](01-scripted-ci.md)).

## Tips

- Provide the reference data directly in your prompt (paste the CSV) or as a file path
  if `allowFileWrite` is enabled and the agent can read it via `ww_file(action="read")`
- Use `op: "contains"` instead of `op: "eq"` when displayed values include currency symbols
  or formatting (`$29.99` vs `29.99`)
- Ask the agent to stop immediately on the first discrepancy or continue through all records —
  depending on whether you want a full report or fast failure

## Limitations

- The agent processes records sequentially — expect roughly 1-3 seconds per record
  depending on app speed and network latency (for remote sessions)
- If the app throttles repeated searches (rate limiting, CAPTCHA), include a pause
  instruction: "Wait 500ms between searches"

---

*[Back to use cases](README.md)*
