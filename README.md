# Vault

A minimal, local password manager for macOS with a Spotlight-like quick search.

All your credentials stay on your Mac — no cloud, no accounts, no tracking.

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Spotlight-style search** — Press `Cmd+Shift+P` from anywhere to instantly search and copy your credentials
- **Folders & entries** — Organize passwords, API keys, tokens into folders with custom fields
- **Secret fields** — Sensitive values are hidden by default, click to reveal
- **One-click copy** — Copy individual fields or everything at once
- **Runs in background** — Closes to dock, always ready when you need it
- **Fully offline** — Data stored locally in `~/.local_vault/`
- **Native macOS** — Built with SwiftUI, lightweight and fast

## Installation

### Option 1: Download the app (recommended)

1. Go to [Releases](../../releases) and download the latest `Vault.app.zip`
2. Unzip and drag **Vault.app** into your `/Applications` folder
3. Double-click to open. macOS might show a security warning the first time:
   - Go to **System Settings > Privacy & Security**, scroll down and click **Open Anyway**
4. Grant **Accessibility** permission when prompted:
   - Go to **System Settings > Privacy & Security > Accessibility**
   - Click the **+** button and add **Vault**
   - This is required for the global shortcut `Cmd+Shift+P` to work

### Option 2: Build from source

Requirements: Xcode Command Line Tools (run `xcode-select --install` if you don't have them).

```bash
git clone https://github.com/YOUR_USERNAME/vault.git
cd vault/VaultSwift
swift build -c release
```

Then copy the built app to Applications:

```bash
cp -r Vault.app /Applications/
```

## Setup: Start at Login

To have Vault launch automatically when you log in:

1. Open **System Settings > General > Login Items**
2. Click **+** and select **Vault** from your Applications folder

## Usage

| Action | How |
|---|---|
| Open quick search | `Cmd+Shift+P` (works from any app) |
| Close quick search | `Esc` |
| Navigate results | `Arrow Up` / `Arrow Down` |
| Expand entry | `Enter` |
| Copy a field | Click **Copy** next to it |
| Open main window | Click the Vault icon in the Dock |

### Managing credentials

1. Open the main window from the Dock
2. Use the **+ Nuovo** button to add entries
3. Organize entries into folders using the sidebar
4. Each entry can have unlimited custom fields (email, password, API key, notes, etc.)
5. Mark fields as **Secret** to keep them hidden by default

## Where is my data?

All data is stored locally at:

```
~/.local_vault/vault.json
```

To back up your passwords, simply copy this file. To migrate to another Mac, copy it to the same path on the new machine.

## Uninstall

1. Remove Vault from Login Items (System Settings > General > Login Items)
2. Delete the app from `/Applications`
3. Optionally delete your data: `rm -rf ~/.local_vault`

## Requirements

- macOS 13.0 (Ventura) or later
- Accessibility permission (for global keyboard shortcut)

## License

MIT
