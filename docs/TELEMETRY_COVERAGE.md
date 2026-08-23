# Telemetry Coverage — Reverse Engineering & Local Enrichment

## Summary

Reverse-engineered the DevBar `telemetry-usage-hook` (v1.5.5) to understand what
Claude Code usage telemetry is sent, identified gaps, and built a local
enrichment layer to track richer signals for AI proficiency measurement.

## Work Done

### 1. Reverse Engineering (telemetry-usage-hook binary)

**Binary**: `~/.devbar/bin/telemetry-usage-hook` (Go, compiled)

**Endpoint**: `https://ai-attribution.sfproxy.devx-preprod.aws-esvc1-useast2.aws.sfdc.cl/api/v1/telemetry`

**Config**: `~/.telemetry-usage-hook/config.yaml`
- `auth_source: daemon` — gets QuantumK token from DevBar daemon socket
- `require_auth: true` — drops events silently if no token
- `compression: false`

**Wire format**: Protobuf (`application/x-protobuf`)

**Decoded payload fields**:
| Field | Source |
|-------|--------|
| conversation_id | Generated UUID (NOT the session_id from input) |
| generation_id | Same UUID |
| timestamp | ISO 8601 |
| vendor | "claude-code" |
| git.repository_url | From CWD git remote |
| labels.org | Parsed from git remote URL |
| labels.repo_name | Parsed from git remote URL |
| labels.hook_event | PreToolUse / PostToolUse / Stop / etc. |
| labels.tool_id | Tool name (remapped: Bash→Shell, Edit→Write) |
| labels.model | Model ID from hook input |
| labels.os | darwin / linux |
| labels.arch | arm64 / amd64 |
| labels.hook_version | 1.5.5 |
| labels.event_name | AI_TOOL_USED |
| labels.payload_kind | usage_sanitized |
| labels.mode | usage_only |

**Key finding**: `payload_kind: usage_sanitized` — no code content, file paths,
or tool input/output is sent. Only metadata about which tool was used.

**Blocker found**: DevBar daemon not authenticated → all events silently dropped.
Production telemetry is NOT flowing in current state.

### 2. Local Enrichment Hook

**Created**: `~/.claude/hooks/usage-tracker.sh`

Fires alongside the DevBar hook on every event, logs to `~/.claude/usage-log.jsonl`
with fields the DevBar hook strips:

```json
{
  "t": 1781820464,
  "sid": "77eed548-854",
  "evt": "PostToolUse",
  "tool": "Edit",
  "model": "claude-opus-4-6-v1",
  "file": "README.md",
  "repo": "dotfiles",
  "ws": "dotfiles"
}
```

**Wired into events**: PostToolUse, SessionStart, Stop, SubagentStart, SubagentStop, UserPromptSubmit

### 3. Usage Report Script

**Created**: `~/.claude/hooks/usage-report.sh [days]`

Generates coverage metrics: tool distribution, session depth, PL3 signals
(agent spawns, read:write ratio, multi-repo breadth).

## Testing

### Test 1: Payload Capture (manual invocation)

Spawned a local HTTP server on port 9877, invoked the hook with:
- `COLLECTOR_ENDPOINT=http://127.0.0.1:9877/api/v1/telemetry`
- `USAGE_HOOK_REQUIRE_AUTH=false`
- `USAGE_HOOK_AUTH_SOURCE=none`

**Result**: Successfully captured 563-byte protobuf payload. Decoded all fields.

### Test 2: Multi-Model Subagent Verification

Spawned 3 parallel agents (Sonnet, Haiku, Opus) each tasked with:
- Reading the usage log (baseline)
- Performing tool calls
- Re-reading the log to confirm their events appeared

**Results** (all 3 consistent):
- Events logged in real-time ✅
- Cross-session visibility (saw other session `14681ffc`) ✅
- Subagent tool calls attributed to parent session_id ✅
- SubagentStart/SubagentStop lifecycle tracked ✅

