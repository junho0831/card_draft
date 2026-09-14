# 모바일 개선과 코드 책임 분리

## 변경 범위

게임 규칙과 저장 형식을 유지하며 화면·입력·저장 처리의 중복을 줄였다. 기존 모바일 조작 및 행동 가능 상태 개선도 함께 반영한다.

| 책임 | 담당 코드 | 변경 이유 |
| --- | --- | --- |
| 전투 저장 데이터 정규화 | `src/battle/battle_snapshot_codec.gd` | 저장/복원 양쪽의 필드·기본값 정의를 하나로 합쳐 누락과 불일치를 방지한다. 카드·유닛 배열은 깊은 복사한다. |
| 화면 분류와 배율 | `src/ui/layout_policy.gd` | 메뉴와 전투가 같은 휴대폰·태블릿 기준을 사용한다. 물리 해상도와 논리 화면 크기를 구분한다. |
| 터치 제스처 | `src/ui/touch_scroll_router.gd` | 입력 종류 해석과 제스처 시작·이동·종료를 분리한다. 스크롤 임계값, 방향 잠금, 중복 마우스 이벤트 처리는 유지한다. |
| 전투의 그리기 스타일 | `src/ui/styles/battle_styles.gd` | 화면 상태와 무관한 카드 프레임·테두리·버튼 스타일을 화면 코드에서 옮긴다. 실제로 쓰이지 않던 프레임 인수를 제거한다. |
| 화면과 게임 진행 연결 | `battle_screen.gd`, `main.gd` | 기존 호출 인터페이스를 유지하고 위 모듈에 변환·표현 작업을 맡긴다. |

`build/.gdignore`는 캡처·QA 빌드가 Godot 리소스로 임포트되는 것을 막는다. `.gitignore`는 이 파일만 추적하고 빌드 결과는 계속 제외한다. Godot가 생성한 누락된 스크립트 UID도 함께 추적한다.

전투 화면의 모든 렌더링과 게임 진행을 새 구조로 전면 재작성한 것은 아니다. 기존 카드 효과·보상·런 생성 서비스는 유지하고, 중복과 저장 호환성 위험이 확인된 경계를 우선 정리했다.

## 유지한 계약

- 구형 저장의 기본값, 적 턴 재개 단계, 유닛 ID 카운터, 드로우 환급 여부를 보존한다.
- 저장 스냅샷과 실제 전투의 카드·유닛 배열이 서로를 수정하지 않는다.
- 모바일 확인 후 사용, 대상 취소, 중앙 스와이프와 하단 버튼의 입력 동작을 보존한다.
- 카드·유닛 효과, 체력·마나 수치, 런 길이와 보상은 변경하지 않는다.

## 검증 명령

```bash
godot --headless --path . -s res://tests/godot/run_tests.gd -- --test-data-dir=/tmp/card-draft-refactor-tests
xvfb-run -a godot --path . -s res://tests/godot/touch_scroll_test.gd -- --test-data-dir=/tmp/card-draft-refactor-touch
xvfb-run -a godot --path . -s res://tests/godot/touch_scroll_test.gd -- --test-data-dir=/tmp/card-draft-refactor-small --small-phone
xvfb-run -a godot --path . -s res://tests/godot/capture_battle_redesign.gd -- --test-data-dir=/tmp/card-draft-refactor-mobile --mobile
xvfb-run -a godot --path . -s res://tests/godot/capture_battle_redesign.gd -- --test-data-dir=/tmp/card-draft-refactor-desktop
```

Android 검증은 API 36 에뮬레이터의 `com.card_draft.mobileqa` 패키지와 `/data/user/0/com.card_draft.mobileqa/files/mobile-qa-0914` 저장 경로를 사용한다. 별도 복사본에서 x86_64 QA APK를 빌드하며 저장 기본 경로도 QA 위치로 고정한다. 소스 저장소의 배포 패키지나 사용자 프로필에는 이 설정을 적용하지 않는다. 이 APK는 실제 휴대폰 배포용 빌드가 아니다.

실물 Android/iPhone 성능, 발열, 장시간 플레이와 사용자 이해도 검증은 별도다. 기존 테스트 종료 시 CanvasItem/ObjectDB 리소스 정리 경고는 기능 통과와 구분해 기록한다.

## 2026-09-14 실행 결과

- Godot 4.6.3 전체 회귀 검사: **1,355개 통과**. 새 저장 분리·구형 저장·화면 배율 계약 검사 10개를 포함한다.
- 390×844와 320×568: 카드 위 가로/세로 스와이프, 오작동 방지, 다음 터치, 하단 버튼 공간 검사 통과.
- 390×844와 1280×720: 대상 선택/취소, 실제 공격과 체력 예측 일치, 비활성 카드, 턴 버튼, 데스크톱 연결선 검사 통과.
- Android API 36, 1080×2340 에뮬레이터: QA APK 업데이트 설치, 기존 저장 이어하기, 손패 스와이프, 스와이프 뒤 첫 터치 확인, 재터치 소환과 진입 피해, 다음 턴 진행 확인.
- Android에서 민병대 사용 후 행동이 없으면 자동 턴 종료되는 기존 규칙을 확인했다. 따라서 완료 후 마나가 0인 상태가 아니라 다음 턴의 3으로 관찰됐다. 수동 턴 종료 후에도 플레이어 3번째 턴과 마나 4로 정상 진행했다.
- 캡처: `build/refactor-qa-2026-09-14/`. 실제 저장은 사용하지 않았다. 기존 테스트 종료 시 리소스 정리 경고는 남아 있다.
