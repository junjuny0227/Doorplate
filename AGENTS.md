# AGENTS.md

<!-- omh:agent-instructions:begin -->
## 기준 문서

- 제품 결정의 기준은 `docs/specs/2026-11-04-doorplate-mvp-design.md`이다. 구현 순서와 인터페이스는 `docs/plans/2026-11-04-0[1-4]-*.md`를 따른다. 각 계획 첫머리의 Global Constraints, 스펙 변경 표, Review Focus를 먼저 읽는다.
- 계획은 1(실험) → 2(Core) → 3(App) → 4(배포) 순서다. 각 계획은 앞 계획이 `main`에 합쳐진 뒤 시작한다.
- 계획 1의 결과 문서 `docs/spikes/01-feasibility.md`가 계획 2–4의 입력이다. 계획에 "실험 결과가 A면 / B면"으로 갈린 곳은 결과 문서에 적힌 쪽만 구현한다.
- 실험의 질문 번호는 스펙 14절 표의 행 순서(1–9)다.
- 구현 중 스펙과 다르게 정한 것은 같은 Task에서 스펙도 고친다. 계획의 "스펙 변경" 표에 적힌 것이 그 목록이다.

## 빌드와 테스트

아직 실행하지 않은 명령은 unverified다. 해당 Task에서 처음 실행해 exit 0을 보면 `verified (exit 0, <날짜>)`로 바꾼다.

| 명령 | 상태 | 생기는 시점 |
|---|---|---|
| `swift test --package-path Packages/DoorplateCore` | verified (exit 0, 2026-11-05) | 계획 2 Task 1 |
| `swift format lint --strict --recursive Packages` (계획 3부터 `App`도) | verified (exit 0, 2026-11-05) | 계획 2 Task 1 |
| `scripts/check-core-imports.sh` | verified (exit 0, 2026-11-05) | 계획 2 Task 1 |
| `swift run --package-path Packages/DoorplateCore doorplate-scan` (`--fixture`) | verified (exit 0, 2026-11-05) | 계획 2 Task 11 (실제 기기를 읽기만 함) |
| `swift test --package-path Packages/DoorplateMenu` | unverified | 계획 3 Task 1 |
| `xcodegen generate && xcodebuild -project Doorplate.xcodeproj -scheme Doorplate -configuration Debug -derivedDataPath build CODE_SIGN_IDENTITY=- build` | unverified | 계획 3 Task 3 |
| `swift test --package-path Packages/ReleaseTools` | unverified | 계획 4 Task 3 (Sparkle을 쓸 때만) |
| `scripts/build-release.sh v<버전>` | unverified | 계획 4 Task 1 |
| `actionlint .github/workflows/*.yml` | unverified | 계획 4 Task 4 |

- 실험 앱(`spikes/ProbeApp`)의 빌드·실행 명령은 계획 1 Task 1의 Interfaces에 있다. `spikes/`는 계획 1 마지막 Task에서 지운다.
- XcodeGen은 `brew install xcodegen`으로 설치한다.
- Docker가 필요한 확인(실험 Task 4, 수동 점검표)은 로컬에서만 한다. CI에서 돌리지 않는다.

## 생성 파일

손으로 고치지 않는다. 원본을 고치고 다시 생성한다.

| 생성 파일 | 원본 | 재생성 | 확인 |
|---|---|---|---|
| `Packages/DoorplateCore/Tests/Fixtures/expected/*.json` | `Tests/Fixtures/scenarios/*.json`과 Core 판단 규칙 | `UPDATE_GOLDEN=1 swift test --package-path Packages/DoorplateCore --filter ScenarioTests` | `swift test`. diff를 읽고 의도한 변경인지 확인한 뒤 커밋한다 |
| `Doorplate.xcodeproj` | `project.yml` | `xcodegen generate` | 빌드. 커밋하지 않는다 |
| `App/Resources/Assets.xcassets/AppIcon.appiconset/` | `assets/AppIcon.svg` | `scripts/make-icon.sh` | 빌드 (계획 4 Task 2) |
| `appcast.xml` (`gh-pages` 브랜치) | 공개한 릴리스의 zip | `.github/workflows/appcast.yml` (`Packages/ReleaseTools`의 `appcast add`) | `AppcastTests`, 릴리스 체크리스트의 `curl` 확인 |
| tap 저장소의 `Casks/doorplate.rb` | `packaging/homebrew/doorplate.rb.template`, 릴리스의 `.sha256` | `scripts/update-cask.sh <버전> <sha256 파일> <tap 폴더>` | `brew style` |
| `docs/spikes/samples/*.json` | 실험 Task 4의 Docker 원본 응답 | 사용자 이름이 든 경로를 `/Users/dev`로 바꿔 복사 | 계획 2 Task 9의 Docker 테스트 |

