## 설치 / Install

macOS 14 이상, Apple Silicon·Intel Universal 빌드입니다. 아래 Assets에서 `Doorplate-<버전>.zip`을 받아 압축을 풀고, **처음 열기 전에 Finder로 Doorplate.app을 `/Applications`에 옮기세요.** 다운로드 위치에서 열면 Sparkle 업데이트가 거부될 수 있습니다.

Requires macOS 14 or later (Apple Silicon and Intel). Download the zip below, extract it, and **move Doorplate.app to `/Applications` in Finder before opening it** so that it can update itself.

Homebrew tap 준비 후 / Once the tap is available:

```sh
brew install --cask junjuny0227/tap/doorplate
```

## 처음 열 때 / First launch

Developer ID 서명·공증 없는 ad-hoc 서명 앱입니다. macOS가 막으면 **완료**를 누르세요(휴지통으로 이동하지 마세요). 시스템 설정 → 개인정보 보호 및 보안 → **그래도 열기**를 누르고 암호 또는 Touch ID로 확인한 뒤, 다시 **그래도 열기**를 누르세요.

This app is ad-hoc signed, not Developer ID signed or notarized. If macOS blocks it, click **Done**, not Move to Trash. In System Settings → Privacy & Security, click **Open Anyway**, authenticate, then confirm **Open Anyway** again.

터미널 대안 / Terminal alternative:

```sh
xattr -dr com.apple.quarantine /Applications/Doorplate.app
```

이 명령은 앱의 다운로드 격리 표시를 재귀적으로 제거합니다. 출처와 체크섬을 확인한 앱에만 사용하세요. This recursively removes the app's download quarantine flag; use it only after verifying the source and checksum.

프로젝트 이름을 읽기 위해 Documents·Desktop·Downloads 폴더 접근 허락을 물을 수 있습니다. 업데이트 뒤에는 보호 폴더마다 다시 물을 수 있으며, 거부하면 폴더 이름으로 표시합니다. Folder access may be requested to read project names and may be requested again after updates; denying access falls back to folder names.

## SHA-256

```text
{{SHA256}}
```

같이 첨부된 `.zip.sha256` 파일과 zip을 같은 폴더에 놓고 확인하세요. Download both assets into the same directory and verify:

```sh
shasum -a 256 -c Doorplate-*.zip.sha256
```
