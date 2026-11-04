# Task 4 수동 점검: 열기·복사·종료

아래는 **사용자 실행용이며 아직 실행하지 않았다**. 자동 테스트 통과와 실제 UI 통과를 구분한다. 본인이 이번 점검을 위해 띄운 `8797`·`8798` 서버에만 종료를 적용한다. 다른 개발 서버, 다른 앱, Docker 런타임의 종료 항목은 누르지 않는다.

1. 기존 Doorplate는 메뉴의 **Doorplate 종료**로 종료한다. Terminal A에서 최신 main 앱을 빌드하고 연다.
   ```sh
   cd /Users/junjuny/Documents/Doorplate
   xcodegen generate && xcodebuild -project Doorplate.xcodeproj -scheme Doorplate -configuration Debug -derivedDataPath build CODE_SIGN_IDENTITY=- build
   open build/Build/Products/Debug/Doorplate.app
   ```
   `** BUILD SUCCEEDED **`를 확인한다. 폴더 접근 허락 창이 나오면 본인 판단으로 응답하고 결과를 기록한다. 다른 설정·업데이트 메뉴는 이 점검에서 누르지 않는다.
2. Terminal B에서 일반 서버를 띄운다. `Address already in use`이면 그 포트의 기존 프로세스를 종료하지 말고 이 점검을 중단해 보고한다.
   ```sh
   mkdir -p "$HOME/.hermes/cache/scratch/doorplate-action-check"
   cd "$HOME/.hermes/cache/scratch/doorplate-action-check"
   printf '%s\n' '{"name":"doorplate-action-check"}' > package.json
   python3 -m http.server 8797 --bind 127.0.0.1
   ```
   Doorplate 문 아이콘을 누르고 `8797  doorplate-action-check` 행이 생길 때까지 약 5초 기다린다. 프로젝트 제목이 다르면 실제 제목을 기록한다.
3. `8797` 행에 마우스를 올려 하위 메뉴를 연다. 아직 **종료**나 ⌥ 클릭은 하지 않는다. 다음 동작을 각각 실행하고 매번 메뉴를 다시 연다.
   - **브라우저에서 열기**: 기본 브라우저가 `http://localhost:8797`을 열고 디렉터리 목록이 보인다.
   - **Finder에서 보기**: Finder가 위 `doorplate-action-check` 폴더를 선택한다.
   - **터미널에서 열기**: Terminal(후속 설정 Task 적용 후에는 선택한 터미널)이 위 폴더를 연다. 열린 창에서 `pwd`를 실행해 경로를 기록한다.
   - **주소 복사**: 별도 Terminal에서 `pbpaste`를 실행한다. 정확히 `localhost:8797`이어야 한다(프로토콜·쉼표 없음).
4. 메뉴를 다시 열고 **⌥를 누른 채 8797 행을 클릭**한다. 일반 하위 메뉴가 아닌 `종료 · 8797 …` 대체 항목인지 확인한 뒤 클릭한다. 추가 확인 창 없이 서버가 끝나고 행이 사라지는지 기록한다. Terminal B가 프롬프트로 돌아오는지도 확인한다.
5. Terminal C에서 TERM을 무시하는 별도 점검 서버를 띄운다.
   ```sh
   cd "$HOME/.hermes/cache/scratch/doorplate-action-check"
   /bin/sh -c 'trap "" TERM; exec python3 -m http.server 8798 --bind 127.0.0.1'
   ```
   `8798` 행의 하위 메뉴 **종료 (PID …)**를 누른다. 메뉴를 다시 열어 `종료 중…` 꼬리표와 비활성 종료 항목을 확인한다. 이때 같은 행의 종료를 다시 시도해도 추가 요청·확인 창이 생기지 않아야 한다. ⌥ 대체 종료 항목은 종료 중에는 없어야 한다. 약 10초 뒤 `…이(가) 아직 실행 중입니다.` 창 하나만 뜨는지 기록한다.
6. 첫 확인 창에서는 **기다리기**를 누른다. **강제 종료는 아직 누르지 않는다**. 약 10초 뒤 같은 확인 창이 다시 하나만 뜨고 서버는 계속 살아 있어야 한다. 두 번째 창에서는 **강제 종료**를 마우스로 눌러 해당 점검 서버만 종료한다. 서버와 `8798` 행이 사라지는지 확인한다. Return 기본 동작은 실수로 강제 종료하지 않도록 **기다리기**다. 시간은 정확한 실시간 보장값이 아니라 대략적인 10초 유예를 확인한다.
7. Doorplate는 **Doorplate 종료**로 닫는다. 아직 점검 서버가 남아 있으면 그 서버를 띄운 Terminal에서 Ctrl-C로 종료한다. 다른 PID에 `kill`을 실행하지 않는다. 보고할 내용:
   - 단계 1–6 각각 통과/실패/미확인, macOS 표시 언어
   - 브라우저 URL, Finder 선택 위치, 터미널 `pwd`, `pbpaste` 결과
   - ⌥ 종료 결과, 종료 중 표시/비활성 여부, 창 개수
   - 최초 확인 창과 기다리기 뒤 재질문까지의 대략적인 시간, 강제 종료 결과
   - 창이 안 보임·메뉴 멈춤·경고음·권한 요청 등 예상과 다른 현상

참고: 이미 사라진 대상의 경고음·즉시 재조회와 PID 재사용 방지는 패키지 테스트가 검사한다. 이를 수동으로 재현하려고 다른 프로세스의 PID를 재사용하거나 종료하지 않는다.
