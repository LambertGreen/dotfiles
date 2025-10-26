# Dotfiles API Architecture: Conversational Configuration Management

## Philosophy

This dotfiles system embodies **consent-based configuration** - it respects user agency by asking permission before making changes, rather than assuming or forcing configurations upon users.

The system is designed around a conversational model:
- "Hey, do you want me to pull in your setup now?" 
- User can decline for urgent work or accept when they need their full configuration
- This creates a **respectful, two-way communication** between user and system

## Core Design Principle: Layered Abstraction

The system follows a strict architectural hierarchy where each layer only communicates with adjacent layers, never penetrating through abstractions:

```
Testing/Automation Layer (Docker, CI/CD)
    ↓ (uses dotfiles API only)
Dotfiles System Layer (scripts, justfile commands) 
    ↓ (converses with configuration)
Configuration Layer (shell config, editor config)
    ↓ (manages implementation details)
Implementation Layer (zinit, elpaca, package managers)
```

### The Universe Metaphor

- **Dotfiles System**: The "universe" with consistent laws and behaviors
- **Configuration Scripts**: The "laws of physics" that govern how things work
- **Testing/Automation**: "Visitors" to the universe who must respect its laws
- **Implementation Tools**: Internal mechanisms that users shouldn't need to understand

## API Design Patterns

### Shell Configuration API

The shell configuration provides these API functions for external systems to use:

```zsh
# Query current state
lgreen_shell_status()           # Returns: "Shell ready: X plugins loaded"
                               # Exit code: 0 if ready, 1 if not

# Wait for ready state  
lgreen_await_shell_ready(timeout) # Waits up to timeout seconds for readiness
                                  # Returns: status message and exit code

# Perform maintenance operations
lgreen_ensure_plugins_updated()   # Updates and compiles all plugins
                                  # Returns: success/failure message
```

### Key Properties of This API:

1. **Self-Describing**: The configuration knows its own state
2. **Non-Intrusive**: External systems don't need to understand internal mechanisms  
3. **Conversational**: Preserves the interactive prompts and timeout behaviors
4. **Testable**: Can be called programmatically while maintaining the user experience
5. **Swappable**: Plugin managers can be changed without affecting external callers

## Implementation Benefits

### Before: Direct Intrusion
```dockerfile
# BAD: Docker knows about zinit internals
RUN echo 'zinit update --all && zinit cclear' | zsh -l -i
```

### After: API Respect
```dockerfile  
# GOOD: Docker uses the dotfiles API
RUN ./scripts/package-management/init-dev-packages.sh
```

```bash
# Inside init-dev-packages.sh - uses the API
zsh -l -i -c 'source ~/.zshrc && lgreen_await_shell_ready 45'
```

## Extending to Other Tools

This pattern should be applied to other app-based package managers:

### Emacs API (Future)
```elisp
(lgreen-emacs-status)              ; Query elpaca state
(lgreen-await-emacs-ready timeout) ; Wait for packages to load
(lgreen-ensure-packages-updated)   ; Update all packages
```

### Neovim API (Future)  
```lua
lgreen_nvim_status()              -- Query lazy.nvim state
lgreen_await_nvim_ready(timeout)  -- Wait for plugins ready
lgreen_ensure_plugins_updated()   -- Update all plugins
```

### Tmux API (Future)
```bash
lgreen_tmux_status()              # Query TPM state
lgreen_await_tmux_ready(timeout)  # Wait for plugins loaded
lgreen_ensure_plugins_updated()   # Update TPM plugins
```

## Testing Philosophy

The system's conversational nature is preserved in testing by:

1. **Using Built-in Timeouts**: The 10-second auto-install timeout IS the unattended mode
2. **Respecting the Conversation**: Tests wait for prompts and let timeouts occur naturally  
3. **API-Based Verification**: Check readiness through the provided APIs, not implementation details
4. **Single Source of Truth**: Each configuration layer reports its own state

## Implementation Guidelines

### For New Tool Integrations

1. **Add API Functions**: Create status, await, and update functions in the tool's config
2. **Use Dotfiles Scripts**: Never call tool APIs directly from Docker/CI  
3. **Respect Timeouts**: Let interactive prompts work via their built-in timeout mechanisms
4. **Test the Real Thing**: Test the actual conversational flow, not a simplified version

### For External Systems (Docker, CI, Scripts)

1. **Use Only the API**: Never directly invoke zinit, elpaca, lazy.nvim, etc.
2. **Call Dotfiles Commands**: Use `just init-dev-packages`, not tool-specific commands
3. **Wait for Ready State**: Use the provided `await_ready` functions
4. **Trust the Status**: Use the tool's self-reported status rather than external checks

## Benefits of This Architecture

### Maintainability
- Plugin managers can be swapped without changing Docker files
- Testing setup is stable regardless of internal tool changes
- Single source of truth for each tool's state

### User Experience  
- Preserves the respectful, conversational interaction model
- Interactive use and automated use follow the same code paths
- No separate "CI mode" that might behave differently

### Reliability
- Each layer has clear responsibilities and boundaries
- Failures are contained within appropriate layers
- APIs provide consistent interfaces regardless of internal complexity

## Conclusion

This architecture treats configuration management as a **conversation between respectful entities** rather than forceful automation. By maintaining strict layer boundaries and providing thoughtful APIs, the system remains both user-friendly and automatable without compromising its core philosophical principles.

The result is a system that asks "May I help you?" rather than "I'm changing your environment now" - a rare and valuable approach in modern software design.