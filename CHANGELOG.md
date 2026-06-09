# Changelog

All notable changes to WinWright will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2026-06-09

Adds a first-class **CLI mode** for environments where MCP is blocked, an **installable
(offline) Claude Code skill**, and a further round of tool consolidation (~59 → ~52). The MCP
stdio and HTTP modes are unchanged. Recorded scripts from 2.x replay unchanged — **no migration
required**.

### Added

- **CLI mode** — drive the full tool surface without an MCP client:
  - `winwright tools [--json | <name>]` — discover the tool surface (replaces MCP's automatic
    schema advertisement).
  - `winwright call <tool> --param value …` — invoke one tool; JSON result to stdout, diagnostics
    to stderr, non-zero exit on an error envelope. Supports scalars, boolean flags, arrays, and
    inline-JSON objects; `--port N` / `--port=N`, `--no-autospawn`.
  - `winwright daemon start | stop | status` — a loopback daemon owns the live sessions, so the
    `appId` from `ww_launch` persists across separate `call` commands (full parity with MCP). It
    auto-starts on first `call`, binds to `127.0.0.1` only, and self-exits when idle.
- **Installable agent skill** — `winwright skills install --scope user|project [--dir <path>] [--force]`
  (also `uninstall`, `--list`). The skill is embedded in the binary and installs with **no network
  access**, so an agent can learn the CLI offline.

### Breaking Changes

- **Agent-facing tool renames.** Sixteen tools were merged into five `action`-parameterised tools.
  MCP/CLI callers must use the new names (run `winwright tools` to discover them). Recorded scripts
  replay unchanged.
- In `ww_dialog`, inner action parameters are `dialogAction`, `fileAction`, and `expectAction`
  (to avoid colliding with the top-level `action`).

### Migration Guide

Update agent/MCP/CLI calls to the consolidated tool names (recorded scripts need no changes):

| Old Tool Name(s) | New Tool | Action |
|---|---|---|
| `ww_get_snapshot` / `ww_get_state_hash` / `ww_diff_state` / `ww_assert_snapshot` | `ww_snapshot` | `get` / `hash` / `diff` / `assert` |
| `ww_get_table_data` / `ww_get_cell` / `ww_set_cell` | `ww_grid` | `get_table` / `get_cell` / `set_cell` |
| `ww_inspect` / `ww_get_attribute` / `ww_find_by_description` / `ww_label_map` | `ww_inspect` | `element` / `attribute` / `find_by_description` / `label_map` |
| `ww_handle_dialog` / `ww_handle_file_dialog` / `ww_expect_dialog` | `ww_dialog` | `handle` / `handle_file` / `expect` |
| `ww_window_resize` / `ww_window_state` / `ww_activate_window` | `ww_window` | `resize` / `state` / `activate` |

## [2.0.0] - 2026-03-09

### Breaking Changes

- **MCP tool consolidation**: Reduced from ~111 individual tools to ~59 consolidated tools using `action`/`mode` parameters. Old tool names (e.g., `ww_right_click`, `ww_shell`, `ww_process_list`) are no longer supported.
- **Recorded script format**: Scripts recorded with v1.x use old tool names and must be migrated to consolidated format (see Migration Guide below).
- **Backward compatibility removed**: StepDispatcher and SystemReplayDispatcher no longer accept old individual tool names during `winwright run` replay.

### Added

- Consolidated system tools with action-based dispatch: `ww_system`, `ww_process`, `ww_network`, `ww_env`, `ww_file`, `ww_registry`, `ww_service`, `ww_task`.
- Consolidated UI tools: `ww_click` (replaces `ww_right_click`, `ww_double_click`), `ww_clipboard` (replaces `ww_clipboard_set`/`ww_clipboard_get`), `ww_handle_dialog` (replaces `ww_handle_message_box`), `ww_scroll` (replaces `ww_scroll_into_view`).
- Action dispatchers in SystemReplayDispatcher for each consolidated system tool family.
- JSON Extra encoding for click variants (`{"button":"right"}`, `{"clickCount":2}`).
- JSON Extra encoding for clipboard actions (`{"action":"set","text":"..."}`).
- MessageBox button detection (`IsMessageBoxButton`) for consolidated `ww_handle_dialog` routing.

### Changed

