# MCP Tool Design Analysis: Should WinWright Consolidate Its 110 Tools?

> Deep analysis of tool count, AI agent adaptability, and MCP best practices — with a recommendation tailored to WinWright's architecture.

## Executive Summary

**Short answer: No — do not blindly consolidate tools into fewer "mega-tools" with mode parameters.**

WinWright's 110 tools are a real concern for AI agent performance, but the right solution is **not** collapsing them into fewer tools with more parameters. Instead, WinWright should adopt **dynamic tool filtering** (exposing only the tools relevant to the current task) and **logical server segmentation** (splitting tools across focused MCP server categories). The tools themselves are well-designed — atomic, single-purpose, clearly named — and that design should be preserved.

---

## Part 1: The Problem — 110 Tools Is Too Many

### What the Research Says

Industry research and MCP community experience have established clear thresholds for AI agent tool selection performance:

| Tool Count | Effect |
|------------|--------|
| **< 30** | Optimal range. Models select tools accurately with minimal confusion |
| **~30** | Tool descriptions begin to overlap; confusion starts |
| **~46** | Smaller models (8B parameters) begin failing benchmarks |
| **~50** | Suboptimal responses become noticeable across most models |
| **80–90** | Context overload; significant performance degradation |
| **100+** | Tool selection failure is virtually guaranteed |

These numbers come from empirical testing. In the Gram's Dog API experiment, models went from 95% accuracy at 20 tools to hallucinating entire endpoints at 107 tools. The RAG-MCP paper (arXiv:2505.03275) showed that reducing exposed tools from 100+ to under 30 via retrieval **tripled** tool selection accuracy (43.13% vs 13.62% baseline).

**WinWright at 110 tools sits firmly in the "guaranteed failure" zone** when all tools are exposed simultaneously.

### Why It Matters for WinWright Specifically

When an AI agent connects to WinWright, it receives all 110 tool definitions in its context window. This causes:

1. **Token bloat** — Each tool definition (name + description + JSON Schema parameters) consumes ~100–300 tokens. 110 tools = 11,000–33,000 tokens just for tool definitions, before any conversation even starts.

2. **Selection confusion** — Tools like `ww_click`, `ww_double_click`, `ww_hover` are semantically close. With 110 options, the model must distinguish between `ww_wait_for`, `ww_wait_for_value`, `ww_wait_for_dialog`, and `ww_expect_dialog` — all waiting-related but subtly different. This is exactly where LLMs make mistakes.

3. **Positional bias** — Research shows models over-select tools that appear earlier in the list. With 110 tools, tools defined later (system management, browser) may be systematically under-selected.

4. **Client hard limits** — Cursor caps at 40 MCP tools. Claude Desktop has been observed capping at 100. WinWright's 110 tools exceed these limits, meaning some tools are silently dropped.

---

## Part 2: The Wrong Solution — Consolidating Into Fewer "Mega-Tools"

The instinctive response is: "Merge related tools into one tool with a mode/action parameter." For example:

```
# Instead of 5 separate tools:
ww_click, ww_double_click, ww_hover, ww_right_click, ww_drag

# Create one tool:
ww_mouse_action { action: "click"|"double_click"|"hover"|"right_click"|"drag", ... }
```

**This is a bad idea.** Here's why:

### 2.1 — It Violates the MCP Design Principle of Atomicity

Docker's official MCP best practices state: *"Design tools to perform a single, well-scoped task."* The MCP spec intentionally models tools as discrete operations with typed input schemas — not as multi-mode dispatchers. Consolidating tools into mega-tools with `action` parameters:

- Turns a **typed, discoverable API** into an **untyped string-dispatched** one
- Loses JSON Schema validation per operation (a `click` needs different params than a `drag`)
- Makes tool descriptions vague ("performs a mouse action" vs "clicks an element")

### 2.2 — It Makes Agent Selection Harder, Not Easier

When tools are consolidated, the agent must now:
1. Select the right mega-tool (easier — fewer options)
2. **Then** select the right `action` parameter value (harder — no schema guidance)
3. **Then** figure out which parameters apply to that action (hardest — conditional schemas)

Research shows LLMs handle **tool selection** (pick from a list of typed tools) better than **parameter inference** (pick the right enum value and its conditional parameters). You're trading a problem the model handles well (choosing between clearly defined tools) for one it handles poorly (navigating conditional parameter logic).

### 2.3 — It Breaks Tool-Level Permissions and Auditing

WinWright has a permission system (`allowShell`, `allowProcessKill`, `allowServiceControl`). These map cleanly to individual tools. If `ww_process_kill` is merged into `ww_process_manage { action: "kill" }`, the permission check moves from "is this tool allowed?" to "is this tool allowed with this parameter value?" — adding runtime parsing complexity and audit ambiguity.

### 2.4 — It Degrades Error Messages

Atomic tools produce clear errors: `"ww_click failed: element not found"`. A mega-tool produces: `"ww_mouse_action failed"` — was it the click? The hover? The drag? The agent and the human reviewing audit logs both lose diagnostic clarity.

### 2.5 — Concrete Example: Why Merging Fails

Consider consolidating all "wait" tools:

```
# Current (4 tools, each crystal clear):
ww_wait_for         { selector, timeoutMs }
ww_wait_for_value   { selector, property, op, expected, timeoutMs }
ww_wait_for_dialog  { timeoutMs }
ww_expect_dialog    { title, timeoutMs }

# Consolidated (1 tool, confusing):
ww_wait {
  mode: "element"|"value"|"dialog"|"expect_dialog",
  selector?,      # required for element/value, ignored for dialog
  property?,      # required for value only
  op?,            # required for value only
  expected?,      # required for value only
  title?,         # required for expect_dialog only
  timeoutMs
}
```

