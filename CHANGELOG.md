# Changelog

All notable changes to WinWright will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.1.0] - 2026-06-10

Hardening and correctness release from a full-codebase deep review: replay/live security
guard parity, a new read-side file permission, ~30 correctness and robustness fixes, a
Caps Lock typing fix, performance quick wins, and a complete documentation sync against the
v3.0.0 tool surface. No breaking changes — recorded scripts and the agent-facing tool
surface are unchanged.

### Security

- **Replay guard parity**: `winwright run` now enforces the same safeguards as the live
  tools — protected-process kill guard (`lsass`, `csrss`, …), protected registry write-path
  guard for value deletion, and shell-metacharacter rejection for scheduled-task commands.
- New **`AllowFileRead`** permission gates `ww_file` read/list (default `true` — read-only,
  no behaviour change; revoke it in HTTP serve mode so authenticated clients cannot read
  `winwright.json`/audit logs). Single reads are capped at 10 MB of content, and successful
  reads/lists are now audit-logged.
- `ww_process(action="kill", name=…)` trims a trailing `".exe"` — it previously slipped past
  the protected-process guard AND matched no process at all (Windows process names exclude
  extensions); same normalization during replay.
- `winwright serve` warns at startup when `AllowNetworkProbe`/`AllowFileRead` are enabled on
  a non-loopback bind; the TLS log line no longer prints the full certificate path; audited
  shell commands are truncated to 200 chars; `ww_env(action="set")` audits only the gated
  Machine/User targets; audit flush errors no longer echo exception detail to stderr.
- `JsStringEscaper` additionally escapes `"` and U+0085; `skills install --dir` paths are
  canonicalized.

### Fixed

- **`ww_type` corrupted text when Caps Lock was on** — virtual-key injection derives shift
  state from `VkKeyScan`, which assumes Caps Lock off, so "MSFT" arrived as "msft" and
  "Hello" as "hELLO". `ww_type` now neutralises Caps Lock for the duration of the type and
  restores the user's state afterwards (whole sequences are serialized so concurrent types
  cannot interleave toggles). Proven by replaying the WPF regression suite with Caps Lock
  forced on: 66/66 steps (was 63/66).
- **Replay `dns_resolve` always threw** — the dispatcher read `hostname` where the recorder
  writes `host` (legacy `hostname` still accepted).
- **Fingerprint healing candidate #2 never matched** — it used invalid `[controlType=…]`
  selector syntax that failed compilation and was silently swallowed; now `type=X[name=…]`.
- **`ww_assert` value assertions errored on non-regex expected strings** (e.g.
  `value_contains` with `"C++ (x86)"`) because the regex was evaluated eagerly for every
  assertion type; an invalid pattern for `value_matches_regex` now returns
  `invalid_argument` with a clear message.
- **Record/replay assertion drift**: invalid regex patterns in replayed assertions were
  silently treated as non-matches; both paths now share `AssertionOperator` and raise a
  clear error. Note: in `winwright run` an existing script step with an invalid regex
  pattern now reports as a JUnit `<error>` (broken test) instead of a silent `<failure>` —
  CI gates that count only failures will see the change.
- **Generic parameter errors now return `invalid_argument`** (bad regex pattern, missing
  `pid`/`name`, …); they were previously mislabelled `selector_invalid`, sending agents off
  fixing selectors when a parameter was at fault. Selector syntax errors still return
  `selector_invalid`.
- Launching/attaching to a process that dies immediately now fails with
  `process_died_on_start` / `process_not_found` instead of returning a successful-looking
  result whose `appId` never resolves; a related race that permanently leaked session
  slots is fixed.
- `LocatorEngine` regex filters now use the pre-compiled, ReDoS-time-boxed regex from the
  selector compiler instead of re-interpreting the pattern per candidate element.
- `ww_snapshot(includeOptions=true)` no longer duplicates the expanded ComboBox dropdown
  subtree, and BFS queue memory is bounded.
- `CdpClient` teardown race that could leave a concurrent request hanging for its full 30 s
  timeout; replay notification helper drains stderr (pipe-buffer deadlock);
  dialog-replay 3 s timers are linked to the outer cancellation token.
- `winwright call` honours Ctrl+C (exit 130) while waiting for the daemon and during the
  tool call; daemon identity check derives the executable name from `Environment.ProcessPath`.
- `UiaDispatchThread` fails fast (30 s bounded enqueue) instead of blocking callers forever
  when the STA queue is saturated; `EventWatcher` explicitly unregisters its UIA handlers on
  dispose (including the global focus-changed subscription), pre-filters foreign-process
  focus events before queueing STA work, and exposes `DroppedEventCount`.
- `AuditLogger` retry buffer is bounded (10k entries); `BrowserRegistry` validates the CDP
  port for direct callers and logs session-dispose failures; retry backoff gained ±20 % jitter.

### Performance

- **FlaUI `CacheRequest` batching in the snapshot/hash engines** — the `ww_snapshot` BFS and
  state hashing now fetch children plus all snapshot-relevant properties in one
  cross-process round-trip per find instead of ~5–8 individual COM calls (~1 ms each) per
  element, and label resolution reuses the sibling batch already in hand. Traversal and
  hash semantics are unchanged — verified with a full-field golden diff against the previous
  engine (identical) and stable hashes on the same live UI. Measured ~2× end-to-end on
  `ww_snapshot(action="get")` on a small 55-element tree (including fixed transport
  overhead, so the engine-level gain is larger); the benefit grows with tree size.
- Removed per-row `ColumnCount` reads in grid extraction, quadruple `BoundingRectangle`
  reads in `ww_inspect(action="attribute")`, per-call JPEG encoder lookup and an extra
  image-buffer copy per screenshot, per-message string allocation in the CDP receive loop,
  and per-poll regex re-interpretation in `ww_wait(mode="value")`.

### Documentation

- Full documentation sync against the live tool surface: `winwright heal` / `ww_heal_script`
  documented, security-model description corrected, `AllowNetworkProbe`/`AllowFileRead` in
  all permission tables, CLI command tables completed, stale counts/TFMs fixed, and a new
  "Troubleshooting — Known UIA Quirks" guide section.
- ~150 tool calls across the regression suites and showcase converted from
  pre-consolidation tool names — the suites were not executable as written.

### Verification

- Build clean (`dotnet build -warnaserror`, net8 + net9); **587 unit tests pass**.
- Regression replay: **3/3 scripts pass** — 150 steps, 0 failures; `01-wpf` additionally
  re-run with Caps Lock forced on (66/66) to prove the `ww_type` fix.
- Snapshot engine golden diff vs the previous implementation: identical 55-node output;
  hashes deterministic.

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
