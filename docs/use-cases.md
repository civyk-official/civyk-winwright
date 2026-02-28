# Use Cases

Practical ways to use WinWright with AI agents and MCP clients.
Each section covers the problem, how WinWright helps, and an example tool sequence.

---

## AI-Powered UI Testing

### The problem

Traditional UI testing relies on hard-coded selectors — XPath, AutomationId, control paths.
When the UI changes (a button moves, a panel gets renamed, a new dialog appears), tests break.
Maintaining selectors across releases is tedious, and selector-based tests can't handle
unexpected dialogs or layout changes.

### How WinWright helps

An AI agent uses `ww_find_elements` to discover controls by name, type, or content — not
by fixed paths. It reads the live element tree, decides what to click and where to type,
and asserts values using `ww_get_value`. When the UI changes, the agent adapts.

### Example flow

```text
ww_launch        → Start the app under test
ww_snapshot      → Capture the full element tree
ww_find_elements → Locate the "Username" text box by name
ww_type          → Enter test credentials
ww_click         → Click "Sign In"
ww_wait_for      → Wait for the dashboard to load
ww_get_value     → Read the welcome message
ww_screenshot    → Capture the result for the test report
```

### What works today

- WinForms, WPF, and Win32 apps with UIA-exposed controls
- Element discovery by AutomationId, Name, ControlType, or content
- Value assertions on text boxes, labels, combo boxes, data grids
- Screenshot capture for visual verification

### Limitations

- Apps that render everything in a single custom canvas (no UIA tree) require
  screenshot-based approaches instead
- Timing-sensitive tests need `ww_wait_for` — the agent must handle async UI updates

---

## Autonomous Desktop Automation

### The problem

Repetitive desktop tasks — filling forms, copying data between apps, clicking through
multi-step workflows — eat hours. Traditional automation (AutoHotkey, Power Automate)
requires scripting every step upfront. When the workflow changes, the script breaks.

### How WinWright helps

An AI agent sees the screen through `ww_snapshot`, understands the current state, and
decides what to do next. It can open apps, navigate menus, type into fields, click
buttons, and verify results — all through natural conversation with the MCP client.

### Example flow

```text
ww_launch        → Open the expense report app
ww_snapshot      → Read the current UI state
ww_find_elements → Locate the "New Report" button
ww_click         → Click it
ww_type          → Fill in date, amount, description fields
ww_click         → Submit the report
ww_screenshot    → Capture confirmation for the user
```

### What works today

- Launch and attach to running Windows applications
- Full keyboard and mouse input (click, type, drag, key combos)
- Read any UIA-exposed control value
- Multi-monitor support
- Browser automation alongside desktop (same MCP session)

### Limitations

- The AI agent needs context about the app — it works best when you describe
  what you want done in plain language
- Some admin operations (registry, services, process kill) are disabled by default
  and require explicit opt-in in `winwright.json`

---

## Legacy App Data Extraction

### The problem

Enterprise apps — ERP systems, medical records, government portals, internal
line-of-business tools — often have no API and no export feature. Data is locked
behind a GUI that was built 15 years ago. Getting data out means manual copy-paste
or expensive vendor integrations.

### How WinWright helps

If Windows UI Automation can see a control, WinWright can read its value. The AI
agent navigates the app, reads data grids row by row, extracts text from labels
and fields, and structures the output. No API needed — just the running application.

### Example flow

```text
ww_attach          → Connect to the running legacy app
ww_find_elements   → Locate the data grid control
ww_get_value       → Read column headers
ww_get_table_data  → Extract rows from the grid
ww_click           → Navigate to next page
ww_get_table_data  → Extract next batch of rows
```

The agent repeats this across pages, tabs, or screens until all data is collected.

### What works today

- Read values from text boxes, labels, combo boxes, list views, tree views, data grids
- Navigate tabbed interfaces and tree structures
- Handle pagination by reading "Next" buttons and page indicators
- Export structured data through the AI agent's output

### Limitations

- Controls rendered as images (not UIA-accessible) can't be read this way —
  use `ww_screenshot` and the AI agent's vision instead
- Very large data sets (thousands of rows) are slow to extract through UIA — batch
  reads with `ww_get_table_data` help, but it's not a database connection

---

## Cross-App Workflows

### The problem

Real work spans multiple applications. You read an invoice number from your accounting
software, look it up in a web portal, download a PDF, and attach it to an email.
Each app has its own interface. No single automation tool covers desktop + browser
in one session.

### How WinWright helps

WinWright runs desktop and browser tools in the same MCP session. The AI agent reads
a value from a desktop app, switches to Chrome/Edge, navigates a web page, fills
a form, and comes back to the desktop — all in one conversation.

### Example flow

```text
ww_attach          → Connect to the desktop accounting app
ww_get_value       → Read invoice number from the detail view
ww_browser_connect → Connect to Chrome via CDP
ww_browser_navigate → Open the vendor portal
ww_browser_find    → Locate the search field
ww_browser_type    → Enter the invoice number
ww_browser_click   → Click "Search"
ww_browser_find    → Locate the download link
ww_browser_click   → Download the PDF
ww_screenshot      → Capture confirmation
```

### What works today

- Seamless switching between desktop and browser tools in one session
- Chrome and Edge supported via Chrome DevTools Protocol (CDP)
- Browser element discovery, clicks, typing, JavaScript evaluation
- Desktop + browser screenshots for verification

### Limitations

