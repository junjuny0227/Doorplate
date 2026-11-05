[English](README.md) · [한국어](README.ko.md)

# Doorplate

**A nameplate on every port's door.**

Doorplate is a macOS menu bar app that shows which project each listening port belongs to. Instead of running `lsof -i :3000`, finding a pid and guessing which server it is, open the menu and see `5173  @repot/desktop  vite`. It names JVM and monorepo servers correctly, too.

Doorplate is in beta (0.x).

## Menu

```
Running · 5
● 3000  @repot/site                    vite ▸
● 5173  @repot/desktop                 vite ▸
● 8080  shop-api · 3d                gradle ▸
──────────
◌ 5000  AirPlay Receiver (macOS)            ▸
──────────
Docker
● 5432  postgres                    shop-db ▸
● 6379  redis                    shop-redis ▸
──────────
3 hidden                                    ▸
──────────
Settings…                                ⌘,
Quit Doorplate                           ⌘Q
```

- The number in the header matches the number in the menu bar: app servers and Docker containers.
- `· 3d` (shown in orange) marks a server that has been running for a long time.
- Hover a row for its submenu: Open in Browser, Show in Finder, Open in Terminal, Copy Address, and Stop (PID …). Hold ⌥ to turn a row into a one-click Stop item.
- Docker rows show the Compose service name, with the container name on the right.

## What it recognizes

Doorplate names each server by the nearest project marker above its working directory (`package.json`, `Cargo.toml`, `pyproject.toml`, `settings.gradle(.kts)`, `pom.xml`, `go.mod`, or a `.git` folder) and labels the tool:

- **Node**: vite, next, nuxt, astro, remix, webpack
- **JVM**: `gradle bootRun`, `mvn spring-boot:run`, `java -jar`; Gradle and Kotlin daemons are hidden. Debugger ports (JDWP) are grouped under their server.
- **Rust**: `cargo run` and binaries under `target/debug` or `target/release`
- **Python**: Django (`manage.py runserver`), uvicorn, Flask, gunicorn
- **Ruby**: Rails, puma
- **Docker Compose**: published ports of running containers, by service name. Works with Docker Desktop, OrbStack and Colima.

Worker processes that share a listening socket (gunicorn, puma cluster, Node cluster) appear as one row. Node inspector and LiveReload ports are grouped under their server. IDEs, macOS services and other apps are hidden.

## Install

Requires macOS 14 or later. Doorplate is in beta.

With Homebrew:

```sh
brew install --cask junjuny0227/tap/doorplate
```

Or download `Doorplate-<version>.zip` from [Releases](https://github.com/junjuny0227/Doorplate/releases) and unzip it. The `.sha256` file next to it holds the checksum.

## First open

Doorplate is signed ad hoc and not notarized by Apple, so macOS blocks the first launch. On macOS 15 and later, right-click → Open no longer gets past this.

1. Before opening it, move `Doorplate.app` to your Applications folder (`/Applications`) in Finder. If you open the app where it was downloaded, macOS runs it from a temporary location (App Translocation) and Doorplate cannot update itself.
2. Open the app. macOS shows "“Doorplate.app” Not Opened" ("Apple could not verify “Doorplate.app” is free of malware that may harm your Mac or compromise your privacy."). Click **Done**. Do not click **Move to Trash**: it moves the app to the Trash.
3. Open System Settings > Privacy & Security, click **Open Anyway** next to the message about Doorplate, confirm with your password or Touch ID, then click **Open Anyway** in the dialog that appears.

If you are comfortable with Terminal, you can run this instead of steps 2–3:

```sh
xattr -dr com.apple.quarantine /Applications/Doorplate.app
```

This removes the download quarantine flag that macOS adds to files from the internet, so Gatekeeper no longer stops the app.

## Privacy

- Nothing leaves your Mac. Doorplate's only network request is the update check against its appcast on GitHub Pages (`https://junjuny0227.github.io/Doorplate/appcast.xml`). You can turn off automatic checks in Settings.
- No telemetry or usage statistics.
- Doorplate reads process and socket information locally, and talks to Docker only through its local unix socket. It never connects to your ports.
- To show a project's name, Doorplate reads files such as `package.json`. If your projects live in `~/Documents`, `~/Desktop`, `~/Downloads` or iCloud Drive, macOS asks whether Doorplate may access that folder ("Doorplate reads project files such as package.json to show which project owns each port."). If you deny it, those servers are named after their folder instead.
- Because Doorplate is signed ad hoc, macOS asks again once per protected folder after each update.

## Build from source

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project Doorplate.xcodeproj -scheme Doorplate -configuration Debug -derivedDataPath build CODE_SIGN_IDENTITY=- build
```

The app is at `build/Build/Products/Debug/Doorplate.app`.

## License

[Apache-2.0](LICENSE)