## 지켜야 할 경계

- `DoorplateCore`는 Foundation, Darwin, Dispatch, os만 import한다. AppKit·SwiftUI 금지는 `scripts/check-core-imports.sh`가 검사한다(SPM은 막지 않는다).
- Core는 외부 명령(`lsof` 등)을 실행하지 않는다. 테스트가 띄울 수 있는 프로세스는 `/bin/sleep`, `/bin/sh`, `/usr/bin/true`뿐이고, 실제 시그널은 테스트가 직접 띄운 프로세스에만 보낸다. 권한 오류 경로는 가짜 `ProcessSignaler`로 시험한다.
- 시스템 조회와 종료는 protocol(`ProcessSource`, `FileProbe`, `DockerSource`, `ProcessSignaler`) 뒤에 두고, 판단은 순수 함수로 둔다.
- 관리자 권한을 쓰지 않는다. 예외는 실험 계획의 비교용 `sudo lsof`이고, 사용자가 직접 실행한다.
- Docker 런타임 프로세스(Docker Desktop, OrbStack, Colima 등)는 종료하지 않는다. 컨테이너는 Docker API로만 정지한다.
- 포트에 접속해 확인하지 않는다. 네트워크는 Docker unix 소켓과 업데이트 확인뿐이고, 사용 통계를 모으지 않는다.
- 외부 패키지는 Sparkle 하나다. 다른 의존성은 계획을 먼저 고친 뒤 추가한다.
- Sparkle EdDSA 비밀 키는 로컬 키체인과 GitHub Secret `SPARKLE_ED_PRIVATE_KEY`에만 둔다. 출력하거나 커밋하지 않는다.
- 실험 측정 결과(`spikes/out/`), `doorplate-scan` 출력, `--fixture` 출력에는 개인 경로와 명령줄이 들어 있다. 커밋하지 않는다.

## 함정

- 실험 계획이 스펙 14절과 다른 질문 수·번호를 쓴 채로 병합되어, 구현 전에 정합성 PR을 따로 내야 했다. 질문이나 절 번호를 문서에 쓸 때는 스펙의 표와 대조한다.
- `gh`의 기본 계정이 이 저장소에 권한이 없는 계정이면 `gh pr create`가 `must be a collaborator`로 실패한다(PR 생성 1회 실패). 기본 계정을 바꾸지 말고 `GH_TOKEN=$(gh auth token --user junjuny0227) gh …`로 그 명령에만 토큰을 넘긴다.

## 규칙

- 브랜치는 계획마다 정해져 있다: `spike/feasibility`, `feat/core`, `feat/app`, `ci/release`. 문서만 고칠 때는 `docs/<주제>`다.
- 커밋 메시지는 영어 Conventional Commits다(`feat(core): …`, `docs: …`). 각 계획 Task의 마지막 단계에 메시지가 적혀 있다.
- 문서(`docs/`)는 한국어, README는 영어(`README.md`)와 한국어(`README.ko.md`)다. 앱 문구는 `DoorplateMenu`의 `L10n`을 거치고, `en.lproj`와 `ko.lproj`에 같은 키를 둔다.
- 원격 push, 태그, 릴리스 공개, tap 저장소 생성, GitHub Pages 설정, Secrets 등록은 실행 전에 사용자에게 확인을 받는다. 릴리스는 draft로 만들고 사용자가 공개한다. 0.x는 prerelease가 아닌 정식 릴리스이고 이름에 `(beta)`를 붙인다.
<!-- omh:agent-instructions:end -->
