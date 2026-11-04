# 계획 1 실험 결과 (feasibility spike)

- 계획: `docs/plans/2026-11-04-01-feasibility-spike.md`
- 질문 번호: 스펙(`docs/specs/2026-11-04-doorplate-mvp-design.md`) 14절 표의 행 순서(1–9)
- 측정 기간: 2026-11-04 ~ 2026-11-05. macOS 27 arm64, Xcode 27.2, Swift 6.4.2
- 실험 앱: ad-hoc 서명, 샌드박스 없음, `LSUIElement` 메뉴바 앱(`ProbeApp`). 측정은 `open -n -W <앱> --args --probe-<이름> <출력.json>`으로 LaunchServices를 거쳐 띄운 GUI 조건에서 했다.
- 실험 코드: `spikes/`를 지우기 직전 커밋은 **`bd9a909`**(`bd9a90968f952a11078854efb6f987bddffeef93`)이다. 원본은 다음처럼 본다.

```sh
git show bd9a909:spikes/ProbeApp/Sources/ProbeLibproc.swift
git show bd9a909:spikes/ProbeApp/Sources/ProbeDocker.swift
```

## 요약 표

| 질문 | 결과(통과/실패/부분) | 근거(측정값, 명령, 관찰) | 결정 |
|---|---|---|---|
| 1. ad-hoc 서명 GUI 앱(샌드박스 없음)에서 libproc로 같은 사용자 프로세스의 소켓·cwd·argv를 읽을 수 있는가 | 통과 | `--probe-libproc`로 소켓, cwd, argv, 시작 시각, uid, ppid를 모두 읽음. 일반 사용자 `lsof -nP -iTCP -sTCP:LISTEN`과 대조해 빠진 사용자 포트 0개, 프로브에만 있는 포트 0개(두 번: 자동 측정 21개 포트, 수동 측정 (pid, 포트) 18/18) | 진행(Go). 계획 2로 간다 |
| 2. 전체 조회 시간 | 통과 | 프로세스 1,137개, 20회 중앙값 17.38ms, p95 31.51ms → 1,000개 환산 15.28ms / 27.71ms(기준 50ms). 이후 측정 1,118–1,141개에서 중앙값 약 17ms | 스펙 주기 그대로 |
| 3. ⌥ 대체 항목만 하위 메뉴가 없어도 되는가 | 통과 | 사용자 확인 5가지 모두 예. 로그 `alternate fired` 3회. 열린 메뉴에서 2초 타이머로 제목이 바뀌고 열린 하위 메뉴가 닫히지 않음 | 8.1절 ⌥ 종료 유지 |
| 4. root 소유 소켓이 보이는가 | 통과(기록) | 사용자가 직접 `sudo lsof -nP -iTCP -sTCP:LISTEN` 실행. (pid, 포트) 기준 root 19, 일반 18, 프로브 18. root로만 보이는 것은 8021 `launchd`(pid 1) 하나 | 7.1절 문구("다른 사용자(root) 소유 소켓은 보이지 않을 수 있다") 확정 |
| 5. GUI 앱에서 Docker 소켓 후보 경로로 접속되는가 | 통과 | Docker Desktop: `~/.docker/run/docker.sock` 연결, HTTP 200, chunked. OrbStack 2.2.5: `/var/run/docker.sock`(→ `~/.orbstack/run/docker.sock` 링크) 연결. 정지 204(0.17초 / 0.78초). 꺼진 상태는 네 후보 모두 `ENOENT` | 후보 순서 유지. 소켓 경로 입력란은 추가하지 않음 |
| 6. `~/Documents` 안 프로젝트의 파일 읽기(TCC) | 통과(업데이트마다 다시 물음) | 허락 창이 한 번 뜨고, 떠 있는 동안 파일 읽기가 블록됨(3초 제한에서 `pending`). 허락 → `read`. 거부 → 이후 즉시 `denied`, cwd·argv는 계속 읽힘. 1.0→1.1 업데이트 뒤 허락 창이 다시 뜸 | 파일 읽기는 메인 스레드 밖. 거부 시 폴더 이름(7.5절). 13.6절 조건은 충족했지만 Developer Program에 가입하지 않음(사용자 결정) |
| 7. 공유 소켓(prefork 서버) | 통과 | 리스너를 `fork`한 부모(27072)와 자식(27073)에 같은 `socketID` `0x9a6f1e5644d2e014`가 보임 | 7.2절 규칙 유지 |
| 8. `/Applications`에 설치한 ad-hoc 서명 앱의 Sparkle 업데이트 | 통과 | 실제 사용자 경로(브라우저 다운로드 → 압축 해제 → Finder로 응용 프로그램 폴더에 이동 → 차단 → "그래도 열기")에서 App Translocation 없이 실행, Check for Updates로 1.1 설치·재실행, `Signature=adhoc`, `codesign --verify --deep --strict` 통과, 업데이트 뒤 격리 속성 없음. Sparkle 2.10.1 | Sparkle 유지(13.3절 기본안). README·cask에 "응용 프로그램 폴더로 옮긴 뒤 실행" 명시 |
| 9. ad-hoc 서명 앱의 `SMAppService` 로그인 항목 | 통과 | 켜면 macOS 알림 "로그인 항목이 추가됨", 상태 `enabled`, `requiresApproval` 없음. 새 빌드(버전 올림)로 바꾼 뒤에도 `enabled`. 로그아웃·재로그인 뒤 자동 실행(PPID 1). 끄면 `notRegistered` | 로그인 항목 토글 유지(4절, 11절 변경 없음) |

