# Testing Documentation

This directory contains the test suite for the dotfiles package management system.

## Test Types

### Unit Tests
- **Purpose**: Test individual components in isolation
- **Tools**: pytest with mocks
- **Location**: `tests/test_*.py`
- **Run**: `just test-unit`

### Functional Tests  
- **Purpose**: Test the system with fake package managers
- **Tools**: pytest with fake PMs and test hooks
- **Location**: `tests/test_e2e_*.py`
- **Run**: `just test-functional`

#### Fakes
Fake package managers used for testing without real system dependencies:

- `fake-pm1` - Basic fake PM
- `fake-pm2` - Basic fake PM  
- `fake-sudo-pm` - Fake PM requiring sudo

#### Test Hooks
Environment variables for automated testing:

- `DOTFILES_PM_UI_SELECT` - Override UI selection (e.g., "1" for first PM)
- `DOTFILES_PM_ONLY_FAKES` - Enable only fake PMs for testing
- `DOTFILES_PM_DISABLE_REAL` - Disable all real PMs for CI

### Integration Tests
- **Purpose**: Test full system setup in containers
- **Tools**: Docker containers
- **Location**: `test/` directory
- **Run**: `just test-integration`
- **Status**: TODO - Implementation needed
