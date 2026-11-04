# Doorplate MVP 설계

- 날짜: 2026-11-04
- 상태: 초안, 검토 대기
- 한 줄 소개: **A nameplate on every port's door.** 포트마다 어느 프로젝트의 서버인지 이름표를 붙여 주는 macOS 메뉴바 앱.

## 1. 배경과 목표

개발자는 거의 매일 `port 3000 is already in use`를 본다. 지금은 `lsof -i :3000`으로 pid를 찾고 `kill`을 친다. 그 pid가 어느 프로젝트의 서버인지는 다시 따로 알아봐야 한다.

Doorplate는 메뉴바에 늘 떠 있으면서 다음을 한 번에 보여 준다.

- 지금 어떤 포트가 열려 있는지
- 각 포트가 **어느 프로젝트의 어떤 도구**인지 (`5173 @repot/desktop vite`)
- 그 서버를 열거나 끄는 동작

이전 제품 Repot은 유용했지만 새 기기를 살 때나 포맷할 때만 쓰여서 사용 빈도가 낮았다. Doorplate는 **매일 생기는 계기**(포트 충돌, 어느 서버가 떠 있는지 확인)에 붙고, 메뉴바 숫자로 **늘 보이는 상태**를 준다.

## 2. 대상과 성공 기준

**대상**: macOS에서 로컬 개발 서버를 띄우는 웹·백엔드 개발자. Node(vite, next 등), JVM(Gradle, Maven, IntelliJ), Rust(cargo), Python(Django, FastAPI, Flask), Ruby(Rails), Docker Compose.

**성공 기준**

| 항목 | 기준 | 확인 방법 |
|---|---|---|
| 메뉴 표시 | 클릭 후 체감 지연 없음(100ms 이하) | 수동 점검 |
| 조회 시간 | 프로세스 1,000개 기준 전체 조회 50ms 이하 | `doorplate-scan` 출력의 시간 |
| 유휴 부담 | CPU 거의 0%, 메모리 30MB 이하 | 활성 상태 보기 |
| 판별 정확도 | 12절 수동 점검표의 모든 시나리오에서 프로젝트 이름과 도구가 맞음 | 수동 점검 + 시나리오 테스트 |
| 안전 | 사용자가 고르지 않은 프로세스를 종료하는 경우 0건 | 종료 흐름 테스트(9절) |

사용 통계는 수집하지 않는다(5절 원칙). 실제 사용 빈도는 GitHub 별·이슈, 사용자 의견 같은 정성 신호로만 판단한다.

## 3. 차별점과 경쟁

### 3.1 조사 요약

2026-11-04에 README, 릴리스, 제품 페이지, 공개 소스를 읽고 정리했다. 앱을 설치하거나 실행하지는 않았다.

