# 계획 7: 프로젝트별 묶음 보기

## 목표

같은 프로젝트에서 서버를 두 개 이상 띄웠을 때 메뉴에서 한 묶음으로 보여 주고, 묶음 단위로 한 번에 종료할 수 있게 한다. 모노레포(web, api, worker)나 Compose 프로젝트(db, redis)를 띄우고 끄는 일이 행마다 반복되지 않게 한다.

```
실행 중 · 6
acme · main                          서버 3개 ▸   ← 묶음 머리 행
    ● 3000  @acme/site                 vite ▸
    ● 5173  @acme/web                  vite ▸
    ● 8000  acme-api                uvicorn ▸
● 8080  shop-api · feat/pay          gradle ▸   ← 서버가 하나뿐인 프로젝트는 지금처럼
──────────
Docker
acme                                 서버 2개 ▸
    ● 5432  postgres               acme-db ▸
    ● 6379  redis               acme-redis ▸
```

## Global Constraints

- 브랜치는 `feat/project-groups`, 버전은 0.5.0이다(새 기능).
- 묶기는 메뉴 표시다. Core의 판단(구역, 종료 가능 여부, 정렬)과 Snapshot은 바꾸지 않는다. 묶는 규칙은 `DoorplateMenu`의 순수 함수로 두고 테스트한다.
- 종료는 지금의 한 행 종료(`StopCoordinator.stop`)를 행마다 그대로 쓴다. 종료 방식(SIGTERM, 일반 앱의 종료 요청, Docker API)과 종료할 수 없는 행(런타임, macOS 서비스)의 규칙은 그대로다.
- 외부 의존성을 추가하지 않는다. 새 문구는 `L10n`을 거쳐 네 언어에 같은 키를 둔다.

## 스펙 변경

| 위치 | 변경 |
|---|---|
| 4 | MVP 범위에 프로젝트별 묶음을 더한다 |
| 8 | 메뉴 예시와 묶음 규칙(8.3절 새로) |
| 8.1 | 묶음 머리 행의 ⌥ 대체 항목 |
| 9 | 전부 종료의 확인 창 |
| 15 | "프로젝트별 묶음 보기"를 뺀다 |

## 결정과 이유

| 결정 | 이유 |
|---|---|
| 앱 구역과 Docker 구역을 따로 묶는다 | 사용자 결정(2026-11-27). DB 컨테이너는 남기고 앱 서버만 끄는 일이 흔하다 |
| 전부 종료는 확인 창을 한 번 띄운다 | 사용자 결정(2026-11-27). 한 번의 클릭으로 여러 서버가 꺼지므로 잘못 눌러도 안전해야 한다. 한 행 종료는 지금처럼 확인 없이 한다 |
| 확인 창의 Return은 취소 | 강제 종료 창과 같은 원칙. Return으로 여러 서버가 꺼지지 않게 한다 |
| 서버가 두 개 이상일 때만 묶는다 | 하나짜리 묶음은 행만 늘린다 |
| 앱 묶음 기준은 저장소 루트, 없으면 프로젝트 폴더 | 모노레포의 패키지들이 한 저장소에 모인다. 워크트리는 루트가 달라 브랜치별로 따로 묶인다 |
| Docker 묶음 기준은 Compose 작업 폴더 | `ServerEntry.directory`에 이미 있다. Compose가 아닌 컨테이너는 묶지 않는다 |
| 묶음 이름은 기준 폴더의 이름 | 저장소 폴더 이름이 사람들이 부르는 프로젝트 이름에 가깝다. Compose 프로젝트 이름도 기본값이 작업 폴더 이름이다 |
| 브랜치는 머리 행에만 | 같은 루트이므로 묶음 안의 브랜치는 모두 같다 |
| 묶음은 첫 행(가장 낮은 포트) 자리에 놓고, 안의 행은 포트 순 | 7.6절의 포트 순 정렬을 유지해 열 때마다 순서가 바뀌지 않는다 |
| 설정 토글을 두지 않는다 | 두 개 이상일 때만 묶이므로 끌 이유가 적다. 설정 창을 늘리지 않는다 |
| 전부 종료는 동시에 시작한다 | 10초 대기가 행마다 이어지지 않게 한다. "아직 실행 중" 창은 행마다 따로 뜬다 |

