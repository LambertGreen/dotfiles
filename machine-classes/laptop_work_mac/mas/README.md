# Mac App Store (mas) Configuration

Mac App Store applications are managed through the `mas` CLI tool.

## Installation

Apps are installed via the Brewfile:
- See `machine-classes/laptop_work_mac/brew/Brewfile` for the list of Mac App Store apps
- Apps are defined using `mas "App Name", id: APP_ID` syntax

## Update/Upgrade

For granular update control, `mas` is available as a separate package manager:
- `mas outdated` - Check for outdated apps
- `mas upgrade` - Upgrade all Mac App Store apps

## Current Apps

Currently managed apps (from Brewfile):
- Windows App (id: 1295203466)