The consolidated version has 7 parameters, most conditionally required based on `mode`. The model must reason about which parameters apply. This is strictly worse for LLM tool calling — conditional parameter schemas are a known failure mode.

---

## Part 3: The Right Solution — Dynamic Tool Filtering and Server Segmentation

### 3.1 — Segment by Category (5-Category Model)

WinWright's 110 tools fall into 5 natural categories that align with its existing architecture. These should be exposed as selectable profiles:

| Category | Tools | Count | Use Cases |
|----------|-------|-------|-----------|
| **Desktop Core** | Launch, attach, click, type, snapshot, query, get_value, screenshot, wait, select, hover, drag, keyboard, dialogs | ~35 | UC-02, UC-03, UC-05, UC-06, UC-10, UC-11 |
| **Recording & Testing** | Record start/pop, test case start/end, export script, heal script, assert_value | ~15 | UC-01, UC-04 |
| **Browser** | CDP connect, navigate, find, click, type, screenshot, eval JS, tab/window mgmt | 15 | UC-07 |
| **System** | Process list/kill, service list/start/stop/restart, registry read/write, shell, file, env vars, scheduled tasks, network | 22 | UC-08, UC-09 |
| **AI Agent** | get_schema, snapshots, state diffing, event watching, action recording | 10 | All (bootstrap) |

**Why 5 categories, not 2 (desktop vs system)?** Desktop Automation alone is 63 tools — still double the ~30-tool degradation threshold. Splitting desktop into "core interaction" (~35) and "recording/testing" (~15) keeps both halves under the sweet spot. Users doing ad-hoc automation load Desktop Core only. Users building CI test suites load Desktop Core + Recording & Testing.

#### Typical Profile Combinations

| User Role | Categories Loaded | Tool Count |
|-----------|-------------------|------------|
| QA engineer (CI scripting) | Desktop Core + Recording & Testing + AI Agent | ~60 → filtered to ~30 via tiering |
| Ad-hoc automation | Desktop Core + AI Agent | ~45 → filtered to ~20 via tiering |
| Sysadmin (remote) | System + AI Agent | ~32 → filtered to ~22 via tiering |
| Cross-app workflow | Desktop Core + Browser + AI Agent | ~60 → filtered to ~30 via tiering |
| Power user | All | 110 (understands the tradeoff) |

### 3.2 — Dynamic Tool Activation via `ww_get_schema`

WinWright already has `ww_get_schema` for tool discovery. Extend this pattern:

1. On startup, expose only a **bootstrap set** of ~10–15 essential tools (launch, attach, snapshot, click, type, get_value, screenshot, get_schema)
2. When the agent calls `ww_get_schema`, it discovers the full catalog organized by category
3. The agent (or middleware) activates additional tools on demand based on the task

This is the **Tool RAG** pattern that research shows yields 3x accuracy improvement. WinWright is already halfway there with `ww_get_schema`.

### 3.3 — Tiered Tool Exposure

Classify tools by frequency of use:

| Tier | Description | Example Tools | Exposure |
|------|-------------|---------------|----------|
| **Core** | Used in almost every session | `ww_launch`, `ww_click`, `ww_type`, `ww_snapshot`, `ww_screenshot`, `ww_get_value` | Always loaded |
| **Extended** | Used in specific workflows | `ww_wait_for`, `ww_select`, `ww_get_table_data`, `ww_assert_value` | Loaded on demand |
| **Specialized** | Rare or admin-only | `ww_heal_script`, `ww_registry_write`, `ww_task_scheduler_create`, `ww_shell` | Loaded explicitly |

A core set of ~12–15 tools covers 80% of use cases. The agent requests more when needed.

---

## Part 4: What WinWright Already Does Right

Before suggesting changes, it's important to acknowledge what's already well-designed:

### 4.1 — Atomic, Single-Purpose Tools
Each tool does one thing. `ww_click` clicks. `ww_type` types. `ww_screenshot` takes a screenshot. This is exactly what MCP best practices prescribe. **Do not change this.**

### 4.2 — Consistent Naming Convention
The `ww_` prefix with verb-noun naming (`ww_get_value`, `ww_wait_for_dialog`, `ww_handle_message_box`) is clear and predictable. The agent can infer tool purpose from the name alone.

### 4.3 — Consistent Parameter Patterns
`appId`, `selector`, `windowId`, `timeoutMs` appear consistently across tools. The agent learns the pattern from the first few calls and applies it thereafter.

### 4.4 — Structured JSON Responses
All tools return typed JSON with consistent fields (`success`, `value`, `elements`, `passed`). This lets the agent parse results predictably.

### 4.5 — Permission-Guarded Dangerous Operations
Separating `allowShell`, `allowProcessKill`, etc. is exactly right — it maps one permission to one capability boundary.

---

## Part 5: Specific Recommendations

### DO: Aggressive Consolidation of Variant Tools

Merge every tool group where the operations share a common schema and differ only by a mode/action value. The guiding rule: if the only difference between two tools is a single enum-like choice and no parameter becomes conditionally required, merge them.

#### Desktop Interaction Merges