## 묶는 규칙

- 대상은 앱 구역(`snapshot.apps`)과 Docker 구역(`snapshot.docker`)이다. 시스템 구역과 숨김 목록은 묶지 않는다.
- 기준 키: 앱은 `repositoryRoot ?? directory`, Docker는 `directory`. 키가 없으면 묶지 않는다.
- 같은 키의 행이 둘 이상이면 묶음 하나로, 아니면 지금의 한 행으로 둔다.
- 머리 행: `<폴더 이름>`, 앱 묶음이고 브랜치가 있으면 회색 `· <브랜치>`, 오른쪽 열에 `서버 N개`. 점 없음.
- 안의 행: 지금의 행과 같고 `indentationLevel = 1`, 브랜치는 뺀다.
- 머리 행의 하위 메뉴: Finder에서 보기(Docker는 Compose 폴더 보기), 터미널에서 열기(앱만), 구분선, 빨간 `전부 종료(N개)`. N은 종료할 수 있고 종료 중이 아닌 행의 수다. 종료할 수 있는 행이 없으면 종료 항목을 두지 않는다.
- ⌥를 누르면 머리 행이 `종료 · acme 서버 3개`로 바뀐다(한 행과 같이 "종료" 단어만 빨강). 확인 창은 같다.

## 파일

- `Packages/DoorplateMenu/Sources/DoorplateMenu/MenuGroups.swift`(새 파일): 묶는 순수 함수
- `MenuBuilder.swift`(머리 행, 들여쓰기, 하위 메뉴, ⌥ 항목), `MenuCommand.swift`(`.stopAll`), `StopCoordinator.swift`(`stopAll`, 확인), `L10n.swift`와 네 언어 `Localizable.strings`
- `App/ActionPerformer.swift`, `App/AlertStopPrompter.swift`(확인 창)
- 테스트: `MenuGroupsTests`, `MenuBuilderTests`, `StopCoordinatorTests`, `L10nTests`, `Support/FakeSystem.swift`
- README 네 개, 사이트 문구, 수동 점검표

## 작업

1. 이 계획과 스펙을 먼저 커밋한다(문서 PR).
2. `MenuGroups`와 테스트: 하나짜리, 둘 이상, 키 없음, 워크트리 분리, Docker Compose와 비 Compose, 순서.
3. `StopCoordinator.stopAll`: 확인 거절 시 아무것도 안 함, 승인 시 모든 행을 동시에 `stop`, 종료 중인 행은 건너뜀. `StopPrompter.confirmStopAll`과 가짜.
4. 메뉴: 머리 행·들여쓰기·하위 메뉴·⌥ 항목, 네 언어 문구.
5. App: 확인 창(`NSAlert`, Return은 취소), `ActionPerformer`가 `.stopAll`을 전달.
6. README·사이트·수동 점검표.
7. 로컬 검사, Debug 빌드로 실제 메뉴와 전부 종료 확인(직접 띄운 서버만), PR 검사 통과 후 병합, 0.5.0 릴리스.

## 확인

- `swift test --package-path Packages/DoorplateCore`, `swift test --package-path Packages/DoorplateMenu`
- `swift format lint --strict --recursive Packages App`, `scripts/check-core-imports.sh`
- Debug 빌드: `~/.hermes/cache/scratch`의 저장소 하나에서 서버 세 개를 띄워 묶음으로 보이는지, 전부 종료의 확인 창에서 취소하면 그대로인지, 종료를 누르면 세 개가 모두 꺼지는지 본다. Docker 묶음은 Compose 두 서비스로 확인한다(런타임은 사용자가 켠다)
- 사이트를 고치면 `pnpm exec biome ci .`, `pnpm --filter @doorplate/site test`, `build`

## Review Focus

- 묶음 때문에 Core의 정렬·구역·`canTerminate`가 바뀌면 막는다.
- 전부 종료가 확인 없이 실행되거나, 종료할 수 없는 행(런타임, macOS 서비스)을 종료하면 막는다.
- 서버가 하나뿐인 프로젝트, 시스템 구역, 숨김 목록의 모양이 바뀌면 안 된다.
