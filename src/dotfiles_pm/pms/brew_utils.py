#!/usr/bin/env python3
"""
Brew Lock Detection and Recovery Utilities

Handles Homebrew's file locking issues by providing detection,
waiting, and cleanup mechanisms for stuck processes.
"""

import subprocess
import time
import re
import os
from typing import List, Dict, Optional, Tuple
from dataclasses import dataclass


class BrewLockError(Exception):
    """Raised when brew is locked and needs manual intervention"""
    pass


@dataclass
class BrewProcess:
    """Information about a running brew process"""
    pid: int
    command: str
    duration: str
    user: str


class BrewLockManager:
    """Manages Homebrew lock detection and recovery"""

    def __init__(self):
        self.max_wait_time = 300  # 5 minutes max wait
        self.check_interval = 5   # Check every 5 seconds

    def find_brew_processes(self) -> List[BrewProcess]:
        """Find all running brew processes"""
        try:
            # Look for brew update, brew upgrade, brew install processes
            result = subprocess.run(
                ['ps', 'aux'],
                capture_output=True,
                text=True,
                timeout=10
            )

            processes = []
            for line in result.stdout.split('\n'):
                if 'brew' in line and any(cmd in line for cmd in ['update', 'upgrade', 'install', 'bundle']):
                    # Skip our own grep process
                    if 'grep' in line or 'ps aux' in line:
                        continue

                    parts = line.split()
                    if len(parts) >= 11:
                        try:
                            processes.append(BrewProcess(
                                pid=int(parts[1]),
                                command=' '.join(parts[10:]),
                                duration=parts[9],  # TIME column
                                user=parts[0]
                            ))
                        except (ValueError, IndexError):
                            continue

            return processes
        except Exception:
            return []

    def is_brew_locked(self) -> Tuple[bool, Optional[str]]:
        """
        Check if brew is currently locked by testing a harmless command

        Returns:
            (is_locked, error_message)
        """
        try:
            # Try a quick, harmless brew command
            result = subprocess.run(
                ['brew', '--version'],
                capture_output=True,
                text=True,
                timeout=5
            )

            if result.returncode != 0:
                error_msg = result.stderr.strip()
                if 'already locked' in error_msg or 'lockf:' in error_msg:
                    return True, error_msg

            return False, None

        except subprocess.TimeoutExpired:
            return True, "Brew command timed out (likely locked)"
        except Exception as e:
            return True, f"Failed to check brew status: {str(e)}"

    def wait_for_brew_unlock(self, max_wait: Optional[int] = None) -> bool:
        """
        Wait for brew to become unlocked

        Args:
            max_wait: Maximum seconds to wait (None uses default)

        Returns:
            True if unlocked, False if timeout
        """
        max_wait = max_wait or self.max_wait_time
        start_time = time.time()

        print(f"⏳ Waiting for brew to become available (max {max_wait}s)...")

        while time.time() - start_time < max_wait:
            is_locked, error = self.is_brew_locked()

            if not is_locked:
                elapsed = int(time.time() - start_time)
                print(f"✅ Brew became available after {elapsed}s")
                return True

            # Show progress every 15 seconds
            elapsed = int(time.time() - start_time)
            if elapsed > 0 and elapsed % 15 == 0:
                processes = self.find_brew_processes()
                if processes:
                    print(f"⏳ Still waiting ({elapsed}s) - Found {len(processes)} brew processes")
                    for proc in processes[:3]:  # Show first 3
                        print(f"   PID {proc.pid}: {proc.command[:60]}...")
                else:
                    print(f"⏳ Still waiting ({elapsed}s) - No visible brew processes")

            time.sleep(self.check_interval)

        print(f"⏰ Timeout after {max_wait}s - brew still locked")
        return False

    def kill_stuck_brew_processes(self, force: bool = False) -> List[int]:
        """
        Kill stuck brew processes

        Args:
            force: Use SIGKILL instead of SIGTERM

        Returns:
            List of PIDs that were killed
        """
        processes = self.find_brew_processes()
        killed_pids = []

        if not processes:
            print("ℹ️  No brew processes found to kill")
            return killed_pids

        signal = 'KILL' if force else 'TERM'
        print(f"🔪 Killing {len(processes)} brew processes with SIG{signal}...")

        for process in processes:
            try:
                subprocess.run(['kill', f'-{signal}', str(process.pid)],
                             check=False, capture_output=True)
                killed_pids.append(process.pid)
                print(f"   Killed PID {process.pid}: {process.command[:50]}...")
            except Exception as e:
                print(f"   Failed to kill PID {process.pid}: {e}")

        if killed_pids:
            print(f"✅ Killed {len(killed_pids)} processes")
            # Give processes time to cleanup
            time.sleep(2)

        return killed_pids

    def _cleanup_stale_locks_if_needed(self) -> None:
        """
        Exception handler: Clean up stale lock files when we encounter lock errors.
        Only called when lock issues actually occur (EAFP pattern).
        """
        lock_file = '/opt/homebrew/var/homebrew/locks/update'
        if os.path.exists(lock_file):
            try:
                # Check if any actual brew update processes are running
                result = subprocess.run(['pgrep', '-f', 'brew.*update'],
                                     capture_output=True, text=True)
                if result.returncode != 0:  # No brew update processes found
                    print(f"🔧 Exception handler: Removing stale lock file")
                    os.remove(lock_file)
                    print("✅ Stale lock cleaned up")
            except Exception as e:
                print(f"⚠️ Failed to cleanup stale lock: {e}")

    def execute_with_lock_detection(self, command: List[str]) -> subprocess.CompletedProcess:
        """
        Execute brew command with lock error detection (no retry - just detect and raise)

        Args:
            command: Command to execute

        Returns:
            subprocess.CompletedProcess result

        Raises:
            BrewLockError: If brew is locked (exit code 41)
            subprocess.CalledProcessError: For other brew errors
        """
        try:
            # Check if command contains shell operators
            needs_shell = any(op in ' '.join(command) for op in ['&&', '||', '|', ';', '>', '<'])

            if needs_shell:
                # Convert to shell string and use shell=True
                cmd_str = ' '.join(command)
                result = subprocess.run(
                    cmd_str,
                    capture_output=True,
                    text=True,
                    shell=True,
                    timeout=300  # 5 minute timeout
                )
            else:
                # Use list form without shell
                result = subprocess.run(
                    command,
                    capture_output=True,
                    text=True,
                    timeout=300  # 5 minute timeout
                )

            # Check for lock errors in stderr regardless of exit code
            error_output = result.stderr.strip()
            if any(indicator in error_output.lower() for indicator in
                   ['already locked', 'lockf:', 'another brew']):
                # Raise specific error with exit code for justfile to handle
                raise BrewLockError(f"Brew locked: {error_output}")

            return result

        except subprocess.TimeoutExpired as e:
            raise BrewLockError("Brew command timed out (likely locked)") from e


