# 릴리스 체크리스트

워크플로 구현과 실제 릴리스는 별개다. **Secret 등록·Pages 설정·태그 push·공개·tap 생성/push·cask 설치는 사용자가 승인하고 직접 수행한다.** 이 문서를 추가하면서 해당 작업은 실행하지 않았다.

## 최초 한 번: 사용자 설정 (계획 4 Task 4 Step 2)

### 1. 기존 EdDSA 키를 GitHub Secret에 등록

저장소 루트에서 `scripts/build-release.sh v0.1.0`으로 Sparkle 도구가 내려받아진 상태여야 한다. 새 키를 만들지 않는다. 로컬 키체인의 계정 `doorplate`에 있는 **기존 키**를 사용하며, 공개 키는 이미 앱의 Info.plist에 있다.

사용자가 아래를 직접 실행한다. `set -x`를 켜지 말고, 키 내용을 터미널·채팅·커밋에 붙이지 않는다. 임시 파일은 본인만 읽을 수 있고 성공·실패 때 모두 지운다.

```bash
(
  set -euo pipefail
  umask 077
  KEY_TOOL="build/release/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys"
  if [[ ! -x "$KEY_TOOL" ]]; then
    KEY_TOOL="build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys"
  fi
  test -x "$KEY_TOOL"
  # generate_keys -x refuses an existing file, so export into a new file in a private temp dir.
  KEY_DIR="$(mktemp -d "${TMPDIR:?}/doorplate-secret.XXXXXX")"
  KEY_FILE="$KEY_DIR/key"
  trap 'rm -rf "$KEY_DIR"' EXIT
  "$KEY_TOOL" --account doorplate -x "$KEY_FILE"
  gh secret set SPARKLE_ED_PRIVATE_KEY -R junjuny0227/Doorplate < "$KEY_FILE"
  rm -rf "$KEY_DIR"
  trap - EXIT
)
gh secret list -R junjuny0227/Doorplate
```

목록에 `SPARKLE_ED_PRIVATE_KEY` 이름이 보이면 등록 확인이다(값은 보이지 않아야 한다). 도구 경로 검사에서 멈추면 XcodeGen/빌드를 먼저 확인하며, `generate_keys`를 인자 없이 실행해 새 키를 만들지 않는다.

### 2. 첫 공개 후 Pages 설정

첫 appcast 실행이 `gh-pages` 브랜치를 만든 뒤, 사용자가 GitHub 저장소 **Settings → Pages → Build and deployment → Source: Deploy from a branch → Branch: gh-pages → /(root) → Save**를 설정한다. 브랜치가 아직 없으면 선택할 수 없으므로 먼저 아래 첫 릴리스 공개 단계까지 진행한다.

첫 실행의 `Request Pages build` 단계는 설정 전에는 실패할 수 있다. 브랜치 생성·appcast 커밋이 성공했는지 확인하고 Pages를 설정한 다음, Actions의 **Publish appcast → 해당 실행 → Re-run failed jobs**로 재시도한다. 태그나 릴리스를 다시 만들지 않는다. 이후에는 워크플로가 Pages 빌드를 명시적으로 요청한다. `GITHUB_TOKEN` push만으로는 Pages 빌드가 시작되지 않기 때문에 이 요청에만 필요한 `pages: write`를 `contents: write`와 함께 허용한다(그 외 권한 없음).

## 릴리스마다

### 1. 버전 PR

- [ ] `project.yml`의 `MARKETING_VERSION`을 배포 버전으로 바꾼다. `CURRENT_PROJECT_VERSION`은 이전 배포보다 1 큰 정수로 올린다. 첫 릴리스는 `0.1.0` / `1`이다.
- [ ] PR의 모든 검사(`core`, `app`, `release-tools`)가 통과한 뒤 main에 합친다.
- [ ] 로컬 빌드·서명·Universal 확인은 `scripts/build-release.sh v<버전>`, `lipo -archs dist/Doorplate.app/Contents/MacOS/Doorplate`, `codesign --verify --deep --strict dist/Doorplate.app`으로 한다.

### 2. 사용자 승인 후 태그

아래는 첫 릴리스 예다. 다음 릴리스에서는 버전을 바꾼다. main이 준비됐고 최초 Secret 등록을 끝냈는지 확인한 뒤 **사용자만 실행**한다.

```bash
git switch main
git pull --ff-only origin main
git tag v0.1.0
git push origin v0.1.0
```

- [ ] Actions의 **Draft release** 성공을 확인한다. 태그와 앱 버전이 다르면 빌드가 실패해야 한다.

### 3. draft 확인

