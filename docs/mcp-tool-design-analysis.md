# MCP Tool Design Analysis: Should WinWright Consolidate Its 110 Tools?

> Deep analysis of tool count, AI agent adaptability, and MCP best practices — with a recommendation tailored to WinWright's architecture.

## Executive Summary

**Short answer: No — do not blindly consolidate tools into fewer "mega-tools" with mode parameters.**

WinWright's 110 tools are a real concern for AI agent performance, but the right solution is **not** collapsing them into fewer tools with more parameters. Instead, WinWright should adopt **dynamic tool filtering** (exposing only the tools relevant to the current task) and **logical server segmentation** (splitting tools across focused MCP servers or categories). The tools themselves are well-designed — atomic, single-purpose, clearly named — and that design should be preserved.

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

### 3.1 — Segment by Category (Multiple Logical Servers)

WinWright already has natural category boundaries. Expose them as separate MCP server configurations:

| Server Profile | Tools | Count |
|----------------|-------|-------|
| `winwright-desktop` | Desktop automation (launch, click, type, snapshot, recording) | ~25 core tools |
| `winwright-browser` | Browser automation (CDP tools) | 15 tools |
| `winwright-system` | System management (process, registry, services, files) | 22 tools |
| `winwright-testing` | Recording, export, assertions, healing | ~15 tools |
| `winwright-full` | Everything (for power users who understand the tradeoff) | 110 tools |

Users configure only the profiles they need. A QA engineer testing a WPF app loads `winwright-desktop` + `winwright-testing` (~40 tools). A sysadmin loads `winwright-system` (22 tools). Both stay under the 30-tool sweet spot.

**Implementation:** This can be a single binary with a `--profile` flag or a `tools` array in `winwright.json`:

```json
{
  "enabledCategories": ["desktop", "testing"]
}
```

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

### DO: Minor Consolidation Where Tools Are Truly Redundant

A few tools can be merged without losing clarity:

| Current | Proposed | Rationale |
|---------|----------|-----------|
| `ww_click` + `ww_double_click` + `ww_right_click` | `ww_click` with `clickType: "single"\|"double"\|"right"` | Same schema, same semantics, only the click type differs. Default to `"single"`. |
| `ww_service_start` + `ww_service_stop` + `ww_service_restart` | `ww_service_control` with `action: "start"\|"stop"\|"restart"` | Same schema (service name), trivially different operations. |
| `ww_test_case_start` + `ww_test_case_end` | `ww_test_case` with `action: "start"\|"end"` | Simple state toggle with same context. |

These are safe to merge because:
- The input schemas are identical (or nearly so)
- The operation is a simple variant, not a conditional mode
- No parameter becomes conditionally required

**Estimated reduction:** ~8–10 tools eliminated, bringing the total to ~100. This alone is insufficient — you still need dynamic filtering.

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

### DON'T: Merge Semantically Distinct Operations

Never merge tools that have different parameter schemas or different semantic meanings:
- `ww_wait_for` vs `ww_wait_for_value` (different schemas)
- `ww_snapshot` vs `ww_query` (tree dump vs element search)
- `ww_click` vs `ww_hover` (interaction vs observation)
- `ww_assert_value` vs `ww_get_value` (assertion vs read — merging confuses the agent about intent)

### DON'T: Create a Generic `ww_execute` Tool

The "single uber-tool" pattern (one tool that accepts arbitrary commands) destroys type safety, audit clarity, and permission granularity. It's mentioned in the literature as a technique but is widely discouraged for production MCP servers.

---

## Part 6: Impact Assessment

| Approach | Tool Count Exposed | Agent Accuracy | Token Cost | Audit Clarity | Implementation Effort |
|----------|--------------------|----------------|------------|---------------|----------------------|
| **Current (110 tools, all exposed)** | 110 | Poor | Very High | Excellent | None |
| **Mega-tool consolidation** | ~25–30 | Medium | Medium | Poor | High (breaking change) |
| **Minor merges only** | ~100 | Poor | High | Good | Low |
| **Category filtering** | 15–40 per session | Good | Low | Excellent | Medium |
| **Bootstrap + discover** | 12–15 initially | Excellent | Very Low | Excellent | Medium |
| **Category filtering + minor merges** | 12–35 per session | Excellent | Very Low | Excellent | Medium |

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

## Conclusion

WinWright's individual tools are well-designed — atomic, consistently named, type-safe, and permission-guarded. The problem is not tool design; it's **tool exposure**. Exposing all 110 tools simultaneously overwhelms the AI agent's selection capability.

The solution is not to collapse tools into fewer mega-tools (which trades one problem for several worse ones), but to **control how many tools the agent sees at any given time** through:

1. **Category-based filtering** — users enable only the categories they need
2. **Bootstrap + discover** — start with core tools, activate more on demand
3. **Minor safe merges** — consolidate only where schemas are truly identical

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