# Global instance for easy access
brew_lock_manager = BrewLockManager()


def check_orphaned_locks() -> Dict[str, any]:
    """Check for orphaned lock files (locks without running processes)"""
    import platform

    # Platform-specific lock directory paths
    if platform.system() == 'Darwin':
        lock_dir = '/opt/homebrew/var/homebrew/locks'
    elif platform.system() == 'Linux':
        # Linuxbrew typically uses ~/.linuxbrew/var/homebrew/locks
        # or /home/linuxbrew/.linuxbrew/var/homebrew/locks
        home = os.path.expanduser('~')
        possible_paths = [
            f'{home}/.linuxbrew/var/homebrew/locks',
            '/home/linuxbrew/.linuxbrew/var/homebrew/locks',
            '/usr/local/var/homebrew/locks'  # fallback
        ]
        lock_dir = None
        for path in possible_paths:
            if os.path.exists(path):
                lock_dir = path
                break
        if not lock_dir:
            return {'orphaned_locks': [], 'errors': ['Linuxbrew lock directory not found']}
    else:
        return {'orphaned_locks': [], 'errors': ['Unsupported platform for brew lock detection']}

    orphaned_locks = []
    errors = []

    try:
        # Check for actual brew processes (not just files in homebrew directory)
        result = subprocess.run(['pgrep', '-f', 'brew.rb|brew update|brew upgrade|brew install'],
                              capture_output=True, text=True)

        if result.returncode == 0:
            # There are actual brew processes running
            return {'orphaned_locks': [], 'errors': ['Real brew processes detected, no orphaned locks']}

        # No real processes, check for lock files
        for filename in os.listdir(lock_dir):
            if filename.endswith('.lock') or filename == 'update':
                lock_file = os.path.join(lock_dir, filename)
                try:
                    # Check if file is actually locked (has content or is recent)
                    stat = os.stat(lock_file)
                    if stat.st_size > 0 or (time.time() - stat.st_mtime) < 3600:  # 1 hour
                        orphaned_locks.append({
                            'filename': filename,
                            'size': stat.st_size,
                            'age_seconds': int(time.time() - stat.st_mtime)
                        })
                except Exception as e:
                    errors.append(f"Failed to check {filename}: {e}")

    except Exception as e:
        errors.append(f"Error during orphaned lock check: {e}")

    return {
        'orphaned_locks': orphaned_locks,
        'errors': errors
    }


