# Android 자동 배포

`.github/workflows/android-play-alpha.yml`은 서명된 AAB를 만들고 검증한 뒤 Fastlane의 `android deploy_test` lane으로 Google Play 테스트 트랙에 배포한다. 프로덕션 출시는 워크플로와 Fastlane 양쪽에서 차단한다.

## 자동 검증 범위

1. Godot 4.6.3으로 Android AAB를 내보낸다.
2. 개인 저장과 분리된 전체 회귀 테스트를 실행한다.
3. AAB 서명과 등록된 업로드 키가 같은지 확인한다.
4. API 36, ARM64, ARMv7, 버전 이름과 버전 코드를 확인한다.
5. 검증된 AAB를 Actions 결과물로 14일 동안 보관한다.
6. 배포를 요청한 경우에만 Fastlane으로 `alpha` 또는 `internal` 테스트 트랙에 AAB와 한국어 변경사항을 제출한다. 스토어 소개, 이미지, 스크린샷은 수정하지 않는다.

Google 검토와 정책 상태 반영은 비동기 작업이다. 워크플로 성공은 Google 검토 승인을 의미하지 않는다.

## 최초 1회 설정

저장소 **Settings → Secrets and variables → Actions**에 다음 Repository secret을 등록한다.

| 이름 | 값 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | 업로드 키스토어 파일 전체를 Base64로 인코딩한 값 |
| `ANDROID_KEYSTORE_PASSWORD` | 키스토어와 키 비밀번호 |
| `ANDROID_KEY_ALIAS` | 업로드 키 별칭 |

Google Play 인증에는 장기 JSON 키나 별도 GitHub 시크릿이 필요하지 않다. Google Cloud의 `card-draft-play-deploy` 프로젝트에서 Workload Identity Federation으로 GitHub의 임시 자격 증명을 발급한다. 권한은 `junho0831/card_draft` 저장소의 이 워크플로와 `main` 수동 실행 또는 `android-v*` 태그 푸시로 제한한다. Google Play Android Developer API와 IAM Service Account Credentials API를 사용할 수 있어야 한다.

Play Console의 **사용자 및 권한**에서 전용 서비스 계정에 `Card Draft: Three Factions` 앱의 테스트 출시 권한만 부여한다. 프로젝트 전체 IAM 역할이나 프로덕션 권한은 부여하지 않는다.

워크플로는 `$RUNNER_TEMP`에 Android 업로드 키스토어를 만들고 실행기 종료 시 폐기한다. OIDC 권한은 빌드가 아닌 Play 인증 작업에만 있으며, 인증 액션은 실행이 끝나면 임시 인증 파일을 삭제한다.

## 실행 방법

GitHub 저장소의 **Actions → Android Play Alpha → Run workflow**에서 다음 값을 입력한다.

- `version_name`: 사용자에게 표시할 버전. 예: `1.0.3`
- `version_code`: Google Play에서 한 번도 사용하지 않은 양의 정수. 비우면 UTC 날짜 `YYYYMMDD`를 사용한다.
- `track`: `alpha` 또는 `internal`
- `release_notes`: 한국어 변경사항
- `publish`: 끄면 빌드·검증·AAB 보관까지만 실행하고, 켜면 Google Play까지 배포한다.
- `verify_auth`: `main`에서 켜면 다른 배포 입력과 무관하게 Play 테스트 트랙 조회만 실행한다. AAB 빌드, 업로드, 심사 제출은 모두 건너뛴다.

`android-v1.0.3` 같은 태그를 푸시하면 `alpha` 트랙 배포가 자동 실행된다. 일반 브랜치 푸시로는 배포하지 않는다. 같은 UTC 날짜에 두 번 배포할 때는 태그 방식 대신 수동 실행에서 더 큰 `version_code`를 직접 입력한다.

처음에는 `publish`를 끈 채로 실행해 AAB를 확인할 수 있다. 실제 배포를 하려면 Play Console에서 대상 트랙 설정을 마치고 서비스 계정의 앱 권한을 확인한다. 비공개 테스트의 테스터 등록과 프로덕션 액세스 신청은 이 워크플로에서 자동화하지 않는다.

배포에 실패하면 Actions 로그의 첫 실패 단계부터 확인한다. Play Console에서 동시에 같은 앱의 출시 초안을 편집하면 Developer API의 edit이 무효화될 수 있으므로 자동 배포 실행 중에는 콘솔 출시 화면을 수정하지 않는다.
