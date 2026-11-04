# 계획 1: 실현 가능성 실험

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 스펙 14절의 아홉 질문에 실제 기기로 답하고, 그 답을 결과 문서와 스펙에 반영한다. 질문 번호는 14절 표의 행 순서(1 libproc 조회, 2 조회 시간, 3 ⌥ 대체 항목, 4 root 소켓, 5 Docker 소켓, 6 TCC, 7 공유 소켓, 8 Sparkle, 9 로그인 항목)를 따른다.

**Architecture:** XcodeGen으로 만든 버리는 메뉴바 앱 `ProbeApp` 하나를 ad-hoc 서명해서 실행한다. 이 앱은 `--probe-*` 인자를 받으면 측정을 하고 JSON을 쓴 뒤 끝나고, 인자가 없으면 메뉴바에 떠서 메뉴·업데이트·로그인 항목을 손으로 확인하게 한다. 이렇게 하면 실제 앱과 같은 조건(LaunchServices로 실행된 GUI 앱, 샌드박스 없음, ad-hoc 서명)에서 측정할 수 있다.

**Tech Stack:** Swift 6.4, Xcode 27.2, XcodeGen, Sparkle 2(SPM), Docker Desktop.

**Spec:** `docs/specs/2026-11-04-doorplate-mvp-design.md` (특히 7.1, 7.4, 8.1, 13.3, 14절)

## Global Constraints

- 브랜치는 `spike/feasibility`이다. 실험 코드는 `spikes/` 아래에만 둔다. 마지막 Task에서 `spikes/`를 지우고, 결과 문서와 샘플만 남긴다.
- 번들 ID와 로그 subsystem은 `io.github.junjuny0227.doorplate.probe`이다.
- 서명은 ad-hoc(`CODE_SIGN_IDENTITY=-`)이고 App Sandbox와 Hardened Runtime은 끈다. 배포 대상은 macOS 14.0이다.
- 관리자 권한을 쓰지 않는다. Task 2의 비교용 `sudo lsof`만 예외이며, 사용자가 직접 실행한다.
- 시그널은 실험이 직접 띄운 프로세스에만 보낸다.
- Sparkle EdDSA 비밀 키는 출력하거나 커밋하지 않는다. 실험이 끝나면 키체인에서 지운다.
- Docker 실험은 Compose 프로젝트 이름 `doorplate-spike`, 호스트 포트 `55432`(postgres)와 `56379`(redis)를 쓴다. 끝나면 `down -v`로 정리한다.
- 측정 결과 JSON은 `spikes/out/`에 쓰고 커밋하지 않는다. 경로와 명령줄이 들어 있기 때문이다.
- Sparkle과 로그인 항목 실험은 실제 사용자와 같은 `/Applications/ProbeApp.app`에서 한다. 관리자 계정이면 `sudo` 없이 쓸 수 있다. 끝나면 지운다.
- 로그는 `Logger(subsystem: "io.github.junjuny0227.doorplate.probe", category: <프로브 이름>)`로 남긴다.
- OrbStack은 설치되어 있을 때만 확인한다. 스펙 14절은 Docker Desktop만 필수로 둔다.

## Review Focus

- `::1`에만 바인드한 서버(Node 17 이상의 vite 기본값)는 IPv4 서버와 똑같이 잡혀야 한다. → Task 2에서 `::1` 리스너를 띄워 확인
- 조회 도중 끝난 프로세스(ESRCH)와 다른 사용자 프로세스(EPERM) 때문에 프로브가 죽거나 전체 결과가 비면 안 된다. → Task 2에서 오류 종류별로 개수를 기록
- 클래스패스가 수백 KB인 Java 명령줄도 잘리지 않고 읽혀야 한다. → Task 2에서 `KERN_ARGMAX` 크기 버퍼를 쓰고, 가장 긴 argv의 길이를 기록
- Docker Desktop을 끈 뒤 소켓 파일만 남은 상태는 "응답 없음"이 아니라 "Docker 없음"으로 보여야 한다. → Task 4에서 끈 상태의 오류 종류(ENOENT/ECONNREFUSED/시간 초과)를 기록
- Sparkle 실험이 실제 사용자 경로를 흉내 내야 한다. 처음 설치한 v1에는 격리 표시가 있고, `/Applications`에서 "그래도 열기"로 승인한 뒤 업데이트한다. 업데이트 뒤 폴더 접근 허락(TCC)을 다시 묻는지도 본다. → Task 5에서 v1에 격리 속성을 붙이고 시작
- `~/Documents` 안의 프로젝트는 파일을 읽을 때 TCC 허락 창이 뜬다. 임시 폴더(`/var/folders`)로만 시험하면 이 문제를 놓친다. → Task 2 Step 2에서 `~/Documents`의 서버를 함께 띄움

