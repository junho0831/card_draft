# 예산 0원 음원 제작

웹·모바일 배포를 위해 유료 API 대신 로컬 공개 생성 모델을 사용한다. 모델 가중치는 게임에 넣지 않고 생성한 오디오만 배포한다. 이전 `original_v1`의 주파수 합성과 다른 제작 경로다.

## 모델과 출처

2026-09-11 확인:

- 음악: [ACE-Step 1.5](https://github.com/ace-step/ACE-Step-1.5), MIT. 코드 `ca1e85fe9430179831e6bc6be790c332190a3866`, [가중치](https://huggingface.co/ACE-Step/Ace-Step1.5) `19671f406d603126926c1b7e2adc169acbcade22`.
- 효과음: [MOSS-SoundEffect v2](https://github.com/OpenMOSS/MOSS-TTS/tree/main/moss_soundeffect_v2), Apache 2.0. [가중치](https://huggingface.co/OpenMOSS-Team/MOSS-SoundEffect-v2.0) `e35df4d82fbe87fcd5d14e5d100e349c0c3c076d`.
- 특정 음악가·기존 곡 모방이나 참조 음원 입력 없이 텍스트 프롬프트로 생성한다. 라이선스의 사용 허용은 생성 결과의 독점성이나 저작권 비침해 보증을 뜻하지 않는다.
- ElevenLabs 무료 미리보기는 다운로드하거나 게임에 포함하지 않는다.

## 이 PC의 실행 환경

CPU: i3-1115G4, 메모리 32GB, CUDA GPU 없음. 게임 저장소 밖 `/home/junho/.cache/card-draft-audio/2026-09-11/acestep`과 `/home/junho/.cache/card-draft-audio/2026-09-11/moss`에 각각 가상 환경을 설치했다. 임시 폴더에서 작업한 뒤 이 캐시 경로로 옮겨, 재부팅 후에도 재사용할 수 있게 했다. 원본 음악과 효과음은 같은 상위 경로의 `masters-music`, `masters-sfx`에 별도로 보관한다.

음악 모델은 약 10GB, 효과음 모델은 약 11GB다. CPU에서는 생성과 오디오 디코딩에 시간이 걸린다. 환경마다 생성 시간과 결과는 달라질 수 있다. 실제 게임에는 Python이나 모델 실행이 필요하지 않다.

## 생성 명령

프로젝트 루트에서 실행한다. 해당 모델과 의존성 설치가 먼저 필요하다. 실행 도구는 모델 설치 도구가 아니며, 기존 게임 파일을 자동 교체하지 않는다.

```bash
/home/junho/.cache/card-draft-audio/2026-09-11/acestep/.venv/bin/python tools/generate_local_music.py \
  --model-root /home/junho/.cache/card-draft-audio/2026-09-11/acestep \
  --output-dir /home/junho/.cache/card-draft-audio/2026-09-11/masters-music/battle-preview \
  --duration 20

/home/junho/.cache/card-draft-audio/2026-09-11/moss/.venv/bin/python tools/generate_local_sfx.py \
  --model-root /home/junho/.cache/card-draft-audio/2026-09-11/moss \
  --output-dir /home/junho/.cache/card-draft-audio/2026-09-11/masters-sfx \
  --key all --steps 24 --skip-existing
```

출력 JSON에 프롬프트·시드·실행 시간·코드 버전을 남긴다. 생성 후 무음·손상·클리핑 검사와 반복 구간 편집을 거쳐 Ogg로 변환한다. 수치 검사와 실제 청감 평가는 별개이며, 미리듣기를 통해 최종 청감을 확인한다. 게임 검증은 반드시 별도 `--test-data-dir`를 사용한다.

초기 효과음 5종은 50스텝으로 생성했다. CPU에서 한 종류에 약 9~10분이 걸려, 후속 3종은 24스텝으로 생성했다. 각 파일의 JSON에 실제 설정을 남기며 기존 완료 파일은 해시가 일치할 때만 보존한다. CPU에서 사용하지 않는 어휘 확률 계산과 오른쪽 패딩의 텍스트 인코딩을 생략하되, 오디오 모델에 전달하는 텍스트 상태의 형태는 유지한다.

## 게임용 인코딩

```bash
/home/junho/.cache/card-draft-audio/2026-09-11/acestep/.venv/bin/python tools/package_model_music.py \
  --generation-dir /home/junho/.cache/card-draft-audio/2026-09-11/masters-music/battle \
  --output-dir assets/audio/local_models_v1 --name battle_base

/home/junho/.cache/card-draft-audio/2026-09-11/acestep/.venv/bin/python tools/package_model_music.py \
  --generation-dir /home/junho/.cache/card-draft-audio/2026-09-11/masters-music/menu \
  --output-dir assets/audio/local_models_v1 --name menu_theme

/home/junho/.cache/card-draft-audio/2026-09-11/acestep/.venv/bin/python tools/package_model_sfx.py \
  --source-dir /home/junho/.cache/card-draft-audio/2026-09-11/masters-sfx --output-dir assets/audio/local_models_v1
```

음악은 0.5초 교차 혼합으로 반복 경계를 편집한다. 효과음은 가장 강한 동작 구간을 선택해 타격이 늦게 들리는 것을 줄이고, 앞뒤 페이드와 음량 조절 후 Ogg로 인코딩한다. 새로운 음표나 주파수를 합성하는 처리가 아니다. 8종을 여러 게임 이벤트에서 공유하여 중복 파일을 줄인다. 완성된 오케스트라 곡 위에는 이전 합성 레이어를 겹치지 않고 상황에 따라 음량만 조절한다.

## 완료 결과와 검증 — 2026-09-12

- 메뉴곡 39.5초, 전투곡 59.5초, 효과음 8종을 `assets/audio/local_models_v1/`에 적용했다. 총 Ogg 용량은 1,989,054바이트다.
- 효과음: 검격, 카드, 소환·갑옷, 회복, 마법 타격, 사망, 골드, 클릭. 39개 게임 이벤트가 이 8종을 공유한다.
- 원본과 인코딩 파일의 유한 샘플·무음·클리핑·길이·SHA-256을 확인했다. 결과는 음원 폴더의 `validation.json`에 있다.
- Godot 4.6.3 전체 검사: **PASS 1261 assertions**. 기존 종료 시 CanvasItem 14개 및 ObjectDB 누수 경고는 남아 있다.
- Web 릴리스 내보내기 성공. 새 라이선스 파일을 포함하며 이전 `original_v1` 팩과 외부 원본 WAV는 내보내기에서 제외한다.
- 웹 PCK를 별도 빈 프로젝트 경로에서 실제 엔진으로 실행했다. 모든 런타임 효과음이 새 팩을 사용하는지, 이전 팩이 제외됐는지, 메뉴→전투→메뉴 및 빠른 전투 재진입이 정상인지 통과했다.
- Master 버스 녹음: 약 10.94초, 최대 진폭 0.6635, RMS 0.1265. 미리듣기는 `build/audio-preview/game-audio.mp3`에 있다. 실제 단말의 청감 평가와 브라우저별 재생 검증을 대신하는 결과는 아니다.
- 검증 저장 경로: `/tmp/card-draft-model-audio-tests-final-0912`, `/tmp/card-draft-model-pack-audio-final-0912`. 실제 런·프로필 저장을 사용하지 않았다.

패키지 재생 검사 예시(웹 PCK를 먼저 내보내야 한다):

```bash
xvfb-run -a godot --path /tmp/card-draft-model-pack-check \
  --main-pack /tmp/card-draft-model-web-final/index.pck \
  -s res://tests/godot/capture_original_audio.gd -- \
  --test-data-dir=/tmp/card-draft-model-pack-audio-check --expect-model-pack
```
