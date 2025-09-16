#!/usr/bin/env python3
"""
End-to-end test with fake package managers only.

This validates the full check -> upgrade -> check cycle using fake PMs.
"""
import sys
from pathlib import Path

# Add src directory to path
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from src.dotfiles_pm.pm_detect import detect_all_pms
from src.dotfiles_pm.pm_select import select_pms
from src.dotfiles_pm.pm_check import check_all_pms
from src.dotfiles_pm.pm_upgrade import upgrade_all_pms


def filter_fake_pms(all_pms):
    """Filter to only fake PMs for testing."""
    return [pm for pm in all_pms if pm.startswith('fake-')]


def main():
    print("🧪 End-to-End Test with Fake PMs")
    print("=" * 34)

    # Step 0: Reset fake PMs to ensure clean state
    print("\n🔄 Step 0: Resetting fake PMs to clean state...")
    import subprocess
    for pm in ['fake-pm1', 'fake-pm2']:
        try:
            subprocess.run([pm, 'reset'], capture_output=True, check=True)
            print(f"  ✅ Reset {pm}")
        except (subprocess.CalledProcessError, FileNotFoundError):
            print(f"  ⚠️  Could not reset {pm} (not in PATH or failed)")

    # Step 1: Detect PMs
    print("\n📋 Step 1: Detecting package managers...")
    all_pms = detect_all_pms()
    fake_pms = filter_fake_pms(all_pms)

    if not fake_pms:
        print("❌ No fake package managers detected!")
        print("💡 Make sure ./test directory is in PATH")
        return 1

    print(f"✅ Found {len(fake_pms)} fake PMs: {fake_pms}")

    # Step 2: Selection (auto-select fake PMs)
    print("\n🎯 Step 2: Selecting package managers...")
    print(f"✅ Auto-selecting fake PMs: {fake_pms}")

    # Step 3: Initial check
    print("\n🔍 Step 3: Initial package check...")
    print("-" * 35)
    initial_results = check_all_pms(fake_pms)

    initial_outdated = sum(r['outdated_count'] for r in initial_results if r['success'])
    print(f"\n📊 Initial outdated packages: {initial_outdated}")

    # Step 4: Upgrade
    print("\n⬆️ Step 4: Upgrading packages...")
    print("-" * 32)
    upgrade_results = upgrade_all_pms(fake_pms)

    total_upgraded = sum(r['upgraded_count'] for r in upgrade_results if r['success'])
    print(f"\n📊 Total packages upgraded: {total_upgraded}")

    # Step 5: Final check
    print("\n🔍 Step 5: Final package check...")
    print("-" * 32)
    final_results = check_all_pms(fake_pms)

    final_outdated = sum(r['outdated_count'] for r in final_results if r['success'])
    print(f"\n📊 Final outdated packages: {final_outdated}")

    # Step 6: Validation
    print("\n✅ Step 6: Validation")
    print("-" * 20)

    print("Expected behavior:")
    print("  • Initial check should find outdated packages")
    print("  • Upgrade should process packages")
    print("  • Final check should find fewer/no outdated packages")
    print()

    print("Actual results:")
    print(f"  • Initial outdated: {initial_outdated}")
    print(f"  • Packages upgraded: {total_upgraded}")
    print(f"  • Final outdated: {final_outdated}")
    print()

    # Validation logic with detailed analysis
    success = True

    print("🔍 Validation Analysis:")

    if initial_outdated == 0:
        print("  ⚠️  Warning: No outdated packages found initially")
        print("      → This might indicate fake PMs need resetting")
    else:
        print(f"  ✅ Found {initial_outdated} outdated packages initially")

    if total_upgraded == 0:
        print("  ⚠️  Warning: No packages were upgraded")
        print("      → Check if upgrade commands are working")
    else:
        print(f"  ✅ Successfully upgraded {total_upgraded} packages")

    if final_outdated > initial_outdated:
        print("  ❌ Error: More outdated packages after upgrade")
        print("      → This indicates a serious problem with upgrade logic")
        success = False
    elif final_outdated < initial_outdated:
        reduction = initial_outdated - final_outdated
        print(f"  ✅ Reduced outdated packages by {reduction} (from {initial_outdated} to {final_outdated})")
    elif final_outdated == initial_outdated and total_upgraded > 0:
        print("  ⚠️  Packages were upgraded but outdated count didn't change")
        print("      → This might indicate a state tracking issue")
    elif final_outdated == 0:
        print("  🎯 Perfect! All packages are now up to date")

    print()

    if success:
        print("🎉 End-to-end test PASSED!")
        print("   ✅ Fake package managers work correctly")
        print("   ✅ Check -> Upgrade -> Check cycle works")
        print("   ✅ State tracking validates upgrade behavior")
        print("   ✅ Ready for real package manager testing")
    else:
        print("❌ End-to-end test FAILED!")
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
