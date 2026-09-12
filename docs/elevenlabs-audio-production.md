# 전문 모델 음원 제작 기록

2026-09-10. 사용자가 직접 합성한 주파수 기반 음원을 거절하고 전문 음악·효과음 생성 서비스 사용을 요청하여 ElevenLabs 웹에서 제작했다. 기존 Python 합성 파일과 구분한다.

## 실제 생성 완료

- 전투곡: **Tactician of the Ruined Gate**, Eleven Music v2, 60초, 1개 변형, 900 크레딧.
- 결과: https://elevenlabs.io/app/music/project/DRRge3qAObU2mfpdxGXC?selectedSongId=OfftpsU1D01dvsKtRPvF
- 검·방패 충돌 효과음: 2초 후보 4개, 한 번 생성에 200 크레딧.
- 효과음 기록: https://elevenlabs.io/app/sound-effects/history
- 음악과 효과음 첫 후보의 브라우저 재생 상태를 확인했다. 청감 평가를 완료했다는 뜻은 아니다.
- 작업 후 표시 잔여 크레딧: 8,900.
- 효과음 자동 공개 공유를 해제하고 생성했다.

## 현재 적용 상태

로그인 계정은 Free 요금제다. 음악 다운로드 제한과 게임 이용 조건 때문에 생성 결과를 다운로드하거나 게임에 연결하지 않았다. 정식 음원 교체는 미완료다. 새로운 구독을 구매하거나 결제하지 않았다.

공식 약관 확인: https://elevenlabs.io/eleven-music-model-specific-terms (2026-05-26 개정, 2026-09-10 확인). Free는 음악 다운로드를 허용하지 않는다. 일반 셀프서비스 음악 요금제의 Media Rights는 Studio Games를 제외한다. 이 문서에서 Studio Games는 판매·광고 등으로 수익화하면서 둘 이상의 플랫폼에 제공하는 게임으로 정의한다. 단순히 소규모 개발이라는 이유만으로 이 제한에서 제외된다고 가정하지 않는다.

사용자는 웹·모바일 배포, 예산 0원을 확정했다. ElevenLabs 유료 구독은 진행하지 않는다. 로컬 공개 모델로 제작 경로를 변경하며, ElevenLabs 미리보기는 배포 파일에 포함하지 않는다. 사용 권한 확인은 저작권 비침해나 독점성을 보증하는 것과는 다르다.

## 전투곡 프롬프트

Instrumental dark fantasy tactical card battle score, 60 seconds. Rich lifelike orchestral recording: expressive low cellos and violas play a measured ostinato, French horns answer with a restrained heroic motif, bass drum and frame drums give weight, subtle hammered dulcimer glints. 96 BPM, D minor, ominous ruined castle at dusk, strategic tension with human warmth. First 8 seconds establish a clear theme, middle develops harmony and counter-melody, last 8 seconds return naturally to the opening energy for a game loop. Detailed acoustic instrument timbres, dynamic performances, cohesive cinematic mix, spacious but controlled reverb, room for combat sound effects. No vocals, no choir, no electronic beeps, no synth lead, no EDM, no trailer riser or abrupt final hit. Compose an original melody.

## 검격 효과음 프롬프트

Single cinematic fantasy sword strike against a heavy wooden shield reinforced with steel. Fast close-up blade whoosh, immediately followed by a weighty wooden thud and crisp steel clang, tiny chainmail rattle, short natural room decay. Detailed realistic foley, tactile and punchy, clean isolated one-shot under 1.2 seconds, silence before and after. No music, no voice, no repeated impacts, no electronic beeps.