| Current | Proposed | Saved | Rationale |
|---------|----------|-------|-----------|
| `ww_click` + `ww_double_click` + `ww_right_click` + `ww_hover` | `ww_click` with `clickType: "single"\|"double"\|"right"\|"hover"` (default `"single"`) | 3 | All take `appId` + `selector` + optional `windowId`. Hover is a positional action on the same element, not semantically distinct enough to warrant its own tool. |
| `ww_launch` + `ww_attach` | `ww_app` with `action: "launch"\|"attach"`, `exePath?`, `processId?` | 1 | Both return `appId`. Launch needs `exePath`, attach needs `processId` — conditionally required but trivially so (one of two fields). |
| `ww_snapshot` + `ww_query` | `ww_inspect` with optional `selector` — omit for full tree, provide for filtered search | 1 | Both read UI state. `ww_snapshot` is `ww_query` without a filter. Merged tool: no selector = full tree, selector = filtered elements. |
| `ww_get_value` + `ww_assert_value` | `ww_get_value` with optional `op` + `expected` + `message` — if assertion params present, assert; if absent, read-only | 1 | Both target the same element with the same selector. Assertion is a superset of reading. Agent intent is clear from whether `op`/`expected` are provided. |
| `ww_wait_for` + `ww_wait_for_value` | `ww_wait_for` with optional `property` + `op` + `expected` — if omitted, waits for element existence; if provided, waits for value match | 1 | Schema is a superset. Element-existence wait is value-wait without assertion params. |
| `ww_wait_for_dialog` + `ww_expect_dialog` | `ww_wait_for_dialog` with optional `title` + `assert: true\|false` — `assert: true` makes it a test assertion (like `ww_expect_dialog`) | 1 | Both wait for a dialog. `expect` adds title matching and assertion semantics. |
| `ww_record_start` + `ww_record_pop` | `ww_record` with `action: "start"\|"pop"`, optional `count` (for pop) | 1 | Both manage recording state. Pop needs `count`, start doesn't — trivially conditional. |
| `ww_test_case_start` + `ww_test_case_end` | `ww_test_case` with `action: "start"\|"end"` | 1 | Simple state toggle. |

#### System Merges

| Current | Proposed | Saved | Rationale |
|---------|----------|-------|-----------|
| `ww_service_start` + `ww_service_stop` + `ww_service_restart` | `ww_service_control` with `action: "start"\|"stop"\|"restart"` | 2 | Same schema (service name), trivially different operations. |
| `ww_process_list` + `ww_process_kill` | `ww_process` with `action: "list"\|"kill"`, optional `processId` (for kill), optional `nameFilter` (for list) | 1 | Both operate on processes. Kill needs PID, list needs filter — trivially conditional. Permission guard on `action: "kill"` replaces tool-level guard. |
| `ww_registry_read` + `ww_registry_write` | `ww_registry` with `action: "read"\|"write"`, optional `data` + `type` (for write) | 1 | Same key/value targeting. Write adds `data` and `type`. Permission guard on `action: "write"`. |

#### Browser Merges

| Current | Proposed | Saved | Rationale |
|---------|----------|-------|-----------|
| `ww_browser_connect` + `ww_browser_disconnect` | `ww_browser_session` with `action: "connect"\|"disconnect"` | 1 | Session lifecycle. Connect needs `debugPort`, disconnect needs nothing — trivially conditional. |

#### Summary

| Category | Tools Before | Tools After | Saved |
|----------|-------------|-------------|-------|
| Desktop Interaction | ~20 | ~10 | ~10 |
| System | ~10 | ~7 | ~3 |
| Testing/Recording | ~5 | ~3 | ~2 |
| Browser | ~3 | ~2 | ~1 |
| **Total** | | | **~16** |

**Estimated reduction:** ~16 tools eliminated, bringing the total from 110 to **~94**. Combined with category filtering + tiering, this puts every filtered view well under the 30-tool threshold.

### DO: Implement Category-Based Tool Filtering

Add a `--categories` flag or `enabledCategories` config option:

```json
{
  "enabledCategories": ["desktop-core", "testing"]
}
```

This is the single highest-impact change. It lets users stay under 30 tools per session.

### DO: Implement a Bootstrap + Discover Pattern

On MCP connection, expose only core tools (~12–15). Include `ww_get_schema` in the bootstrap set. When the agent needs specialized tools, it calls `ww_get_schema` to discover and activate them.

### DON'T: Merge Operations With Fundamentally Different Semantics

Never merge tools where the operations require completely different mental models:
- `ww_click` vs `ww_drag` (point action vs source-target action — `drag` needs two selectors)
- `ww_type` vs `ww_keyboard` (text input vs key commands — different input models)
- `ww_screenshot` vs `ww_snapshot` (pixel capture vs UIA tree — different output types)
- `ww_export_script` vs `ww_heal_script` (serialize vs repair — different workflows)

### DON'T: Create a Generic `ww_execute` Tool

The "single uber-tool" pattern (one tool that accepts arbitrary commands) destroys type safety, audit clarity, and permission granularity. It's mentioned in the literature as a technique but is widely discouraged for production MCP servers.

---

## Part 6: Impact Assessment

| Approach | Tool Count Exposed | Agent Accuracy | Token Cost | Audit Clarity | Implementation Effort |
|----------|--------------------|----------------|------------|---------------|----------------------|
| **Current (110 tools, all exposed)** | 110 | Poor | Very High | Excellent | None |
| **Mega-tool consolidation** | ~25–30 | Medium | Medium | Poor | High |
| **Aggressive merges only** | ~94 | Poor | High | Good | Medium |
| **Category filtering** | 15–40 per session | Good | Low | Excellent | Medium |
| **Bootstrap + discover** | 12–15 initially | Excellent | Very Low | Excellent | Medium |
| **Category filtering + aggressive merges** | 10–30 per session | Excellent | Very Low | Excellent | Medium |

**Recommended approach:** Category filtering + bootstrap/discover pattern + minor safe merges.

---

## Part 7: How This Aligns with MCP Standards

