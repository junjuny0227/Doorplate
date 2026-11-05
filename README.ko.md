[English](README.md) · [한국어](README.ko.md)

# Doorplate

**A nameplate on every port's door.**

Doorplate는 열려 있는 포트마다 어느 프로젝트의 서버인지 보여 주는 macOS 메뉴바 앱입니다. `lsof -i :3000`으로 pid를 찾고 어느 서버인지 짐작하는 대신, 메뉴를 열면 `5173  @repot/desktop  vite`처럼 보입니다. JVM과 모노레포의 서버 이름도 정확하게 붙입니다.

Doorplate는 베타(0.x)입니다.

## 메뉴

```
실행 중 · 5
● 3000  @repot/site                    vite ▸
● 5173  @repot/desktop                 vite ▸
● 8080  shop-api · 3일째             gradle ▸
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

- 머리글의 숫자는 메뉴바 숫자와 같습니다. 앱 서버와 Docker 컨테이너를 셉니다.
- `· 3일째`(주황 글자)는 오래 켜진 서버입니다.
- 행에 마우스를 올리면 하위 메뉴가 열립니다: 브라우저에서 열기, Finder에서 보기, 터미널에서 열기, 주소 복사, 종료 (PID …). ⌥를 누르고 있으면 행이 바로 종료하는 항목으로 바뀝니다.
- Docker 행은 Compose 서비스 이름을 제목으로, 컨테이너 이름을 오른쪽에 보여 줍니다.

## 무엇을 알아보나

작업 폴더에서 위로 올라가며 가장 가까운 프로젝트 표식(`package.json`, `Cargo.toml`, `pyproject.toml`, `settings.gradle(.kts)`, `pom.xml`, `go.mod`, `.git` 폴더)으로 서버 이름을 붙이고, 도구를 표시합니다.

- **Node**: vite, next, nuxt, astro, remix, webpack
- **JVM**: `gradle bootRun`, `mvn spring-boot:run`, `java -jar`. Gradle·Kotlin 데몬은 숨깁니다. 디버거 포트(JDWP)는 해당 서버 아래에 묶습니다.
- **Rust**: `cargo run`, `target/debug`·`target/release` 아래의 실행 파일
- **Python**: Django(`manage.py runserver`), uvicorn, Flask, gunicorn
- **Ruby**: Rails, puma
- **Docker Compose**: 실행 중인 컨테이너의 게시 포트를 서비스 이름으로 보여 줍니다. Docker Desktop, OrbStack, Colima에서 동작합니다.

LISTEN 소켓을 나눠 쓰는 worker 프로세스(gunicorn, puma cluster, Node cluster)는 한 행으로 보입니다. Node inspector와 LiveReload 포트는 해당 서버 아래에 묶습니다. IDE, macOS 서비스, 다른 앱은 숨깁니다.

## 설치

macOS 14 이상이 필요합니다. Doorplate는 베타입니다.

Homebrew:

```sh
brew install --cask junjuny0227/tap/doorplate
```

또는 [Releases](https://github.com/junjuny0227/Doorplate/releases)에서 `Doorplate-<버전>.zip`을 받아 압축을 풉니다. 옆의 `.sha256` 파일에 체크섬이 있습니다.

## 처음 열 때

Doorplate는 ad-hoc 서명만 했고 Apple 공증을 받지 않았으므로, macOS가 첫 실행을 막습니다. macOS 15부터는 우클릭 → 열기로 넘어갈 수 없습니다.

1. 처음 열기 전에 Finder에서 `Doorplate.app`을 응용 프로그램 폴더(`/Applications`)로 옮깁니다. 다운로드한 자리에서 열면 macOS가 앱을 임시 위치(App Translocation)에서 실행해, Doorplate가 스스로 업데이트하지 못합니다.
2. 앱을 엽니다. "'Doorplate.app'을(를) 열지 않음" 창("Apple은 'Doorplate.app'에 사용자의 Mac에 손상을 입히거나 사용자의 개인 정보에 침입할 수 있는 악성 코드가 없음을 확인할 수 없습니다.")이 뜹니다. **완료**를 누릅니다. **휴지통으로 이동**은 누르지 않습니다. 앱이 휴지통으로 옮겨집니다.
3. 시스템 설정 > 개인정보 보호 및 보안에서 Doorplate 안내 옆의 **그래도 열기**를 누르고 암호나 Touch ID로 확인한 뒤, 다시 뜨는 창에서 **그래도 열기**를 누릅니다.

터미널에 익숙하다면 2–3단계 대신 다음 명령을 쓸 수 있습니다.

```sh
xattr -dr com.apple.quarantine /Applications/Doorplate.app
```

이 명령은 인터넷에서 받은 파일에 macOS가 붙이는 다운로드 격리 표시를 지웁니다. 그러면 Gatekeeper가 앱을 막지 않습니다.

## 개인정보

- Mac 밖으로 보내는 정보는 없습니다. 네트워크 요청은 GitHub Pages의 appcast(`https://junjuny0227.github.io/Doorplate/appcast.xml`)로 하는 업데이트 확인뿐입니다. 자동 확인은 설정에서 끌 수 있습니다.
- 사용 통계를 모으지 않습니다.
- 프로세스와 소켓 정보는 Mac 안에서만 읽고, Docker와는 로컬 unix 소켓으로만 통신합니다. 포트에 접속해 확인하지 않습니다.
- 프로젝트 이름을 보여 주려고 `package.json` 같은 파일을 읽습니다. 프로젝트가 `~/Documents`, `~/Desktop`, `~/Downloads`, iCloud Drive에 있으면 macOS가 그 폴더에 접근해도 되는지 묻습니다("Doorplate는 각 포트가 어느 프로젝트의 것인지 보여 주려고 package.json 같은 프로젝트 파일을 읽습니다."). 거부하면 그 서버는 폴더 이름으로 보입니다.
- Doorplate는 ad-hoc 서명이라, 업데이트할 때마다 보호 폴더별로 한 번씩 다시 묻습니다.

## 소스에서 빌드

Xcode와 [XcodeGen](https://github.com/yonaskolb/XcodeGen)이 필요합니다.

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project Doorplate.xcodeproj -scheme Doorplate -configuration Debug -derivedDataPath build CODE_SIGN_IDENTITY=- build
```

앱은 `build/Build/Products/Debug/Doorplate.app`에 생깁니다.

## 라이선스

[Apache-2.0](LICENSE)
