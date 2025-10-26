# AI Assistant Guidelines

## Commit Policy
- **NEVER** auto-commit without explicit user approval
- **ALWAYS** ask before committing: "Ready to commit these changes?"
- **WAIT** for user's explicit "yes" or "commit this"
- **SUGGEST** commit messages but let user decide
- **ALWAYS** check `git status` before committing to ensure nothing is missed
- **AMEND** commits if needed rather than creating separate cleanup commits

## Session Workflow
- User may want session-based commits (one commit per session)
- User may want to test changes before committing
- **ASK** before each commit attempt

## Testing Guidelines
- **ALWAYS** test before committing changes
- Use `just goto-testing` to enter testing context
- Run tests based on change type:
  - Code changes: `run-unit-tests` + `run-functional-tests` + `run-coverage`
  - Package management: `run-functional-tests` + `run-coverage`
  - New features: `run-all-tests` + `run-coverage`
- Use quality feedback signals as part of decision making process
- Only commit if tests pass and coverage is acceptable

## Context Navigation
- Use `just goto-testing` to enter testing context
- Use `just goto-package-managers` to enter package management context
- Use `just goto-debugging` to enter debugging context

## Standard Approaches
- **ALWAYS** use standard approaches (e.g., `layout python3` for direnv)
- **NEVER** deviate from standard practices without explicit discussion
- **DISCUSS** any non-standard approaches before implementing
- **ASK** if unsure about the standard way to do something

## Environment Setup
- **ALWAYS** run `just check-dev-prerequisites` first to verify direnv and pyenv are installed
- **ALWAYS** run `direnv allow && eval "$(direnv export bash)"` to activate the environment
- **VERIFY** virtual environment is active with `which python3` before running Python commands
- **PERSISTENT SHELL**: The shell session persists between commands, so direnv activation only needed once per session
- **SIMPLE SETUP**: Only direnv and pyenv are needed - they handle everything else

## Working Directory Management
- **PREFER** running actions from project root by cd'ing to project at session start
- **AVOID** polluting command list with `cd` operations for every command
- **REMEMBER** to reset to project root whenever doing a `cd` operation
- **KEEP** command list focused on actual work, not navigation
- Context jumping is available for AI use, not just humans

## Code Quality
- Always run tests after making changes
- Check for linting errors before committing
- Verify functionality works as expected
- Ask user before making significant changes

## Fail Fast Principles
- **NEVER** hide failures with silent fallbacks or default values
- **ALWAYS** throw exceptions or assertions when encountering unexpected states
- **NEVER** use `.get()` with defaults for critical configuration
- **ALWAYS** validate platform/environment detection explicitly
- **FAIL LOUDLY** when something is wrong - silent failures waste hours of debugging
- **ASSERT PRECONDITIONS** - if a function expects certain state, validate it at entry
- **NO SILENT DEFAULTS** - if platform is unknown, crash with clear error message
- **EXAMPLES OF WHAT NOT TO DO**:
  - `executors.get(platform, LinuxTerminalExecutor)` ❌ Silent fallback hides unknown platform
  - `config.get('key', 'default')` ❌ when 'key' is required
  - `try: ... except: pass` ❌ Swallowing exceptions
- **EXAMPLES OF WHAT TO DO**:
  - `if platform not in executors: raise RuntimeError(f"Unsupported platform: {platform}")` ✅
  - `assert config['key'], "Required config missing"` ✅
  - `try: ... except SpecificError as e: raise RuntimeError(f"Failed because: {e}")` ✅