---

### Task 1: 실험 앱 뼈대

**Files:**
- Create: `spikes/ProbeApp/project.yml`
- Create: `spikes/ProbeApp/Sources/main.swift`, `spikes/ProbeApp/Sources/AppDelegate.swift`
- Create: `spikes/ProbeApp/Info.plist`
- Create: `spikes/.gitignore` (`*.xcodeproj/`, `out/`, `build/`, `.spm/`, `updates/`)

**Interfaces:**
- Produces: `ProbeApp.app`. 인자가 없으면 메뉴바 아이콘 "P"와 메뉴(`Quit`)를 띄운다. `--probe-<name> <출력 경로>`로 실행하면 해당 프로브를 돌리고 JSON을 쓴 뒤 종료 코드 0으로 끝낸다. 프로브는 `[String: (URL) async throws -> Void]` 표에 등록하고, 이후 Task가 여기에 추가한다.
- 빌드 명령(이후 Task 공통): `cd spikes/ProbeApp && xcodegen generate && xcodebuild -project ProbeApp.xcodeproj -scheme ProbeApp -configuration Release -derivedDataPath build -clonedSourcePackagesDirPath .spm CODE_SIGN_IDENTITY=- build`
- 실행 명령: `open -n -W spikes/ProbeApp/build/Build/Products/Release/ProbeApp.app --args --probe-<name> "$PWD/spikes/out/<name>.json"`

- [ ] **Step 1: 브랜치와 도구 준비**

Run: `git switch -c spike/feasibility && brew install xcodegen && xcodegen --version`
Expected: 버전이 출력된다.

- [ ] **Step 2: `project.yml`과 Info.plist 작성**

target 하나(`ProbeApp`, type application, platform macOS, deploymentTarget 14.0)로 만든다. 설정은 `PRODUCT_BUNDLE_IDENTIFIER=io.github.junjuny0227.doorplate.probe`, `CODE_SIGN_IDENTITY=-`, `ENABLE_HARDENED_RUNTIME=NO`, `SWIFT_VERSION=6.0`이다. entitlements는 두지 않는다(샌드박스 없음). Info.plist에는 `LSUIElement=true`와 `CFBundleShortVersionString=1.0`, `CFBundleVersion=1`을 넣는다.

- [ ] **Step 3: `main.swift`와 `AppDelegate` 작성**

`main.swift`는 `CommandLine.arguments`에서 `--probe-<name> <path>`를 찾는다. 찾으면 등록된 프로브를 실행하고 `exit(0)`, 실패하면 오류를 stderr에 쓰고 `exit(1)`한다. 찾지 못하면 `NSApplication`을 띄운다.

- [ ] **Step 4: 빌드와 서명 확인**

Run: 위 빌드 명령, 이어서 `codesign -dv spikes/ProbeApp/build/Build/Products/Release/ProbeApp.app 2>&1 | grep Signature`
Expected: `** BUILD SUCCEEDED **`, `Signature=adhoc`

- [ ] **Step 5: 실행 확인**

Run: `open spikes/ProbeApp/build/Build/Products/Release/ProbeApp.app`
Expected: 메뉴바에 "P"가 나타나고, Dock 아이콘은 없다. `Quit`으로 끝난다.

- [ ] **Step 6: Commit**

```bash
git add spikes/
git commit -m "chore(spike): add the probe app skeleton"
```

### Task 2: libproc 조회, 조회 시간, root 소켓, TCC, 공유 소켓 (질문 1, 2, 4, 6, 7)

**Files:**
- Create: `spikes/ProbeApp/Sources/ProbeLibproc.swift`

