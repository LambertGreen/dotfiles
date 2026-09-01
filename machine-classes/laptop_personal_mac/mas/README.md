# Mac App Store (mas) Configuration

Mac App Store applications are managed through the `mas` CLI tool.

This directory exists so `mas` is detected as a package manager for this
machine class — detection enumerates the directories under the machine class.
Without it the `mas "..."` entries in the Brewfile were declared but never
checked or upgraded by `just update` / `just upgrade`.

## Installation

Apps are installed via the Brewfile:
- See `machine-classes/laptop_personal_mac/brew/Brewfile` for the list of Mac App Store apps
- Apps are defined using `mas "App Name", id: APP_ID` syntax

## Update/Upgrade

For granular update control, `mas` is available as a separate package manager:
- `mas outdated` - Check for outdated apps
- `mas upgrade` - Upgrade all Mac App Store apps

## Current Apps

Currently managed apps (from Brewfile):
- AmorphousDiskMark (id: 1168254295)
- GIPHY CAPTURE (id: 668208984)
- iMovie (id: 408981434)
- Time Out (id: 402592703)
- Windows App (id: 1295203466)
- Xcode (id: 497799835)
