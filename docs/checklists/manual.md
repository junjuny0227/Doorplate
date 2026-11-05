# 릴리스 전 수동 점검표

스펙 12.5절 항목과 계획 3 Task 7 Step 2의 폴더 접근(TCC) 행을 옮긴 표다. 릴리스마다 이 표를 채운다.

- 기대 제목·도구는 스펙 7.4–7.5절과 8절에서 가져왔다. 제목은 가장 가까운 표식(`package.json` → `Cargo.toml` → `pyproject.toml` → `settings.gradle(.kts)` → `pom.xml` → `go.mod` → `.git` 폴더)의 이름이다.
- 결과 칸에는 `통과`, `실패: <관측>`, `미확인(<이유>)` 중 하나를 쓴다. 사람이 메뉴·창을 봐야 하는 행은 실제로 확인하기 전까지 `미확인(사용자 점검)`이다. 자동 테스트 통과를 이 표의 통과로 옮기지 않는다.
- 이 기기에 도구가 없는 시나리오는 `미확인(도구 없음)`으로 둔다.
- 점검을 위해 띄운 서버만 종료한다. 다른 서버, 다른 앱, Docker 런타임(Docker Desktop, OrbStack 등)은 종료하지 않는다.

## 개발 서버

| 시나리오 | 기대 제목·도구 | 결과 | 날짜 |
|---|---|---|---|
| vite (`npm run dev`) | `package.json`의 `name` · `vite` | Core 스캔 통과: scan-vite · vite (메뉴 미확인) | 2026-11-05 |
| next (`next dev`) | `package.json`의 `name` · `next` | Core 스캔 통과: scan-next · next (메뉴 미확인) | 2026-11-05 |
| `gradle bootRun` | `settings.gradle(.kts)`의 `rootProject.name` · `gradle`. Gradle 데몬 자신은 숨김 | 미확인(도구 없음) | 2026-11-05 |
| `mvn spring-boot:run` | `pom.xml`의 `artifactId` · `maven` | 미확인(도구 없음) | 2026-11-05 |
| IntelliJ 실행(Spring) | 프로젝트 표식 이름 · 실행 방식에 맞는 도구(`gradle`·`maven`·`java`). IntelliJ 자신의 포트는 숨김 | 통과(메뉴): `8080 spring-demo` · `java`. IntelliJ가 Gradle을 거치지 않고 `java`로 직접 띄움(부모 프로세스가 IntelliJ). 개발 도구 표시를 켜면 IntelliJ 자신의 포트와 Gradle 데몬(`java` · `gradle daemon`)이 따로 보임 | 2026-11-05 |
| `java -jar`(프로젝트 밖) | jar가 있는 폴더 기준 이름, 표식이 없으면 jar 파일 이름 · `java` | Core 스캔 통과: app.jar · java (메뉴 미확인) | 2026-11-05 |
| `cargo run` | `Cargo.toml`의 `[package] name` · `cargo` | Core 스캔 통과: scan-cargo · cargo (메뉴 미확인) | 2026-11-05 |
| Django (`manage.py runserver`) | `pyproject.toml`의 `[project] name`(없으면 `.git` 폴더 이름) · `django` | Core 스캔 통과: scan-django · django (메뉴 미확인) | 2026-11-05 |
| FastAPI (`uvicorn`) | `pyproject.toml`의 `[project] name`(없으면 `.git` 폴더 이름) · `uvicorn`. `--reload`의 worker가 아닌 주인 프로세스 한 행 | Core 스캔 통과: scan-fastapi · uvicorn (메뉴 미확인) | 2026-11-05 |
| Rails | `.git` 폴더 이름 · `rails` | 미확인(도구 없음) | 2026-11-05 |

## Docker Compose

| 시나리오 | 기대 제목·도구 | 결과 | 날짜 |
|---|---|---|---|
| Docker Compose: Docker Desktop | 제목은 Compose 서비스 이름(`postgres`), 오른쪽 열은 컨테이너 이름(`shop-db`). Docker 런타임 행은 숨김. "컨테이너 정지"가 API로 정지 | 통과(메뉴, 0.1.0): Docker 구역에 `8088 web` · `shop-web`, 포트를 연 `com.docker.backend` 행 없음. 컨테이너 정지 후 행이 사라지고 컨테이너는 `Exited (0)`, Docker Desktop은 계속 실행 | 2026-11-05 |
| Docker Compose: OrbStack | 위와 같음. 런타임 `OrbStack`은 숨김 | 통과(메뉴, 0.1.0): Docker 구역에 `8088 web` · `shop-web`, OrbStack 행 없음. 하위 메뉴는 열기·복사·Compose 폴더·컨테이너 정지(정보 줄 없음). Compose 폴더 항목은 Finder에서 폴더를 선택해 보여 줌. 컨테이너 정지 후 행이 사라지고 컨테이너는 `Exited (0)`, OrbStack은 계속 실행 | 2026-11-05 |

## 시스템·숨김