| MCP Best Practice | WinWright Current | Recommendation |
|-------------------|-------------------|----------------|
| Atomic, single-purpose tools | Compliant | Keep as-is |
| Clear, descriptive naming | Compliant | Keep as-is |
| Typed JSON Schema inputs | Compliant | Keep as-is |
| Focused, scoped servers | Non-compliant (110 tools in one server) | Add category filtering / multiple profiles |
| Manage tool budget (< 30) | Non-compliant | Dynamic filtering brings this into range |
| Error messages for agents | Compliant (structured JSON) | Keep as-is |
| Tool-level permissions | Compliant | Keep as-is; do not merge permission boundaries |

---

## Part 8: Critique and Open Questions

### 8.1 — Desktop Core at 35 Tools Still Exceeds the Threshold

Even after splitting Desktop Automation into Core (~35) and Recording/Testing (~15), the Desktop Core category alone exceeds the optimal 30-tool threshold. This means category filtering alone is insufficient — it must be combined with tiered exposure (Section 3.3) to bring the initial tool set down to ~12–15 core tools. Without tiering, a user who loads only Desktop Core still sees 35 tools, which is above the confusion onset point.

**Mitigation:** Tier 1 (always loaded) should be capped at 12–15 tools even within a category. The remaining Desktop Core tools (~20) should be Tier 2, activated on demand via `ww_get_schema`.

### 8.2 — The `ww_get_schema` Bootstrap Pattern Requires MCP Client Support

The bootstrap + discover pattern assumes the MCP client can dynamically add tools mid-session. Not all clients support this:

- **Claude Code / Claude Desktop** — Support `tools/list_changed` notifications (MCP spec 2024-11-05+), so dynamic tool sets work.
- **Cursor** — Hard cap at 40 tools, but unclear if it handles mid-session tool list changes.
- **Custom integrations** — Many simple MCP clients fetch tools once at connection and never refresh.

For clients that don't support dynamic tool lists, the fallback is static category filtering via `enabledCategories` in `winwright.json`.

### 8.3 — Aggressive Merges Reduce Tool Count Significantly but Don't Solve the Core Problem Alone

Aggressive merging across all categories saves ~16 tools (110 → ~94). This is a 15% reduction — meaningful, and it lowers the ceiling for every filtered view. But 94 tools exposed simultaneously is still in the "guaranteed failure" zone. Merges must be combined with category filtering + tiering to reach the ≤ 30 target.

### 8.4 — Category Boundaries May Not Match Real Workflows

Use Case 07 (Cross-App Workflows) and Use Case 08 (App Health Monitoring) both cross category boundaries — UC-07 needs Desktop Core + Browser, UC-08 needs Desktop Core + System. If the default is to load one category, users doing cross-category work must know to enable multiple categories. This is a UX design decision: auto-detect from the task vs. require explicit configuration.

### 8.5 — No Source Code Available for Verification

This analysis is based entirely on documentation (README, use case walkthroughs, configuration examples). The actual tool registration code, parameter schemas, and server architecture have not been reviewed. Recommendations should be validated against the source before implementation.

---

## Part 9: Implementation Plan

### 9.1 — What and Why (Specification)

#### Problem Statement

WinWright exposes 110 MCP tools simultaneously to AI agents. This causes:
- Tool selection failure (research shows >95% accuracy at 20 tools, near-zero at 100+)
- 11,000–33,000 tokens consumed by tool definitions alone
- Client hard limits exceeded (Cursor: 40, Claude Desktop: ~100)
- Positional bias causing systematic under-selection of later-defined tools

#### Goal

Reduce the number of tools exposed to any AI agent session to **≤ 30** (the optimal range) while preserving WinWright's atomic tool design, permission model, and audit clarity.

#### Success Criteria

| Metric | Current | Target |
|--------|---------|--------|
| Tools exposed on connection | 110 | 12–15 (bootstrap set) |
| Tools exposed per session (typical) | 110 | 20–30 (category + tier filtered) |
| Tools exposed per session (max) | 110 | ~94 (power user, explicit opt-in, after merges) |
| Token cost for tool definitions | 11K–33K | 1.2K–9K |
| Backward compatibility | N/A | Not required — clean break for merged tools |

#### Non-Goals

- Rewriting tool implementations (tools are well-designed as-is)
- Changing tool naming conventions
- Removing any tools
- Altering the permission/audit system

### 9.2 — How (Technical Implementation)

#### Architecture Overview

The implementation adds three layers between tool registration and tool exposure:

```
┌──────────────────────────────────────────────────┐
│  Tool Registry (all 110 tools, always registered) │
└──────────────────┬───────────────────────────────┘
                   │
          ┌────────▼────────┐
          │  Category Filter │ ← winwright.json: enabledCategories
          └────────┬────────┘
                   │
          ┌────────▼────────┐
          │   Tier Filter    │ ← bootstrap (Tier 1) on connect,
          │                  │   Tier 2/3 activated via ww_get_schema
          └────────┬────────┘
                   │
          ┌────────▼────────┐
          │  MCP tools/list  │ ← only filtered tools sent to client
          └─────────────────┘
```

#### Component 1: Tool Metadata (Category + Tier Annotations)

Each tool definition gets two new metadata fields:

```csharp
[McpTool("ww_click", Category = "desktop-core", Tier = ToolTier.Core)]
[McpTool("ww_heal_script", Category = "testing", Tier = ToolTier.Specialized)]
[McpTool("ww_browser_connect", Category = "browser", Tier = ToolTier.Core)]
[McpTool("ww_shell", Category = "system", Tier = ToolTier.Specialized)]
[McpTool("ww_get_schema", Category = "agent", Tier = ToolTier.Core)]
```

Category values: `desktop-core`, `testing`, `browser`, `system`, `agent`
Tier values: `Core` (always loaded), `Extended` (on demand), `Specialized` (explicit)

