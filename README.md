# WinWright — Windows Automation MCP Server

Playwright-style MCP server for Windows desktop, system, and browser automation.
105 tools for WPF, WinForms, Win32, and Chrome/Edge via the
[Model Context Protocol](https://modelcontextprotocol.io/).

## Quick Install

### Claude Code Plugin (Recommended)

```bash
# Install the plugin — Claude Code downloads and configures everything
claude /plugin install https://github.com/civyk-official/civyk-winwright

# Then run the install script to download the binary
powershell -File ~/.claude/plugins/winwright/scripts/install.ps1
```

### Manual Binary Download

Download the latest release from
[GitHub Releases](https://github.com/civyk-official/civyk-winwright/releases):

| Asset | Architecture |
|-------|-------------|
| `winwright-*-win-x64.zip` | Intel/AMD 64-bit |
| `winwright-*-win-arm64.zip` | ARM64 (Surface Pro, etc.) |

Or use PowerShell:

```powershell
# Download and extract to a directory in your PATH
$version = "1.0.0-preview.1"
$url = "https://github.com/civyk-official/civyk-winwright/releases/download/v$version/winwright-$version-win-x64.zip"
Invoke-WebRequest $url -OutFile winwright.zip
Expand-Archive winwright.zip -DestinationPath "$env:LOCALAPPDATA\WinWright"
$env:PATH += ";$env:LOCALAPPDATA\WinWright"
```

### VSCode MCP Configuration

Add to your `.vscode/mcp.json`:

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

Or for HTTP transport:

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

Start the HTTP server first: `Civyk.WinWright.Mcp.exe serve --port 8765`

### Claude Desktop Configuration

Add to your `claude_desktop_config.json`:

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

## Requirements

- Windows 10 or 11 (x64 or ARM64)
- No .NET SDK required — the binary is fully self-contained

## What Can It Do?

WinWright exposes 105 MCP tools across five categories:

### Desktop Automation (58 tools)

Launch apps, click buttons, type text, read values, take screenshots,
navigate trees, handle dialogs — all via UI Automation (UIA3).

```text
ww_launch → ww_click → ww_type → ww_get_value → ww_screenshot
```

### System Tools (22 tools)

Process management, registry, environment variables, file system,
network interfaces, services, and scheduled tasks.

### Browser Automation (15 tools)

Connect to Chrome/Edge via CDP, navigate pages, find elements,
click, type, evaluate JavaScript — no Selenium or Playwright dependency.

### AI Agent Features (10 tools)

Snapshots, state diffing, event watching, action recording,
and `ww_get_schema` for tool discovery.

### Security Layer

Three-layer security model: tool visibility filtering, runtime
permission guards, and JSONL audit logging. Dangerous operations
(shell, registry write, process kill) require explicit opt-in
in `winwright.json`.

## CLI Commands

```text
winwright mcp              Start MCP server over stdio
winwright serve --port N   Start MCP server over HTTP (default 8765)
winwright inspect <pid>    Dump UIA element tree for a process
winwright doctor           Verify environment prerequisites
```

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

All dangerous operations are **disabled by default**. Enable only what you need.

## License

WinWright is free to use for any purpose (personal, academic, commercial).
See [LICENSE](LICENSE) for full terms. Attribution is required when redistributing.
