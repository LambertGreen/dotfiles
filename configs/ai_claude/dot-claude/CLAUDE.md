# Lambert - Working Identity

## Core Principle

**Text-based + programmable + AI-legible = compounding leverage.**

Tools where AI can read, suggest, and apply changes directly. Avoid GUI-locked systems where the human becomes the bottleneck.

## The Epistemological Loop

```
Theory (notes/plans) → Implementation (testing) → Results (tables) → Refined Theory
```

| Stage | Structure | Why |
|-------|-----------|-----|
| Conceptual knowledge | Graph/linked notes | Relationships, serendipity |
| Plans/builds | Prose, structured templates | Intentionality, reasoning |
| Results | Tables | Comparison, sorting, quantitative analysis |
| Insights | Notes (earned) | Validated patterns, not assumptions |

The note system receives and preserves insights. Tables are the crucible where patterns are proven. The graph shows what *might* connect; tables show what *actually* worked.

## Weapon Stack

| Function | Tool | Rationale |
|----------|------|-----------|
| Input | Split mechanical keyboard (Dygma Raise) | Physical foundation, daily practice |
| Planning | Emacs + Org-mode + org-roam | Programmable, AI-manipulable via emacsclient/elisp |
| Implementation | Code (polyglot) | The craft itself |
| Analysis | SQL + org-babel (DuckDB/SQLite) | Text-based, AI-legible, integrates with planning |
| Visualization | Generated (or Tableau for sharing) | Output format, not thinking tool |

## Development Environment

When running bash commands, prefer these modern tools (installed system-wide via dotfiles):

| Instead of | Use | Why |
|------------|-----|-----|
| grep | rg (ripgrep) | Faster, respects .gitignore, better output |
| find | fd | Faster, simpler syntax, respects .gitignore |
| sed (find/replace) | sd | Simpler syntax, safer defaults — `sd 'PATTERN' 'REPLACEMENT' FILE` (regex by default; not sed's `s/foo/bar/`) |
| ad-hoc JSON parsing | jq | Query/transform JSON pipelines |
| regex-based refactors | ast-grep | Structural (AST-aware) code search and rewrites — matches by syntax tree, not text |

Notes:
- Use rg for content search in files
- Use fd for finding files by name/path
- Available on my Mac machine classes via Brewfile; respect .gitignore by default for speed - use `-uu` flag when searching outside version control (build artifacts, system configs, etc.)
- Prefer the Edit tool over sd/sed for file edits I want reviewed; use sd for shell pipelines and one-shots
- Reach for ast-grep when a regex would over- or under-match because the change is language-structural (e.g., "rename this function's call sites but not string literals")

## Goals

Building a formal self-improving system applicable across work, games, and life.

- Games are the fast-feedback training ground for systematic iteration
- The meta-skill: recognizing patterns, testing hypotheses, encoding validated insights
- Hack the game rather than letting the game play me

## Working Context

- Software engineer (Salesforce/Tableau Analytics Cloud) - test automation, CVTs, quality
- Polyglot coder, cross-platform (Mac/Linux/Windows)
- Emacs as the integration point - org-roam for knowledge, org-babel for literate analysis
- Values: GNU philosophy, text-first tools, reproducible configurations

## Collaboration Notes for AI

- I prefer direct, technical discussion - skip disclaimers
- Help me see transferable patterns across domains
- Code and config suggestions should be text-based and editable
- When analyzing, prefer SQL/org-babel approaches over GUI tools
- I'm building systems for compounding returns, not one-off solutions
