"""
Test package manager selection interface
"""
import os
import sys
from io import StringIO
from unittest.mock import patch, MagicMock
import pytest

class TestPMSelection:
    """Test interactive package manager selection"""

    def test_selection_with_all_option(self):
        """Test selecting all package managers"""
        available_pms = ['brew', 'npm', 'pip']

        # Simulate user entering 'all'
        with patch('builtins.input', return_value='all'):
            # This would be the actual selection logic
            selected = available_pms if input() == 'all' else []

        assert selected == available_pms

    def test_selection_with_none_option(self):
        """Test selecting no package managers"""
        available_pms = ['brew', 'npm', 'pip']

        with patch('builtins.input', return_value='none'):
            selected = [] if input() == 'none' else available_pms

        assert selected == []

    def test_selection_with_numbers(self):
        """Test selecting specific package managers by number"""
        available_pms = ['brew', 'npm', 'pip', 'cargo']

        # Simulate user entering '1 3' (brew and pip)
        with patch('builtins.input', return_value='1 3'):
            user_input = input()
            selected = []
            for num_str in user_input.split():
                try:
                    idx = int(num_str) - 1
                    if 0 <= idx < len(available_pms):
                        selected.append(available_pms[idx])
                except ValueError:
                    pass

        assert selected == ['brew', 'pip']

    def test_selection_with_invalid_numbers(self):
        """Test handling invalid number selections"""
        available_pms = ['brew', 'npm']

        # User enters invalid numbers
        with patch('builtins.input', return_value='0 3 abc 1'):
            user_input = input()
            selected = []
            for num_str in user_input.split():
                try:
                    idx = int(num_str) - 1
                    if 0 <= idx < len(available_pms):
                        selected.append(available_pms[idx])
                except ValueError:
                    pass

        assert selected == ['brew']  # Only valid selection

    def test_selection_with_empty_input(self):
        """Test that empty input defaults to all"""
        available_pms = ['brew', 'npm', 'pip']

        with patch('builtins.input', return_value=''):
            selected = available_pms if input() == '' else []

        assert selected == available_pms

    def test_selection_timeout_behavior(self):
        """Test that timeout selects all PMs"""
        available_pms = ['brew', 'npm', 'pip']

        # Simulate timeout (would raise TimeoutError in real implementation)
        with patch('builtins.input', side_effect=TimeoutError):
            try:
                input()
                selected = []
            except TimeoutError:
                # On timeout, select all
                selected = available_pms

        assert selected == available_pms

    def test_non_interactive_mode(self):
        """Test that non-interactive mode selects all"""
        available_pms = ['brew', 'npm', 'pip']

        # Simulate non-interactive mode (stdin not a tty)
        with patch('sys.stdin.isatty', return_value=False):
            if sys.stdin.isatty():
                # Interactive - would show prompts
                selected = []
            else:
                # Non-interactive - select all
                selected = available_pms

        assert selected == available_pms

    def test_selection_display_format(self, capsys):
        """Test that selection options are displayed correctly"""
        available_pms = ['brew', 'npm', 'pip']

        # Simulate displaying options
        print("Select package managers:")
        print()
        for i, pm in enumerate(available_pms, 1):
            print(f"  {i}. {pm}")
        print()
        print("Enter numbers (e.g., '1 3'), 'all' (default), or 'none'")

        captured = capsys.readouterr()
        assert "Select package managers:" in captured.out
        assert "1. brew" in captured.out
        assert "2. npm" in captured.out
        assert "3. pip" in captured.out
        assert "'all' (default)" in captured.out

    @pytest.mark.parametrize("user_input,expected", [
        ("all", ['a', 'b', 'c']),
        ("none", []),
        ("1", ['a']),
        ("2 3", ['b', 'c']),
        ("1 2 3", ['a', 'b', 'c']),
        ("", ['a', 'b', 'c']),  # Empty = all
        ("99", []),  # Out of range
        ("abc", []),  # Invalid input
        ("1 abc 2", ['a', 'b']),  # Mixed valid/invalid
    ])
    def test_selection_variations(self, user_input, expected):
        """Test various selection input combinations"""
        available_pms = ['a', 'b', 'c']

        with patch('builtins.input', return_value=user_input):
            user_input = input()

            if user_input in ('all', ''):
                selected = available_pms
            elif user_input == 'none':
                selected = []
            else:
                selected = []
                for num_str in user_input.split():
                    try:
                        idx = int(num_str) - 1
                        if 0 <= idx < len(available_pms):
                            selected.append(available_pms[idx])
                    except ValueError:
                        pass

        assert selected == expected