## 질문 1, 2, 4, 7 — libproc (Task 2)

### 조회 시간

자동 측정(LaunchServices GUI 경로, 20회 전체 libproc/sysctl 조회, 파일 읽기와 JSON 쓰기는 시간에서 제외):

| 항목 | 값 |
|---|---|
| 프로세스 수 | 1,137 |
| 중앙값 | 17.38ms |
| p95 | 31.51ms |
| 1,000개 비례 환산 중앙값 | 15.28ms (17.38 × 1000 / 1137) |
| 1,000개 비례 환산 p95 | 27.71ms (31.51 × 1000 / 1137) |
| 기준 | 1,000개 기준 50ms 이하 → 통과 |

이후 수동 측정에서도 같은 범위였다.

| 측정 | 프로세스 수 | 중앙값 | p95 |
|---|---|---|---|
| TCC 첫 요청 | 1,118 | 17.5ms | 23.6ms |
| root 비교 | 1,120 | 16.99ms | 22.27ms |
| TCC 거부 | 1,141 | 17.35ms | 21.55ms |

마지막 스냅샷의 실패 호출 수(PID 수가 아니라 호출 수): `EPERM`(EACCES 포함) 768, `ESRCH` 8, 기타 258. 다른 사용자(root 등) 프로세스의 정보를 읽지 못한 것이며, 같은 사용자 리스너는 모두 읽혔다.

### 같은 사용자 리스너 대조

- 자동 측정: 일반 `lsof -nP -iTCP -sTCP:LISTEN`의 사용자 포트 21개와 프로브 포트 21개가 같았다. 빠진 포트 0개.
- 시험 서버 8765(`127.0.0.1`), 8766(`::1`)에서 주소, cwd, argv(`http.server`), 시작 시각, uid, `package.json` 읽기(`read`)를 확인했다.
- 수동 측정(root 비교 때): (pid, 포트) 기준 일반 lsof 18, 프로브 18. 일반 lsof에만 있는 것 0, 프로브에만 있는 것 0.

### argv

- 가장 긴 argv: **6,976바이트**(보이는 argv 문자열의 UTF-8 바이트와 각 NUL의 합. 실행 파일 경로 머리와 환경 변수는 제외). 버퍼는 `KERN_ARGMAX`로 정했다. 수백 KB짜리 JVM argv는 이 기기에 없어 확인하지 못했다.
- `argvShorterThanArgc`: **75개**. 프로세스가 제 argv를 고쳐 쓴 경우(제목 변경)로 보인다.

