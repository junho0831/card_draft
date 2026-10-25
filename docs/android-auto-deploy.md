# Android 자동 배포

`.github/workflows/android-play-alpha.yml`은 서명된 AAB를 만들고 검증한 뒤 Google Play 테스트 트랙에 배포한다. 프로덕션 출시는 이 워크플로에서 허용하지 않는다.

## 자동 검증 범위

1. Godot 4.6.3으로 Android AAB를 내보낸다.
2. 개인 저장과 분리된 전체 회귀 테스트를 실행한다.
3. AAB 서명과 등록된 업로드 키가 같은지 확인한다.
4. API 36, ARM64, ARMv7, 버전 이름과 버전 코드를 확인한다.
5. 검증된 AAB를 Actions 결과물로 14일 동안 보관한다.
6. `alpha` 또는 `internal` 테스트 트랙에 출시하고 Google 검토로 전송한다.

Google 검토와 정책 상태 반영은 비동기 작업이다. 워크플로 성공은 Google 검토 승인을 의미하지 않는다.

## 최초 1회 설정

저장소 **Settings → Secrets and variables → Actions**에 다음 Repository secret을 등록한다.

| 이름 | 값 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | 업로드 키스토어 파일 전체를 Base64로 인코딩한 값 |
| `ANDROID_KEYSTORE_PASSWORD` | 키스토어와 키 비밀번호 |
| `ANDROID_KEY_ALIAS` | 업로드 키 별칭 |
| `PLAY_SERVICE_ACCOUNT_JSON` | Play Console 권한을 받은 Google Cloud 서비스 계정 JSON 전체 |

서비스 계정에는 전체 계정 관리자 권한을 주지 않는다. Play Console의 **사용자 및 권한**에서 `Card Draft: Three Factions` 앱의 테스트 트랙 출시 관리에 필요한 권한만 부여한다. Google Cloud 프로젝트에서는 Google Play Android Developer API를 활성화해야 한다.

키스토어와 서비스 계정 JSON은 저장소 파일로 커밋하지 않는다. 워크플로는 실행 중 `$RUNNER_TEMP`에 키스토어를 만들고 GitHub 호스팅 실행기가 종료될 때 함께 폐기한다.

## 실행 방법

GitHub 저장소의 **Actions → Android Play Alpha → Run workflow**에서 다음 값을 입력한다.

- `version_name`: 사용자에게 표시할 버전. 예: `1.0.3`
- `version_code`: Google Play에서 한 번도 사용하지 않은 양의 정수. 비우면 UTC 날짜 `YYYYMMDD`를 사용한다.
- `track`: `alpha` 또는 `internal`
- `release_notes`: 한국어 변경사항
- `publish`: 끄면 빌드·검증·AAB 보관까지만 실행하고, 켜면 Google Play까지 배포한다.

`android-v1.0.3` 같은 태그를 푸시해도 `alpha` 트랙 배포가 실행된다. 같은 UTC 날짜에 두 번 배포할 때는 태그 방식 대신 수동 실행에서 더 큰 `version_code`를 직접 입력한다.

배포에 실패하면 Actions 로그의 첫 실패 단계부터 확인한다. Play Console에서 동시에 같은 앱의 출시 초안을 편집하면 Developer API의 edit이 무효화될 수 있으므로 자동 배포 실행 중에는 콘솔 출시 화면을 수정하지 않는다.
