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

## 2026-09-13 추가 구현과 검증

참조의 네 화면 구성을 실제 데이터에 연결했다. 1100px 이상 가로 화면에 새 메인·상점·보상 구성을 적용하고, 세로 화면은 기존 스크롤과 하단 조작 구조를 유지한다.

| 참조 요소 | 구현 | 차이 |
| --- | --- | --- |
| 메인 왼쪽 행동·중앙 인물·오른쪽 런 | 새 지휘관 그림과 저장된 런 정보 | 게임명은 Card Draft 유지 |
| 상점 인물·상품·오른쪽 미리보기 | 상품 선택 후 별도 구매 | 실제 상품 3개와 기존 가격·서비스 사용 |
| 보상 중앙 카드 3장·오른쪽 추천 | 선택과 확정 분리, 유물 선택 유지 | 실제 카드 효과와 보상액 표시 |
| 지도 중앙 경로·양쪽 정보 | 5지점 지도와 목적지 이동 | 구형 긴 지도는 기존 화면 유지 |
| 금색 주 행동·파란색 보조 행동 | 직접 작성한 SVG 테두리와 버튼 | 참조의 복잡한 장식은 단순화 |
| 카드 그림·비용·공격·체력 | 기존 카드 원화와 보석 모양 수치 배지 | 신규 카드 원화 제작 없음 |

새 그림 `merchant_hall_v1.png`, `king_commander_v1.png`는 내장 이미지 생성 도구로 제작했다. 각각 UI 글자 없는 중세 상인 홀(인물 왼쪽, 오른쪽 어두운 공간), 푸른 갑옷과 모피 망토의 독자적 지휘관이라는 지시를 사용했다. 지휘관은 투명 이미지가 아닌 어두운 배경을 포함한다. `assets/ui/fantasy/*.svg`는 코드로 작성한 벡터 자산이다.

- 전체 회귀: Godot 4.6.3, **PASS 1321 assertions**.
- 첫 플레이 입력: **PASS 56 input assertions**.
- 새 가로 화면 선택·구매·보상 확정: **PASS 7 fantasy screen checks**.
- 종료 시 기존 CanvasItem/ObjectDB 해제 경고가 남는다.
- 웹 내보내기는 성공했으나 브라우저 접속 검증은 연결 실패/시간 초과로 완료하지 못했다. 네이티브 Godot 렌더링 검증과 구분한다.
- 신규 사용자 재미·완주 시간은 아직 실측하지 않았다.

### 전체 화면 캡처

주요 화면 외에도 보관함, 도감, 성장, 설정, 조작 안내, 현재 업적 안내 메시지, 카드 제거·강화, 패배 결과, 이어하기 메인을 포함한다. 전투 대상 선택과 모바일 손패 상태도 별도 캡처한다. 테스트 fixture로 화면을 구성하며 모든 분기나 스크롤 위치의 조합을 의미하지 않는다.

```bash
xvfb-run -a godot --path . -s res://tests/godot/capture_ui_responsive.gd -- --test-data-dir=/tmp/card-draft-all-desktop --single-viewport desktop 1280 720
xvfb-run -a godot --path . -s res://tests/godot/capture_ui_responsive.gd -- --test-data-dir=/tmp/card-draft-all-mobile --single-viewport mobile 390 844
```

PNG는 지정한 테스트 디렉터리의 `ui_captures_responsive/`에 저장된다.

## 캡처 피드백 반영 (2026-09-13)

- 모바일 상점의 고정 행동은 덱 보기·나가기 두 개로 제한하고, 카드 제거·회복은 상품 아래 정비 영역으로 옮겼다. 고정 버튼 문구에 줄바꿈을 허용했다.
- 모바일 보상의 유물 두 후보를 가로로 배치하고 반복되는 빌드 설명을 뺐다. 유물의 실제 효과는 계속 표시한다.
- 메인의 시작/이어하기는 왼쪽에만 두고, 도감·설정의 중복 진입 버튼을 제거했다.
- 미래 지도 지점은 클릭 불가 상태를 유지하면서 이름과 외곽선을 더 밝게 표시한다.
- 전투 카드 테두리와 비용·공격·체력 배지에 공통 금속·보석 자산을 적용했다. 유닛의 선택·공격 상태는 짧은 배지 하나로 표시하고, 피해 예측은 대상 상태 배지에 함께 표시해 중첩을 없앴다. 적의 다음 공격은 기존 중앙 예고 영역에 유지한다.
- 일반 런의 추천 자동 실행은 유지하며 안내를 짧게 수정했다. 첫 학습 전투의 도움 보기는 직접 조작 안내를 유지한다.

### 그림 교정

기존 `art_id` 파일들에 샘플 시트의 무관한 그림이 복제돼 있었다. `ui_factory.gd:card_art_texture`에서 불꽃·치유·해골·궁수 등은 샘플 시트의 의미에 맞는 영역을 사용한다. 일부 카드는 같은 계열 원화를 공유하며, 모든 카드에 전용 원화가 생긴 것은 아니다.

내장 이미지 생성으로 `training_sword.png`를 교체하고 `goblin_raider.png`를 추가했다. 각각 글자·테두리 없는 평범한 훈련용 강철 검과 독자적 고블린 약탈자 초상이라는 지시를 사용했다. 외부 유료 API는 사용하지 않았다. 고블린 초상은 해당 적 ID에만 적용한다.

전투 화면의 후속 구조 개선과 검증 기준은 [전투 화면 우선 리디자인](battle-presentation.md)에 기록한다.