| 앱 | UI | 프로젝트 식별 | JVM | Docker | 종료 | 배포 | 활동 |
|---|---|---|---|---|---|---|---|
| [Port Menu](https://github.com/wieandteduard/port-menu) | 패널 | git 루트 이름과 브랜치 | `java` 이름뿐 | "Docker"로만 | SIGTERM, 확인 없음 | 공증 DMG | ★384, 2026-04 |
| [Berth](https://github.com/08820048/berth) | 패널 | cwd에서 `.git`, `package.json` 등 | Spring 명령줄 패턴 | 컨테이너 이름, `docker stop` | 확인 창, pid 재확인, SIGKILL은 선택 | 공증 DMG, Sparkle | ★2, 2026-08 |
| [Portpourri](https://github.com/jskoiz/portpourri) | 팝오버 | `package.json`, `.git`(Node 전용) | 확인 안 됨 | "Docker가 막고 있음" 판정 | 확인 창, SIGTERM만 | 공증 zip | ★7, 2026-05 |
| [Seeports](https://www.gingerbeardman.com/apps/seeports/) | 메뉴 | 없음 | 확인 안 됨 | Docker 분류 | SIGTERM·SIGKILL | App Store, $4.99 | 2026-04 |
| [portbar (laurenschristian)](https://github.com/laurenschristian/portbar) | **NSMenu** | git 체크아웃·워크트리 | "Java" 라벨뿐 | **Compose 프로젝트** | SIGTERM → 3초 뒤 SIGKILL, 부모도 종료 | DMG·tap, **미공증** | ★0, 2026-10 |
| [portbar (markoradak)](https://github.com/markoradak/portbar) | 패널 | cwd 표식, 브랜치, 실행 스크립트 | 확인 안 됨 | 확인 안 됨 | pid·포트 재확인, 강제 종료 제안 | 공증 zip | ★0, 2026-07 |
| [PortWatch](https://github.com/hackspaces/PortWatch) | 팝오버 | 없음 | 아이콘뿐 | 아이콘뿐 | 없음 | 소스 빌드만 | ★0, 2026-01 이후 멈춤 |

가장 가까운 경쟁 앱은 laurenschristian/portbar(NSMenu, Compose, 미공증)이다. 가장 많이 쓰이는 앱은 Port Menu다.

### 3.2 Doorplate가 내세울 점

조사한 앱 중 아무도 하지 않는 것이다.

1. **JVM을 제대로 다룬다.** Gradle·Kotlin 데몬 숨김, `gradle bootRun`과 `mvn spring-boot:run` 구분, `settings.gradle`과 `pom.xml` 기준의 프로젝트 이름.
2. **프로세스당 한 행과 보조 포트 역할.** 디버거(5005), LiveReload(35729), Node inspector를 대표 포트 아래 하위 메뉴로 묶는다.
3. **Compose 서비스 이름까지 보여 준다.** 서비스 이름(`postgres`)을 제목으로, 컨테이너 이름(`shop-db`)을 옆에 표시한다.

pid 재확인과 단계적 종료(SIGTERM → 확인 후 SIGKILL)는 Berth와 markoradak/portbar도 한다. 차별점이 아니라 갖춰야 할 기본 수준으로 본다.

소개 문구는 "JVM과 모노레포에서도 정확한 이름표"를 앞세운다.

### 3.3 경쟁 앱에는 있지만 MVP에서 하지 않는 것

| 기능 | 하는 앱 | 판단 |
|---|---|---|
| git 브랜치 표시 | Port Menu, markoradak/portbar | MVP에서 뺀다. 15절에서 검토 |
| CLI, MCP 서버 | Portpourri, laurenschristian/portbar | 뺀다. `doorplate-scan`은 진단용이다 |
| 유휴 서버 자동 종료 | laurenschristian/portbar | 하지 않는다(5절: 사용자가 고를 때만 종료) |
| 포트 고정, 변화 알림 | Berth, markoradak/portbar | 뺀다. 15절 |
| 공증 | Port Menu, Berth, Portpourri, markoradak/portbar | 하지 않는다(13절). 첫 실행에서 불리하다는 점을 알고 감수한다 |

## 4. 범위

### MVP에 넣는다

1. 메뉴바 아이콘과 **보이는 서버 수**. 오래 켜진 서버가 있으면 아이콘에 작은 주황 점.
2. TCP LISTEN 포트를 **프로세스당 한 행**으로 보여 주는 네이티브 메뉴(`NSMenu`).
3. 프로젝트 이름 추론(7.5절)과 도구 판별(7.5절 규칙 표). Node, JVM, Rust, Python, Ruby를 지원한다.
4. 보조 포트 역할 표시(디버거, LiveReload, Node inspector).
5. Docker 컨테이너를 Compose 프로젝트·서비스 이름으로 표시하고 API로 정지.
6. 개발 도구 포트(Gradle 데몬, Kotlin 데몬, IDE)와 다른 앱 포트는 기본 숨김. 설정에서 보이게 할 수 있다.
7. macOS AirPlay 수신(5000, 7000)을 "시스템"으로 표시하고 끄는 방법을 안내.
8. 동작: 브라우저에서 열기, Finder에서 보기, 터미널에서 열기, 주소 복사, 종료.
9. 오래 켜진 서버 표시(기본 24시간).
10. 설정 창: 로그인 시 실행, 오래 켜짐 기준, 숨김 항목 표시, 터미널 앱, 업데이트 확인.
11. 앱 업데이트(13절).
12. 언어: 영어 원본과 한국어. 시스템 언어를 따른다.

### MVP에서 뺀다

- 알림 센터 알림
- 프로젝트별 묶음 보기
- UDP, 원격 연결, LISTEN이 아닌 연결
- 메뉴를 여는 전역 단축키
- 일본어·중국어
- Windows, Linux
- Developer ID 서명과 공증(13절)

## 5. 원칙

- **로컬 전용**: 네트워크는 업데이트 확인뿐이다. 포트·프로세스·경로 정보를 밖으로 보내지 않는다. 사용 통계를 수집하지 않는다.
- **사용자가 고를 때만 종료한다.** 자동 종료나 일괄 정리는 없다.
- **Docker 런타임 프로세스(Docker Desktop, OrbStack, Colima 등)를 직접 종료하지 않는다.** 모든 컨테이너가 내려가기 때문이다. 컨테이너는 Docker API로만 정지한다. 런타임 프로세스와 "다른 앱"은 설정으로 보이게 해도 종료 항목을 두지 않는다.
- **관리자 권한을 쓰지 않는다.** 권한이 필요한 helper나 `sudo`가 없다.
- **포트에 접속해 확인하지 않는다.** HTTP 여부는 포트 번호, 이미지 이름, 도구로만 추정한다. 남의 서버에 요청을 보내는 부작용을 피한다.
- **판단 로직은 테스트 가능한 순수 함수로 둔다.** 시스템 조회와 종료는 protocol 뒤에 모은다.

## 6. 구조

Core 패키지와 App 두 덩어리로 나눈다.

- **`DoorplateCore`**(Swift Package, AppKit 없음): 시스템 조회와 판단.
- **App**(AppKit + SwiftUI): 메뉴, 동작, 설정 창.

나누는 이유는 이 앱 자체에 있다.

1. 복잡도 대부분이 판단 규칙(도구 판별, 프로젝트 이름, 보조 포트, Docker 연결)에 있다. 이 규칙은 fixture 사례를 많이 쌓아 검증해야 한다.
2. `swift test`로 Xcode 없이 터미널에서 바로 검증할 수 있다. AI와 고치고 확인하는 반복이 빨라진다.
3. 경계가 분명해진다. SPM은 macOS에서 AppKit import를 막지 않으므로, Core가 AppKit·SwiftUI를 import하지 않는다는 규칙은 CI 검사(`scripts/check-core-imports.sh`)로 지킨다.
4. 버그 제보 환경을 fixture로 재현할 수 있어, 내 기기에 Gradle이나 Docker가 없어도 된다.

```
[App]  StatusItemController ── 5초 타이머 → 아이콘 숫자·주황 점
          │ menuNeedsUpdate (메뉴를 여는 순간)
          ▼
       MenuBuilder: Snapshot → NSMenu      ActionPerformer: 열기/Finder/터미널/복사/종료
          ▲                                    │
──────────┼────────────────────────────────────┼──────────
[Core]  SnapshotBuilder ◀── Classifier ◀── 원시 정보        Terminator ── ProcessSignaler (protocol)
                               │                             ├ 프로세스: SIGTERM / SIGKILL
        ProcessSource (protocol)  FileProbe (protocol)  DockerSource (protocol)
         └ libproc 구현            └ 파일 시스템         └ Docker 소켓 HTTP(POSIX)
         └ Fake (테스트)           └ Fake (테스트)       └ Fake (테스트)
```

### 6.1 Core 단위

| 단위 | 하는 일 | 의존 |
|---|---|---|
| `ProcessSource` | LISTEN 소켓(pid, 포트, 바인드 주소, 소켓 식별자)과 프로세스 정보(이름, 실행 파일 경로, argv, cwd, 부모 pid, 시작 시각, 소유 uid) | libproc, `sysctl(KERN_PROCARGS2)` |
| `FileProbe` | 파일 있음·없음·접근 거부(TCC) 확인과 읽기 | 파일 시스템 |
| `DockerSource` | 컨테이너 목록, 게시 포트, Compose 라벨, 시작 시각, 정지 | Docker 소켓(7.4절) |
| `ToolDetector` | argv·부모 프로세스로 도구와 분류 결정 | 순수 함수 |
| `ProjectResolver` | 프로젝트 이름과 루트 경로 | `FileProbe` |
| `PortRoleDetector` | 대표 포트와 보조 포트 역할 | 순수 함수 |
| `Classifier` | 위 결과를 합쳐 `ServerEntry` 생성 | 위 단위들 |
| `SnapshotBuilder` | 구역 나누기, 정렬, 숨김, 오래 켜짐 표시 | 순수 함수(현재 시각과 설정을 입력으로 받음) |
| `Terminator` | 프로세스 종료와 컨테이너 정지 | `ProcessSignaler`(protocol, 시그널과 시작 시각), `DockerSource`. 부작용은 여기에만 둔다 |

명령 실행·파일·환경 변수를 한 protocol에 모으지 않는다. 조회 대상의 성격이 서로 달라서 작은 protocol 여러 개로 둔다. 외부 명령(`lsof` 등)은 실행하지 않는다.

### 6.2 App 단위

- `StatusItemController`: `NSStatusItem`, 5초 타이머, 메뉴 열 때 갱신.
- `MenuBuilder`: `Snapshot`을 받아 `NSMenu`를 만든다.
- `ActionPerformer`: `NSWorkspace`로 열기·Finder·터미널을 처리하고, 복사와 `Terminator` 호출을 맡는다.
- `SettingsView`: SwiftUI 설정 창. 로그인 시 실행은 `SMAppService`.
- `Updater`: 13.3절.

### 6.3 저장소 모양

```
project.yml                  XcodeGen 설정 (생성된 .xcodeproj는 커밋하지 않음)
Packages/DoorplateCore/
  Sources/DoorplateCore/
  Sources/doorplate-scan/    진단 명령
  Tests/DoorplateCoreTests/
  Tests/Fixtures/            scenarios/, docker/, expected/
App/                         AppDelegate, StatusItemController, MenuBuilder, ActionPerformer, Settings/
App/Resources/               Localizable.xcstrings (en, ko), Info.plist (LSUIElement)
AppTests/                    MenuBuilder 테스트
docs/specs, docs/plans
.github/workflows/
```

### 6.4 기술 선택

- Swift 6, 엄격 동시성. 조회는 백그라운드 actor에서 하고 `Snapshot`은 `Sendable` 값 타입으로 메인 스레드에 넘긴다.
- 대상 macOS 14 이상. Universal(Apple Silicon, Intel) 빌드.
- XcodeGen: `.pbxproj`를 사람과 AI가 직접 고치지 않게 하고 병합 충돌을 피한다.
- 외부 의존성은 Sparkle 하나. Docker 소켓 통신은 POSIX unix 소켓으로 직접 구현한다. Network 프레임워크는 연결 거부를 실패가 아닌 대기 상태로 다뤄서, "Docker 꺼짐"과 "응답 없음"을 구분하기 어렵다.
- 테스트는 Swift Testing(`import Testing`). 포맷 검사는 Swift 툴체인에 포함된 `swift format`.

## 7. 데이터 흐름

5초마다, 그리고 메뉴를 열 때 아래 6단계로 `Snapshot` 하나를 만든다. 동시에 하나의 조회만 실행하고, 이전 조회가 진행 중이면 그 주기를 건너뛴다.

```
1 수집 → 2 프로세스별 묶기 → 3 정보 보강 → 4 Docker 연결 → 5 분류 → 6 Snapshot
```

### 7.1 수집

- TCP LISTEN 소켓만 모은다: `(pid, 포트, 바인드 주소, 소켓 식별자)`. 소켓 식별자는 libproc `socket_fdinfo.psi.soi_so`이다.
- 같은 pid·포트의 IPv4·IPv6 중복은 하나로 합친다. `::`에 바인드한 소켓은 IPv4·IPv6 표시가 둘 다 켜져 있으므로 IPv6를 먼저 본다.
- 바인드 주소로 노출 범위를 기록한다. `127.0.0.1`·`::1`은 이 기기만, `0.0.0.0`·`::`은 네트워크에 열림.
- 관리자 권한 없이는 다른 사용자(root) 소유 프로세스의 소켓이 보이지 않는다. 14절 실험에서 `sudo lsof`에만 보인 LISTEN 소켓은 launchd(pid 1)의 8021 하나였다. 개발 서버는 사용자 계정으로 실행되므로 받아들인다.

### 7.2 프로세스별 묶기

먼저 소켓 단위로 주인을 정한다. gunicorn, puma cluster, `uvicorn --reload`, Node cluster처럼 자식이 LISTEN 소켓을 물려받으면 같은 소켓 식별자가 여러 pid에 보인다. 이때는 그 소켓을 가진 프로세스 중 부모가 그 목록에 없는 가장 위 조상을 주인으로 정한다. 그런 프로세스가 여럿이면 pid가 가장 작은 것이다. worker를 종료하면 master가 다시 띄우므로, 행과 종료 대상은 주인이다.

14절 실험에서 LISTEN 소켓을 연 프로세스가 fork하면 부모와 자식 pid에 같은 소켓 식별자가 보이는 것을 확인했다.

그다음 주인 pid로 묶는다. 이후 **한 행 = 한 프로세스**다.

### 7.3 정보 보강

pid마다 이름, 실행 파일 경로, argv, cwd, 부모 pid, 부모의 argv, 시작 시각, 소유 uid를 읽는다. 일부를 읽지 못해도 실패로 처리하지 않는다. 읽은 것까지 쓰고, 빈 칸은 대체 규칙(7.5절)이 채운다. 프로세스 제목을 바꾸는 프로그램(`next-server`, `puma`)은 argv가 argc보다 적게 읽히므로, 읽힌 인자까지만 쓴다.

### 7.4 Docker 연결

- 소켓 후보 경로를 차례로 시도한다: Docker Desktop(`~/.docker/run/docker.sock`), `/var/run/docker.sock`, OrbStack(`~/.orbstack/run/docker.sock`), Colima(`~/.colima/default/docker.sock`). 14절 실험에서 Docker Desktop은 첫 후보로 접속되었다. OrbStack을 설치하면 `/var/run/docker.sock`이 `~/.orbstack/run/docker.sock`을 가리키는 심볼릭 링크가 되어 둘째 후보로 접속된다. 응답은 chunked 전송으로 온다.
- 소켓 파일이 없거나 연결이 거부되면(ENOENT, ECONNREFUSED) 다음 후보로 넘어간다. 모두 그렇다면 "Docker 없음"이다. Docker를 끈 사용자에게 오류를 보이지 않기 위해서다. 1초 안에 응답이 없거나 API가 오류를 돌려주면 "응답 없음"이다.
- 실험에서 Docker Desktop을 켠 적이 없을 때와 종료한 뒤에는 네 후보 모두 ENOENT였다(소켓 파일이 남지 않는다). OrbStack을 종료하면 `/var/run/docker.sock` 심볼릭 링크가 대상 없이 남는데, 연결이 ENOENT로 실패하므로 "응답 없음"이 아니라 "Docker 없음"으로 처리한다.
- 게시 포트의 노출 범위는 `Ports[].IP`로 정한다(`127.0.0.1`이면 이 기기만). `0.0.0.0`과 `::`에 같은 호스트 포트가 두 번 나오므로(실험의 postgres) 하나로 합친다.
- 정지(`POST /containers/{id}/stop?t=10`)는 컨테이너가 멈출 때까지 응답하지 않으므로 시간 제한을 15초로 따로 둔다. 실험에서는 Docker Desktop 0.17초, OrbStack 0.78초에 204로 끝났다.
- 실행 중인 컨테이너의 **게시된 호스트 포트 집합**을 만든다. 이 집합에 속한 포트는 프로세스가 아니라 **컨테이너 행**으로 바꾼다. Docker 런타임 프로세스 이름에 기대지 않으므로 런타임 종류와 관계없이 동작한다.
- 컨테이너 행의 제목은 Compose 서비스 이름(`postgres`)이고, 오른쪽 열(`tool` 자리)에 컨테이너 이름(`shop-db`)을 둔다. Compose가 아니면 제목은 컨테이너 이름, 오른쪽 열은 이미지 짧은 이름(레지스트리 경로와 태그를 뺀 마지막 마디, `ghcr.io/org/redis:7` → `redis`)이다.
- 소켓이 없으면 Docker 구역을 숨긴다. 소켓은 있는데 1초 안에 응답이 없으면 "Docker (응답 없음)" 행을 보여 주고 정지 동작을 끈다.

### 7.5 분류

**도구 판별**: 위에서부터 처음 맞는 규칙을 쓴다. 규칙은 코드 안의 표 하나로 관리하고, 규칙마다 맞는 사례와 아닌 사례를 하나 이상 테스트한다.

| 단서 | 분류 | 도구 표시 |
|---|---|---|
| 컨테이너 런타임: `Docker`·`OrbStack`·`Rancher Desktop`·`Podman Desktop` 앱 안의 실행 파일, 또는 `limactl`·`vfkit`·`qemu-system-*`·`gvproxy`·`krunkit` | 다른 앱(숨김, 종료 불가) | 런타임 이름 |
| node + argv에 `vite`·`next`·`nuxt`·`astro`·`remix`·`webpack` | 앱 | 해당 이름 |
| java + 메인 클래스 `GradleDaemon`·`KotlinCompileDaemon` | 개발 도구(숨김) | `gradle daemon` 등 |
| java + 부모가 Gradle 데몬 | 앱 | `gradle` |
| java + 부모가 Maven 런처 | 앱 | `maven` |
| java + `-jar <파일>` | 앱 | `java` |
| 부모가 `cargo run`, 또는 실행 파일 경로에 `target/debug`·`target/release` | 앱 | `cargo` |
| python + `manage.py runserver`·`uvicorn`·`flask`·`gunicorn` | 앱 | `django`·`uvicorn`·`flask`·`gunicorn` |
| ruby + `puma`·`rails` | 앱 | `rails` |
| IntelliJ, VS Code, Cursor 등 IDE 프로세스 | 개발 도구(숨김) | IDE 이름 |
| ControlCenter의 5000·7000 포트 | 시스템 | `AirPlay 수신 (macOS)` |
| macOS 서비스: 실행 파일이 `/System/`·`/usr/libexec/`·`/usr/sbin/` 아래에 있음(예: `rapportd`) | 다른 앱(숨김, 종료 불가) | 실행 파일 이름 |
| 실행 파일 경로에 `.app/Contents/`가 있는 다른 앱 | 다른 앱(숨김, 종료 불가) | 앱 이름 |
| 그 밖 | 앱 | 실행 파일 이름 |

14절 실험에서 확인한 게시 포트의 주인 프로세스는 Docker Desktop이 `com.docker.backend`(`/Applications/Docker.app/Contents/MacOS/`), OrbStack이 `OrbStack Helper`(`/Applications/OrbStack.app/Contents/Frameworks/OrbStack Helper.app/Contents/MacOS/`)다. 실행 파일 경로의 가장 바깥 `.app` 이름(`Docker`, `OrbStack`)으로 판별하므로 둘 다 첫 규칙에 걸린다.

**프로젝트 이름**: 시작 폴더에서 위로 올라가며(홈 폴더에서 멈춘다) **가장 가까운 표식**의 이름을 쓴다.

- 시작 폴더: cwd. `java -jar`는 jar 파일이 있는 폴더.
- 같은 폴더 안의 표식 우선순위: `package.json`의 `name` → `Cargo.toml`의 `[package] name` → `pyproject.toml`의 `[project] name` → `settings.gradle(.kts)`의 `rootProject.name` → `pom.xml`의 `artifactId` → `go.mod`의 module 마지막 마디 → `.git`이 있는 폴더 이름.
- TOML과 Gradle 파일은 라이브러리 없이 이름 줄만 정규식으로 읽는다. `pom.xml`은 `XMLParser`로 읽는다. 해석에 실패하면 다음 표식으로 넘어간다.
- 시작 폴더가 `/`이거나 홈 폴더이면 쓰지 않는다. 대체 순서: jar 파일 이름 → 실행 파일 이름 → 프로세스 이름.
- 표식 폴더와 별도로 git 루트 경로를 기록한다. 메뉴에는 보여 주지 않는다(8.2절).
- **폴더 접근 허락(TCC)**: `~/Documents`, `~/Desktop`, `~/Downloads`, iCloud Drive 안의 파일을 읽으면 macOS가 허락 창을 띄운다. 거부되었거나 아직 허락을 받지 못해 접근이 막히면(EPERM·EACCES) 더 올라가지 않고, 시작 폴더 이름을 프로젝트 이름으로 쓴다. 허락 창의 설명 문구는 13.1절에 둔다.
  - 14절 실험에서 허락 창이 떠 있는 동안에는 파일 읽기가 응답 없이 멈췄다. 그래서 프로젝트 파일은 메인 스레드에서 읽지 않는다.
  - 거부하면 이후 읽기는 바로 EPERM·EACCES로 실패한다. libproc로 읽는 cwd와 argv는 거부와 관계없이 읽히므로 시작 폴더 이름으로 대체할 수 있다.

**대표 포트와 보조 포트**

- 역할을 아는 포트는 보조 포트다: argv의 `-agentlib:jdwp` 주소(디버그), Node `--inspect` 포트(기본 9229), 35729(LiveReload).
- 남은 포트 중 가장 작은 번호가 대표 포트다. 남은 포트가 없으면 보조 포트 중 가장 작은 번호.

### 7.6 Snapshot

- 구역 순서: 앱 서버 → 시스템 → Docker → "숨김 N개".
- 구역 안에서는 대표 포트 번호 순. 열 때마다 순서가 바뀌지 않게 한다.
- 오래 켜짐: `현재 시각 - 시작 시각 > 기준값`. 컨테이너는 Docker API의 시작 시각을 쓴다.
- 메뉴바 숫자는 숨김을 뺀 행 수다.

```swift
struct ServerEntry: Sendable, Equatable {
  let id: EntryID              // "pid:48211" / "docker:3f2a…"
  let target: Target           // .process(pid, startedAt) / .container(id) / .unknownDocker
  let section: Section         // .app / .system / .docker / .hidden(.devTool | .otherApp)
  let title: String            // 프로젝트 이름 → jar 이름 → 실행 파일 이름
  let tool: String?            // "vite", "gradle"
  let primary: PortBinding     // port, exposure(.loopback / .network)
  let extras: [PortBinding]    // role: .debugger, .liveReload, .inspector
  let directory: URL?          // 표식 폴더
  let repositoryRoot: URL?     // git 루트
  let startedAt: Date?
  let isLongRunning: Bool
  let likelyHTTP: Bool
  let canTerminate: Bool
}
```

### 7.7 메뉴를 여는 순간

가장 최근 Snapshot(최대 5초 전)으로 메뉴를 즉시 그린다. 동시에 새 조회를 시작하고, 결과가 오면 열린 메뉴의 항목을 그 자리에서 고친다.

## 8. 메뉴

사용자 시안을 따른다. 아래는 한국어 화면이다(영어는 `Running · 5`, `· 3d`처럼 `L10n`의 같은 키).

```
실행 중 · 5                                   (회색 머리글)
● 3000  @repot/site                    vite ▸
● 5173  @repot/desktop                 vite ▸
● 8080  shop-api · 3일째             gradle ▸   (`· 3일째`는 주황 글자)
──────────
◌ 5000  AirPlay 수신 (macOS)                ▸
──────────
Docker
● 5432  postgres                    shop-db ▸
● 6379  redis                    shop-redis ▸
──────────
숨김 3개                                    ▸
──────────
설정…                                    ⌘,
Doorplate 종료                           ⌘Q
```

- 머리글은 `실행 중 · N`이다. N은 메뉴바 숫자와 같다(7.6절).
- 앱 행: 색 점, 포트, 프로젝트 제목, 오른쪽 끝에 도구 이름과 하위 메뉴 화살표.
- 오래 켜진 행은 제목 뒤에 주황 글자로 `· 3일째`(영어 `· 3d`)를 붙인다.
- Docker 행: 제목은 Compose 서비스 이름, 오른쪽 열은 컨테이너 이름이다. Compose가 아니면 제목은 컨테이너 이름, 오른쪽 열은 이미지 짧은 이름이다(7.4절).
- 서버가 없으면 "No servers running" 한 줄.
- 행의 도구 이름과 Docker 행의 오른쪽 열은 탭 정지가 있는 `attributedTitle`로 오른쪽에 맞춘다.
- 메뉴가 열린 상태에서 글자를 치면 해당 항목으로 이동한다(macOS 기본 동작).
- "숨김" 하위 메뉴는 숨긴 항목을 정보로만 보여 준다.

### 8.1 행 동작

macOS 메뉴에서 하위 메뉴가 달린 항목은 클릭해도 동작을 실행하지 않는다. 그래서 다음과 같이 한다.

- 행에 마우스를 올리면 하위 메뉴가 열리고, 첫 동작 항목이 가장 흔한 동작(HTTP면 "브라우저에서 열기", 아니면 "주소 복사")이다.
- **⌥를 누르고 있으면** 행이 하위 메뉴 없는 "종료 · 5173 @repot/desktop" 대체 항목으로 바뀌고, 클릭하면 바로 종료한다. 14절 실험에서 대체 항목만 하위 메뉴가 없어도 정상 동작했다: ⌥로 전환, 클릭으로 실행, ⌥를 떼면 원래 행과 하위 메뉴로 복귀, 키보드(↓, ⌥, Return), 메뉴가 열린 채 2초 타이머로 제목 갱신(열린 하위 메뉴도 유지).
- `canTerminate`가 거짓인 행에는 ⌥ 대체 항목을 두지 않는다.

### 8.2 하위 메뉴

프로세스 행:

```
네트워크에 열림                              (회색, 네트워크에 열린 포트일 때만)
──────────
브라우저에서 열기          localhost:5173
Finder에서 보기
터미널에서 열기
주소 복사
──────────
5005  디버거                                 (보조 포트가 있을 때만, 클릭하면 주소 복사)
──────────
종료 (PID 48211)                             (빨간 글자)
```

- 시안에 맞춰 회색 정보 줄(표식 폴더 경로, `도구 · 실행 시간 · PID · 노출`, Repository)은 두지 않는다. 도구는 행에, 오래 켜짐은 행의 주황 글자에, PID는 종료 항목에 있다.
- 노출은 네트워크에 열린 포트일 때만 맨 위 회색 "네트워크에 열림" 줄로 보여 준다. 이 기기만이면 줄이 없다. 프로세스 하위 메뉴에만 둔다. Docker는 포트를 기본으로 모든 네트워크에 열어서 컨테이너에는 거의 항상 붙고, 그러면 알려 주는 것이 없다.
- `likelyHTTP`가 거짓이면 "브라우저에서 열기"를 빼고 "주소 복사"를 맨 위에 둔다. `likelyHTTP`가 거짓인 경우: 포트 5432·3306·6379·27017·9092·11211, 또는 컨테이너 이미지의 짧은 이름(마지막 `/` 뒤, `:` 앞)이 `postgres`·`postgresql`·`mysql`·`mariadb`·`redis`·`valkey`·`mongo`·`mongodb`·`kafka`·`cp-kafka`·`memcached` 중 하나와 정확히 같을 때. 접두어로 판단하지 않는다(`redis-exporter`는 HTTP다).
- "터미널에서 열기"는 설정의 터미널 앱(기본 Terminal)으로 표식 폴더를 연다.
- 컨테이너 행: 열기·복사 → "Compose 폴더를 Finder에서 보기" → "컨테이너 정지". Compose 폴더 경로, 이미지, 실행 시간 줄은 두지 않는다.
- 시스템 행(AirPlay): "Turn off in System Settings > General > AirDrop & Handoff" 안내만 보여 준다.

## 9. 종료 흐름

1. **pid 재확인**: 종료 직전에 그 pid의 시작 시각이 Snapshot의 `startedAt`과 같은지 확인한다. 다르거나 프로세스가 없으면 아무것도 하지 않고 "이미 종료됨"을 짧게 알린다.
2. **SIGTERM**을 보낸다. 확인 창은 없다. 정상 종료 신호이고 사용자가 명시적으로 고른 동작이다.
3. kqueue 종료 이벤트로 **최대 10초** 기다린다. 그동안 행에 "Stopping…"을 표시한다.
4. 10초 안에 끝나지 않으면 확인 창: "shop-api is still running. [Force Stop] [Keep Waiting]". 강제 종료는 SIGKILL이다. 이때도 1번 재확인을 다시 한다.
5. 부모 프로세스(`npm`, `gradle`, `cargo` 등)는 건드리지 않는다.
6. 컨테이너는 Docker API `POST /containers/{id}/stop`(Docker 기본 유예 10초)으로 정지한다.
7. 종료 권한이 없는 프로세스(다른 사용자 소유, 시스템)는 `canTerminate = false`이고 종료 항목이 비활성이다.

## 10. 오류 처리

| 상황 | 처리 |
|---|---|
| 특정 pid를 읽지 못함 | 그 pid를 건너뛰거나 읽은 정보까지만 쓴다. 알리지 않는다 |
| 조회 전체 실패 | 직전 Snapshot을 유지하고 머리글에 "Update failed · 1m ago"(분 단위, 최소 1분) |
| 이전 조회 진행 중 | 이번 주기를 건너뛴다 |
| Docker 소켓 없음 | Docker 구역을 숨긴다 |
| Docker 소켓 응답 없음(1초) | "Docker (not responding)" 행, 정지 비활성 |
| 프로젝트 파일 해석 실패 | 다음 표식으로 |
| 열기·Finder·터미널 실패 | 경고음과 짧은 확인 창 |
| 종료 중 EPERM | "Not allowed to stop this process" 확인 창 |
| Docker 정지 실패 | API 오류 메시지를 담은 확인 창 |

기록은 `os.Logger`(subsystem `io.github.junjuny0227.doorplate`, 카테고리 `scan`, `docker`, `terminate`, `menu`, `update`)에만 남긴다. 파일 로그는 없다.

## 11. 설정

| 설정 | 기본값 |
|---|---|
| 로그인 시 실행 | 꺼짐(첫 실행 때 켤지 묻는다) |
| 오래 켜짐 기준 | 24시간 |
| 개발 도구 포트 표시 | 꺼짐 |
| 다른 앱 포트 표시 | 꺼짐 |
| 터미널 앱 | Terminal. 설치된 Terminal, iTerm, Ghostty, Warp 등에서 고른다 |
| 업데이트 자동 확인 | 켜짐 |

## 12. 테스트

### 12.1 Core 단위·시나리오 테스트 (`swift test`)

- Fixture
  - `Tests/Fixtures/scenarios/*.json`: 한 파일에 현재 시각·홈 경로·사용자 uid·설정, 프로세스와 LISTEN 소켓, 프로젝트 파일 내용, 접근 거부 경로, Docker 상태와 컨테이너를 모두 담는다. 날짜는 ISO 8601이며 `trees/` 폴더는 두지 않는다
  - `Tests/Fixtures/docker/`: Docker Desktop의 실제 `/containers/json` 응답(OrbStack은 확인할 수 있을 때 추가)
- 도구 판별 규칙마다 맞는 사례와 아닌 사례를 하나 이상 둔다.
- 시나리오 테스트: fixture 하나를 파이프라인 전체에 넣고 `Tests/Fixtures/expected/*.json`과 비교한다. 기대 결과는 `UPDATE_GOLDEN=1 swift test`로 다시 만들고, diff를 읽은 뒤 커밋한다.
- 현재 시각과 설정은 입력으로 넣어 고정한다.

### 12.2 실제 시스템 테스트 (`swift test`, 외부 도구 없음)

- 수집: 테스트 프로세스가 임시 포트를 열고, libproc 조회 결과에 자기 pid·포트·cwd가 나오는지 확인한다.
- 종료: `/bin/sleep 60`을 띄워 SIGTERM으로 끝나는지 확인한다. SIGTERM 무시 모드는 `/bin/sh -c 'trap "" TERM; exec /bin/sleep 60'`으로 띄워 SIGKILL 경로로 끝나는지 확인한다. 실제 시그널은 테스트가 직접 띄운 프로세스에만 보내고, 테스트 끝에 살아 있으면 정리한다. pid 재확인은 시작 시각을 바꾼 가짜 항목으로 확인한다.

### 12.3 App 테스트 (`xcodebuild test`)

- `MenuBuilder`: Snapshot fixture로 만든 `NSMenu`의 항목 제목, 활성 여부, ⌥ 대체 항목, `likelyHTTP` 거짓일 때의 순서.

### 12.4 진단 명령

`swift run doorplate-scan`은 이 기기의 Snapshot을 JSON으로 출력하고 걸린 시간을 표시한다. 버그 제보에도 쓴다. 출력에 경로가 들어 있으므로 공유 여부는 사용자가 정한다.

### 12.5 릴리스 전 수동 점검표

- vite, next, `gradle bootRun`, `mvn spring-boot:run`, IntelliJ 실행(Spring), `java -jar`(프로젝트 밖), `cargo run`, Django, FastAPI(uvicorn), Rails
- Docker Compose: Docker Desktop, OrbStack 각각
- AirPlay 5000, Gradle 데몬 숨김
- 성공 기준(2절)의 메뉴 지연, 유휴 CPU, 메모리
- 폴더 접근 허락(TCC): `~/Desktop`, `~/Downloads`, iCloud Drive 안의 프로젝트에서 폴더마다 허락 창이 한 번 뜨는지, 허락하면 프로젝트 이름이, 거부하면 폴더 이름이 나오는지(실험은 `~/Documents`만 확인했다)
- `~/Downloads`에서 옮기지 않고 바로 실행했을 때: App Translocation으로 실행되는지, Sparkle 업데이트가 거부되는지, 13.1절 안내와 맞는지
- Homebrew cask 설치와 업데이트: 설치한 앱에 격리 표시가 남는지, 첫 실행, `brew upgrade` 뒤와 Sparkle 업데이트 뒤의 실행

## 13. 배포

Apple Developer Program에 가입하지 않는다. Developer ID 서명과 공증 없이 배포한다.

### 13.1 서명과 첫 실행

- ad-hoc 서명(`codesign -s -`)으로 배포한다.
- 다운로드한 앱은 Gatekeeper가 첫 실행을 막는다. macOS 15부터는 우클릭 → 열기로 우회할 수 없다. README와 릴리스 노트에 다음 절차를 적는다.
  1. 처음 열기 전에 zip을 풀고 앱을 Finder로 `/Applications`에 옮긴다. 다운로드한 위치에서 실행되는 앱은 Sparkle이 "can't be updated if it's running from the location it was downloaded to"로 업데이트를 거부한다(14절 실험에서 App Translocation 상태로 확인).
  2. 앱을 연다. 다음 창이 뜨며 막힌다. 제목 "'Doorplate.app'을(를) 열지 않음", 본문 "Apple은 'Doorplate.app'에 사용자의 Mac에 손상을 입히거나 사용자의 개인 정보에 침입할 수 있는 악성 코드가 없음을 확인할 수 없습니다.", 버튼 [휴지통으로 이동] [완료]. "완료"를 누른다("휴지통으로 이동"은 앱을 휴지통으로 옮긴다).
  3. 시스템 설정 > 개인정보 보호 및 보안에서 "그래도 열기"를 누르고 암호나 Touch ID로 확인한 뒤, 다시 뜨는 창에서 "그래도 열기"를 누른다.
  4. 터미널에 익숙하면 `xattr -dr com.apple.quarantine /Applications/Doorplate.app`도 안내한다. 이 명령이 무엇을 하는지(다운로드 격리 표시 제거)도 함께 적는다.
- **폴더 접근 허락(TCC)**: Info.plist에 `NSDocumentsFolderUsageDescription`, `NSDesktopFolderUsageDescription`, `NSDownloadsFolderUsageDescription`을 둔다. 문구는 "Doorplate reads project files such as package.json to show which project owns each port."이고, 한국어는 `ko.lproj/InfoPlist.strings`에 둔다. ad-hoc 서명 앱은 macOS가 빌드마다 바뀌는 해시로 앱을 구분하므로, 업데이트하면 허락을 다시 묻는다(14절 실험에서 1.0 → 1.1 업데이트 뒤 확인). 보호 폴더마다 업데이트당 한 번이며, 릴리스 노트에 적는다.

### 13.2 배포 경로

- GitHub Releases: Universal 앱 zip(`ditto -c -k --keepParent`)과 SHA-256.
- Homebrew: 자체 tap의 cask(`brew install --cask junjuny0227/tap/doorplate`). cask caveats에 13.1 절차를 적는다. 공식 cask는 서명·공증이 없어서 목표로 두지 않는다.

### 13.3 업데이트

- Sparkle을 쓴다. EdDSA로 서명한 업데이트를 받는다. appcast는 GitHub Pages에 둔다. 버전은 2.10.1로 고정한다(실험에서 쓴 버전).
- 14절 실험에서 실제 사용자 경로(브라우저 다운로드 → 압축 해제 → Finder로 `/Applications`에 옮김 → "그래도 열기")로 설치한 ad-hoc 서명 앱이 Sparkle로 새 버전을 받아 설치하고 다시 실행했다. App Translocation 없이 `/Applications`에서 실행되었고, 새 버전은 막히지 않았다(서명 adhoc, `codesign --verify --deep --strict` 통과, 격리 표시 없음).
- 메뉴바 전용 앱(`LSUIElement`)이라 Sparkle이 "Background app automatically schedules for update checks but does not implement gentle reminders" 경고를 남긴다. `SPUStandardUserDriverDelegate`로 gentle reminders를 구현할지, 경고를 받아들일지는 계획 3에서 정한다.
- 실험이 실패했을 때의 대안이었다(쓰지 않음): GitHub `releases/latest`를 하루 한 번 확인한다. 새 버전이 있으면 메뉴에 "Update Available: 0.2.0" 항목을 보여 주고, 누르면 릴리스 페이지를 연다. Homebrew 사용자는 `brew upgrade`를 쓴다.
- Sparkle EdDSA 비밀 키는 로컬 키체인과 GitHub Secrets에만 둔다. 출력하거나 커밋하지 않는다. 공개 키만 `Info.plist`에 둔다.

### 13.4 릴리스 방식

- 릴리스 워크플로는 draft를 만들고, 사용자가 확인한 뒤 공개한다.
- 0.x는 prerelease가 아닌 정식 릴리스로 내고 이름에 `(beta)`를 붙인다.

### 13.5 CI (GitHub Actions, macOS 러너)

- `swift format lint --recursive`
- `swift test` (Core)
- XcodeGen → `xcodebuild build test` (App)
- Docker가 필요한 점검은 CI에서 돌리지 않는다.

### 13.6 Developer Program 재검토 조건

다음 중 하나가 생기면 가입을 다시 검토한다.

- GitHub 별 200개 이상
- 첫 실행이 막혀 설치를 포기했다는 이슈나 의견이 3건 이상
- 업데이트할 때마다 폴더 접근 허락이나 로그인 항목 승인을 다시 묻는 것이 실험(14절) 또는 실제 릴리스에서 확인됨
- 공식 Homebrew cask 등록이 필요해짐

셋째 조건(업데이트마다 폴더 접근 허락)은 14절 실험에서 충족되었다. 사용자는 2026-11-05에 가입하지 않기로 했다. 영향은 업데이트마다 보호 폴더당 허락 창 한 번이고, 거부해도 폴더 이름으로 대체된다(7.5절). 로그인 항목은 새 빌드로 바꾼 뒤에도 켜져 있어 승인을 다시 묻지 않았다.

## 14. 첫 단계 실험

본 구현 전에 확인한다. 실험 코드는 버린다. 결과(2026-11-05)는 `docs/spikes/01-feasibility.md`에 있다.

| 확인할 것 | 통과 기준 | 실패하면 | 결과 |
|---|---|---|---|
| ad-hoc 서명 GUI 앱(샌드박스 없음)에서 libproc로 같은 사용자 프로세스의 소켓·cwd·argv를 읽을 수 있는가 | 모두 읽힘 | 설계를 다시 본다(가장 큰 위험) | 결과: 통과. 소켓·cwd·argv·시작 시각·uid 모두 읽힘. 관리자 권한 없는 `lsof`와 비교해 빠지거나 더 나온 사용자 포트 0개 |
| 전체 조회 시간 | 프로세스 1,000개 기준 50ms 이하 | 주기를 늘리거나 메뉴 열 때만 조회 | 결과: 통과. 프로세스 1,137개 중앙값 17.38ms, p95 31.51ms(1,000개 기준 15.28ms / 27.71ms) |
| ⌥ 대체 항목만 하위 메뉴가 없어도 되는가 | 정상 동작 | 8.1절의 대안 | 결과: 통과. 전환, 클릭, ⌥를 떼면 복귀, 키보드, 열린 메뉴 갱신 모두 정상(8.1절) |
| root 소유 소켓이 보이는가 | 결과를 기록 | 7.1절 문구를 확정 | 결과: `sudo lsof`에만 보인 것은 launchd(pid 1)의 8021 하나. 7.1절 문구를 확정 |
| GUI 앱에서 Docker 소켓 후보 경로로 접속되는가 | Docker Desktop 필수, OrbStack은 설치되어 있으면 | 설정에 소켓 경로 입력란 추가 | 결과: 통과. Docker Desktop은 `~/.docker/run/docker.sock`, OrbStack은 `/var/run/docker.sock` 심볼릭 링크로 접속. 꺼진 상태는 ENOENT(7.4절) |
| `~/Documents` 안 프로젝트의 파일 읽기(TCC) | 허락 창이 한 번 뜨고, 허락 뒤 이름이 맞게 나온다. 업데이트 뒤 다시 묻는지 기록 | 거부되면 폴더 이름(7.5절). 업데이트마다 묻는다면 13.6절 조건 | 결과: 허락 창이 한 번 뜨고, 허락 뒤 이름이 맞음. 창이 떠 있는 동안 읽기가 멈춤. 거부하면 EPERM·EACCES로 폴더 이름. 업데이트(1.0 → 1.1) 뒤 다시 물음 → 13.6절 조건 충족 |
| 공유 소켓(prefork 서버) | 같은 소켓 식별자가 여러 pid에 보인다 | 7.2절 규칙을 다시 본다 | 결과: 통과. fork한 listener의 부모·자식 pid에 같은 소켓 식별자 |
| `/Applications`에 설치한 ad-hoc 서명 앱의 Sparkle 업데이트 | 격리 표시가 있는 첫 설치를 "그래도 열기"로 승인한 뒤 업데이트하면, 새 버전이 막힘 없이 실행된다. App Translocation 여부 기록 | 13.3절 대안 | 결과: 통과(Sparkle 2.10.1). 실제 사용자 경로로 설치하면 App Translocation 없이 `/Applications`에서 실행되고 업데이트 뒤에도 막히지 않음. 격리 표시를 손으로 쓴 설치는 Translocation이 남아 업데이트가 거부됨(13.1절) |
| ad-hoc 서명 앱의 `SMAppService` 로그인 항목 | 재로그인 후 자동 실행. 새 빌드로 바꾼 뒤 상태 기록 | 로그인 항목 토글을 숨긴다 | 결과: 통과. 재로그인 후 자동 실행, 새 빌드로 바꾼 뒤에도 켜짐, 승인 요청 없음 |

## 15. 이후 (MVP 밖)

- 알림 센터 알림(오래 켜짐, 포트 충돌, 고정한 포트의 변화)
- git 브랜치 표시
- 자주 쓰는 포트 고정
- 프로젝트별 묶음 보기
- 일본어·중국어
- Developer ID 서명과 공증(13.6절)
- Windows(WSL 내부 조회 포함), Linux. 실제 요청이 쌓이면 별도 제품으로 검토한다.

## 16. 결정 기록

| 결정 | 이유 |
|---|---|
| macOS 전용 | 메뉴바 앱 사용층이 맥에 있다. 핵심인 "포트 → 프로젝트" 연결이 맥에서 가장 쉽다. Windows는 WSL 때문에 사실상 다른 제품이다 |
| Swift(AppKit 메뉴 + SwiftUI 설정) | 늘 켜 두는 앱이라 가볍고 네이티브여야 한다. 핵심 로직이 OS별 시스템 조회라 크로스 플랫폼 프레임워크로 아끼는 코드가 적다 |
| 네이티브 `NSMenu` | 가볍고 키보드로 다룰 수 있다. 정보가 한 줄로 줄어드는 대가는 하위 메뉴와 ⌥ 대체 항목으로 메운다 |
| Core 패키지 분리 | 6절 |
| 이름 Doorplate | 비슷한 앱이 많은 분야라 `Port*` 이름 사이에서 구별되는 것을 우선했다. 뜻은 한 줄 소개로 보완한다 |
| Developer Program 미가입 | 사용자 결정. 대상이 개발자라 첫 실행 절차를 감당할 수 있다고 본다. 재검토 조건은 13.6절 |
| Sparkle 유지 | 14절 실험에서 ad-hoc 서명 앱의 업데이트가 실제 사용자 경로로 통과했다(13.3절) |
| Developer Program 미가입 유지(2026-11-05) | 업데이트마다 폴더 접근을 다시 묻는 13.6절 조건이 충족되었지만, 영향이 업데이트마다 보호 폴더당 한 번이고 거부해도 폴더 이름으로 대체되어 사용자가 가입하지 않기로 했다 |
| 메뉴는 사용자 시안을 따른다 | Docker 행은 서비스 이름 제목과 컨테이너 이름 오른쪽 열, 오래 켜짐은 주황 글자, 하위 메뉴의 정보 줄을 빼고 PID는 종료 항목에 둔다(8절) |