**Interfaces:**
- Consumes: Task 1의 프로브 표
- Produces: `--probe-libproc <path>`. 출력 JSON 모양은 다음과 같다.
  ```json
  { "processCount": 812, "runs": 20, "medianMs": 0.0, "p95Ms": 0.0,
    "errors": { "EPERM": 0, "ESRCH": 0, "other": 0 },
    "missingSymbols": [],
    "longestArgvBytes": 0,
    "argvShorterThanArgc": [ { "pid": 1, "name": "", "argc": 0, "read": 0 } ],
    "sharedSockets": [ { "socketID": "0x…", "pids": [1, 2] } ],
    "listeners": [ { "pid": 1, "port": 1, "address": "::1", "socketID": "0x…", "name": "", "path": "",
                     "cwd": "", "argv": [""], "ppid": 1, "uid": 501, "startedAt": "ISO8601",
                     "packageJSON": "read|denied|absent" } ] }
  ```
  `packageJSON`은 앱이 `<cwd>/package.json`을 읽어 본 결과다(TCC 확인용).

- [ ] **Step 1: 프로브 구현**

`proc_listallpids` → pid마다 `proc_pidinfo(PROC_PIDLISTFDS)` → 소켓 fd마다 `proc_pidfdinfo(PROC_PIDFDSOCKETINFO)`로 읽는다. `soi_kind == SOCKINFO_TCP`이고 `tcpsi_state == TSI_S_LISTEN`인 것만 남긴다.
- 포트: `UInt16(bigEndian: UInt16(truncatingIfNeeded: insi_lport))`
- 주소: `insi_vflag`의 IPv6 비트(`INI_IPV6`)를 먼저 본다. `::`에 바인드한 소켓은 두 비트가 모두 켜져 있다.
- 소켓 식별자: `psi.soi_so`. 같은 값이 여러 pid에 나오면 `sharedSockets`에 기록한다.
- argv: `KERN_PROCARGS2`에서 읽힌 인자 수가 argc보다 적으면 `argvShorterThanArgc`에 기록한다(프로세스 제목을 바꾸는 프로그램).
- 프로세스 정보: `PROC_PIDTBSDINFO`(이름, ppid, uid, 시작 시각 `pbi_start_tvsec`/`pbi_start_tvusec`), `proc_pidpath`, `PROC_PIDVNODEPATHINFO`(cwd `pvi_cdir`), `sysctl([CTL_KERN, KERN_PROCARGS2, pid])`. 버퍼 크기는 `KERN_ARGMAX`로 정한다.
- Swift에서 가져오지 못한 상수나 함수는 직접 정의하고, 그 이름을 `missingSymbols`에 기록한다.
- 전체 조회를 20번 반복해 중앙값과 p95(ms)를 잰다.

- [ ] **Step 2: 확인용 서버 띄우기**

Run:
```bash
d=$(mktemp -d) && echo '{"name":"spike-site"}' > "$d/package.json" && cd "$d" \
  && (python3 -m http.server 8765 --bind 127.0.0.1 & python3 -m http.server 8766 --bind ::1 &) ; cd -
mkdir -p ~/Documents/doorplate-tcc-check && echo '{"name":"tcc-check"}' > ~/Documents/doorplate-tcc-check/package.json \
  && (cd ~/Documents/doorplate-tcc-check && python3 -m http.server 8767 --bind 127.0.0.1 &)
python3 -c 'import socket,os,time; s=socket.socket(); s.bind(("127.0.0.1",8768)); s.listen(); os.fork(); time.sleep(600)' &
```
Expected: 서버 네 개가 백그라운드에서 뜬다. 8768은 부모와 자식이 같은 소켓을 갖는다.

- [ ] **Step 3: 프로브 실행**

Run: 빌드 명령, 이어서 실행 명령(`libproc`), 이어서 `jq '{processCount, medianMs, p95Ms, errors, missingSymbols, longestArgvBytes, n: (.listeners|length)}' spikes/out/libproc.json`
Expected:
- `listeners`에 8765(`127.0.0.1`)와 8766(`::1`)이 있다. 둘 다 cwd가 `$d`이고, argv에 `http.server`가 있고, `startedAt`이 있고, `packageJSON == "read"`이다.
- 8767을 처음 조회할 때 "ProbeApp이 문서 폴더의 파일에 접근하려고 합니다" 창이 뜨는지, 뜨는 동안 프로브가 기다리는지 아니면 바로 `denied`를 돌려주는지 기록한다. 허락한 뒤 다시 실행하면 `read`여야 한다. 거부했을 때 libproc의 cwd 읽기는 여전히 되는지도 기록한다.
- `sharedSockets`에 8768의 pid 두 개가 같은 `socketID`로 있다.

