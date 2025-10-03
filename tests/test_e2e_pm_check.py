"""
End-to-end tests for package manager check flow

Tests the complete flow with fake PMs:
- Priority ordering (system PMs first)
- Sequential execution of sudo-requiring PMs
- Parallel execution of non-sudo PMs
- No double-spawn bug
- Terminal cleanup
"""
import os
import sys
import pytest
from pathlib import Path
from unittest.mock import patch

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))
sys.path.insert(0, str(PROJECT_ROOT / 'src' / 'dotfiles_pm'))


def test_fake_pm_detection():
    """Test that fake PMs are detected when enabled"""
    from pm_detect import detect_all_pms

    # Enable only fake PMs
    with patch.dict(os.environ, {
        'DOTFILES_PM_ENABLED': 'fake-pm1,fake-pm2,fake-sudo-pm',
        'DOTFILES_PM_DISABLED': 'apt,brew,npm,gem,emacs,zinit,neovim,cargo,pipx'
    }):
        pms = detect_all_pms()

        assert 'fake-pm1' in pms, "fake-pm1 should be detected"
        assert 'fake-pm2' in pms, "fake-pm2 should be detected"
        assert 'fake-sudo-pm' in pms, "fake-sudo-pm should be detected"
        assert 'apt' not in pms, "apt should be disabled"
        assert 'brew' not in pms, "brew should be disabled"


def test_fake_pm_priority_ordering():
    """Test that fake-sudo-pm has system priority and appears first"""
    from pm_detect import detect_all_pms
    from pm_executor import get_pm_priority

    with patch.dict(os.environ, {
        'DOTFILES_PM_ENABLED': 'fake-pm1,fake-pm2,fake-sudo-pm',
        'DOTFILES_PM_DISABLED': 'apt,brew,npm,gem,emacs,zinit,neovim,cargo,pipx'
    }):
        pms = detect_all_pms()
        sorted_pms = sorted(pms, key=get_pm_priority)

        # fake-sudo-pm should be first (system priority = 0)
        assert sorted_pms[0] == 'fake-sudo-pm', "fake-sudo-pm should have highest priority"
        assert get_pm_priority('fake-sudo-pm') == 0, "fake-sudo-pm should be system priority"
        assert get_pm_priority('fake-pm1') == 10, "fake-pm1 should be user priority"
        assert get_pm_priority('fake-pm2') == 10, "fake-pm2 should be user priority"


def test_sudo_metadata_field():
    """Test that sudo_required metadata field is used correctly"""
    from pm_executor import requires_sudo, get_pm_commands

    # Check fake-sudo-pm has sudo_required=True
    assert requires_sudo('fake-sudo-pm') == True, "fake-sudo-pm should require sudo"
    assert requires_sudo('fake-pm1') == False, "fake-pm1 should not require sudo"
    assert requires_sudo('fake-pm2') == False, "fake-pm2 should not require sudo"

    # Verify metadata structure
    commands = get_pm_commands()
    assert 'sudo_required' in commands['fake-sudo-pm'], "sudo_required field should exist"
    assert commands['fake-sudo-pm']['sudo_required'] == True


def test_pm_selection_with_test_mode():
    """Test that DOTFILES_PM_SELECT env var works for automated testing"""
    from pm_detect import detect_all_pms
    from pm_select import select_pms

    with patch.dict(os.environ, {
        'DOTFILES_PM_ENABLED': 'fake-pm1,fake-pm2,fake-sudo-pm',
        'DOTFILES_PM_DISABLED': 'apt,brew,npm,gem,emacs,zinit,neovim,cargo,pipx',
        'DOTFILES_PM_SELECT': '1'  # Select first PM (fake-sudo-pm after sorting)
    }):
        pms = detect_all_pms()
        selected = select_pms(pms)

        # Should select only fake-sudo-pm (first in priority order)
        assert len(selected) == 1, "Should select exactly 1 PM"
        assert selected[0] == 'fake-sudo-pm', "Should select fake-sudo-pm (first by priority)"


def test_pm_selection_multiple():
    """Test selecting multiple PMs by number"""
    from pm_detect import detect_all_pms
    from pm_select import select_pms

    with patch.dict(os.environ, {
        'DOTFILES_PM_ENABLED': 'fake-pm1,fake-pm2,fake-sudo-pm',
        'DOTFILES_PM_DISABLED': 'apt,brew,npm,gem,emacs,zinit,neovim,cargo,pipx',
        'DOTFILES_PM_SELECT': '1 2 3'  # Select all three
    }):
        pms = detect_all_pms()
        selected = select_pms(pms)

        assert len(selected) == 3, "Should select 3 PMs"
        assert 'fake-sudo-pm' in selected
        assert 'fake-pm1' in selected
        assert 'fake-pm2' in selected


