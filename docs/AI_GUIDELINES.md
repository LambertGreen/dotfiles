# AI Assistant Guidelines

## Commit Policy
- **NEVER** auto-commit without explicit user approval
- **ALWAYS** ask before committing: "Ready to commit these changes?"
- **WAIT** for user's explicit "yes" or "commit this"
- **SUGGEST** commit messages but let user decide

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
- Context jumping is available for AI use, not just humans

## Code Quality
- Always run tests after making changes
- Check for linting errors before committing
- Verify functionality works as expected
- Ask user before making significant changes