- ActionTools now records `ww_click` with button/clickCount in Extra JSON instead of `ww_right_click`/`ww_double_click`.
- ClipboardTools now records `ww_clipboard` with action JSON instead of `ww_clipboard_set`.
- `IsReadOnlyTool` returns `false` for all tools (action inside JSON Extra determines read vs write).
- `IsSystemTool` now recognizes only the 8 consolidated tool names.
- Updated all regression test scripts (`01-wpf-regression.json`, `02-wf-regression.json`, `03-system-regression.json`) to consolidated format.

### Migration Guide

To migrate v1.x recorded scripts to v2.0 format:

| Old Tool Name | New Tool Name | Extra Format |
|---|---|---|
| `ww_right_click` | `ww_click` | `{"button":"right"}` |
| `ww_double_click` | `ww_click` | `{"clickCount":2}` |
| `ww_scroll_into_view` | `ww_scroll` | `into_view` |
| `ww_clipboard_set` | `ww_clipboard` | `{"action":"set","text":"..."}` |
| `ww_clipboard_get` | `ww_clipboard` | `{"action":"get"}` |
| `ww_handle_message_box` | `ww_handle_dialog` | Button name (e.g., `OK`) |
| `ww_shell` | `ww_system` | `{"action":"shell","command":"..."}` |
| `ww_system_info` | `ww_system` | `{"action":"info"}` |
| `ww_notification` | `ww_system` | `{"action":"notification",...}` |
| `ww_process_list` | `ww_process` | `{"action":"list",...}` |
| `ww_process_kill` | `ww_process` | `{"action":"kill",...}` |
| `ww_env_get` | `ww_env` | `{"action":"get","name":"..."}` |
| `ww_env_set` | `ww_env` | `{"action":"set","name":"...","value":"..."}` |
| `ww_file_read` | `ww_file` | `{"action":"read","path":"..."}` |
| `ww_file_write` | `ww_file` | `{"action":"write","path":"...","content":"..."}` |
| `ww_file_list` | `ww_file` | `{"action":"list","path":"..."}` |
| `ww_file_ops` | `ww_file` | `{"action":"ops","operation":"...","sourcePath":"..."}` |
| `ww_registry_read` | `ww_registry` | `{"action":"read","hive":"...","keyPath":"..."}` |
| `ww_registry_write` | `ww_registry` | `{"action":"write",...}` |
| `ww_registry_delete` | `ww_registry` | `{"action":"delete",...}` |
| `ww_service_list` | `ww_service` | `{"action":"list",...}` |
| `ww_service_start` | `ww_service` | `{"action":"start","serviceName":"..."}` |
| `ww_service_stop` | `ww_service` | `{"action":"stop","serviceName":"..."}` |
| `ww_task_list` | `ww_task` | `{"action":"list",...}` |
| `ww_task_create` | `ww_task` | `{"action":"create",...}` |
| `ww_task_run` | `ww_task` | `{"action":"run","taskName":"..."}` |
| `ww_task_delete` | `ww_task` | `{"action":"delete","taskName":"..."}` |
| `ww_ping` | `ww_network` | `{"action":"ping","host":"..."}` |
| `ww_dns_resolve` | `ww_network` | `{"action":"resolve","hostname":"..."}` |
| `ww_network_interfaces` | `ww_network` | `{"action":"interfaces"}` |
| `ww_network_stats` | `ww_network` | `{"action":"stats"}` |

## [1.1.0] - 2026-02-15

### Added

- Remote administration: IP allowlist (CIDR), Negotiate auth, group permissions, rate limiting, max sessions per user, audit logging, TLS support.
- Script healing (`winwright heal`): auto-fix broken selectors with configurable thresholds.
- Script runner (`winwright run`): replay recorded scripts with JUnit and text reporters.
- Recording tools: `ww_record_start`/`stop`/`pop`, `ww_test_case_start`/`end`, `ww_export_script`, `ww_assert_value`.
- Browser automation via CDP (Chrome/Edge).
- HTTP serve mode (`winwright serve --port 8765`).

## [1.0.0] - 2026-01-01

### Added

- Initial release with ~111 MCP tools for desktop automation.
- WPF, WinForms, and Win32 support via UI Automation.
- Selector engine with CSS-like syntax (`#id`, `[name="..."]`, `type=Button`).
- System tools: shell, file, registry, network, environment, services, task scheduler.
- Permission-gated security model.
