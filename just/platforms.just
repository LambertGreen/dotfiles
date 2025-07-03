# Platform definitions and mappings

# Supported platforms with descriptions
platforms := '''
arch        - Arch Linux
ubuntu      - Ubuntu Linux
osx         - macOS
win-wsl     - Windows (WSL)
win-msys2   - Windows (MSYS2)
'''

# Docker testable platforms
docker_platforms := "arch ubuntu"

# Platform to package manager mapping
pm_arch := "pacman"
pm_ubuntu := "apt"
pm_osx := "brew"
pm_win_wsl := "apt"
pm_win_msys2 := "pacman"