| 이름 | argc | 읽힌 개수 | 프로세스 수 | pid |
|---|---|---|---|---|
| node | 2 | 1 | 19 | 3749, 7279, 7311, 14397, 30693, 33832, 38548, 38591, 41519, 44667, 51999, 53739, 59803, 64116, 86486, 89072, 92251, 92286, 97097 |
| node | 3 | 1 | 22 | 3497, 7257, 7259, 7315, 14012, 30387, 33531, 38512, 38514, 38596, 41295, 44208, 51673, 53443, 59298, 63878, 86039, 88660, 92097, 92099, 92294, 96701 |
| node | 4 | 1 | 16 | 3498, 7258, 14009, 30390, 33530, 38513, 41300, 44206, 51672, 53447, 59301, 63889, 86032, 88661, 92098, 96700 |
| node | 5 | 1 | 17 | 3499, 4135, 7313, 14008, 30391, 33527, 38595, 41298, 44201, 51671, 53446, 59299, 63884, 86040, 88657, 92289, 96697 |
| open | 7 | 4 | 1 | 27075 |

주의: 프로브는 빈 argv 토큰(연속 NUL)에서 읽기를 끝낸다. 실제로 빈 문자열 인자를 받은 프로세스도 이 목록에 들어갈 수 있으므로, 이 목록만으로 제목 변경을 단정하지 않는다.

### sharedSockets (질문 7)

`127.0.0.1:8768`에 `listen`한 뒤 `fork`한 파이썬 서버:

```json
{ "port": 8768, "pids": [27072, 27073], "socketID": "0x9a6f1e5644d2e014" }
```

부모(ppid 1)와 자식(ppid 27072)에 같은 소켓 식별자(`psi.soi_so`)가 보였다. 7.2절의 공유 소켓 규칙을 그대로 쓴다.

### root로만 보이는 포트 (질문 4)

| 포트 | 프로세스 | pid | 소유자 |
|---|---|---|---|
| 8021 | launchd | 1 | root |

하나뿐이고 개발 서버가 아니다. 7.1절 문구를 바꾸지 않고 확정한다.

### Swift에서 직접 정의한 선언 (계획 2 Task 8이 그대로 쓴다)

Swift로 가져오지 못한 것은 `sys/proc_info.h`의 매크로 `PROC_PIDPATHINFO_MAXSIZE`(`(4*MAXPATHLEN)`) 하나다. 나머지 libproc 함수·구조체·상수(`proc_listallpids`, `proc_pidinfo`, `proc_pidfdinfo`, `PROC_PIDLISTFDS`, `PROC_PIDFDSOCKETINFO`, `socket_fdinfo` 등)는 `Darwin`에서 바로 가져왔다. 직접 다시 선언한 구조체나 함수는 없다.

```swift
// sys/proc_info.h: this expression macro is not imported into Swift.
private let PROC_PIDPATHINFO_MAXSIZE = 4 * MAXPATHLEN
```

## 질문 6 — TCC (`~/Documents`)

`~/Documents/doorplate-tcc-check`에서 띄운 서버(8767)를 대상으로 `--probe-libproc`을 실행했다. 프로브는 cwd마다 백그라운드에서 `package.json`을 실제로 열어 읽고, 약 3초 안에 끝나지 않으면 `pending`으로 적는다.

| 상황 | 관찰 |
|---|---|
| 허락 상태 초기화 뒤 첫 실행 | tccd `kTCCServiceSystemPolicyDocumentsFolder`, `AUTHREQ_PROMPTING` → 허락 창이 뜸. 창이 떠 있는 동안 파일 읽기가 **블록**되어 `pending`. 즉시 거부를 돌려주지 않고 응답을 기다린다 |
| "허용 안 함" 뒤 다시 실행 | 창 없이 즉시 `denied`. cwd·argv·시작 시각은 그대로 읽힘 |
| 초기화 뒤 "허용" | 창 없이 `read` |
| 같은 바이너리를 다른 위치에서 실행 | 이전 허락이 그대로 적용됨(tccd "Allowed (User Consent)") |
| Sparkle로 1.0 → 1.1 업데이트 뒤 | 허락 창이 **다시** 뜸(tccd "Auth Right: Unknown (None)"). ad-hoc 앱은 코드 해시로 식별되고, 새 빌드는 해시가 다르다 |

