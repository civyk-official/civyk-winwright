# WinWright

[![NuGet](https://img.shields.io/nuget/v/Civyk.WinWright?label=NuGet)](https://www.nuget.org/packages/Civyk.WinWright)
[![GitHub Release](https://img.shields.io/github/v/release/civyk-official/civyk-winwright?label=Release)](https://github.com/civyk-official/civyk-winwright/releases)
[![License](https://img.shields.io/badge/License-Freeware-blue)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0078D4)](https://github.com/civyk-official/civyk-winwright)
[![MCP](https://img.shields.io/badge/MCP-110%20tools-0D9488)](https://modelcontextprotocol.io/)

Windows automation server for the [Model Context Protocol](https://modelcontextprotocol.io/).
110 tools for desktop (WPF, WinForms, Win32), browser (Chrome/Edge via CDP),
and system management — all accessible to AI agents over MCP.

![WinWright Demo](assets/demo.gif)

## Contents

- [Quick Start](#quick-start)
- [Use Cases](#use-cases)
- [Install](#install)
- [MCP Client Configuration](#mcp-client-configuration)
- [Tools](#tools)
- [Configuration](#configuration)
- [Who Is This For](#who-is-this-for)
- [How It Compares](#how-it-compares)
- [Support](#support)
- [License](#license)

## Quick Start

Install, configure your MCP client, then ask the agent to do something:

> "Launch Notepad, type 'Hello from WinWright', then read back what you typed."

The agent calls WinWright tools and returns results:

```text
ww_launch    → { "processId": 12840, "mainWindowTitle": "Untitled - Notepad" }
ww_type      → { "success": true }
ww_get_value → { "value": "Hello from WinWright" }
```

Every tool returns structured JSON. The agent decides which tools to call and in what order —
you describe the goal in plain language.

## Use Cases

> Each card links to a detailed walkthrough with real prompts, tool call parameters,
> and example output. Browse all guides in [docs/use-cases/](docs/use-cases/).

### [Scripted UI Test Automation for CI](docs/use-cases/01-scripted-ci.md)

Record an AI session once — the agent discovers the UI, performs actions, embeds assertions —
then export a portable JSON script that replays in CI without an AI agent. Describe your app
or paste your existing manual test suite; the agent scripts it automatically.

### [Autonomous Desktop Automation](docs/use-cases/02-desktop-automation.md)

Give an AI agent access to your desktop. It launches apps, moves data between them,
fills forms, and takes screenshots for verification — no scripts to write or maintain.

### [Legacy App Data Extraction](docs/use-cases/03-data-extraction.md)

Many enterprise apps have no API. If Windows UI Automation can see a control,
WinWright can read its value. Extract data from apps that were never built for integration.

### [Scripted Desktop Automation for Repeated Tasks](docs/use-cases/04-scripted-desktop-rpa.md)

Record a repetitive daily workflow once. Export as an RPA script and replay on demand —
no AI agent required after the recording. Ideal for report exports, data imports,
and any multi-step task that runs the same way every time.

### [AI-Powered UI Testing](docs/use-cases/05-ui-testing.md)

An AI agent explores your WinForms or WPF app, finds elements, and asserts state.
No brittle XPath selectors to maintain — the agent adapts when UI changes.

### [Bulk Data Validation](docs/use-cases/06-bulk-data-validation.md)

Drive an app through 50+ records automatically. Compare each displayed value against
a reference table and get a structured pass/fail report with discrepancy details.

### [Cross-App Workflows](docs/use-cases/07-cross-app-workflows.md)

Automate workflows that span desktop apps and browser — read from an accounting app,
submit to a web portal, screenshot the confirmation.

### [Application Health Monitoring](docs/use-cases/08-app-health-monitoring.md)

Verify a running app is alive and responsive — process running, connection status showing
'Connected', service healthy. Pair with Windows Task Scheduler for scheduled checks.

### [Remote Administration](docs/use-cases/09-remote-administration.md)

Manage processes, services, registry, and scheduled tasks on remote machines over HTTP.
Five-layer security: IP allowlist, Windows Negotiate auth, AD group authorization,
rate limiting, and per-user session limits.

### [Accessibility Auditing](docs/use-cases/10-accessibility-auditing.md)

Traverse the full UIA element tree. Check that controls have names, buttons have labels,
and keyboard paths exist. The AI agent generates a compliance report.

### [Dialog and Modal Handling](docs/use-cases/11-dialog-handling.md)

Detect unexpected confirmation dialogs, file-save prompts, and Win32 MessageBox popups
after every click. Handle or dismiss them without breaking the automation flow.

## Install

### Claude Code Plugin

```bash
claude /plugin install https://github.com/civyk-official/civyk-winwright
powershell -File ~/.claude/plugins/winwright/scripts/install.ps1
```

### Binary Download

Download from [GitHub Releases](https://github.com/civyk-official/civyk-winwright/releases):

| Asset | Architecture |
|-------|-------------|
| `winwright-*-win-x64.zip` | Intel/AMD 64-bit |
| `winwright-*-win-arm64.zip` | ARM64 (Surface Pro, etc.) |

### NuGet Package

```bash
dotnet tool install -g Civyk.WinWright
```

Requires .NET 8+ runtime. The binary download above is self-contained and needs no runtime.

## MCP Client Configuration

### Claude Code / VSCode (stdio)

```json
{
  "servers": {
    "winwright": {
      "type": "stdio",
      "command": "C:/path/to/Civyk.WinWright.Mcp.exe",
      "args": ["mcp"]
    }
  }
}
```

### Claude Code / VSCode (HTTP)

Start the server first: `Civyk.WinWright.Mcp.exe serve --port 8765`

```json
{
  "servers": {
    "winwright": {
      "type": "http",
      "url": "http://localhost:8765/mcp"
    }
  }
}
```

### Claude Desktop

```json
{
  "mcpServers": {
    "winwright": {
      "command": "C:/path/to/Civyk.WinWright.Mcp.exe",
      "args": ["mcp"]
    }
  }
}
```

## Tools

110 tools across five categories:

| Category | Count | What it does |
|----------|-------|-------------|
| **Desktop Automation** | 63 | Launch apps, click, type, read values, screenshots, tree navigation, dialogs, test case recording, CI script export (UIA3) |
| **System** | 22 | Processes, registry, environment variables, file system, network, services, scheduled tasks |
| **Browser** | 15 | Chrome/Edge via CDP — navigate, find elements, click, type, evaluate JS. No Selenium dependency |
| **AI Agent** | 10 | Snapshots, state diffing, event watching, action recording, `ww_get_schema` for tool discovery |
| **Security** | — | Tool visibility filtering, runtime permission guards, JSONL audit logging |

## Configuration

Create `winwright.json` next to the binary (or `%APPDATA%\WinWright\winwright.json`):

```json
{
  "permissions": {
    "allowShell": false,
    "allowRegistryWrite": false,
    "allowProcessKill": false,
    "allowFileWrite": false,
    "allowServiceControl": false,
    "allowTaskScheduler": false,
    "allowEnvironmentWrite": false,
    "allowBrowserEval": false
  },
  "audit": {
    "enabled": true,
    "logPath": "audit.jsonl"
  }
}
```

All dangerous operations are disabled by default. Enable only what you need.

## CLI

```text
winwright mcp                                    Start MCP server (stdio)
winwright serve --port N                         Start MCP server (HTTP, default 8765)
winwright run <script.json> [--format text|junit] [--output <file>]
                                                 Replay a recorded automation script
winwright heal <script.json> [--app <path>|--pid <n>] [--output <file>] [--min-confidence <0-1>]
                                                 Probe broken selectors against a live UI and repair them
winwright inspect <pid>                          Dump UIA element tree for a process
winwright doctor                                 Verify environment prerequisites
```

## Requirements

- Windows 10 or 11 (x64 or ARM64)
- No .NET runtime needed for the binary download — it's self-contained

## Who Is This For

**Good fit:**

- QA engineers testing WinForms, WPF, or Win32 apps who want AI-assisted test creation
- Developers building AI agents that need to interact with the Windows desktop
- Teams extracting data from legacy enterprise apps that have no API
- Anyone automating repetitive multi-app workflows on Windows

**Not a good fit:**

- Linux or macOS automation — WinWright is Windows-only (UIA is a Windows API)
- Web-only testing — use [Playwright](https://playwright.dev/) instead; WinWright's browser tools are for mixed desktop+browser workflows
- High-throughput data pipelines — UIA reads controls one at a time; if you need bulk data transfer, a proper API or database connection is better

## How It Compares

| | WinWright | UiPath | Power Automate Desktop | Playwright |
| - | --------- | ------ | ---------------------- | ---------- |
| **What it automates** | Desktop + browser + system | Desktop + browser + system | Desktop + browser + cloud | Browser only |
| **How you use it** | AI agent via MCP (natural language) | Visual workflow designer | Visual workflow designer | Code (JS/Python/C#) |
| **Desktop support** | WPF, WinForms, Win32 (UIA3) | WPF, WinForms, Win32, Java, SAP | WPF, WinForms, Win32 | None |
| **Browser support** | Chrome/Edge via CDP | Chrome, Edge, Firefox | Chrome, Edge, Firefox | Chrome, Edge, Firefox, Safari |
| **Selector model** | AI picks elements by name/type | Visual selector recorder | Visual selector recorder | CSS/XPath selectors |
| **Cost** | Free | Licensed (per-user/bot) | Free (desktop), licensed (cloud) | Free |
| **Setup** | Single binary, no runtime | Full install + studio | Windows store app | npm install |
| **Designed for** | AI agents and MCP clients | Enterprise RPA | Business user automation | Developer testing |

WinWright is not an RPA platform. It's a tool server that gives AI agents access to Windows.
If you need a visual workflow builder or enterprise orchestration, UiPath or Power Automate
are better choices. If you need browser-only testing, Playwright is more mature.

WinWright fits where those tools don't — when an AI agent needs to see and operate
the Windows desktop, or when you need desktop + browser in one MCP session.

## Support

- **Issues:** [GitHub Issues](https://github.com/civyk-official/civyk-winwright/issues)
- **Changelog:** [GitHub Releases](https://github.com/civyk-official/civyk-winwright/releases)

## License

Free to use for any purpose — personal, academic, commercial.
See [LICENSE](LICENSE) for full terms. Attribution required when redistributing.

---

**Built on Trust, Driven by Value** — [Civyk](https://civyk.com)