- [ ] **Step 4: root 소켓 비교 (사용자 실행)**

사용자에게 `! sudo lsof -nP -iTCP -sTCP:LISTEN > spikes/out/lsof-root.txt` 실행을 부탁한다. 이어서 `lsof -nP -iTCP -sTCP:LISTEN > spikes/out/lsof-user.txt`를 실행한다.
그다음 세 목록을 비교해 "root만 보이는 포트"(포트, 프로세스 이름, 소유자)와 "프로브에 빠진 사용자 포트"를 적는다. 빠진 사용자 포트가 0개여야 질문 1을 통과한다.

- [ ] **Step 5: 확인용 서버 정리**

Run: `pkill -f 'http.server 876[567]'; pkill -f 'bind\(\("127.0.0.1",8768\)\)'; rm -r ~/Documents/doorplate-tcc-check`
Expected: 실험이 띄운 서버만 종료된다. TCC 허락 상태는 `tccutil reset SystemPolicyDocumentsFolder io.github.junjuny0227.doorplate.probe`로 지워 Task 5에서 다시 쓴다.

- [ ] **Step 6: Commit**

```bash
git add spikes/ProbeApp/Sources/ProbeLibproc.swift
git commit -m "chore(spike): probe listening sockets with libproc"
```

### Task 3: ⌥ 대체 항목 (질문 3)

**Files:**
- Modify: `spikes/ProbeApp/Sources/AppDelegate.swift`

**Interfaces:**
- Produces: 메뉴에 항목 두 개를 추가한다.
  - `row`: 제목 `5173  sample`, 하위 메뉴에 `Open`과 `Stop`. action은 없다.
  - `alt`: 제목 `Stop 5173 sample`, `isAlternate = true`, `keyEquivalentModifierMask = [.option]`, `keyEquivalent = ""`, 하위 메뉴 없음. action은 `Logger(subsystem: "io.github.junjuny0227.doorplate.probe", category: "menu").info("alternate fired")`.
  - 메뉴가 열린 동안에도 `.common` 모드 2초 타이머가 `row`의 제목 뒤 숫자를 바꾼다. 열린 메뉴에서 제목이 바뀌는지, 하위 메뉴가 열린 채 유지되는지 함께 본다.

- [ ] **Step 1: 메뉴 항목 추가 후 빌드, 앱 실행**

- [ ] **Step 2: 수동 확인 (사용자와 함께)**

Run: `log stream --predicate 'subsystem == "io.github.junjuny0227.doorplate.probe"' --style compact`를 켜 둔다.
확인할 것:
1. 메뉴를 열고 ⌥를 누르면 `row`가 `alt`로 바뀐다.
2. `alt`를 클릭하면 로그에 `alternate fired`가 찍힌다.
3. ⌥를 떼면 `row`로 돌아오고, 하위 메뉴가 열린다.
4. 키보드(↓, ⌥, Return)로도 같은 동작이 된다.
5. 메뉴를 연 채로 두면 `row` 제목의 숫자가 2초마다 바뀌고, 하위 메뉴를 연 상태에서도 닫히지 않는다.

Expected: 다섯 가지 모두 되면 통과다. 하나라도 안 되면 어떻게 동작했는지 적는다.

- [ ] **Step 3: Commit**

```bash
git add spikes/ProbeApp/Sources/AppDelegate.swift
git commit -m "chore(spike): try an option-key alternate menu item"
```

### Task 4: Docker 소켓 (질문 5)

**Files:**
- Create: `spikes/ProbeApp/Sources/ProbeDocker.swift`
- Create: `spikes/docker/compose.yaml`