#### Component 2: Category Filter (Config-Driven)

`winwright.json` gets a new `enabledCategories` field:

```json
{
  "enabledCategories": ["desktop-core", "testing", "agent"],
  "permissions": { ... }
}
```

Rules:
- If `enabledCategories` is absent or empty → all categories enabled (backward compatible)
- `agent` category is always implicitly included (contains `ww_get_schema`)
- CLI override: `winwright mcp --categories desktop-core,browser`

#### Component 3: Tier Filter (Dynamic)

On MCP connection:
1. Only **Tier 1 (Core)** tools from enabled categories are listed in `tools/list`
2. `ww_get_schema` response includes the full catalog with tier and category metadata
3. When the agent calls `ww_activate_tools` (new tool) with a list of tool names or a category, those tools are added to the active set
4. Server sends `notifications/tools/list_changed` to notify the client
5. For clients that don't support `tools/list_changed`, a fallback mode exposes all enabled-category tools at connect time (no tiering)

#### Component 4: `ww_activate_tools` (New Bootstrap Tool)

```json
ww_activate_tools
{
  "tools": ["ww_wait_for", "ww_select", "ww_get_table_data"],  // specific tools
  // OR
  "category": "browser",           // activate an entire category
  // OR
  "tier": "extended"               // activate all extended-tier tools
}
```

Response:

```json
{
  "activated": ["ww_wait_for", "ww_select", "ww_get_table_data"],
  "totalActive": 18,
  "notification": "tools/list_changed sent"
}
```

This tool is always in the bootstrap set alongside `ww_get_schema`.

#### Component 5: Enhanced `ww_get_schema` Response

Current `ww_get_schema` returns tool descriptions. Enhanced version adds:

```json
{
  "categories": {
    "desktop-core": {
      "description": "Launch apps, click, type, read values, navigate UI trees",
      "tools": [
        { "name": "ww_click", "tier": "core", "active": true,
          "description": "Click an element by selector" },
        { "name": "ww_wait_for", "tier": "extended", "active": false,
          "description": "Wait for an element to appear" },
        { "name": "ww_drag", "tier": "extended", "active": false,
          "description": "Drag an element to a target" }
      ]
    },
    "testing": { ... },
    "browser": { ... },
    "system": { ... },
    "agent": { ... }
  },
  "activeTool Count": 15,
  "totalToolCount": 110
}
```

The agent sees the full catalog organized by category and tier, and can activate what it needs.

#### Component 6: `tools/list_changed` Notification

When `ww_activate_tools` adds tools, the server sends:

```json
{
  "method": "notifications/tools/list_changed"
}
```

Per MCP spec, this tells the client to re-fetch `tools/list`. The client then sees the newly activated tools.

**Fallback for clients that ignore this notification:** `winwright.json` option:

```json
{
  "toolExposure": "static"  // disables tiering; all enabled-category tools exposed at connect
}
```

Default is `"dynamic"` (tiered).

### 9.3 — Detailed Task Breakdown (Dependency Order)

#### Phase 1: Tool Inventory and Classification (No Code Changes)

| # | Task | Depends On | Output |
|---|------|------------|--------|
| 1.1 | Audit all 110 tools: extract name, current category, parameter schema, permission guard (if any) | — | `docs/tool-inventory.csv` |
| 1.2 | Assign each tool a category (`desktop-core`, `testing`, `browser`, `system`, `agent`) | 1.1 | Updated inventory |
| 1.3 | Assign each tool a tier (`core`, `extended`, `specialized`) based on use-case frequency analysis | 1.1, 1.2 | Updated inventory |
| 1.4 | Validate that the bootstrap set (Tier 1 core tools across all categories) is ≤ 15 tools | 1.3 | Validation report |
| 1.5 | Validate that each category's Tier 1 + Tier 2 tools are ≤ 30 | 1.3 | Validation report |

**Acceptance:** Final inventory reviewed and approved. No category exceeds 30 tools at Tier 1 + Tier 2. Bootstrap set is 12–15 tools.

#### Phase 2: Configuration Schema

| # | Task | Depends On | Output |
|---|------|------------|--------|
| 2.1 | Define `enabledCategories` field in `winwright.json` schema | 1.2 | Schema definition |
| 2.2 | Define `toolExposure` field (`"dynamic"` / `"static"`) | — | Schema definition |
| 2.3 | Add CLI `--categories` flag to `mcp` and `serve` commands | 2.1 | CLI parser update |
| 2.4 | Implement config loading: parse `enabledCategories` and `toolExposure` at startup | 2.1, 2.2 | Config loader |
| 2.5 | Add validation: warn if `enabledCategories` contains unknown category names | 2.4 | Validation logic |

**Acceptance:** `winwright.json` with `enabledCategories: ["desktop-core"]` starts the server with only desktop-core + agent tools. Missing field = all categories (backward compatible).

#### Phase 3: Tool Metadata and Registry

| # | Task | Depends On | Output |
|---|------|------------|--------|
| 3.1 | Define `ToolCategory` enum and `ToolTier` enum | 1.2, 1.3 | Enum types |
| 3.2 | Add `Category` and `Tier` metadata to tool registration (attribute or builder pattern) | 3.1 | Updated tool registrations |
| 3.3 | Annotate all 110 tools with their category and tier (per inventory from Phase 1) | 3.2, 1.2, 1.3 | All tools annotated |
| 3.4 | Build `ToolRegistry` class that holds all tools with metadata, supports filtering by category + tier | 3.3 | Registry class |
| 3.5 | Unit tests for `ToolRegistry` filtering logic | 3.4 | Test suite |

