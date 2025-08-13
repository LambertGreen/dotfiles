# Emacs 30+ Package Manager Strategy

## Goal
Install Emacs 30+ on all systems using the best available package manager per platform, avoiding duplicate installations.

## Strategy by Platform

### macOS
- **laptop_personal_mac**: `d12frosted/emacs-plus/emacs-plus@30` (Homebrew tap with native compilation)
- **laptop_work_mac**: `pkryger/emacsmacport-exp/emacs-mac-exp@31` (Homebrew tap, latest version)

### Linux Ubuntu
- **docker_ubuntu_essential**: Homebrew `emacs` (30+) - APT has old version
- **docker_ubuntu_developer**: Homebrew `emacs` (30+) - APT has old version  
- **wsl_work_ubuntu**: Homebrew `emacs` (30+) - Consistent with other Ubuntu

### Linux Arch
- **docker_arch_essential**: Homebrew `emacs` (30+) - Consistent experience
- **docker_arch_developer**: Pacman `emacs` (30+) - Arch repos usually have latest

### Windows
- **windows_arm64_dev**: MSYS2 pacman `mingw-w64-clang-aarch64-emacs` (29.4) - Need to check for 30+
- **windows_x64_dev**: MSYS2 pacman `mingw-w64-clang-aarch64-emacs` (29.4) - Need to check for 30+

## Package Manager Priority

1. **Homebrew**: Best for getting Emacs 30+ on Linux, good macOS taps available
2. **Native package managers**: Arch pacman (usually latest), macOS specialized taps
3. **MSYS2**: For Windows, but version may lag - need source build fallback

## Avoided Conflicts

- **Ubuntu**: Removed `emacs` from APT packages (old version)
- **Windows**: Removed `emacs` from Scoop packages (use MSYS2 instead)
- **Multiple PMs**: Only one package manager installs emacs per machine class

## TODO for Windows

- Check MSYS2 for Emacs 30+ availability
- If not available, add source build recipe or alternative Windows package manager
- Update pacman package names when 30+ becomes available