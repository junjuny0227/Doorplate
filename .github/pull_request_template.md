## Summary

<!-- What changes and why. Link the issue, plan task (docs/plans/...) or spec section (docs/specs/...). -->

## Type

- [ ] feat
- [ ] fix
- [ ] refactor / chore / test
- [ ] docs
- [ ] ci / build / release

## Changes

-

## Checks

<!-- Tick what you ran. CI runs an older Swift than a current Xcode: wait for the PR checks before merging. -->

- [ ] `swift format lint --strict --recursive Packages App`
- [ ] `scripts/check-core-imports.sh`
- [ ] `swift test --package-path Packages/DoorplateCore`
- [ ] `swift test --package-path Packages/DoorplateMenu`
- [ ] `swift test --package-path Packages/ReleaseTools` (release tooling changed)
- [ ] Debug app build (`xcodegen generate && xcodebuild ... build`, see AGENTS.md)
- [ ] Ran the real app or `doorplate-scan` if behavior changed
- [ ] Not checked locally, CI only (say which):

## Spec, strings and generated files

- [ ] Spec updated in this PR if a product decision changed, or no decision changed
- [ ] New or changed UI text goes through `L10n` with the same key in `en`, `ko`, `ja` and `zh-Hans`
- [ ] Generated files regenerated from their source, not edited by hand (golden `expected/*.json`, `AppIcon.appiconset/`)
- [ ] Golden diffs read and intended

## Boundaries

- [ ] `DoorplateCore` imports only Foundation, Darwin, Dispatch and os, and runs no external commands
- [ ] System lookups and stopping go through `ProcessSource`, `FileProbe`, `DockerSource`, `ProcessSignaler`; tests use fakes
- [ ] No administrator rights, no connections to listening ports, no telemetry
- [ ] Docker runtimes are never stopped; containers stop only through the Docker API
- [ ] No new dependency besides Sparkle, or the plan/spec was updated first
- [ ] No personal paths, scan output or keys in the diff

## Screenshots

<!-- Menu or settings changes: before and after, light and dark. Delete this section otherwise. -->