**Acceptance:** `ToolRegistry.GetTools(categories: ["desktop-core"], maxTier: Core)` returns exactly the expected subset. All 110 tools are annotated.

#### Phase 4: Category Filter (Static Filtering)

| # | Task | Depends On | Output |
|---|------|------------|--------|
| 4.1 | Wire `enabledCategories` config into `ToolRegistry` at startup | 2.4, 3.4 | Filtered registry |
| 4.2 | Modify `tools/list` handler to query `ToolRegistry` instead of exposing all tools | 4.1 | Updated handler |
| 4.3 | Ensure `agent` category is always included regardless of config | 4.1 | Implicit include logic |
| 4.4 | Wire CLI `--categories` flag to override config at runtime | 2.3, 4.1 | CLI override |
| 4.5 | Integration test: connect with `enabledCategories: ["system"]`, verify only system + agent tools are listed | 4.2, 4.3 | Integration test |

**Acceptance:** MCP client connecting to a server configured with `enabledCategories: ["system"]` sees only system + agent tools (~32). All other tools are hidden.

#### Phase 5: Tier Filter (Dynamic Filtering)

| # | Task | Depends On | Output |
|---|------|------------|--------|
| 5.1 | Add `ActiveToolSet` class: tracks which tools are currently exposed per session | 3.4 | Session state class |
| 5.2 | On connect, populate `ActiveToolSet` with Tier 1 (Core) tools from enabled categories | 5.1, 4.1 | Bootstrap logic |
| 5.3 | Modify `tools/list` to return only tools in `ActiveToolSet` | 5.2, 4.2 | Updated handler |
| 5.4 | Implement `toolExposure: "static"` fallback: if static, populate `ActiveToolSet` with all tiers at connect | 5.2, 2.2 | Fallback mode |
| 5.5 | Integration test: connect in dynamic mode, verify only Tier 1 tools listed | 5.3 | Integration test |

**Acceptance:** Dynamic mode exposes 12–15 tools on connect. Static mode exposes all enabled-category tools (backward compatible fallback).

#### Phase 6: `ww_activate_tools` Tool

| # | Task | Depends On | Output |
|---|------|------------|--------|
| 6.1 | Implement `ww_activate_tools` tool handler | 5.1 | Tool implementation |
| 6.2 | Support activation by tool name list, category, or tier | 6.1, 3.4 | Activation logic |
| 6.3 | Send `notifications/tools/list_changed` after activation | 6.1 | MCP notification |
| 6.4 | Validate: cannot activate tools from disabled categories | 6.2, 4.1 | Guard logic |
| 6.5 | Add `ww_activate_tools` to bootstrap set (always in Tier 1, agent category) | 6.1, 3.3 | Metadata |
| 6.6 | Unit + integration tests for activation flows | 6.1–6.5 | Test suite |

**Acceptance:** Agent calls `ww_activate_tools { "category": "browser" }`, server adds browser tools to active set, sends `tools/list_changed`, client re-fetches and sees browser tools.

#### Phase 7: Enhanced `ww_get_schema`

| # | Task | Depends On | Output |
|---|------|------------|--------|
| 7.1 | Extend `ww_get_schema` response to include category groupings, tier labels, and active/inactive status | 3.4, 5.1 | Updated response schema |
| 7.2 | Include tool descriptions and parameter summaries in the grouped response | 7.1 | Enhanced output |
| 7.3 | Add `activeToolCount` and `totalToolCount` to response | 7.1 | Metadata fields |
| 7.4 | Unit tests for enhanced schema output | 7.1–7.3 | Test suite |

**Acceptance:** `ww_get_schema` returns a categorized, tiered catalog. Agent can see all available tools (including inactive ones) and knows which to activate.

#### Phase 8: Documentation and Migration

| # | Task | Depends On | Output |
|---|------|------------|--------|
| 8.1 | Update README: document `enabledCategories`, `toolExposure`, and `--categories` CLI flag | 4.5, 5.5 | README update |
| 8.2 | Add "Tool Filtering" section to README with recommended profiles per role | 8.1 | New section |
| 8.3 | Update use case docs: add recommended `enabledCategories` to each use case's Prerequisites | 8.1 | Use case updates |
| 8.4 | Document the bootstrap + discover workflow for agent developers | 6.6, 7.4 | Developer guide |
| 8.5 | Add migration guide for users upgrading from previous versions | 8.1 | Migration doc |

**Acceptance:** A new user reading the README understands how to configure tool filtering for their role. Existing users upgrading see no behavior change (default = all categories, static mode).

#### Phase 9: Aggressive Tool Merges

Merge all tool groups where operations share a common schema and differ only by a mode/action value. Old tool names are removed — no aliases.

**Desktop interaction merges:**

| # | Task | Depends On | Output |
|---|------|------------|--------|
| 9.1 | Merge `ww_click` + `ww_double_click` + `ww_right_click` + `ww_hover` → `ww_click` with `clickType: "single"\|"double"\|"right"\|"hover"` (default `"single"`) | Phase 5 complete | Merged tool (saves 3) |
| 9.2 | Merge `ww_launch` + `ww_attach` → `ww_app` with `action: "launch"\|"attach"`, optional `exePath` / `processId` | Phase 5 complete | Merged tool (saves 1) |
| 9.3 | Merge `ww_snapshot` + `ww_query` → `ww_inspect` with optional `selector` (omit = full tree, provide = filtered) | Phase 5 complete | Merged tool (saves 1) |
| 9.4 | Merge `ww_get_value` + `ww_assert_value` → `ww_get_value` with optional `op` + `expected` + `message` (if present = assert, if absent = read-only) | Phase 5 complete | Merged tool (saves 1) |
| 9.5 | Merge `ww_wait_for` + `ww_wait_for_value` → `ww_wait_for` with optional `property` + `op` + `expected` (if omitted = wait for existence, if present = wait for value match) | Phase 5 complete | Merged tool (saves 1) |
| 9.6 | Merge `ww_wait_for_dialog` + `ww_expect_dialog` → `ww_wait_for_dialog` with optional `title` + `assert` flag | Phase 5 complete | Merged tool (saves 1) |

