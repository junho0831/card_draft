# 사운드와 전투 애니메이션

## 현재 음원과 연결

BGM은 `community_v1`의 RandomMind CC0 메뉴·탐험·전투 세 곡이다. 효과음은 `combat_edited_v1`의 Kenney 편집본을 먼저 찾고, 없으면 `community_v1`을 사용한다. 일반 실행에서 파일이 없으면 오류를 기록하고 빈 스트림을 반환하며 AI 생성·주파수 합성으로 대체하지 않는다. 합성 코드는 이전 제작 도구가 명시적으로 활성화할 때만 사용한다.

출처·라이선스·파일 해시는 [커뮤니티 오디오](community-audio.md)와 각 팩의 `manifest.json`에서 관리한다. 이전 모델 제작 문서는 과거 실험 기록이다.

| 상황 | 연결 |
| --- | --- |
| 메뉴·세력 선택·결과 | `menu_theme` |
| 지도·상점·이벤트·휴식·보상 | `exploration` |
| 일반·엘리트·보스 전투 | `battle_base` 공유, 상태별 음량 조절 |
| 카드 피해 | 카드의 `impact_profile`로 소리와 시각 모티프 선택 |
| 회복·사망·필살기 | 회복 입자·사망 파편·확산 연출과 해당 효과음 |

피해 계열은 `src/battle/card_impact_profiles.gd`에서 정의한다. 카드마다 독립 음원 파일을 만드는 방식이 아니라 효과 계열을 공유한다. 피해 수치와 소리·시각 모티프 선택은 구분한다.

| 계열 | 음원 키 | 시각 모티프 |
| --- | --- | --- |
| 금속 | `sword_hit` | 베기 |
| 화살 | `arrow_hit` | 관통 |
| 화염 | `spell_hit` | 폭발 |
| 얼음 | `ice_hit` | 파편 |
| 번개 | `lightning_hit` | 번개 |
| 암흑 | `shadow_hit` | 안쪽으로 수축 |
| 독 | `poison_hit` | 방울 |
| 뼈 | `bone_hit` | 조각 |
| 혈기 | `blood_hit` | 비산 |
| 신성 | `heal` | 빛 고리 |
| 바람 | `wind_hit` | 돌풍 |
| 돌 | `heavy_hit` | 균열 |

## 재생 규칙

- 같은 탐험곡을 쓰는 지도→상점 등에서는 재생 위치를 유지한다. 곡을 바꾸면 새 곡이 0.6초 동안 서서히 커진다.
- 보스→일반 전투에서는 일반 전투곡을 복원한다. 전투를 떠나면 전투곡을 종료한다. 이미 재생 중인 전투에 상태 갱신이 들어와도 곡을 처음부터 재생하지 않는다.
- 강타·필살기가 재생되면 음악 전용 하위 버스 `MusicMix`를 최대 5dB 낮췄다가 복구한다. 사용자가 설정한 상위 `BGM` 음량은 수정하지 않는다.
- 일반 타격은 대상 주변을 강조한다. 강타에서만 화면 전체의 짧은 빛을 사용한다.
- 회복·사망·필살기 이펙트는 입력을 가로채지 않는다. 사망 파편은 전장 슬롯과 독립되어 다음 유닛의 위치·투명도를 바꾸지 않는다.
- 효과 종료 시 임시 노드와 Tween을 정리한다. 테스트/헤드리스의 연출 생략 규칙은 유지한다.

## 실행 검증

아래 명령은 프로젝트 루트에서 실행한다. 모든 Godot 실행에 별도 저장 경로를 지정한다.

```bash
godot --headless --path . -s res://tests/godot/run_tests.gd -- --test-data-dir=/tmp/card-draft-av-regression
xvfb-run -a godot --path . -s res://tests/godot/capture_original_audio.gd -- --test-data-dir=/tmp/card-draft-av-audio
xvfb-run -a godot --path . -s res://tests/godot/capture_av_presentation.gd -- --test-data-dir=/tmp/card-draft-av-desktop
xvfb-run -a godot --path . -s res://tests/godot/capture_av_presentation.gd -- --test-data-dir=/tmp/card-draft-av-mobile --mobile
```

오디오 검사는 메뉴→일반 전투→보스→탐험→메뉴 전환과 효과음을 실제 AudioStreamPlayer로 재생하고 Master 출력을 `engine_audio.wav`에 녹음한다. 연출 검사는 테스트 전장을 사용해 공격 연출 진입점과 이펙트를 실행하며 `heal.png`, `death.png`, `ultimate.png`를 저장한다. 연출만 실행했을 때 전투 상태가 그대로인지, 공격 카드의 크기·회전이 복원되는지, 임시 이펙트가 정리되는지도 검사한다.

현재 CC0 편집본의 파일·해시는 다음 명령으로 검사한다. 의존성·미리듣기 방법은 [커뮤니티 오디오](community-audio.md)를 참고한다.

```bash
python3 tools/package_combat_audio.py --check
```

## 검증 범위

신호 검사와 엔진 재생/화면 캡처는 자동 검증이다. 실제 휴대폰 스피커·이어폰에서의 타격감, 장시간 반복 시 피로도, 저사양 모바일 프레임 속도는 사람이 별도로 확인해야 한다. 기존 엔진 종료 시 ObjectDB/CanvasItem 관련 경고는 이 작업의 임시 이펙트 정리 검사와 별개다.