- 거부 때의 errno: 프로브는 `open`이 `ENOENT`·`ENOTDIR` 외의 오류로 실패하면 모두 `denied`로 묶었고 errno 값을 따로 남기지 않았다. TCC 거부는 `EPERM`(Operation not permitted) 계열이며, 계획 2는 `EPERM`과 `EACCES`를 모두 거부로 처리한다.
- 결론: 프로젝트 파일 읽기는 메인 스레드에서 하지 않는다(허락 창이 떠 있는 동안 블록된다). 거부되면 시작 폴더 이름으로 대신한다(7.5절). 업데이트마다 폴더별로 한 번씩 다시 묻는다 → 13.6절의 재검토 조건이 충족됐다(아래 사용자 결정 참고).
- `~/Documents`만 시험했다. `~/Desktop`, `~/Downloads`는 같은 방식(폴더마다 따로 묻기)으로 가정하고, iCloud Drive는 시험하지 않았다(미해결 항목).

## 질문 3 — ⌥ 대체 항목 (Task 3)

사용자 확인 결과(모두 예):

1. ⌥를 누르면 행이 대체 항목(종료)으로 바뀐다.
2. 대체 항목을 클릭하면 동작한다(로그 `alternate fired` 3회).
3. ⌥를 떼면 원래 행과 하위 메뉴로 돌아간다.
4. 키보드(↓, ⌥, Return)로도 동작한다.
5. 메뉴가 열린 채로 2초 타이머가 항목 제목을 바꾸고, 열어 둔 하위 메뉴는 닫히지 않는다.

→ 8.1절의 ⌥ 종료를 그대로 쓴다. 계획 3 Task 2의 갱신 방식(항목을 새로 만들지 않고 제목만 바꿈)도 근거가 생겼다.

## 질문 5 — Docker 소켓 (Task 4)

후보 순서: `~/.docker/run/docker.sock` → `/var/run/docker.sock` → `~/.orbstack/run/docker.sock` → `~/.colima/default/docker.sock`. AF_UNIX 논블로킹 connect, HTTP/1.1 `Connection: close`, 연결·읽기 전체 1초 제한.

### Docker Desktop

| 항목 | 값 |
|---|---|
| 연결된 경로 | `~/.docker/run/docker.sock` (connect ok, HTTP 200, 목록 요청 포함 17.95ms) |
| 나머지 후보 | 실행 중에도 파일 없음, `ENOENT`(errno 2) |
| chunked 응답 | 목록과 inspect 모두 `Transfer-Encoding: chunked`. 정지 응답은 chunked 아님 |
| 게시 포트 주인 프로세스 | `com.docker.backend`, 실행 파일 `/Applications/Docker.app/Contents/MacOS/com.docker.backend` |
| `Ports[].IP` | postgres 55432: `0.0.0.0`과 `::`로 같은 포트가 두 번 → 중복 제거가 필요하다. redis 56379: `127.0.0.1` |
| Compose 라벨 | `com.docker.compose.project`, `com.docker.compose.service`, `com.docker.compose.project.working_dir` 등 (샘플 참고) |
| 정지 | `POST /containers/{id}/stop?t=10` → HTTP 204, 0.17초 |
| 꺼진 상태(한 번도 안 켬, 종료 뒤) | 네 후보 모두 파일 없음, connect `ENOENT`(errno 2). 소켓 파일이 남지 않음. `ECONNREFUSED`나 시간 초과는 나오지 않았다 |
| 시작 시간 | `open -a Docker` 뒤 `docker info` 성공까지 5.0초. 종료 뒤 backend가 없어지기까지 17.9초 |

### OrbStack

