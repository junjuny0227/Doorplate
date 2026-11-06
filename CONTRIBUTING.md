# Contributing to Doorplate

Thanks for helping. Doorplate is a small macOS menu bar app, so the rules below are mostly about keeping it small, local and predictable.

## Before you start

- **Bugs and small fixes:** open a pull request directly. An issue first is welcome but not required.
- **New features or behavior changes:** open an issue first. Product decisions live in the [design spec](docs/specs/2026-11-04-doorplate-mvp-design.md) (Korean), and a change that contradicts it needs agreement before code.
- Issues and pull requests can be written in English or Korean.

## Development setup

Requirements: macOS 14 or later, Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`). The product site also needs Node.js and the pnpm version pinned in `package.json`.

```sh
xcodegen generate
xcodebuild -project Doorplate.xcodeproj -scheme Doorplate -configuration Debug \
  -derivedDataPath build CODE_SIGN_IDENTITY=- build
open build/Build/Products/Debug/Doorplate.app
```

`Doorplate.xcodeproj` is generated from `project.yml`; do not commit it.

To see what the scanner finds on your Mac without the app (read-only):

```sh
swift run --package-path Packages/DoorplateCore doorplate-scan
```

Its output contains your paths and command lines. Do not paste it into issues or commit it.

## Layout

- `Packages/DoorplateCore`: scanning, classification and stopping. Foundation, Darwin, Dispatch and os only.
- `Packages/DoorplateMenu`: the `NSMenu`, settings and localized strings.
- `App`: the app target (AppKit, SwiftUI settings, Sparkle).
- `site`: the product page (React, Vite).
- `docs`: spec, plans and checklists, in Korean.

## Rules the code keeps

- `DoorplateCore` never imports AppKit or SwiftUI (`scripts/check-core-imports.sh`) and never runs external commands such as `lsof`.
- System access (processes, files, Docker, signals) stays behind protocols; decisions are pure functions tested with fakes and fixtures. Tests may only start `/bin/sleep`, `/bin/sh` and `/usr/bin/true`, and only signal processes they started.
- No administrator rights, no connections to listening ports, no telemetry. The only network use is the Docker unix socket and the update check.
- Docker runtimes (Docker Desktop, OrbStack, Colima, …) and macOS services are never stopped; containers stop only through the Docker API.
- Sparkle is the only app dependency. Propose any other dependency in an issue first.
- Every user-facing string goes through `L10n`, with the same key in `en`, `ko`, `ja` and `zh-Hans`.
- Generated files are regenerated from their source, never edited by hand. For example, scenario goldens: `UPDATE_GOLDEN=1 swift test --package-path Packages/DoorplateCore --filter ScenarioTests`, then read the diff.

## Checks

Run what your change touches:

```sh
swift format lint --strict --recursive Packages App
scripts/check-core-imports.sh
swift test --package-path Packages/DoorplateCore
swift test --package-path Packages/DoorplateMenu
swift test --package-path Packages/ReleaseTools
# product site
pnpm install --frozen-lockfile
pnpm exec biome ci .
pnpm --filter @doorplate/site test
pnpm --filter @doorplate/site build
```

CI runs on an older Swift than a current local Xcode, so a change can pass locally and still fail CI. Fix the failure rather than relying on a rerun.

## Pull requests

- Branch from `main` with a prefix that matches the change: `feat/`, `fix/`, `docs/`, `ci/`, `refactor/`, `test/` or `chore/`. The prefix sets the PR label and the release-notes section.
- Commit messages are English [Conventional Commits](https://www.conventionalcommits.org/): `feat(core): …`, `fix(menu): …`, `docs: …`. Small commits are easier to review than one large one.
- Fill in the [pull request template](.github/pull_request_template.md) and tick only the checks you actually ran.
- If the change alters a product decision, update the spec in the same pull request.
- A pull request merges once every check passes and review comments are resolved.

## License

By contributing, you agree that your contribution is licensed under the [Apache License 2.0](LICENSE), the same license as the project.