**Interfaces:**
- Produces: `--probe-docker <path>`. 후보 경로를 차례로 시도한다: `~/.docker/run/docker.sock`, `/var/run/docker.sock`, `~/.orbstack/run/docker.sock`, `~/.colima/default/docker.sock`. 경로마다 `{path, exists, connect: "ok"|"ENOENT"|"ECONNREFUSED"|"timeout"|"<errno>", status, ms}`를 기록한다. 처음 성공한 경로에 `GET /containers/json`을 보내고, 실행 중인 컨테이너마다 `GET /containers/{id}/json`을 보낸다. 원본 응답은 `spikes/out/docker-list.json`, `spikes/out/docker-inspect-<서비스>.json`에 쓴다.
- 연결은 POSIX `socket(AF_UNIX, SOCK_STREAM)`을 논블로킹으로 `connect`하고, `poll`로 시간 제한을 건다. 요청은 `GET <경로> HTTP/1.1\r\nHost: docker\r\nConnection: close\r\n\r\n`이고, 시간 제한은 1초다. 응답 헤더에 `Transfer-Encoding: chunked`가 있었는지도 기록한다.
- `--probe-docker-stop <path>`: `doorplate-spike` 프로젝트의 redis 컨테이너에 `POST /containers/{id}/stop?t=10`을 보내고 응답 코드와 걸린 시간을 기록한다(시간 제한 15초).
- `compose.yaml`: `postgres:16-alpine`(환경 변수 `POSTGRES_PASSWORD=spike`, `55432:5432`)과 `redis:7-alpine`(`127.0.0.1:56379:6379`, 이 기기만 노출되는 경우 확인용).

- [ ] **Step 1: 프로브와 compose 파일 작성 후 빌드**

- [ ] **Step 2: Docker Desktop 켠 상태에서 측정 (사용자가 Docker Desktop 실행)**

Run: `docker compose -f spikes/docker/compose.yaml -p doorplate-spike up -d && sleep 5`, 이어서 실행 명령(`docker`)
Expected: Docker Desktop 경로가 `connect: ok`이다. `docker-list.json`에 `com.docker.compose.project=doorplate-spike` 라벨과 `PublicPort` 55432, 56379가 있다.

- [ ] **Step 3: 포트 주인 확인**

Run: `lsof -nP -iTCP:55432 -sTCP:LISTEN`
Expected: 포트 주인이 Docker 런타임 프로세스이고 컨테이너가 아니다. 그 프로세스 이름과 실행 파일 경로를 기록한다. 스펙 7.4절의 "게시 포트 집합으로 바꾼다"는 규칙과 7.5절의 런타임 규칙이 필요한 근거다. `docker-list.json`의 redis `Ports[].IP`가 `127.0.0.1`인지도 기록한다.

Run: 실행 명령(`docker-stop`)
Expected: 204, 걸린 시간(초)을 기록한다. 1초보다 길면 스펙 7.4절의 정지 시간 제한 15초가 필요한 근거다.

- [ ] **Step 4: Docker Desktop을 끈 상태에서 측정**

Run: `docker compose -f spikes/docker/compose.yaml -p doorplate-spike down -v`. 사용자가 Docker Desktop을 종료한 뒤 실행 명령(`docker`)을 다시 돌린다. 결과는 `docker-stopped.json`에 쓴다.
Expected: 소켓 파일이 남는지, 연결 오류 종류가 무엇인지(ENOENT, ECONNREFUSED, 시간 초과) 기록된다.

- [ ] **Step 5: OrbStack**

이 기기에는 OrbStack이 없다. 사용자에게 설치해서 같은 측정(Step 2)을 할지 묻는다. 설치하지 않으면 결과 문서에 "OrbStack 미확인, 12.5절 수동 점검표로 넘김"이라고 적는다.

- [ ] **Step 6: Commit**

```bash
git add spikes/ProbeApp/Sources/ProbeDocker.swift spikes/docker/compose.yaml
git commit -m "chore(spike): probe Docker sockets"
```

### Task 5: ad-hoc 서명 앱의 Sparkle 업데이트 (질문 8, 업데이트 뒤 질문 6)

**Files:**
- Modify: `spikes/ProbeApp/project.yml` (패키지 `Sparkle`: `https://github.com/sparkle-project/Sparkle`, `from: 2.6.0`)
- Modify: `spikes/ProbeApp/Info.plist` (`SUFeedURL=http://127.0.0.1:8777/appcast.xml`, `SUPublicEDKey=<공개 키>`, `NSAppTransportSecurity.NSAllowsLocalNetworking=true`)
- Modify: `spikes/ProbeApp/Sources/AppDelegate.swift` (`SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)`, 메뉴 `Check for Updates…`, 메뉴에 현재 버전과 `Bundle.main.bundlePath` 표시, 메뉴 `Read ~/Documents file`: `~/Documents/doorplate-tcc-check/package.json`을 읽고 결과(`read`/`denied`)를 메뉴 제목에 표시)