| 항목 | 값 |
|---|---|
| 버전 | OrbStack 2.2.5(Homebrew cask), Docker 엔진 29.8.2 |
| 소켓 | 첫 실행이 `/var/run/docker.sock` → `~/.orbstack/run/docker.sock` 심볼릭 링크(root:daemon)를 만든다. 그래서 후보 2(`/var/run/docker.sock`)가 먼저 연결된다. `~/.orbstack/run/docker.sock`도 연결 ok |
| 응답 | HTTP 200, chunked. Compose 라벨 있음. postgres는 `0.0.0.0`과 `::`로 55432 두 번, redis는 `127.0.0.1:56379` |
| 게시 포트 주인 프로세스 | lsof COMMAND `OrbStack`, 실행 파일 `/Applications/OrbStack.app/Contents/Frameworks/OrbStack Helper.app/Contents/MacOS/OrbStack Helper`. 가장 바깥 `.app`은 `OrbStack`으로, 계획 2의 런타임 규칙과 맞는다 |
| 정지 | HTTP 204, 0.78초 |
| 종료 뒤 | `~/.orbstack/run/docker.sock`이 사라지고 `/var/run/docker.sock` 링크는 대상 없이 남는다 → connect `ENOENT`. 네 후보 모두 `ENOENT`라 "Docker 없음"으로 판정된다("응답 없음"이 아님) |

### 샘플

Docker Desktop 실행 중 원본 응답을 `docs/spikes/samples/`에 두었다. 사용자 이름이 든 경로는 `/Users/dev`로 바꿨다. 계획 2 Task 9의 Docker 테스트가 쓴다.

- `samples/docker-list.json`: `GET /containers/json` (postgres, redis)
- `samples/docker-inspect-postgres.json`: `GET /containers/{id}/json` (postgres)

## 질문 8 — Sparkle 업데이트 (Task 5)

### 실제 사용자 경로: 통과

1. 로컬 HTTP 서버의 `ProbeApp-1.0.zip`을 브라우저로 내려받음 → zip에 실제 격리 속성(`0081;…;<브라우저>;<이벤트 UUID>`)이 붙음.
2. Archive Utility로 압축 해제 → Finder로 응용 프로그램 폴더에 끌어다 놓음 → 더블클릭.
3. Gatekeeper 차단 창(아래) → [완료] → 시스템 설정 > 개인정보 보호 및 보안 > "그래도 열기" → 암호 또는 Touch ID → "그래도 열기".
4. 실행 경로 `/Applications/ProbeApp.app`(`bundlePath`). App Translocation 없음(로그에도 번역 기록 없음).
5. Check for Updates → 거부 없이 1.1 설치·재실행. 업데이트 뒤 `Signature=adhoc`, `codesign --verify --deep --strict` 통과, 격리 속성 없음(`com.apple.provenance`만).

Gatekeeper 차단 창(한국어):

- 제목: "'ProbeApp.app'을(를) 열지 않음"
- 본문: "Apple은 'ProbeApp.app'에 사용자의 Mac에 손상을 입히거나 사용자의 개인 정보에 침입할 수 있는 악성 코드가 없음을 확인할 수 없습니다."
- 버튼: [휴지통으로 이동] [완료]. "휴지통으로 이동"을 누르면 앱이 휴지통으로 간다(실험 중 한 번 일어남).

### 앞서 본 거짓 실패와 원인

처음에는 격리 속성을 명령으로 직접 붙이고(`xattr -w com.apple.quarantine "0081;<시간>;Safari;"`) `ditto`로 `/Applications`에 설치했다. 차단 창과 "그래도 열기"는 똑같이 나왔지만, 승인 뒤에도(격리 속성 `0081` → `00c1`) 앱은 계속 App Translocation 경로(`/private/var/folders/.../AppTranslocation/.../d/ProbeApp.app`)에서 실행됐다. 스크립트로 Finder 이동을 시키거나 사용자가 Finder로 직접 옮겨도 풀리지 않았다. 이 상태에서 Sparkle은 다음 메시지로 업데이트를 거부했다.

> ProbeApp can't be updated if it's running from the location it was downloaded to. Quit ProbeApp, move it into your Applications folder, relaunch it from there and try again.