| 시나리오 | 기대 제목·도구 | 결과 | 날짜 |
|---|---|---|---|
| AirPlay 5000 | `AirPlay 수신 (macOS)` 시스템 행. 메뉴바 숫자에 세지 않음. 하위 메뉴는 끄는 방법 안내만 | 통과(시스템 구역에 표시, 숫자 제외) | 2026-11-05 |
| Gradle 데몬 숨김 | 기본 숨김(숨김 수에 포함). 설정의 개발 도구 포트 표시를 켜면 `gradle daemon`으로 보임 | 미확인(사용자 점검) | |

## 성공 기준(스펙 2절)

| 시나리오 | 기대 제목·도구 | 결과 | 날짜 |
|---|---|---|---|
| 메뉴 지연 | 클릭 후 체감 지연 없음. Instruments Points of Interest의 `menuNeedsUpdate` 구간 100ms 이하 | 통과: Debug 빌드 signpost 11회, 최대·중앙 1ms(로그 해상도 1ms) | 2026-11-05 |
| 유휴 CPU | 거의 0% | 자동 측정(아래 기록): 60초 동안 5초 간격 12회 0.0–0.2%. 30분 측정 통과: 0.0–0.1%(아래 기록) | 2026-11-05 |
| 메모리 | 30MB 이하(활성 상태 보기의 메모리 = 물리 풋프린트) | 자동 측정(아래 기록): 물리 풋프린트 23.3MB, RSS 약 89MB. 30분 측정 통과: 물리 풋프린트 17–21MB(아래 기록) | 2026-11-05 |

## 폴더 접근 허락(TCC)

계획 1 실험은 `~/Documents`만 확인했다. 폴더마다 아래 세 가지를 적는다: 허락 창이 그 폴더에 대해 한 번 뜨는지, 허락하면 프로젝트 이름이 제목인지, 거부하면 시작 폴더 이름이 제목인지.