def get_brew_status_report() -> Dict[str, any]:
    """Get comprehensive brew status for troubleshooting"""
    manager = brew_lock_manager

    # Check lock status
    is_locked, lock_error = manager.is_brew_locked()

    # Find running processes
    processes = manager.find_brew_processes()

    # Check brew installation
    try:
        version_result = subprocess.run(['brew', '--version'],
                                     capture_output=True, text=True, timeout=5)
        brew_version = version_result.stdout.strip().split('\n')[0] if version_result.returncode == 0 else "Unknown"
    except:
        brew_version = "Not available"

    return {
        'is_locked': is_locked,
        'lock_error': lock_error,
        'running_processes': len(processes),
        'process_details': [
            {
                'pid': p.pid,
                'command': p.command[:80],
                'duration': p.duration,
                'user': p.user
            } for p in processes
        ],
        'brew_version': brew_version,
        'recommendations': _get_recommendations(is_locked, processes)
    }


def _get_recommendations(is_locked: bool, processes: List[BrewProcess]) -> List[str]:
    """Generate recommendations based on brew status"""
    recommendations = []

    if is_locked:
        recommendations.append("Brew is currently locked")

        if processes:
            recommendations.append(f"Found {len(processes)} running brew processes")
            recommendations.append("Try waiting with: python3 -m src.dotfiles_pm.pms.brew_utils wait")
            recommendations.append("Or force kill with: python3 -m src.dotfiles_pm.pms.brew_utils kill")
        else:
            recommendations.append("No visible processes - may be a stale lock file")
            recommendations.append("Try: brew cleanup --prune=all")
    else:
        recommendations.append("Brew appears to be available")
        if processes:
            recommendations.append(f"But {len(processes)} brew processes are running")

    return recommendations


if __name__ == '__main__':
    import sys

    if len(sys.argv) < 2:
        print("Usage: python3 brew_utils.py <command>")
        print("Commands: status, wait, kill, kill-force, check-orphaned-locks")
        sys.exit(1)

    command = sys.argv[1]
    manager = brew_lock_manager

    if command == 'status':
        status = get_brew_status_report()
        print("🍺 Brew Status Report")
        print("=" * 20)
        print(f"Locked: {status['is_locked']}")
        if status['lock_error']:
            print(f"Error: {status['lock_error']}")
        print(f"Running processes: {status['running_processes']}")
        print(f"Brew version: {status['brew_version']}")

        if status['process_details']:
            print("\nRunning processes:")
            for proc in status['process_details']:
                print(f"  PID {proc['pid']} ({proc['duration']}): {proc['command']}")

        if status['recommendations']:
            print("\nRecommendations:")
            for rec in status['recommendations']:
                print(f"  • {rec}")

    elif command == 'wait':
        max_wait = int(sys.argv[2]) if len(sys.argv) > 2 else None
        success = manager.wait_for_brew_unlock(max_wait)
        sys.exit(0 if success else 1)

    elif command in ['kill', 'kill-force']:
        force = command == 'kill-force'
        killed = manager.kill_stuck_brew_processes(force)
        print(f"Killed {len(killed)} processes")
        sys.exit(0)

    elif command == 'check-orphaned-locks':
        result = check_orphaned_locks()
        if result['orphaned_locks']:
            print(f"🔍 Found {len(result['orphaned_locks'])} orphaned lock files:")
            for lock in result['orphaned_locks']:
                age_min = lock['age_seconds'] // 60
                print(f"  • {lock['filename']} ({lock['size']} bytes, {age_min}m old)")
        else:
            print("✅ No orphaned lock files found")

        if result['errors']:
            print("\n⚠️  Errors:")
            for error in result['errors']:
                print(f"  • {error}")

        sys.exit(0)

    else:
        print(f"Unknown command: {command}")
        sys.exit(1)