원인: 명령으로 붙인 격리 속성과 `ditto` 설치는 macOS가 "사용자가 옮긴 앱"으로 보지 않아 번역 경로에 묶였다. 실제 다운로드 → Finder 이동 경로에서는 재현되지 않았다. 격리 속성을 지운(`xattr -dr com.apple.quarantine`) 설치에서도 업데이트는 동작했다.

→ README와 cask 안내에 "처음 열기 전에 응용 프로그램 폴더로 옮긴다"를 적는다. 다운로드 폴더에서 바로 실행하면 번역 경로가 된다고 가정한다(시험하지 않음).

### Sparkle 버전과 경고

- 실제로 받은 버전: **Sparkle 2.10.1**. 계획 3은 `exactVersion: 2.10.1`로 고정한다.
- `LSUIElement` 앱에서 Sparkle이 경고를 남긴다: "Background app automatically schedules for update checks but does not implement gentle reminders". 계획 3 Task 6에서 gentle reminders(`SPUStandardUserDriverDelegate`)를 구현하거나 경고를 받아들이기로 정한다.
- 같은 위치(`~/Documents` 아래)에 둔 개발 빌드를 업데이트할 때는 Sparkle 설치 도우미가 `~/Documents` 접근 허락을 따로 요청했다. `/Applications` 설치에서는 해당 없다.

## 질문 9 — 로그인 항목 (Task 6)

1. `/Applications`에 2.0 설치(격리 없음)·실행 → Open at Login 켬 → macOS 알림 "로그인 항목이 추가됨", `SMAppService.mainApp.status == .enabled`, `requiresApproval` 없음.
2. 2.1(버전만 올린 새 빌드, 새 코드 해시)로 바꿈 → 상태 `enabled`, 체크 유지. 다시 승인할 필요 없음.
3. 로그아웃·재로그인 → 2.1이 `/Applications/ProbeApp.app`에서 PPID 1로 자동 실행됨.
4. 끔 → `notRegistered`.

→ `SMAppService` 토글을 그대로 쓴다(스펙 4절, 11절 변경 없음).

## 진행 판단 (Task 7 Step 2)

질문 1이 통과했으므로 **진행(Go)** 한다. 나머지 질문도 모두 통과해 스펙의 대안으로 갈 곳은 없다. 계획 2(Core)를 시작한다.

## 사용자 결정 (2026-11-05)

| 결정 | 내용 |
|---|---|
| 진행 | 계획 2로 간다 |
| Sparkle | 유지(13.3절 기본안). README·cask에 "응용 프로그램 폴더로 옮긴 뒤 열기"를 적는다 |
| Apple Developer Program | **가입하지 않는다.** 13.6절의 재검토 조건("업데이트할 때마다 폴더 접근 허락을 다시 묻는 것")은 충족됐지만, 영향은 업데이트마다 보호 폴더당 허락 창 한 번이고 거부해도 폴더 이름으로 대신하므로 작다고 판단했다 |
| 로그인 항목 | `SMAppService` 토글 유지 |
| ⌥ 종료 | 유지(8.1절) |

## 참고: 실행 방법에 관한 관찰

`open -n -W <앱> --args …`는 프로브의 종료 코드를 돌려주지 않고, LaunchServices가 `Unable to block on application`을 출력할 수 있다. 성공 여부는 프로브가 쓴 JSON 파일(생성, 파싱, 필드)로 판단했다.

## 미해결 항목

| 항목 | 넘기는 곳 |
|---|---|
| `~/Desktop`, `~/Downloads`, iCloud Drive 안 프로젝트의 TCC 동작(폴더마다 따로 묻는지, iCloud Drive가 어떤 권한으로 묶이는지) | 릴리스 전 수동 점검표 |
| Homebrew cask로 설치하면 격리 속성이 남는지, 그때 "그래도 열기"와 Sparkle 업데이트가 되는지 | 계획 4 Task 6 |
| 다운로드 폴더에서 바로 실행했을 때 App Translocation과 Sparkle 거부(가정만 함) | 계획 4 Task 6, README 안내 |
| 수백 KB짜리 JVM argv | 계획 2 Task 8 테스트 |