**Interfaces:**
- Sparkle 도구는 `spikes/ProbeApp/.spm/artifacts/sparkle/Sparkle/bin/`(`generate_keys`, `sign_update`, `generate_appcast`)에 있다. 경로가 다르면 `find spikes/ProbeApp/.spm -name generate_keys`로 찾는다.
- 실험용 appcast와 zip은 `spikes/updates/`에 둔다(커밋하지 않음).

- [ ] **Step 1: 실험용 키 만들기**

`generate_keys -h`로 계정 옵션 이름을 확인한 뒤, 계정 `doorplate-spike`로 키를 만든다. 공개 키만 Info.plist에 넣는다. 비밀 키는 출력하지 않는다.

- [ ] **Step 2: v1과 v2 빌드**

v1(`1.0`/`1`)을 빌드해 `ditto`로 `/Applications/ProbeApp.app`에 복사한다. 이어서 v2(`1.1`/`2`)를 빌드한다. v2는 `ditto -c -k --keepParent`로 `spikes/updates/ProbeApp-1.1.zip`에 압축한다. 그다음 `generate_appcast --account doorplate-spike spikes/updates`를 실행한다.

- [ ] **Step 3: v1을 다운로드한 앱처럼 만들기**

Run: `xattr -w com.apple.quarantine "0081;$(printf %x $(date +%s));Safari;" /Applications/ProbeApp.app && open /Applications/ProbeApp.app`
Expected: Gatekeeper가 실행을 막는다. 사용자가 시스템 설정 > 개인정보 보호 및 보안에서 "그래도 열기"로 승인하는 절차를 그대로 기록한다. 실행된 뒤 메뉴에 보이는 `bundlePath`가 `/Applications/ProbeApp.app`인지, App Translocation 경로(`/private/var/folders/.../AppTranslocation/...`)인지 기록한다.

`~/Documents/doorplate-tcc-check/package.json`을 다시 만들고 메뉴의 `Read ~/Documents file`을 누른다. 허락 창이 뜨면 허락하고, 결과가 `read`인지 확인한다.

- [ ] **Step 4: 업데이트**

Run: `(cd spikes/updates && python3 -m http.server 8777 --bind 127.0.0.1 &)`. 사용자가 메뉴의 `Check for Updates…`로 업데이트를 설치하고 다시 실행한다.
Expected: 메뉴에 `1.1`이 보이고, 실행이 막히지 않는다. `xattr -l /Applications/ProbeApp.app`과 `codesign -dv /Applications/ProbeApp.app`의 결과, Sparkle이 보인 오류 문구가 있으면 그것까지 기록한다. 업데이트 뒤 `Read ~/Documents file`을 다시 눌러 허락 창이 다시 뜨는지 기록한다(스펙 13.6절 재검토 조건). 실제로 받은 Sparkle 버전(`spikes/ProbeApp/.spm/workspace-state.json` 또는 빌드 로그)도 기록한다. 계획 3이 이 버전을 `exactVersion`으로 고정한다.

- [ ] **Step 5: 정리**

`pkill -f 'http.server 8777'`로 서버를 끈다. 앱을 종료한다. 앱은 Task 6에서 다시 쓰므로 지우지 않는다. `~/Documents/doorplate-tcc-check`는 지운다. `security delete-generic-password -s "https://sparkle-project.org" -a doorplate-spike`로 키를 지운다. 서비스 이름이 다르면 키체인 접근 앱에서 계정 `doorplate-spike` 항목을 찾아 지운다.

- [ ] **Step 6: Commit**

```bash
git add spikes/ProbeApp
git commit -m "chore(spike): try Sparkle updates on an ad-hoc signed app"
```

### Task 6: ad-hoc 서명 앱의 로그인 항목 (질문 9)

**Files:**
- Modify: `spikes/ProbeApp/Sources/AppDelegate.swift` (메뉴 `Open at Login` 토글: `SMAppService.mainApp.register()`/`unregister()`, 메뉴에 `SMAppService.mainApp.status` 표시)

- [ ] **Step 1: 구현 후 빌드, `/Applications`에 복사해 실행, 토글 켜기**

Expected: 상태가 `.enabled`이다. `.requiresApproval`이면 그 사실과 시스템 설정 > 일반 > 로그인 항목에서 승인하는 절차를 기록한다.

