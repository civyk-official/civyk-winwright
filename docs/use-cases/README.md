# WinWright Use Cases

Practical scenarios with real prompts, tool call parameters, and example output.
Each guide is a self-contained tutorial you can follow from first command to result.

## Use Cases

| # | Use Case | Summary |
|---|----------|---------|
| [01](01-scripted-ci.md) | **Scripted UI Test Automation for CI** | Record an AI session once, embed assertions, export a portable JSON script, replay in CI without an agent |
| [02](02-desktop-automation.md) | **Autonomous Desktop Automation** | Fill forms, navigate menus, move data between apps using plain-language instructions |
| [03](03-data-extraction.md) | **Legacy App Data Extraction** | Read grids and labels from apps with no API; paginate and batch-export to CSV |
| [04](04-scripted-desktop-rpa.md) | **Scripted Desktop Automation for Repeated Tasks** | Record a repetitive workflow once, export as an RPA script, replay on demand |
| [05](05-ui-testing.md) | **AI-Powered UI Testing** | Discover controls by name/type, click and type, assert values — no brittle XPath selectors |
| [06](06-bulk-data-validation.md) | **Bulk Data Validation** | Drive an app through 50+ records; compare each displayed value against a reference table |
| [07](07-cross-app-workflows.md) | **Cross-App Workflows** | Span desktop and browser in one session — read ERP, submit web portal, download PDF |
| [08](08-app-health-monitoring.md) | **Application Health Monitoring** | Verify a running app is responsive and connected; pair with Task Scheduler for scheduled checks |
| [09](09-remote-administration.md) | **Remote Administration** | Manage processes, services, and registry on remote Windows machines over HTTP |
| [10](10-accessibility-auditing.md) | **Accessibility Auditing** | Traverse the full UIA element tree; report unlabelled buttons and broken tab order |
| [11](11-dialog-handling.md) | **Dialog and Modal Handling** | Detect unexpected dialogs after every click; handle Save/Discard, file-save, MessageBox |

## Quick Start — 3 Commands

```bash
# Install once
dotnet tool install -g Civyk.WinWright

# stdio mode — for Claude Desktop and Claude Code (local machine)
winwright mcp

# HTTP mode — for remote access and multi-client setups
winwright serve --port 8765
```

Then tell your agent what to do:

> "Launch the app at C:\MyApp\app.exe, click the Login button, and take a screenshot."

WinWright handles the rest.

## How Prompts Work

You describe the goal in plain language. The agent decides which tools to call and in what order.
You never write tool call JSON directly — that is what the examples in these guides show you
*what the agent is doing internally* so you understand what's happening.

## Configuration

Create `winwright.json` next to the binary to enable non-default capabilities:

```json
{
  "permissions": {
    "allowShell": false,
    "allowRegistryWrite": false,
    "allowProcessKill": false,
    "allowFileWrite": false,
    "allowServiceControl": false
  }
}
```

All sensitive operations are disabled by default. Enable only what each use case requires.

---

*Back to [project README](../../README.md)*
