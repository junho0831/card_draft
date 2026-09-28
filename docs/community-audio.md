# 무료 상업용 오디오 적용

2026-09-28 기준. 비용 0원. AI 생성 작업은 재시작하지 않았다.

## 이번 적용

| 제공처 | 음원 | 게임 용도 |
|---|---|---|
| Kenney Interface Sounds | click_001 | 클릭, 호버 |
| Kenney RPG Audio | bookFlip1 | 카드 사용·드로우 |
| Kenney RPG Audio | handleCoins | 보상 |
| Kenney RPG Audio | knifeSlice | 일반 무기 타격 |
| Kenney Impact Sounds | impactPunch_heavy_000 | 강타 |
| Kenney Impact Sounds | impactWood_light_002 / impactWood_heavy_002 | 화살 / 뼈 |
| Kenney Impact Sounds | impactPunch_medium_002 | 혈기 |
| Kenney RPG Audio | cloth1 / creak1 | 바람 / 독의 마찰 질감 |
| RandomMind / OpenGameArt | Medieval: The Bard's Tale (loop) | 메뉴 |
| RandomMind / OpenGameArt | Medieval: Battle | 전투 |
| RandomMind / OpenGameArt | Medieval: Exploration | 지도·상점·휴식 |

위 13개 파일은 CC0로 공개된 자료다. 원문 링크와 해시는
`assets/audio/community_v1/manifest.json`에 보존한다. Kenney 배포본의 라이선스도
동봉한다. 공개 저장소에 넣을 수 있는 이 팩부터 적용한다. 기존 마법·회복·소환
등은 유지하므로 게임 전체의 음원을 새 CC0 팩으로 교체한 것은 아니다.

주파수 합성이나 AI 추론 없이 FFmpeg로 음량·포맷만 조정했다. 효과음은 원래
길이를 유지한다. 메뉴는 제공된 루프, 전투·탐험은 전체 곡 반복이다. 전투·탐험의
시작/끝에 짧은 페이드를 적용했으며 음악적으로 완벽히 이어지는 루프라고 주장하지 않는다.

## 나머지 두 제공처

