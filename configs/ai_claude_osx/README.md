# Claude Code Configuration for macOS

This directory contains Claude Code MCP server configuration template for macOS.

## Files

- `dot-claude.json.template` - Template for MCP server configurations

## Usage

The template file will be stowed to `~/.claude.json.template`. To use it:

1. Review the MCP server configurations in `~/.claude.json.template`
2. Manually merge the `mcpServers` section into your active `~/.claude.json` file
3. Note: Do NOT copy the entire template file - `~/.claude.json` contains runtime state

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
  - Location: `/Users/lambert.green/dev/work/mcp-server-gus/mcp-server.js`

## Platform-Specific Paths

The `mcp-adaptor` binary path is platform-specific:
- macOS: `~/.mcp-adaptor/bin/mcp-adaptor-go-v2.0.5-darwin-arm64`
- Linux: Will need `mcp-adaptor-go-*-linux-amd64`
- Windows: Will need `mcp-adaptor-go-*-windows-amd64.exe`
