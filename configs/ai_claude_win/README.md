# Claude Code Configuration for Windows

This directory contains Claude Code MCP server configuration template for Windows.

## Files

- `dot-claude.json.template` - Template for MCP server configurations

## Usage

The template file will be stowed to `~/.claude.json.template`. To sync it:

### Quick Start
```bash
just stow          # Stows the template to ~/.claude.json.template
just sync-configs  # Shows sync instructions and commands
```

### Manual Sync (PowerShell/Git Bash)
1. Review the MCP server configurations in `~/.claude.json.template`
2. Merge the `mcpServers` section into your active `~/.claude.json`:
   ```bash
   # Using jq in Git Bash
   jq -s '.[0] * {mcpServers: .[1].mcpServers}' ~/.claude.json ~/.claude.json.template > /tmp/merged.json && mv /tmp/merged.json ~/.claude.json
   ```

   Or manually copy the `mcpServers` section from `~/.claude.json.template` into `~/.claude.json`

3. Note: Do NOT copy the entire template file - `~/.claude.json` contains runtime state

### When to Sync
- After `just stow` when you first set up
- After updating MCP server configs in the dotfiles repo
- When you need to restore MCP servers after Claude Code config issues

## Why a template?

Claude Code's `.claude.json` file contains:
- Runtime state (startup count, tips history, etc.)
- User preferences and settings
- **Sensitive data** (API keys, credentials)

Therefore, it cannot be directly version-controlled. This template provides just the MCP server configuration for reference.

## MCP Servers Configured

- **mcp-adaptor**: Salesforce DX MCP adaptor (internal tool)
- **GUS MCP Server**: Salesforce GUS (work item tracking) integration
  - Requires: Node.js and authenticated SFDX CLI (`sfdx auth:web:login -a GUS`)
  - Location: `C:\Users\lambert.green\dev\work\mcp-server-gus\mcp-server.js`

## Prerequisites

### Directory Junction Setup

The template assumes `~/dev/work` exists. On Windows work machines where the actual work directory is on `D:\dev\work` (for space reasons), create a junction:

```cmd
mklink /J C:\Users\lambert.green\dev\work D:\dev\work
```

This allows the template to use portable paths like `C:\Users\lambert.green\dev\work\...` that work via the junction.

## Platform-Specific Paths

The `mcp-adaptor` binary path is platform-specific:
- Windows: `~/.mcp-adaptor/bin/mcp-adaptor-go-v2.0.5-windows-amd64.exe`
- macOS: `~/.mcp-adaptor/bin/mcp-adaptor-go-v2.0.5-darwin-arm64`
- Linux: `~/.mcp-adaptor/bin/mcp-adaptor-go-*-linux-amd64`