**Recording & testing merges:**

| # | Task | Depends On | Output |
|---|------|------------|--------|
| 9.7 | Merge `ww_record_start` + `ww_record_pop` → `ww_record` with `action: "start"\|"pop"`, optional `count` | Phase 5 complete | Merged tool (saves 1) |
| 9.8 | Merge `ww_test_case_start` + `ww_test_case_end` → `ww_test_case` with `action: "start"\|"end"` | Phase 5 complete | Merged tool (saves 1) |

**System merges:**

| # | Task | Depends On | Output |
|---|------|------------|--------|
| 9.9 | Merge `ww_service_start` + `ww_service_stop` + `ww_service_restart` → `ww_service_control` with `action: "start"\|"stop"\|"restart"` | Phase 5 complete | Merged tool (saves 2) |
| 9.10 | Merge `ww_process_list` + `ww_process_kill` → `ww_process` with `action: "list"\|"kill"`. Permission guard on `action: "kill"` | Phase 5 complete | Merged tool (saves 1) |
| 9.11 | Merge `ww_registry_read` + `ww_registry_write` → `ww_registry` with `action: "read"\|"write"`. Permission guard on `action: "write"` | Phase 5 complete | Merged tool (saves 1) |

**Browser merges:**

| # | Task | Depends On | Output |
|---|------|------------|--------|
| 9.12 | Merge `ww_browser_connect` + `ww_browser_disconnect` → `ww_browser_session` with `action: "connect"\|"disconnect"` | Phase 5 complete | Merged tool (saves 1) |

**Cleanup:**

| # | Task | Depends On | Output |
|---|------|------------|--------|
| 9.13 | Remove all old tool registrations (16 removed tools) | 9.1–9.12 | Dead code removal |
| 9.14 | Update recorded script runner to use new tool names only | 9.13 | Runner update |
| 9.15 | Update permission guards: `allowProcessKill` → guards `ww_process { action: "kill" }`, `allowRegistryWrite` → guards `ww_registry { action: "write" }` | 9.10, 9.11 | Permission migration |
| 9.16 | Update all documentation and use case examples to use new tool names | 9.1–9.12 | Doc updates |

**Acceptance:** All 16 merges complete. Old tool names removed. Permission guards migrated to action-level checks. Total tool count reduced by ~16 (110 → ~94).

### 9.4 — New Tool: `ww_type_human` (Human-Speed Typing)

#### What and Why

Many desktop and web applications have anti-bot detection, input validation tied to keystroke timing, or event handlers that fire per-character (e.g., autocomplete, live search, input masks). WinWright's current `ww_type` tool sends text instantly via UIA `ValuePattern.SetValue()` or equivalent — this bypasses per-key event handlers and is detectable as non-human input.

A new `ww_type_human` tool simulates typing at human speed (~40 words per minute, ~5 characters per second) by sending individual key events with realistic inter-key delays.

**Use cases:**
- Applications with anti-bot detection that flag instant text injection
- Input fields with per-keystroke event handlers (autocomplete, live validation, character counters)
- RPA workflows that must appear human-operated (compliance, audit trail realism)
- Testing keystroke-triggered behaviors (debounced search, input masking)

#### Tool Definition

