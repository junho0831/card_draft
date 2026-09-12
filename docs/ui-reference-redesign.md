# 참조 이미지 기반 UI 정리

2026-09-10. 전투·메인·지도·상점·보상 이미지를 참고해 실제 Godot 화면을 수정했다. 카드와 유물 효과, 가격, 전투 규칙은 유지한다.

## 반영

- 공통: 성채 배경, 어두운 패널, 얇은 테두리, 한글 산세리프 글꼴. 런 화면의 제목과 메뉴를 한 줄로 합쳤다. 금색은 보상과 구매, 파란색은 이동과 보조 행동에 사용한다.
- 전투: 1280×720 가로 화면은 왼쪽 영웅 정보, 오른쪽 5칸 전장, 중앙 공격 예고로 배치한다. 손패는 겹치지 않는 가로 스크롤이며 행동 버튼을 하단에 고정한다. 모바일은 세로 전장과 가로 손패를 유지한다.
- 메인: 왼쪽 시작 메뉴, 중앙 캐릭터, 오른쪽 현재 런과 기록. 경로 표시는 저장된 실제 지도에 따른다.
- 보상: 카드별 반복 배지를 줄이고 그림·효과·추천 이유를 보여준다. 가로 화면의 유물 선택을 왼쪽에 배치해 카드 3장과 선택 버튼을 함께 볼 수 있다.
- 상점: 1280×720에서 상품을 가로로 배치한다. 구매 버튼과 가격을 상품 아래에 두고 정비와 나가기는 하단에 고정한다.
- 지도: 새 런의 5개 지점은 아래에서 위로 이어진다. 기존 긴 지도와 모바일의 가로 경로는 유지한다. 지도 배경과 경로 버튼은 분리되어 있어 실제 이동을 클릭할 수 있다.
- 손패 새로고침 시 삭제 예약 중인 카드가 레이아웃 계산에 포함되어 카드가 밀리던 문제도 수정했다.

## 검증

모든 실행은 `--test-data-dir`로 개인 저장과 분리했다. Godot 4.6.3과 Xvfb/Mesa로 검사한다. 구체적인 결과는 아래 최종 검증 기록에 적는다.

기본 회귀 테스트는 카드 효과뿐 아니라 GUI 입력을 통한 화면 전환, 빠른 시작, 유닛 그림을 눌러 장비 대상 확정도 포함한다. 캡처는 화면 전환 핸들러로 구성한 상태이며 사람이 한 판을 직접 플레이한 결과는 아니다.

`tests/godot/capture_battle_redesign.gd`는 두 아군, 한 적, 다섯 손패를 배치한 시각 점검용 fixture다. 마나 4는 화면 점검을 위한 값이며 실제 첫 턴 기본 마나를 바꾸지 않는다.

```bash
xvfb-run -a godot --path . -s res://tests/godot/capture_battle_redesign.gd -- --test-data-dir=/tmp/card-draft-battle-art
xvfb-run -a godot --path . -s res://tests/godot/capture_battle_redesign.gd -- --test-data-dir=/tmp/card-draft-battle-art-mobile --mobile
```

전체 화면 캡처와 회귀 테스트 명령은 [실행과 테스트](run-and-test.md)를 참고한다.

## 배경 생성 기록

내장 image_gen의 참조 기반 생성 모드로 만들고 프로젝트에 복사했다. UI와 문자 없이 환경만 생성했다. 기존 카드 그림은 유지했다.

### 성채

저장: `assets/backgrounds/siege_castle_v1.png`

참조: 사용자가 첨부한 전투 화면.

프롬프트:

> Create one landscape 16:9 game background asset only, inspired by the attached reference's dark fantasy siege atmosphere. Remove ALL interface elements, cards, text, numbers, logos, bars, characters and portraits. Background environment only: distant gothic ruined castle silhouette under storm-blue clouds, medieval stone battlements, worn royal-blue banners and a small amber brazier along the extreme right edge, dark red tattered banner on far left. Painterly realistic high-end fantasy card game art. Keep the central 80% low-contrast, very dark charcoal navy, quiet atmospheric fog, so separate live game cards will be highly readable. Fine dramatic detail confined mainly to edges and top skyline. No panels, no rectangles, no UI mockup, no text, no people. Full bleed production environment illustration.

### 원정 지도

저장: `assets/backgrounds/campaign_valley_v1.png`

참조: 사용자가 첨부한 사진 4의 지도 화면.

프롬프트:

> Generate a production background illustration for a dark medieval fantasy card game's campaign map. Landscape 3:2 composition. Bird's-eye painted panorama: mountain valley, winding river from lower left toward the distant towering red-lit fortress at top center, small ruined settlements, dense blue-gray forests, rugged icy peaks on the upper edges, warm sparse fires. Match the attached reference's premium realistic painterly dark fantasy mood. ENVIRONMENT ART ONLY: absolutely no interface, no icons, no map nodes, no path markers or dotted routes, no cards, no text or lettering, no portraits, no borders. Quiet low-contrast central valley with dark navy atmosphere to place live readable game nodes over it. High detail in landscape, balanced subdued lighting; red fortress draws eye at top.

## 최종 검증 기록

- Godot 4.6.3: 오디오 연결을 포함해 `PASS 1242 assertions`.
- 1920×1080, 1280×720, 1024×768, 800×1280, 390×844의 화면 캡처를 생성했다. 모바일 제목이 세로로 줄바꿈되던 문제는 확인 후 고쳤다.
- 개인 저장을 사용하지 않았다. 검증 저장 위치는 `/tmp/card-draft-ref-ui-final`, `/tmp/card-draft-original-audio-tests` 등이다.
- 회귀 테스트 종료 시 기존 CanvasItem/ObjectDB 해제 경고가 남는다.
- 배경은 새로 생성했지만 카드별 원화는 기존 파일이다. 참조 이미지의 모든 인물·카드 원화를 새로 제작한 작업은 아니다.