### Test 3: MCP Tool Coverage

Spawned 3 agents using different MCP servers:
- Slack: `mcp__plugin_slack_slack__slack_search_public` ✅ tracked
- GUS: `mcp__GUS_MCP_Server__getCurrentUser` ✅ tracked
- Codesearch: failed (auth), but ToolSearch itself was tracked ✅

**Key finding**: MCP tools logged with full namespaced name (`mcp__<server>__<method>`),
making it easy to filter with the `mcp__` prefix.

### Test 4: Workflow Orchestration

Ran a 3-agent pipeline workflow (`telemetry-coverage-test`), each agent testing
a different tool (grep, glob, read).

**Results**:
- `Workflow` tool call itself tracked ✅ (shows as `tool: "Workflow"`)
- 3x `SubagentStart` events logged at workflow launch ✅
- 3x `SubagentStop` events logged at workflow completion ✅
- All subagent tool calls (Bash, Read) attributed to parent session ✅
- Workflow completed in ~12 seconds, all 3 agents confirmed their events appeared

### Test 5: Cross-Session Tracking

A concurrent session (`14681ffc`) working in `tableau-core-q3-cvt-flows` was
active during testing. Its events (UserPromptSubmit, Stop, Edit, Bash) all
appeared in the shared log interleaved with our test session.

**Result**: Multi-session, multi-repo tracking confirmed ✅

### Final Session Stats

After all testing in a single session:
- **109 total events** captured
- **15 agent/subagent spawns** tracked
- **2 repos** active concurrently
- **9 unique tools** in distribution (including 2 MCP, 1 Workflow)
- **1 session exceeding 50 events** (this one)

## Coverage Map

### Currently Tracked (via local enrichment hook)

| Signal | Status |
|--------|--------|
| Tool invocations (built-in) | ✅ Full |
| Tool invocations (MCP) | ✅ Full, with server namespace |
| Session lifecycle | ✅ Start, Stop |
| Subagent lifecycle | ✅ Start, Stop |
| User prompts | ✅ Each message |
| Tool failures | ✅ PostToolUseFailure |
| Repo/workspace context | ✅ Per event |
| Model per call | ✅ (when populated) |
| Session correlation | ✅ sid field |
| File paths (basename only) | ✅ No content |
| Multi-session cross-visibility | ✅ Shared log |

### Not Yet Tracked (Gaps)

| Signal | Reason |
|--------|--------|
| Token usage / cost | Not in hook input |
| Tool execution duration | Derivable from Pre→Post timestamp pairs (now wired) |
| Permission prompts | PermissionRequest not wired |
| Skill invocations | No distinct hook event (tool_name is "Skill" — use that) |
| Plan mode enter/exit | No distinct hook event |
| Workflow depth (nested agents) | Attributed to parent session |
| Git operations (commits, PRs) | Would need Bash command parsing |

### PL3 Signals Derivable from Current Data

| Metric | How to Compute |
|--------|---------------|
| Orchestration depth | Count Agent + SubagentStart events per session |
| Tool ecosystem breadth | Unique tool names, especially `mcp__*` prefix |
| Session intensity | Events per session, sessions > 50 events |
| Multi-repo activity | Unique repos per time window |
| Generation vs review | Edit+Write : Read ratio |
| Error recovery | PostToolUseFailure followed by retry patterns |

## Files

| File | Purpose |
|------|---------|
| `~/.claude/hooks/usage-tracker.sh` | Local enrichment hook |
| `~/.claude/hooks/usage-report.sh` | Coverage report generator |
| `~/.claude/usage-log.jsonl` | Event log (append-only) |
| `~/.claude/settings.json` | Hook wiring (PostToolUse, lifecycle events) |
| `~/.telemetry-usage-hook/config.yaml` | DevBar hook config |

## MCP Server Expected State

For maximum telemetry coverage, all MCP tools should be exercised. Target state:

### Tier 1: Must Work (exercise depends on these)

