> **Unsigned beta.** Not code-signed or notarized yet; see the [README](https://github.com/junjuny0227/Doorplate#first-open) for first launch on macOS.

### Which file do I download?

| Your computer | Download |
|---|---|
| Mac (Apple silicon or Intel), macOS 14 or later | [`Doorplate-{{VERSION}}.zip`](https://github.com/junjuny0227/Doorplate/releases/download/v{{VERSION}}/Doorplate-{{VERSION}}.zip) |

Homebrew: `brew install --cask junjuny0227/tap/doorplate`

Move Doorplate.app to /Applications in Finder before opening it, or it cannot update itself.

`Doorplate-{{VERSION}}.zip.sha256` holds the checksum: `shasum -a 256 -c Doorplate-{{VERSION}}.zip.sha256`.
SHA-256: `{{SHA256}}`