이어서 버전만 올린 새 빌드로 `/Applications/ProbeApp.app`을 바꾼 뒤(업데이트 흉내), 다시 실행해 `SMAppService.mainApp.status`를 기록한다.

- [ ] **Step 2: 재로그인 확인 (사용자)**

사용자가 로그아웃했다가 다시 로그인한 뒤 `pgrep -fl ProbeApp`을 실행한다.
Expected: 프로세스가 있다.

- [ ] **Step 3: 정리**

토글을 끄고 상태가 `.notRegistered`인지 확인한다. 앱을 지운다.

- [ ] **Step 4: Commit**

```bash
git add spikes/ProbeApp/Sources/AppDelegate.swift
git commit -m "chore(spike): try SMAppService login item"
```

### Task 7: 결과 기록, 스펙 반영, 실험 코드 삭제

**Files:**
- Create: `docs/spikes/01-feasibility.md`
- Create: `docs/spikes/samples/docker-list.json`, `docs/spikes/samples/docker-inspect-postgres.json` (Task 4 원본에서 사용자 이름이 든 경로를 `/Users/dev`로 바꾼 것)
- Modify: `docs/specs/2026-11-04-doorplate-mvp-design.md`
- Delete: `spikes/`

- [ ] **Step 1: 결과 문서 작성**

질문마다 한 행씩 쓴다. 열은 `질문 | 결과(통과/실패/부분) | 근거(측정값, 명령, 관찰) | 결정`이다. 다음 내용도 함께 적는다.
- Task 2: 프로세스 수, 중앙값, p95. 성공 기준은 1,000개 기준 50ms이므로, 실제 프로세스 수로 비례 환산한 값도 적는다.
- Task 2: 가장 긴 argv 크기, `argvShorterThanArgc` 목록, `sharedSockets` 결과, root만 보이는 포트 목록, TCC 허락 창의 동작(기다림 또는 즉시 거부)과 거부 때의 errno.
- Task 2: Swift에서 가져오지 못해 직접 정의한 상수·구조체·함수의 **선언 전체**를 코드 블록으로 옮긴다. 계획 2 Task 8이 그대로 쓴다.
- Task 3: ⌥ 대체 항목 결과와, 열린 메뉴의 제목 갱신·하위 메뉴 유지 결과.
- Task 4: Docker 런타임 프로세스 이름과 실행 파일 경로, chunked 응답 여부, 꺼진 상태의 오류 종류, `Ports[].IP`, 정지 응답 시간.
- Task 5, 6: 사용자가 실제로 거친 승인 절차, `bundlePath`(App Translocation 여부), 업데이트 뒤 TCC 재요청 여부, 새 빌드로 바꾼 뒤 로그인 항목 상태, 실제로 받은 Sparkle 버전.
- 실험 코드를 지우기 직전 커밋의 sha를 적는다. 이후 계획은 `git show <sha>:spikes/ProbeApp/Sources/ProbeLibproc.swift`처럼 원본을 볼 수 있다.

- [ ] **Step 2: 갈지 말지 판단**

질문 1이 실패하면 여기서 멈추고, 사용자와 설계를 다시 논의한다. 나머지 질문이 실패하면 스펙에 적힌 대안을 그대로 고른다.

- [ ] **Step 3: 스펙 반영**

- 7.1절: root 소켓 문구를 확정한다.
- 7.2절: 공유 소켓 규칙이 실제 결과와 맞는지.
- 7.4절: 실제 소켓 경로, 꺼진 상태의 오류 종류, 정지 시간 제한.
- 7.5절: 런타임 프로세스 목록에 실제 이름이 들어 있는지, TCC 거부 때의 동작.
- 8.1절: ⌥ 결과.
- 13.1절, 13.3절: TCC 재요청 여부, Sparkle을 쓸지 대안으로 갈지.
- 14절: 각 행에 "결과: …"를 추가한다.
- 11절과 4절: 로그인 항목 방식.

- [ ] **Step 4: 샘플 저장과 실험 코드 삭제**

Run: `git log -1 --format=%H -- spikes` (결과 문서에 적을 sha), 이어서 `rm -rf /Applications/ProbeApp.app && git rm -r spikes && git status --short`
Expected: `spikes/`가 삭제 대상으로 나오고, 문서만 추가된다.

- [ ] **Step 5: Commit**

```bash
git add docs/spikes docs/specs
git commit -m "docs: record the feasibility spike results"
```