| 시나리오 | 기대 제목·도구 | 결과 | 날짜 |
|---|---|---|---|
| `~/Documents` 안 프로젝트(앱) | 허락 창 한 번. 허락 → 프로젝트 이름, 거부 → 폴더 이름 | 통과(PR #43 뒤). 거부 → `doorplate-menu-tcc-check`, 허락 → `menu-check`. 수정 전에는 거부 시 `Python`으로 나왔다 | 2026-11-05 |
| `~/Desktop` 안 프로젝트 | 허락 창 한 번. 허락 → 프로젝트 이름, 거부 → 폴더 이름 | 미확인(사용자 점검) | |
| `~/Downloads` 안 프로젝트 | 허락 창 한 번. 허락 → 프로젝트 이름, 거부 → 폴더 이름 | 미확인(사용자 점검) | |
| iCloud Drive(`~/Library/Mobile Documents/com~apple~CloudDocs`) 안 프로젝트 | 별도 허락 창이 뜨는지와 어떤 권한으로 묶이는지 기록. 허락 → 프로젝트 이름, 거부 → 폴더 이름 | 미확인(사용자 점검) | |
| 업데이트마다 다시 묻는지 | 빌드 번호만 올린 새 ad-hoc 빌드로 바꾼 뒤 보호 폴더마다 허락 창이 다시 뜸(계획 1의 1.0→1.1 결과). 거부 시 폴더 이름으로 돌아감 | 미확인(사용자 점검) | |

## 배포 경로

| 시나리오 | 기대 제목·도구 | 결과 | 날짜 |
|---|---|---|---|
| `~/Downloads`에서 옮기지 않고 바로 실행 | App Translocation으로 실행되고 Sparkle이 업데이트를 거부함. 스펙 13.1절 안내와 맞음 | 미확인(사용자 점검, 계획 4 릴리스 뒤) | |
| Homebrew cask 설치 | 설치한 앱의 격리 표시 여부 기록, 첫 실행 절차가 13.1절과 맞음 | 통과: 격리 표시 남음(`0181;…`), 13.1절 "열지 않음" 창 → 그래도 열기로 열림, caveats 출력 | 2026-11-05 |
| `brew upgrade` 뒤 실행 | 앱이 열리고 폴더 허락을 다시 물음 | 미확인(사용자 점검, 계획 4 릴리스 뒤) | |
| Sparkle 업데이트 뒤 실행 | 새 버전이 설치·재실행되고 폴더 허락을 다시 물음 | 미확인(사용자 점검, 계획 4 릴리스 뒤) | |

## 유휴 부담 기록

### 2026-11-05 30분 측정 (Homebrew로 설치한 0.1.0 Release)

- 앱을 연 뒤 메뉴를 열지 않고 11:40–12:10에 5분 간격 7회 측정했다(`ps`, `top -stats pid,cpu,mem`, `footprint`).
- CPU: 첫 표본 1.3%(앱을 연 직후), 이후 0.0–0.1%. 30분 동안 누적 CPU 시간 4.7초(0:01.75 → 0:06.44).
- 물리 풋프린트: 17MB → 21MB(11:55–12:00 사이에 늘고 이후 그대로). RSS 82–94MB.
- 같은 시간에 다른 작업자가 개발 서버 6개를 띄웠다 내렸으므로 순수 유휴보다 조금 바쁜 조건이다.
- 판단: CPU 거의 0%, 메모리 30MB 이하로 기준 안이다.

### 2026-11-05 자동 측정 (60초)

- 대상: `main` `c1a0a7b`의 Release 빌드. `xcodegen generate && xcodebuild -project Doorplate.xcodeproj -scheme Doorplate -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY=- build` → `** BUILD SUCCEEDED **`.
- 환경: macOS 27.2 arm64. `open build/Build/Products/Release/Doorplate.app`로 실행하고 메뉴를 열지 않았다. 점검용 서버는 띄우지 않았다.
- 실행 3초 뒤부터 5초 간격으로 `ps -o %cpu=,rss= -p <pid>` 12회:

| 경과(초) | CPU% | RSS(KB) |
|---|---|---|
| 8 | 0.0 | 90832 |
| 13 | 0.0 | 90832 |
| 18 | 0.0 | 90832 |
| 23 | 0.0 | 90832 |
| 28 | 0.0 | 90848 |
| 33 | 0.0 | 90800 |
| 38 | 0.0 | 90752 |
| 43 | 0.0 | 90752 |
| 48 | 0.2 | 90768 |
| 53 | 0.0 | 90768 |
| 58 | 0.0 | 90784 |
| 63 | 0.0 | 90736 |

- 63초까지 누적 CPU 시간 `0:00.27`.
- 같은 프로세스의 `top -l 1 -pid <pid> -stats pid,cpu,mem` → `0.0  23M`. `footprint`와 `vmmap --summary`의 Physical footprint → 23.3MB(최고 23.3MB).
- 판단: CPU는 기준(거의 0%) 안이다. RSS 약 89MB는 공유 시스템 프레임워크 페이지를 포함한 값이고, 스펙이 말하는 활성 상태 보기의 메모리(물리 풋프린트)는 23.3MB로 30MB 기준 안이다.
- 종료: `osascript -e 'quit app "Doorplate"'`가 `사용자가 취소함. (-128)`로 두 번 실패했다. 첫 실행 로그인 질문 창이 떠 있었을 가능성이 있다(화면은 보지 않았다). 직접 띄운 그 pid에 SIGTERM을 보내 종료했다.
- 남은 것: 스펙과 계획이 정한 30분 유휴 측정(`top -l 1 -pid $(pgrep -x Doorplate) -stats pid,cpu,mem`)은 사용자 점검이다.

상세 절차: 열기·복사·종료 흐름은 [stop-flow.md](stop-flow.md)에 있다.

## 2026-11-05 사용자 점검(계획 3 Task 2–6, Debug 빌드, macOS 한국어)

- 첫 실행: 로그인 질문 한 번, 메뉴바 아이콘 있음, Dock 아이콘 없음. 질문이 떠 있는 동안 종료가 `-128`로 거절되던 문제는 PR #47에서 일반 창으로 바꿔 고쳤다.
- 실시간 갱신: 메뉴를 연 채 서버를 껐다 켜자 행이 사라졌다 다시 생겼고 메뉴는 닫히지 않았다. 열고 닫기에서 멈춤 없음.
- 열기·복사·종료: 브라우저·Finder·터미널·주소 복사 통과. ⌥ 대체 항목으로 확인 없이 종료 통과. TERM을 무시하는 서버에서 `종료 중…`, 종료 항목 비활성, 10초 뒤 창 하나, 기다리기 뒤 다시 창, 강제 종료 통과. 비활성 종료 항목이 연분홍으로 보이던 것은 PR #44에서 회색으로 고쳤다.
- 설정: 창 하나만 열림. 다른 앱 포트 표시를 켜면 숨김 10개가 앱 구역으로 옮겨짐. 표시한 다른 앱에 비활성 종료 항목이 보이던 것은 PR #45에서 뺐다. 개발 도구 표시는 대상 포트가 없어 미확인. 터미널 목록은 Terminal, iTerm. 로그인 시 열기를 켜면 시스템 설정 로그인 항목에 생김.
- 업데이트: 업데이트 확인…은 "업데이트 정보를 수집하는 중 오류" 창(appcast 미배포, 기대한 결과). 자동 확인 기본 켜짐. gentle reminders 경고 로그 없음.
- 그 밖에 고친 것: Android `adb` 데몬이 실행 폴더의 프로젝트 이름으로 앱 구역에 보이던 것(PR #46, 개발 도구로 숨김). 허락 창이 떠 있는 동안 조회 전체가 멈추던 것(PR #48, 프로젝트 파일 읽기를 분리).
- 남은 것: 한국어 문구 전체 점검, 개발 서버 표, Docker Compose, Desktop·Downloads·iCloud, 30분 유휴.
