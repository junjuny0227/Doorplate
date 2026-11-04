# 릴리스 전 수동 점검표

스펙 12.5절 항목과 계획 3 Task 7 Step 2의 폴더 접근(TCC) 행을 옮긴 표다. 릴리스마다 이 표를 채운다.

- 기대 제목·도구는 스펙 7.4–7.5절과 8절에서 가져왔다. 제목은 가장 가까운 표식(`package.json` → `Cargo.toml` → `pyproject.toml` → `settings.gradle(.kts)` → `pom.xml` → `go.mod` → `.git` 폴더)의 이름이다.
- 결과 칸에는 `통과`, `실패: <관측>`, `미확인(<이유>)` 중 하나를 쓴다. 사람이 메뉴·창을 봐야 하는 행은 실제로 확인하기 전까지 `미확인(사용자 점검)`이다. 자동 테스트 통과를 이 표의 통과로 옮기지 않는다.
- 이 기기에 도구가 없는 시나리오는 `미확인(도구 없음)`으로 둔다.
- 점검을 위해 띄운 서버만 종료한다. 다른 서버, 다른 앱, Docker 런타임(Docker Desktop, OrbStack 등)은 종료하지 않는다.

## 개발 서버

| 시나리오 | 기대 제목·도구 | 결과 | 날짜 |
|---|---|---|---|
| vite (`npm run dev`) | `package.json`의 `name` · `vite` | 미확인(사용자 점검) | |
| next (`next dev`) | `package.json`의 `name` · `next` | 미확인(사용자 점검) | |
| `gradle bootRun` | `settings.gradle(.kts)`의 `rootProject.name` · `gradle`. Gradle 데몬 자신은 숨김 | 미확인(사용자 점검) | |
| `mvn spring-boot:run` | `pom.xml`의 `artifactId` · `maven` | 미확인(사용자 점검) | |
| IntelliJ 실행(Spring) | 프로젝트 표식 이름 · 실행 방식에 맞는 도구(`gradle`·`maven`·`java`). IntelliJ 자신의 포트는 숨김 | 미확인(사용자 점검) | |
| `java -jar`(프로젝트 밖) | jar가 있는 폴더 기준 이름, 표식이 없으면 jar 파일 이름 · `java` | 미확인(사용자 점검) | |
| `cargo run` | `Cargo.toml`의 `[package] name` · `cargo` | 미확인(사용자 점검) | |
| Django (`manage.py runserver`) | `pyproject.toml`의 `[project] name`(없으면 `.git` 폴더 이름) · `django` | 미확인(사용자 점검) | |
| FastAPI (`uvicorn`) | `pyproject.toml`의 `[project] name`(없으면 `.git` 폴더 이름) · `uvicorn`. `--reload`의 worker가 아닌 주인 프로세스 한 행 | 미확인(사용자 점검) | |
| Rails | `.git` 폴더 이름 · `rails` | 미확인(사용자 점검) | |

## Docker Compose

| 시나리오 | 기대 제목·도구 | 결과 | 날짜 |
|---|---|---|---|
| Docker Compose: Docker Desktop | 제목은 Compose 서비스 이름(`postgres`), 오른쪽 열은 컨테이너 이름(`shop-db`). Docker 런타임 행은 숨김. "컨테이너 정지"가 API로 정지 | 미확인(사용자 점검) | |
| Docker Compose: OrbStack | 위와 같음. 런타임 `OrbStack`은 숨김 | 미확인(사용자 점검) | |

## 시스템·숨김

| 시나리오 | 기대 제목·도구 | 결과 | 날짜 |
|---|---|---|---|
| AirPlay 5000 | `AirPlay 수신 (macOS)` 시스템 행. 메뉴바 숫자에 세지 않음. 하위 메뉴는 끄는 방법 안내만 | 미확인(사용자 점검) | |
| Gradle 데몬 숨김 | 기본 숨김(숨김 수에 포함). 설정의 개발 도구 포트 표시를 켜면 `gradle daemon`으로 보임 | 미확인(사용자 점검) | |

## 성공 기준(스펙 2절)

| 시나리오 | 기대 제목·도구 | 결과 | 날짜 |
|---|---|---|---|
| 메뉴 지연 | 클릭 후 체감 지연 없음. Instruments Points of Interest의 `menuNeedsUpdate` 구간 100ms 이하 | 미확인(사용자 점검) | |
| 유휴 CPU | 거의 0% | 미확인(사용자 점검) |  |
| 메모리 | 30MB 이하(활성 상태 보기의 메모리 = 물리 풋프린트) | 미확인(사용자 점검) |  |

## 폴더 접근 허락(TCC)

계획 1 실험은 `~/Documents`만 확인했다. 폴더마다 아래 세 가지를 적는다: 허락 창이 그 폴더에 대해 한 번 뜨는지, 허락하면 프로젝트 이름이 제목인지, 거부하면 시작 폴더 이름이 제목인지.

| 시나리오 | 기대 제목·도구 | 결과 | 날짜 |
|---|---|---|---|
| `~/Desktop` 안 프로젝트 | 허락 창 한 번. 허락 → 프로젝트 이름, 거부 → 폴더 이름 | 미확인(사용자 점검) | |
| `~/Downloads` 안 프로젝트 | 허락 창 한 번. 허락 → 프로젝트 이름, 거부 → 폴더 이름 | 미확인(사용자 점검) | |
| iCloud Drive(`~/Library/Mobile Documents/com~apple~CloudDocs`) 안 프로젝트 | 별도 허락 창이 뜨는지와 어떤 권한으로 묶이는지 기록. 허락 → 프로젝트 이름, 거부 → 폴더 이름 | 미확인(사용자 점검) | |
| 업데이트마다 다시 묻는지 | 빌드 번호만 올린 새 ad-hoc 빌드로 바꾼 뒤 보호 폴더마다 허락 창이 다시 뜸(계획 1의 1.0→1.1 결과). 거부 시 폴더 이름으로 돌아감 | 미확인(사용자 점검) | |

## 배포 경로

| 시나리오 | 기대 제목·도구 | 결과 | 날짜 |
|---|---|---|---|
| `~/Downloads`에서 옮기지 않고 바로 실행 | App Translocation으로 실행되고 Sparkle이 업데이트를 거부함. 스펙 13.1절 안내와 맞음 | 미확인(사용자 점검, 계획 4 릴리스 뒤) | |
| Homebrew cask 설치 | 설치한 앱의 격리 표시 여부 기록, 첫 실행 절차가 13.1절과 맞음 | 미확인(사용자 점검, 계획 4 릴리스 뒤) | |
| `brew upgrade` 뒤 실행 | 앱이 열리고 폴더 허락을 다시 물음 | 미확인(사용자 점검, 계획 4 릴리스 뒤) | |
| Sparkle 업데이트 뒤 실행 | 새 버전이 설치·재실행되고 폴더 허락을 다시 물음 | 미확인(사용자 점검, 계획 4 릴리스 뒤) | |