- Browser must be launched with remote debugging enabled (`--remote-debugging-port`)
- Firefox is not supported (no CDP)
- File download handling depends on the browser's download settings — WinWright
  doesn't manage the file system directly unless `allowFileWrite` is enabled

---

## Accessibility Auditing

### The problem

Windows applications need to be accessible — screen readers depend on UIA properties
like Name, Role, and KeyboardShortcut being set correctly. Manual auditing is slow:
open the app, inspect each control, check properties one by one.

### How WinWright helps

WinWright exposes the full UIA element tree. An AI agent traverses every control,
checks for missing names, unlabeled buttons, empty tooltips, and broken keyboard
navigation paths. It generates a structured report of accessibility issues.

### Example flow

```text
ww_launch          → Start the app
ww_snapshot        → Capture the complete element tree
ww_find_elements   → Query all Button controls
                   → Check: does each button have a Name?
ww_find_elements   → Query all Edit controls
                   → Check: does each text box have an associated label?
ww_find_elements   → Query all Image controls
                   → Check: does each image have alt text (Name property)?
ww_keyboard_focus  → Tab through controls
                   → Check: is every interactive control reachable by keyboard?
```

### What works today

- Full UIA tree traversal with `ww_snapshot` and `ww_find_elements`
- Read Name, ControlType, AutomationId, IsKeyboardFocusable on any control
- Tab order testing with keyboard input tools
- Tree view of the element hierarchy for structural analysis

### Limitations

- WinWright reads what UIA exposes — if a control is invisible to UIA
  (custom-drawn without automation peers), it won't appear in the tree
- Color contrast and visual spacing checks require screenshots +
  image analysis, not UIA properties

---

## Scripted Automation for CI

### The problem

Running an AI agent for every CI build is expensive and non-deterministic.
AI-driven UI tests are useful during development, but CI needs fast, repeatable,
and cost-predictable test runs.

### How WinWright helps

An AI agent explores the application once — discovers elements, builds a test flow,
and exports it as a deterministic JSON script. The script runs in CI without AI
involvement. The AI writes the test; the machine runs it.

### Why it matters

- Zero AI token cost per CI run
- Deterministic — same inputs, same results
- Fast — no LLM round-trips between steps
- The AI re-generates the script only when the UI changes

### Example flow

```text
ww_record_start       → Begin recording the session
ww_test_case_start    → Mark start of test case "TC-001: Login"
ww_launch             → Start the app
ww_type               → Enter username and password
ww_click              → Click "Sign In"
ww_assert_value       → Assert welcome label contains "Welcome" (embedded in script)
ww_test_case_end      → Close the test case
ww_export_script      → Export as test-mode JSON script
```

The exported script captures every step and assertion. A future runner replays it in CI
without an agent — the AI writes once, CI runs many times.

### What works today

- `ww_record_start` / `ww_record_stop` capture tool calls during an agent session
- `ww_record_pop` removes mistaken steps before export
- `ww_test_case_start` / `ww_test_case_end` group steps into named test cases
- `ww_assert_value` embeds assertions into the recording with property, operator, and expected value
- `ww_export_script` serialises the recording as a portable JSON script (test mode or RPA mode)
- `ww_snapshot` + `ww_diff_state` track UI state changes between actions

---

## Remote Administration

### The problem

Managing Windows machines remotely — restarting services, checking processes,
reading registry keys, verifying scheduled tasks — usually means RDP, PowerShell
Remoting, or vendor-specific tools. Each has its own access model and learning curve.

### How WinWright helps

WinWright's HTTP transport (`winwright serve --port 8765`) exposes system tools
over MCP with enterprise-grade security built in. An AI agent connects remotely
and manages the machine through the same tool set used locally: process management,
service control, registry reads, environment variables, and scheduled tasks.

### Example flow

```text
# On the remote machine:
winwright serve --port 8765  (with winwright.json security config)

# AI agent connects and:
ww_process_list    → Find a stuck process by name
ww_process_kill    → Terminate it (requires AllowProcessKill permission)
ww_service_list    → Check which services are stopped
ww_service_start   → Restart a failed service (requires AllowServiceControl)
ww_registry_read   → Read a configuration value
ww_shell           → Run a diagnostic script (requires AllowShell)
```

### What works today

- HTTP transport with full MCP tool access (`winwright serve`)
- 22 system tools: processes, registry, services, environment, network, tasks
- **5-layer remote access security model:**
  - R1: IP allowlist (CIDR ranges + exact IPs; localhost always passes)
  - R2: Windows Negotiate authentication (Kerberos/NTLM, captures `DOMAIN\user`)
  - R3: AD group authorization (caller must be in at least one required group)
  - R4: Fixed-window rate limiting per IP (auto-disabled for localhost)
  - R5: Per-user session limits + per-AD-group permission overrides
- TLS/HTTPS via PFX certificate or reverse proxy
- Daily-rotated audit log (`audit-YYYY-MM-DD.jsonl`) with Windows identity + auto-purge

### Limitations

- Requires both server and clients to be domain-joined for Kerberos auth (NTLM works cross-domain)
- `ww_shell`, `ww_process_kill`, `ww_service_start`, `ww_service_stop`, and other
  destructive tools are disabled by default — enable only what you need in `winwright.json`
- Browser tools (`ww_browser_*`) require Chrome/Edge on the **remote** machine with CDP enabled

---

*Built on Trust, Driven by Value* — [Civyk](https://civyk.com)