- [ ] Releases에서 `Doorplate 0.1.0 (beta)`가 **Draft**, prerelease가 아닌 정식 릴리스인지 확인한다.
- [ ] `Doorplate-0.1.0.zip`과 `Doorplate-0.1.0.zip.sha256` 두 자산, 본문의 실제 SHA-256(`{{SHA256}}`가 남지 않음)을 확인한다.
- [ ] 브라우저로 두 자산을 같은 폴더에 내려받아 `shasum -a 256 -c Doorplate-0.1.0.zip.sha256`의 `OK`를 확인한다.
- [ ] zip을 풀어 **Finder로 `/Applications`에 옮긴 뒤 처음 연다.** 차단 창에서 완료(휴지통으로 이동 아님) → 시스템 설정 → 개인정보 보호 및 보안 → 그래도 열기 → 인증 → 그래도 열기를 확인한다. 릴리스 노트와 동작이 같은지, 메뉴바 아이콘이 나타나는지 확인한다.

### 4. 사용자 공개

- [ ] 사용자가 draft를 최종 확인하고 **Publish release**를 누른다. 0.x도 prerelease로 체크하지 않는다.
- [ ] **Publish appcast**가 공개한 태그의 정확한 zip을 받아 Sparkle **2.10.1**로 서명하는지 확인한다. 빌드 번호는 zip 내부 앱의 `CFBundleVersion`에서 읽는다.
- [ ] 최초 실행이면 위 Pages 설정을 직접 완료하고 실패한 작업을 다시 실행한다.

### 5. 피드와 Pages 확인

```bash
curl --fail --silent --show-error \
  "https://junjuny0227.github.io/Doorplate/appcast.xml" \
  | grep -E 'shortVersionString|edSignature'
```

- [ ] Pages 배포가 끝난 후 현재 버전과 서명이 보인다. 첫 릴리스는 `0.1.0` 항목 하나, 다음 릴리스는 이전 항목도 남아 있어야 한다.
- [ ] gh-pages의 커밋 작성자가 `github-actions[bot]`인지 확인한다. appcast.xml을 손으로 고치지 않는다.
- [ ] 실패하면 Actions 로그를 확인하고 동일 실행을 재시도한다. 동일 build는 항목을 추가하지 않고 교체된다. 이미 만든 draft를 다시 만들려고 Draft release를 재실행하지 않는다.

### 6. cask 갱신 (사용자 승인 필요)

tap이 없다면 먼저 사용자가 `junjuny0227/homebrew-tap` 공개 저장소 생성과 로컬 clone을 승인한다. 다음은 **이미 clone된 tap**을 갱신하는 예다. 저장소 루트에서 실행한다.

```bash
(
  set -euo pipefail
  ASSET_DIR="$(mktemp -d "${TMPDIR:?}/doorplate-cask.XXXXXX")"
  trap 'rm -rf "$ASSET_DIR"' EXIT
  gh release download v0.1.0 -R junjuny0227/Doorplate \
    --pattern 'Doorplate-0.1.0.zip.sha256' --dir "$ASSET_DIR"
  scripts/update-cask.sh "0.1.0" "$ASSET_DIR/Doorplate-0.1.0.zip.sha256" \
    "$HOME/Documents/homebrew-tap"
  brew style "$HOME/Documents/homebrew-tap/Casks/doorplate.rb"
)
```

- [ ] 렌더링된 버전·zip URL·sha256을 공개 릴리스와 대조한다.
- [ ] 사용자가 tap의 `Casks/doorplate.rb`만 commit/push한다.
- [ ] 사용자 승인 후 `brew install --cask junjuny0227/tap/doorplate`로 설치하고 `xattr -p com.apple.quarantine /Applications/Doorplate.app` 출력 여부, 그래도 열기 창 여부, 실행 결과를 기록한다. 결과에 따라 이 문서와 스펙 14절 Sparkle 행을 갱신한다. 미실행 상태를 통과로 적지 않는다.

### 7. 이전 버전에서 업데이트 (다음 릴리스 때)

- [ ] **0.1.0 설치본에서 0.1.1 업데이트(Sparkle) 확인. zip 설치본과 Homebrew cask 설치본을 각각 확인한다.** 첫 0.1.0 공개 시에는 확인할 수 없다.
- [ ] `/Applications`에서 이전 버전을 실행 → 메뉴의 업데이트 확인 → 새 버전 설치·재실행 → 버전과 실제 실행 경로 확인. 새 버전이 Gatekeeper에 막히지 않는지 기록한다.
- [ ] 업데이트 후 보호 폴더 접근 허락이 다시 나오는지 기록한다. 거부 시 폴더 이름 대체가 유지되어야 한다.
- [ ] 두 설치 경로 결과를 이 체크리스트와 스펙 14절 Sparkle 행에 추가한다.

## 검증 경계

actionlint·셸 구문 검사·가짜 서명 출력으로 만든 로컬 XML은 워크플로 구조와 CLI 연결만 확인한다. 실제 비밀 키 서명, 태그에서 draft 생성, 공개 이벤트, gh-pages push·Pages 배포, Gatekeeper·Sparkle 업데이트는 사용자 승인 후 실제 릴리스에서만 확인할 수 있다.