- [Sonniss GDC](https://sonniss.com/gameaudiogdc/): 상업 게임에 포함 가능하지만
  [GDC 라이선스](https://sonniss.com/gdc-bundle-license/)상 원본·편집본을 독립 음원으로
  재배포할 수 없다. 공개 GitHub에 WAV/OGG로 추가하지 않는다. 이번 팩에는 미적용.
- [Pixabay 후보: Medieval Castle Loop](https://pixabay.com/music/main-title-medieval-castle-loop-366828/):
  Content ID 등록 표시를 확인했다. 후보 링크만 남기며 다운로드·적용하지 않았다.
  개별 파일의 출처·허가 기록 및 독립 음원 재배포 조건을 확인한 뒤 별도 취급한다.

네 곳을 모두 검토하는 것과 네 곳의 음원을 모두 게임에 적용하는 것은 구분한다.
Sonniss/Pixabay는 필요한 소리가 현재 팩에 없을 때 추가 검토한다.

## 검증

```sh
# 파일 검증은 저장 파일을 읽지 않는다
python3 tools/validate_community_audio.py
# 모든 게임 실행은 분리된 저장 경로에서 수행
 godot --headless --editor --path . --import -- --test-data-dir=/tmp/card-draft-community-import
 xvfb-run -a godot --path . -s res://tests/godot/audio_mix_test.gd -- --test-data-dir=/tmp/card-draft-community-mix
 xvfb-run -a godot --path . -s res://tests/godot/capture_original_audio.gd -- --test-data-dir=/tmp/card-draft-community-capture
```

자동 검증은 파일 디코딩, 선택 우선순위, 기존 마법 효과음 유지, 음악 전환,
중복 재생 억제, 엔진 출력·헤드룸을 확인한다. 사람이 느끼는 타격감과 모바일
스피커의 청감은 자동 검사와 별개이며 아직 사용자 평가 전이다.

2026-09-28 자동 검사 결과: 13개 파일 디코딩·해시·피크 검증 통과, Godot 4.6.3의
오디오 믹스 및 음악 전환/21개 이벤트 녹음 검사 통과. 테스트 저장은 `/tmp/card-draft-community-*`에 격리했다.
미리듣기 HTML은 작성했으나 브라우저 도구가 로컬 파일 URL을 차단하여 브라우저 조작은 미검증이다.

## 카드별 효과 계열

147종(유닛 78·주문 42·장비 27), 강화판 제외. 기존 47종에도 명시적인
`impact_profile`을 추가했다. 추가 100종의 기존 지정은 유지한다.
12계열(검·화살·불·얼음·번개·암흑·독·뼈·혈기·빛·바람·돌)은 각각 다른
소리 파일과 모양을 쓴다. 새로 추가한 CC0 음원은 화살·바람·뼈·혈기·독 5개다.
독은 실제 액체 녹음이 아니라 삐걱이는 마찰음을 사용한 후보이므로 청감 평가가 필요하다.

일반 공격은 소환된 유닛에 보존된 효과 계열로 재생된다. 작은 불꽃·화염구·질풍 사격은
피해 처리 직전에 해당 효과를 표시하며, 카드 사용 시 같은 타격음을 중복 재생하지 않는다.
회복·드로우·소환 같은 비공격 행동은 기존 기능별 피드백을 유지한다.

`card_effect_identity_test.gd`는 전체 카드·강화판 계열, 소리/형태 중복,
세 주문의 영웅/유닛 대상 타격 시점과 기존 피해량을 검사한다.
`frontier_fx_capture.gd`는 12계열 렌더링과 임시 노드 정리를 확인한다.
미리듣기는 `python3 tools/build_audio_preview.py`로 다시 만들 수 있다.

추가 검증 명령:

```sh
godot --headless --path . -s res://tests/godot/card_effect_identity_test.gd -- --test-data-dir=/tmp/card-draft-effect-identity
xvfb-run -a godot --path . -s res://tests/godot/frontier_fx_capture.gd -- --test-data-dir=/tmp/card-draft-effect-capture
godot --headless --path . -s res://tests/godot/run_tests.gd -- --test-data-dir=/tmp/card-draft-effect-regression
```

2026-09-28: 전체 회귀 2,325개 검증 통과. 12계열 캡처에서 형태 차이를 확인했다.
이 캡처는 전투 효과 전용 테스트 화면이며 실제 휴대폰 전투 플레이 검증은 아니다.

## 실제 카드 사용 연결 보완

- 기존 주문: 흡혈의 일격·장례 안개·역병 확산·시체 폭발을 실제 피해 직전에 연결.
- 민병대 진입, 해골 병사 사망, 뼈 갑옷 파열, 잿불 검 추가 피해 연결.
- 확장 카드의 선봉 피해도 같은 경로를 사용하며 보정된 피해량으로 한 번 호출.
- 훈련용 검·잿불 검·바람깃 화살통·피의 칼날 장착 후 일반 공격 계열 변경.
- 소환된 해골·지원병에도 계열을 지정. 장비의 추가·사망 피해 계열을 유닛에 보존.
- 적 카드 사용에도 소환·장비·비공격 주문의 사용음을 연결.
- 속성 타격이 발생한 영웅 피해에는 기본 타격음을 중복 재생하지 않음.

실제 전투 화면의 `_work_on_hand_card_pressed` 경로와 AudioManager 재생 기록을
함께 검사하는 테스트(PC Godot 실행이며 휴대폰 터치 검사는 아님):

```sh
xvfb-run -a godot --path . -s res://tests/godot/card_audio_runtime_test.gd -- --test-data-dir=/tmp/card-draft-live-audio
```

연결 보완 검증: 실제 카드 사용 경로 및 오디오 플레이어 호출 검사 통과,
전체 회귀 2,325개 통과, 장비 효과의 JSON 저장 복원 후 소리 계열 유지 검사 통과.
전투 화면 테스트 종료 시 남던 Tween 3개는 갱신 중 해제된 카드 칸의
흔들기 애니메이션에서 `finished` 신호를 기다리던 불필요한 코루틴 때문이었다.
후속 처리 없는 대기를 제거하고 동일 테스트를 verbose 모드로 재실행해
ObjectDB 누수 경고 및 leaked instance 출력 없이 종료되는 것을 확인했다.
실기기 연결은 없으며 Android QA APK는 최신 연결 코드로 다시 내보낸다.