| Server | Auth Mechanism | Fix if Broken |
|--------|---------------|---------------|
| Slack (`plugin:slack:slack`) | aisuite proxy (port 29051) | `/reload-plugins` or restart session |
| GUS MCP Server | User MCPs (settings.json) | Check `~/.claude/claude.json` |
| GitHub (`plugin:github`) | aisuite proxy | `/reload-plugins` |
| Google (`plugin:google`) | aisuite proxy | `/reload-plugins` |
| Gmail (`plugin:gmail`) | aisuite proxy | `/reload-plugins` |
| AISuite Python (`plugin:aisuite`) | aisuite proxy | `/reload-plugins` |
| mcp-adaptor (codesearch) | QuantumK via `mcp-adaptor auth` | Run `/salesforce-trust-foundations:mcp-auth` |

### Tier 2: Should Work (extend coverage)

| Server | Auth Mechanism | Fix if Broken |
|--------|---------------|---------------|
| Codesearch (`plugin:codesearch`) | aisuite proxy | `/reload-plugins` — proxy is healthy (port 29051 responds) |
| Enterprise Search (`plugin:search`) | aisuite proxy | `/reload-plugins` — same proxy, should reconnect |
| Columbo (`plugin:columbo`) | aisuite proxy + Delphi SSO | Call `mcp__plugin_columbo_columbo__refresh_auth` (needs browser) |
| Browser (`plugin:browser`) | None (local) | Should always work |
| Playwright | User MCPs | Should always work |

### Tier 3: Nice to Have (org-specific, often fail)

| Server | Auth Mechanism | Fix if Broken |
|--------|---------------|---------------|
| dxmcp-* (7 servers) | mcp-adaptor QuantumK + network | Often fail — need VPN + fresh `mcp-adaptor auth` |
| falcon, git-emu, git-soma | vmcp (virtual MCP) | Need salesforce-native-ai-stack marketplace working |
| google-workspace | vmcp | Separate from plugin:google (which works) |
| monitoring | vmcp | Org-specific, low priority |
| gus:gus_server | Separate from GUS MCP Server | Use GUS MCP Server instead |
| Local slack | Needs separate auth | Use plugin:slack:slack instead |

### Remediation Playbook

```
Problem: "Not connected" / "Token expired"
  1. Check proxy: curl -s http://127.0.0.1:29051/health → expect 200
  2. If proxy down: restart DevBar app
  3. If proxy up but tools fail: /reload-plugins in Claude Code
  4. If still fails: restart Claude Code session

Problem: mcp-adaptor tools fail
  1. Run: ~/.mcp-adaptor/bin/mcp-adaptor auth
  2. Complete browser SSO
  3. /mcp → reconnect mcp-adaptor

Problem: DevBar telemetry "dropping (no token)"
  1. Open DevBar app → ensure signed in
  2. Verify: USAGE_HOOK_DEBUG=1 ~/.devbar/bin/telemetry-usage-hook < payload
  3. Should show "sending" not "dropping"

Problem: dxmcp-* all fail
  1. These need both mcp-adaptor auth AND network/VPN access
  2. Often not needed — mcp-adaptor search covers codesearch use cases
  3. Low priority unless specifically needed
```

## Next Steps

- [x] ~~Authenticate DevBar daemon~~ — working (exit 0, no "dropping" message)
- [x] ~~Wire PreCompact/PostCompact hooks~~ — done, all 11 events wired
- [x] ~~Test Workflow orchestration tracking~~ — done, Workflow tool + SubagentStart/Stop all tracked
- [x] ~~Add PreToolUse to enrichment hook~~ — done, enables duration calc
- [ ] Build weekly digest from usage-log.jsonl
- [ ] Parse Bash commands to detect git commit/push/PR creation patterns
- [ ] Add skill_name extraction (hook source reveals `GetSkillName` field exists)
- [ ] Fix plugin:codesearch reconnection (proxy is healthy, plugin layer issue)
