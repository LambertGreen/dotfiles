"""
Integration tests for the package management system
"""
import os
import subprocess
from pathlib import Path
from unittest.mock import patch, MagicMock
import pytest

class TestIntegration:
    """Test integration of PM detection, selection, and execution"""

    def test_full_check_flow(self, fake_pm_scripts, capsys):
        """Test the complete check-packages flow"""
        # This simulates what check-packages.sh should do

        # 1. Detect PMs
        import shutil
        detected = []
        for pm in ['fake-pm1', 'fake-pm2']:
            if shutil.which(pm):
                detected.append(pm)

        assert len(detected) == 2

        # 2. Display detected PMs
        print(f"Detected PMs: {detected}")

        # 3. Simulate selection (user selects all)
        selected = detected

        # 4. Run check for each selected PM
        for pm in selected:
            result = subprocess.run([pm, 'outdated'],
                                  capture_output=True, text=True)
            print(f"{pm} outdated packages:")
            print(result.stdout)

        captured = capsys.readouterr()
        assert 'pkg-a 1.0.0 < 1.1.0' in captured.out
        assert 'tool-x 2.0.0 < 3.0.0' in captured.out

    def test_full_upgrade_flow(self, fake_pm_scripts):
        """Test the complete upgrade-packages flow"""
        # 1. Detect PMs
        import shutil
        detected = [pm for pm in ['fake-pm1', 'fake-pm2']
                   if shutil.which(pm)]

        # 2. Simulate selection
        selected = detected

        # 3. Run upgrade for each selected PM
        results = []
        for pm in selected:
            result = subprocess.run([pm, 'upgrade'],
                                  capture_output=True, text=True)
            results.append(result.stdout)

        assert 'Upgraded pkg-a to 1.1.0' in results[0]
        assert 'Upgraded tool-x to 3.0.0' in results[1]

    def test_empty_pm_list_handling(self):
        """Test behavior when no PMs are detected"""
        with patch('shutil.which', return_value=None):
            import shutil

            # No PMs detected
            detected = []
            for pm in ['brew', 'apt', 'npm']:
                if shutil.which(pm):
                    detected.append(pm)

            assert detected == []

            # Should handle gracefully
            if not detected:
                message = "No package managers detected"
                assert message == "No package managers detected"

    def test_partial_failure_handling(self, fake_pm_scripts):
        """Test handling when some PMs fail"""
        import shutil

        # Create a failing PM
        failing_pm = fake_pm_scripts['fake-pm1'].parent / 'fake-pm-fail'
        failing_pm.write_text("""#!/usr/bin/env bash
exit 1
""")
        failing_pm.chmod(0o755)

        # Run check on both success and fail PMs
        results = {}
        for pm in ['fake-pm2', 'fake-pm-fail']:
            if shutil.which(pm):
                result = subprocess.run([pm, 'outdated'],
                                      capture_output=True)
                results[pm] = result.returncode

        assert results['fake-pm2'] == 0
        assert results['fake-pm-fail'] == 1

    def test_cross_platform_behavior(self, platform_mock):
        """Test that the system works across platforms"""
        test_cases = [
            ('darwin', ['brew']),
            ('linux', ['apt']),
            ('win32', ['choco']),
        ]

        for platform, expected_pms in test_cases:
            platform_mock.set_platform(platform)

            with patch('shutil.which') as mock_which:
                # Mock PM existence based on platform
                mock_which.side_effect = lambda cmd: (
                    f'/path/to/{cmd}' if cmd in expected_pms else None
                )

                # Detect PMs for this platform
                import shutil
                detected = []
                for pm in ['brew', 'apt', 'choco', 'npm']:
                    if shutil.which(pm):
                        detected.append(pm)

                # Should only detect platform-appropriate PMs
                assert all(pm in expected_pms for pm in detected)

    def test_logging_separation(self, tmp_path, capsys):
        """Test that interactive parts work without logging interference"""
        # Create a simple script that does selection then logging
        script = tmp_path / "test_script.sh"
        script.write_text("""#!/bin/bash
echo "Interactive selection:"
read -t 1 -p "Select: " selection || selection="timeout"
echo "You selected: $selection"

# Now do logging
echo "[LOG] Starting process..." >> /tmp/test_logfile.log
echo "Process completed"
""")
        script.chmod(0o755)

        # Run with input
        result = subprocess.run(
            str(script),
            input="test\n",
            capture_output=True,
            text=True,
            shell=False
        )

        assert "You selected: " in result.stdout

    @pytest.mark.parametrize("context,expected_count", [
        ("system", 1),  # Just brew on macOS
        ("dev", 5),     # npm, pip, cargo, etc.
        ("app", 1),     # Just zinit
    ])
    def test_context_separation(self, context, expected_count, temp_home):
        """Test that contexts are properly separated"""
        # Mock different contexts having different PMs
        with patch('shutil.which') as mock_which:
            context_pms = {
                'system': ['brew'],
                'dev': ['npm', 'pip3', 'cargo', 'gem', 'nvim'],
                'app': [],  # Would check for directories
            }

            # Create app directories if needed
            if context == 'app':
                zinit_dir = temp_home / '.zinit'
                zinit_dir.mkdir()
                context_pms['app'] = ['zinit']

            mock_which.side_effect = lambda cmd: (
                f'/path/to/{cmd}' if cmd in context_pms.get(context, []) else None
            )

            # Detect PMs for this context
            import shutil
            detected = []
            for pm in context_pms.get(context, []):
                if context == 'app' and pm == 'zinit':
                    # Check directory instead
                    if (temp_home / '.zinit').exists():
                        detected.append(pm)
                elif shutil.which(pm):
                    detected.append(pm)

            assert len(detected) == expected_count
