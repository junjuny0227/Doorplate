## Install

Requires macOS 14 or later. Universal build (Apple Silicon and Intel).

With Homebrew:

```sh
brew install --cask junjuny0227/tap/doorplate
```

Or download `Doorplate-<version>.zip` from the assets below, extract it, and **move Doorplate.app to `/Applications` in Finder before opening it for the first time.** Opened from the download location, the app may be unable to install updates.

## First launch

Doorplate is ad hoc signed, not signed with a Developer ID or notarized. If macOS blocks it, click **Done**, not Move to Trash. Then open System Settings > Privacy & Security, click **Open Anyway**, authenticate with your password or Touch ID, and confirm **Open Anyway** again.

Terminal alternative:

```sh
xattr -dr com.apple.quarantine /Applications/Doorplate.app
```

This recursively removes the app's download quarantine flag; use it only after verifying the source and checksum.

To read project names, Doorplate may ask for access to your Documents, Desktop or Downloads folders. It may ask again after an update. If you deny access, rows show the folder name instead.

## SHA-256

```text
{{SHA256}}
```

Download both assets into the same directory and verify:

```sh
shasum -a 256 -c Doorplate-*.zip.sha256
```