```json
ww_type_human
{
  "appId": "app-1a2b",
  "selector": "AutomationId:txtSearch",
  "text": "quarterly revenue report 2026",
  "charsPerSecond": 5,         // default: 5 (~40 WPM). Range: 1–50
  "jitter": true,              // default: true. Adds ±30% random variation per keystroke
  "clearFirst": false          // default: false. Clear existing text before typing
}
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `appId` | string | Yes (desktop) | — | Target application ID |
| `selector` | string | Yes | — | Element selector (same syntax as `ww_type`) |
| `text` | string | Yes | — | Text to type |
| `charsPerSecond` | number | No | 5 | Typing speed. 5 = ~40 WPM. Range: 1–50 |
| `jitter` | boolean | No | true | Add ±30% random variation to inter-key delay |
| `clearFirst` | boolean | No | false | Clear existing text before typing |
| `windowId` | string | No | — | Target a specific window (for dialogs) |

**Response:**

```json
{
  "success": true,
  "charsTyped": 29,
  "durationMs": 5800,
  "averageCharsPerSecond": 5.0
}
```

**Behavior:**
- Sends individual `SendKeys` / keyboard events (not `ValuePattern.SetValue`)
- Base delay per character = `1000 / charsPerSecond` ms (200ms at 5 cps)
- With jitter: each delay is `baseDelay × (1 + random(-0.3, 0.3))`
- Works on Desktop (UIA `SendKeys`), WPF, WinForms, and Browser (CDP `Input.dispatchKeyEvent`)
- For browser targets, uses the same `selector` syntax as `ww_browser_type` (CSS selectors)
- Records to test scripts like `ww_type` — the replay runner respects the `charsPerSecond` timing

**Category:** `desktop-core` (also works for browser elements via CDP)
**Tier:** `Extended` (not needed in most sessions — loaded on demand)

#### Implementation Tasks

| # | Task | Depends On | Output |
|---|------|------------|--------|
| T.1 | Implement `SendKeysWithDelay` helper: sends one character at a time via UIA `SendKeys` with configurable delay + jitter | — | Helper method |
| T.2 | Implement CDP equivalent: `Input.dispatchKeyEvent` with per-key delay for browser targets | — | CDP helper |
| T.3 | Implement `ww_type_human` MCP tool handler: parameter validation, routing to desktop vs browser backend | T.1, T.2 | Tool handler |
| T.4 | Add focus management: click/focus the target element before typing (same as `ww_type`) | T.3 | Focus logic |
| T.5 | Add `clearFirst` support: select-all + delete before typing | T.3 | Clear logic |
| T.6 | Add recording support: `ww_type_human` steps include `charsPerSecond` in the recorded `extra` JSON | T.3 | Recording integration |
| T.7 | Add runner support: replay `ww_type_human` steps with correct timing | T.6 | Runner update |
| T.8 | Annotate with category `desktop-core`, tier `Extended` | T.3 | Metadata |
| T.9 | Unit tests: verify timing (within tolerance), jitter range, parameter validation | T.3 | Test suite |
| T.10 | Integration test: type into Notepad at 5 cps, verify text appears correctly | T.3 | Integration test |
| T.11 | Add to use case documentation (UC-02 Autonomous Desktop Automation, UC-06 Bulk Data Validation) | T.3 | Doc updates |

**Timing considerations:**
- At 5 cps, typing "Hello World" (11 chars) takes ~2.2 seconds
- At 1 cps (slow), same text takes ~11 seconds
- The tool is inherently slow by design — the `timeoutMs` for the step should account for text length × delay
- Runner should calculate expected duration and set an appropriate timeout

### 9.5 — Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Clients don't support `tools/list_changed` | Medium | Medium | `toolExposure: "static"` fallback bypasses dynamic tiering |
| Category assignments are wrong (tool in wrong category) | Low | Low | Phase 1 review + easy to re-categorize via metadata change |
| Bootstrap set is too small (agent can't do basic tasks) | Low | Medium | Include `ww_get_schema` + `ww_activate_tools` so agent can always self-expand |
| Breaking change for existing integrations | Low | High | Default config = all categories + static mode = identical to current behavior |
| Performance overhead of filtering | Very Low | Very Low | Filtering is a startup-time list operation, not a hot path |
| `ww_type_human` timing accuracy on loaded systems | Low | Low | Use `Task.Delay` with `Stopwatch`-based correction; tolerance documented |

### 9.6 — Implementation Priority

**Must-have (solves the core problem):**
- Phase 1 (inventory) → Phase 2 (config) → Phase 3 (metadata) → Phase 4 (category filter)

**Should-have (maximizes accuracy improvement):**
- Phase 5 (tier filter) → Phase 6 (`ww_activate_tools`) → Phase 7 (enhanced schema)

**Should-have (reduces total tool count):**
- Phase 9 (aggressive merges — can run in parallel with Phases 5–7)

**Should-have (polish):**
- Phase 8 (docs)

Category filtering alone (Phases 1–4) gets tool exposure from 110 → 22–45 per session. Aggressive merges (Phase 9) reduce the total from 110 to ~94, lowering every filtered view by ~15%. Adding tiering (Phases 5–7) gets it to 10–15 on connect.

---

## Conclusion

WinWright's individual tools are well-designed — atomic, consistently named, type-safe, and permission-guarded. The problem is not tool design; it's **tool exposure**. Exposing all 110 tools simultaneously overwhelms the AI agent's selection capability.

The solution is not to collapse tools into fewer mega-tools (which trades one problem for several worse ones), but to **control how many tools the agent sees at any given time** through:

1. **Category-based filtering** — users enable only the categories they need (5-category model: desktop-core, testing, browser, system, agent)
2. **Bootstrap + discover** — start with core tools, activate more on demand via `ww_activate_tools`
3. **Tool merges** — consolidate where schemas are identical (click variants, service control, test case lifecycle)

This preserves WinWright's clean architecture while bringing tool exposure into the optimal range for AI agent performance.

---

## References

- [MCP Specification (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25)
- [Docker: Top 5 MCP Server Best Practices](https://www.docker.com/blog/mcp-server-best-practices/)
- [Speakeasy: MCP Tools — Less Is More](https://www.speakeasy.com/mcp/tool-design/less-is-more)
- [RAG-MCP: Mitigating Prompt Bloat in LLM Tool Selection (arXiv:2505.03275)](https://arxiv.org/pdf/2505.03275)
- [Red Hat: Tool RAG — The Next Breakthrough in Scalable AI Agents](https://next.redhat.com/2025/11/26/tool-rag-the-next-breakthrough-in-scalable-ai-agents/)
- [MCP Discussion: Maximum Number of Tools](https://github.com/orgs/modelcontextprotocol/discussions/537)
- [MCP Discussion: How Many Servers and Tools Can It Handle?](https://github.com/modelcontextprotocol/modelcontextprotocol/discussions/1251)
- [Armin Ronacher: Your MCP Doesn't Need 30 Tools](https://lucumr.pocoo.org/2025/8/18/code-mcps/)
- [Lunar: How to Prevent MCP Tool Overload](https://www.lunar.dev/post/why-is-there-mcp-tool-overload-and-how-to-solve-it-for-your-ai-agents)
- [Allen Chan: How Many Tools Can an AI Agent Have?](https://achan2013.medium.com/how-many-tools-functions-can-an-ai-agent-has-21e0a82b7847)
- [Speakeasy: Reducing MCP Token Usage by 100x](https://www.speakeasy.com/blog/how-we-reduced-token-usage-by-100x-dynamic-toolsets-v2)
- [MCP Tool Design Guide (Obot AI)](https://obot.ai/resources/learning-center/mcp-tools/)
