---
version: alpha
name: Doorplate Site
colors:
  primary: "#1D3A63"
  on-primary: "#FFFFFF"
  surface: "#F5F5F5"
  on-surface: "#1D1D1F"
  card: "#FFFFFF"
  on-card: "#1D1D1F"
  muted: "#626267"
  border: "#DCDCE0"
  ring: "#B8521F"
  warm: "#F59E4C"
  on-warm: "#1D1D1F"
typography:
  display:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: 64px
    fontWeight: 700
    lineHeight: 1.06
  heading:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: 36px
    fontWeight: 700
    lineHeight: 1.15
  body:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: 17px
    lineHeight: 1.55
  caption:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: 14px
    lineHeight: 1.5
spacing:
  unit: 4px
  small: 8px
  medium: 16px
  large: 24px
  section: 112px
rounded:
  small: 6px
  medium: 12px
  large: 24px
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.medium}"
    height: 44px
  button-primary-hover:
    backgroundColor: "#294F7E"
    textColor: "{colors.on-primary}"
  card:
    backgroundColor: "{colors.card}"
    textColor: "{colors.on-card}"
    rounded: "{rounded.medium}"
    padding: "{spacing.large}"
  page:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
  copy-status:
    backgroundColor: "{colors.warm}"
    textColor: "{colors.on-warm}"
---

## Overview

로컬 서버를 쓰는 macOS 개발자를 위한 소개·설치 페이지다. 주 방향은 Repot의 미니멀 네이티브 제품 소개: 담백함, 명료함, 신뢰. 크림색·세리프·테라코타 편집 디자인은 쓰지 않는다. 초기 브랜치는 feat/site이며 재사용하는 단위는 Section, CardList, Screenshot, CopyCommand, LanguageLinks다.

## Signature Element

실제 NSMenu 화면이 주인공이다. 포트와 프로젝트가 한 행에 연결된 모습을 440px 메뉴 스크린샷으로 보여 준다. 문 장식이나 가짜 터미널 대신 실제 앱과 Doorplate 아이콘을 쓴다.

## Colors

아이콘의 남색 #1D3A63/#3B6EA8, 문 오렌지 #F59E4C, 황동 #F2C14E를 따른다. 기본 면은 중립 회색과 흰색, 강조색은 버튼·순서 번호에만 쓴다. 장식용 그라디언트는 없다. WCAG AA 4.5:1을 텍스트 기준으로 한다. 어두운 모드는 같은 토큰을 surface #1E1E1E, on-surface #F5F5F7, card #2A2A2C, on-card #F5F5F7, muted #B4B4BC, border #48484C, primary #F2C14E, on-primary #1D1D1F, ring #F59E4C로 바꾼다.

## Typography

로컬 시스템 글꼴만 쓴다. 제목 64/36px, 본문 17px, 리드 19px, 캡션 14px. 720px 아래에서는 제목 44/28px. CJK는 자간 0, line-height 1.6, 한국어는 keep-all과 overflow-wrap을 함께 쓰고 일본어는 auto-phrase를 쓴다. 코드만 ui-monospace다.

## Layout

Repot에서 추출한 최대 1080px, 좌우 24px(모바일 20px), 섹션 간격 112px를 따른다. Hero는 가운데 정렬, 기능과 상세 화면은 2열, 설치는 2열, 720/880px 아래에서는 1열이다. 페이지가 스크롤을 소유하고 긴 명령은 코드 영역 안에서만 가로 스크롤한다. /, /ko/, /ja/, /zh-Hans/를 정적 HTML로 만든다. 390/768/1280px에서 문구와 표를 확인한다.

## Elevation & Depth

메뉴 스크린샷만 부드러운 drop-shadow로 띄운다. 카드는 그림자 대신 1px 테두리다. 헤더는 불투명 면과 구분선으로 만든다.

## Shapes

--radius 12px 하나에서 6/12/24px를 파생한다. 네이티브 버튼은 44px 높이, 언어 링크도 터치에 충분한 높이를 확보한다.

## Components

버튼·링크: 기본, hover 색, 3px focus-visible, active 밝기. CopyCommand는 성공을 aria-live로 알리고 실패하면 명령을 선택해 복사하도록 안내한다. LanguageMenu는 details/summary와 네 언어 링크, Escape와 바깥 클릭 닫기를 제공한다. 이미지에는 의미 있는 대체 문구, 본문 시작 skip link와 landmarks가 있다. 다운로드는 일반 링크라 disabled/loading 상태가 없다. 정적 페이지는 원격 데이터 loading/empty/error 상태가 없다. 클립보드 실패만 오류 상태로 다룬다.

## Motion & Interaction

장식 애니메이션과 스크롤 효과는 없다. 색·밝기 전환만 120ms ease-out, reduced-motion이면 전환을 없앤다. 언어 자동 이동과 브라우저 저장소를 쓰지 않는다.

## Do's and Don'ts

README 문구를 재사용한다. 제목마다 eyebrow를 붙이지 않는다. 3열 템플릿 카드, 외부 글꼴, 추적기, 배경 blob, 가짜 지표는 금지한다. 밝은 모드의 앱 스크린샷은 어두운 페이지에서도 원본 그대로 표시한다.

## Accessibility Constraints & Accepted Debt

키보드와 네이티브 disclosure, visible focus, 14px CJK 바닥, responsive overflow 방지를 지킨다. 성능 목표는 정적 제품 페이지의 모바일 cold-load LCP 2.5초 이하이며 현장 데이터나 Lighthouse 측정은 이 작업의 성공 기준이 아니므로 통과로 주장하지 않는다. 이미지 치수를 고정해 레이아웃 이동을 막는다. 1280px 영어/한국어 밝음·어두움 및 390px 전체 페이지 캡처로 시각 확인한다.

## Research Log

Repot apps/site의 site.css와 Header/Hero/LanguageMenu/head/i18n, Pages 워크플로를 읽었다. 1080px 폭, 52px 헤더, 64/36/17/14 타입, 112px 섹션 간격, 12px 카드, 44px 버튼을 추출했다. Live Repot 페이지도 확인했다. assets/AppIcon.svg에서 남색·오렌지·황동색을 추출했다. omh design data의 dev-tool palette를 조회했지만 외부 기준 팔레트보다 실제 앱 아이콘을 우선했다. 외부 이미지·폰트 서비스는 쓰지 않는다.