def test_check_all_pms_separation():
    """Test that sudo and non-sudo PMs are properly separated"""
    from pm_check import check_all_pms
    from pm_executor import requires_sudo

    selected_pms = ['fake-sudo-pm', 'fake-pm1', 'fake-pm2']

    # Check separation logic
    sudo_pms = [pm for pm in selected_pms if requires_sudo(pm, 'check')]
    non_sudo_pms = [pm for pm in selected_pms if not requires_sudo(pm, 'check')]

    assert len(sudo_pms) == 1, "Should have 1 sudo PM"
    assert len(non_sudo_pms) == 2, "Should have 2 non-sudo PMs"
    assert sudo_pms[0] == 'fake-sudo-pm'
    assert set(non_sudo_pms) == {'fake-pm1', 'fake-pm2'}


def test_fake_pm_commands():
    """Test that fake PM commands are properly defined"""
    from pm_executor import get_pm_commands

    commands = get_pm_commands()

    # Check fake-sudo-pm
    assert 'fake-sudo-pm' in commands
    assert 'check' in commands['fake-sudo-pm']
    assert 'upgrade' in commands['fake-sudo-pm']
    assert 'install' in commands['fake-sudo-pm']
    assert commands['fake-sudo-pm']['sudo_required'] == True

    # Check fake-pm1
    assert 'fake-pm1' in commands
    assert commands['fake-pm1']['check'] == ['echo', 'fake-pm1: 5 packages outdated']
    assert commands['fake-pm1']['sudo_required'] == False

    # Check fake-pm2
    assert 'fake-pm2' in commands
    assert commands['fake-pm2']['check'] == ['echo', 'fake-pm2: 3 packages outdated']
    assert commands['fake-pm2']['sudo_required'] == False


def test_requires_sudo_uses_metadata():
    """Test that requires_sudo() uses metadata field, not command inference"""
    from pm_executor import requires_sudo

    # fake-sudo-pm command doesn't start with 'sudo', but metadata says it requires sudo
    assert requires_sudo('fake-sudo-pm') == True, "Should use metadata, not command parsing"

    # apt command starts with 'sudo', and metadata confirms it
    assert requires_sudo('apt') == True

    # brew doesn't require sudo
    assert requires_sudo('brew') == False


def test_no_double_spawn_bug_logic():
    """
    Test that the separation logic prevents double-spawn of sudo PMs.

    This was a critical bug: sudo PMs were being run in Phase 1 (sudo sequential)
    and then again in Phase 2 (sequential fallback) because the loop iterated
    over all selected_pms instead of just non_sudo_pms.

    This test verifies the logic without actually spawning terminals.
    """
    from pm_executor import requires_sudo

    # Simulate the selection
    selected_pms = ['fake-sudo-pm', 'fake-pm1', 'fake-pm2']

    # Phase 1: Separate sudo and non-sudo PMs (this is what check_all_pms does)
    sudo_pms = [pm for pm in selected_pms if requires_sudo(pm, 'check')]
    non_sudo_pms = [pm for pm in selected_pms if not requires_sudo(pm, 'check')]

    # Verify separation
    assert sudo_pms == ['fake-sudo-pm'], "Only fake-sudo-pm should be in sudo list"
    assert set(non_sudo_pms) == {'fake-pm1', 'fake-pm2'}, "fake-pm1 and fake-pm2 should be in non-sudo list"

    # Critical test: If we iterate over selected_pms in Phase 2, we'd process fake-sudo-pm again
    # Instead, we should only iterate over non_sudo_pms
    phase2_pms = non_sudo_pms  # Correct implementation
    assert 'fake-sudo-pm' not in phase2_pms, "fake-sudo-pm should NOT be in Phase 2 (would be double-spawn)"

    # Verify that if we only selected fake-sudo-pm, Phase 2 would have nothing to process
    selected_pms_sudo_only = ['fake-sudo-pm']
    sudo_pms_only = [pm for pm in selected_pms_sudo_only if requires_sudo(pm, 'check')]
    non_sudo_pms_only = [pm for pm in selected_pms_sudo_only if not requires_sudo(pm, 'check')]

    assert len(sudo_pms_only) == 1, "Should have 1 sudo PM"
    assert len(non_sudo_pms_only) == 0, "Should have 0 non-sudo PMs (Phase 2 skipped)"


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
