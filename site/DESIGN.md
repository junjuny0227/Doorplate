---
version: alpha
name: Doorplate Site
colors:
  accent: "#0068DA"
  accent-dark: "#0071E3"
  link-dark: "#409CFF"
  on-accent: "#FFFFFF"
  window: "#F5F5F5"
  window-dark: "#1E1E1E"
  group: "#FFFFFF"
  group-dark: "#2A2A2A"
  label: "rgb(0 0 0 / 0.85)"
  label-2: "rgb(0 0 0 / 0.6)"
typography:
  display:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"SF Pro Text\", \"Helvetica Neue\", system-ui, sans-serif"
    fontSize: 64px
    fontWeight: 700
    lineHeight: 1.06
  heading:
    fontSize: 36px
    fontWeight: 700
    lineHeight: 1.15
  body:
    fontSize: 17px
    lineHeight: 1.47
  small:
    fontSize: 14px
    lineHeight: 1.43
spacing:
  width: 1080px
  pad: 24px
  header: 52px
  section: 112px
rounded:
  control: 6px
  group: 10px
  card: 12px
  button-large: 11px
---

## Overview

Doorplate 소개·설치 페이지는 같은 소유자의 Repot 사이트(`junjuny0227/Repot`의 `apps/site`)와 최대한 같게 만든다. 소유자 결정: "Repot이랑 가능한 비슷하게". 색·글꼴·간격·컴포넌트는 Repot에서 가져오고, 내용만 Doorplate다.

## Sources

- `src/styles/tokens.css`: Repot `apps/desktop/src/styles/tokens.css`를 그대로 복사했다(macOS 팔레트, 시스템 글꼴, 반경). Repot이 바뀌면 같이 맞춘다.
- `src/styles/site.css`: Repot `apps/site/src/styles/site.css`를 거의 그대로 옮겼다. Doorplate용 추가분은 파일 끝 "Doorplate additions"에 모았다.
- 컴포넌트: Header, LocaleSuggestion, LanguageMenu(지구본), Hero, HowItWorks, Principles, Tools, Footer, `i18n.ts`, `head.ts`, `content.ts`, `icons.tsx`는 Repot의 구조를 따른다.

## Deviations from Repot (이유)

- 강조색: Repot의 `#007aff`는 흰 글자 4.0:1, 창 배경 위 링크 3.7:1이라 WCAG 4.5:1에 못 미친다. `site.css`에서 `--accent`를 밝은 모드 `#0068da`, 어두운 모드 `#0071e3`로, 링크(`--site-link`)를 `#0068da`/`#409cff`로 덮어쓴다.
- 스크린샷: Doorplate 캡처는 투명 배경에 macOS 메뉴 그림자가 들어간 어두운 1x PNG 하나뿐이라, Repot처럼 밝음/어두움을 바꾸지 않고 그림자 필터도 더하지 않는다(`.screenshot.baked`).
- 다운로드: macOS 전용 universal zip 하나라 OS 감지와 분할 버튼이 없다. 대신 Homebrew 명령을 히어로와 설치 구역에 복사 버튼과 함께 둔다.
- 복사 버튼(`CopyCommand`): Repot에는 없다. 성공은 체크 표시와 화면 낭독기용 문구로 조용히, 실패만 빨간 글자로 알린다. 긴 명령은 잘리지 않고 줄바꿈한다.
- "What it does": Repot에 없는 기능 목록을 Tools와 같은 그룹 목록 모양(타일 아이콘 + 제목 + 설명)으로 둔다.
- How it works: 서버·Docker 하위 메뉴 캡처 두 장을 단계 옆에 쌓는다. 1x 캡처라 단계 열을 4:8로 좁혔다.
- `<button class="button">`의 UA 테두리를 없앤다(Repot의 언어 제안 "닫기" 버튼은 기본 테두리가 남아 있다).

## Accessibility

skip link, landmark, 한 개의 h1과 구역마다 h2, 3px focus ring, 44px 이상 누름 영역(복사 버튼은 의사 요소로 확장), 번역된 대체 문구. 헤더 반투명은 `prefers-reduced-transparency`에서 불투명, 모션은 `prefers-reduced-motion`에서 끈다. 390px에서 가로 넘침이 없어야 한다.

## Locale suggestion

영어 페이지에서만, 브라우저 언어가 지원 언어면 한 번 제안한다. 고르거나 닫으면 `localStorage`의 `doorplate.site.locale`에 기억하고, 저장소를 못 쓰면 이번 방문 동안만 숨긴다. 자동 이동은 없다.
