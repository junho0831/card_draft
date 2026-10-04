# Choice depth: paired playthrough verification

## Agency Agents UI/UX 개선

- Agency Agents 앱에서 프로젝트의 UI Designer 역할을 설치하고 지침을 적용했다.
  UX Architect 및 UI Finish-Gate Reviewer의 정보 계층·반응형·증거 중심
  검토 기준도 확인했다. 웹 전용 지침은 Godot 프로젝트에 적용하지 않았다.
- 전투 정보는 현재 위협과 대상별 공격 결과를 구분한다. 양쪽 잔여 체력은
  나란히 배치하고, 처치·돌파·마나 환급·반격과 제거되는 개별 위협을 별도 행에
  표시한다. 모든 수치는 기존 전투 계산에서 읽고 추가 시뮬레이션을 하지 않는다.
- 보상·상점 카드 상세는 구조 데이터로 빌드 점수·활성 상태 및 비용 분포를
  현재/추가 후 열에 표시한다. 변경된 값만 강조하며 최선의 선택을 평가하지 않는다.
  구매/획득·닫기 버튼은 스크롤과 분리해 고정하고 기존 가격과 아트를 유지한다.
- 전체 검사 **2361개 통과**, 오류 로그 없음.
  `/tmp/card-draft-agency-suite-final.log`.
- 844x390 및 1280x720 직접 입력·정보 보기·닫기·취소·저장·난수 보존과
  비교 텍스트 가로 범위/줄바꿈 높이 검증 통과.
  `/tmp/card-draft-agency-mobile-final`, `/tmp/card-draft-agency-desktop-final`.
- 경제 상세의 양쪽 크기 캡처, 구조 데이터 일치, 겹침, 고정 버튼, 스크롤,
  구매 가격/장수 및 닫기 검사 통과. 담당 UI Designer 검증 결과 **13068개
  단언 통과**이며, 셀 간 겹침의 쌍별 검사도 이 숫자에 포함된다.
  `/tmp/card-draft-economy-detail-ready-captures-20261004`.
- 데스크톱 상점 preview와 보상 본화면에도 같은 비교표를 적용했다.
  선택 변경 시 이전 표가 교체되고 스크롤은 상단으로 돌아간다.
  최종 경제 검사는 headless **21626개**, 렌더링 **21678개** 단언 통과.
  `/tmp/card-draft-economy-desktop-final-verified-20261004`.
  이전 실행의 닫기 입력 실패는 동일 소스 재실행에서 통과했으며, 입력 검사
  변동성을 숨기지 않는다.
- 데스크톱 전투 정보의 기본 창 버튼 대신 전용 overlay를 사용해 닫기 목표를
  96x52px로 확보했다. 직접 클릭·Escape·취소·저장·난수 검사 통과.
  `/tmp/card-draft-agency-desktop-finish`.
- UI Finish-Gate Reviewer 최종 정적 검토 **PASS**, critical 0건. 실제 desktop
  상점/보상 본화면 및 모바일 상세와 전투 비교 캡처를 검토했다. 자동 입력 결과는
  별도 검사의 증거이며 정적 화면 검토만으로 실기기 터치를 검증하지 않는다.
- 최종 통합 전체 검사 **2361개 통과**, `/tmp/card-draft-agency-complete-suite.log`.
  개선본 iPhone 빌드·설치·실행 성공, PID 5621. 최종 캡처는 홈 화면이며 앱
  프로세스는 남아 있다. 최신 UI의 실기기 전투 화면·터치는 미검증이다.
- 아래 공식 비교는 이전 고정 소스 기준이다. UI 개선으로 이전 종료 오류가
  해결됐다고 주장하지 않는다. 실제 기기의 전투 터치 검증도 별도로 기록한다.

## 10월 4일 후속 검증

- 전체 검사 재실행: **2359개 단언 통과**, 종료 코드 0.
  경로: `/tmp/card-draft-choice-resume-suite3`.
- 안내 만료 타이머의 콜백이 전투 객체를 강하게 참조하는 것을 방지하도록
  약한 참조를 사용했다. 타이머가 대기 중인 상태에서도 전투 객체가 해제되는
  회귀 검사를 추가했다. 전투 수치와 추천 봇 정책은 변경하지 않았다.
- 경제 검사 **160개**, 경제 화면 배치 검사 **82개** 재실행 통과.
  경로: `/tmp/card-draft-choice-resume-economy`,
  `/tmp/card-draft-choice-resume-economy-layout`.
- 모바일 844x390 및 데스크톱 1280x720의 정보 보기, 직접 입력, 취소와
  저장 취소 상태 검사를 다시 통과했다.
  경로: `/tmp/card-draft-choice-resume-mobile`,
  `/tmp/card-draft-choice-resume-desktop`.
- 최신 소스로 iOS 내보내기, Xcode 빌드, 기존 앱에 덮어 설치 및 실행 성공.
  잠금 해제 후 실행 캡처에 실제 가로 메뉴가 보인다.
  `build/ios/choice-device-resume-launched.png`.
  검은 잠금 화면 캡처는 앱 오류의 증거가 아니다.
- 위 후속 수정은 아래 공식 480개 비교의 고정 스냅샷에 포함되지 않는다.
  기존 보고서의 실패 판정을 후속 검사로 덮어쓰지 않는다.
- `elf_cycle`의 동일 40런을 후속 수정 상태로 재실행했다. 완주 40/40,
  기존 보고서와 케이스·전투 데이터가 모두 일치했다. 그러나 종료 리소스 오류는
  여전히 재현되었다. 안내 타이머 회귀 수정만으로 전체 종료 오류가 해결됐다고
  판단하지 않는다. 로그: `/tmp/card-draft-choice-resume-cycle-final.log`.

## 검증 요약

- 메인 에이전트 보고: 최종 전체 테스트 **2358개 통과, 종료 코드 0**.
  증거 경로: `/tmp/card-draft-choice-suite-final`.
- 메인 에이전트 보고: 모바일 844x390 캡처에서 실제 입력 경로, 선택 취소,
  게임플레이 난수 보존 및 하단 스크롤 검증 통과.
  증거 경로: `/tmp/card-draft-choice-mobile-final`.
- 메인 에이전트 보고: 데스크톱 1280x720 캡처 검증 통과.
  증거 경로: `/tmp/card-draft-choice-desktop-verified`.
- 경제 검증은 별도 에이전트 담당: 160개 단언 및 초기 레이아웃 64개 검증 통과로
  보고됨. 모달 닫기 버튼 수정 후 최종 레이아웃 **82개 검증 통과**로 보고됨.
  캡처 경로: `/tmp/card-draft-economy-close-qa`.
- 실기기 전달 기록 확인: 10월 4일 16:22 새 PCK 내보내기, 16:23 Xcode 빌드,
  기존 저장 데이터를 유지한 설치 및 `com.junho.carddraft` 실행 성공.
  진단 재실행 PID는 5287. 내보낸 PCK와 앱에 포함된 PCK 해시가 일치한다.
  [실기기 전달 증거](../build/ios/choice-device-verification.md).
- 기기 캡처 두 장이 검은 화면이며 백라이트 꺼짐이 확인됨.
  **실제 화면·물리 터치·선택 취소는 실기기에서 미검증**이다.
  데스크톱 및 모바일 크기 뷰포트의 입력 검증과 구분한다.
- 공식 비교는 동일 하네스로 **480개 케이스 실행 완료**: 기준선 240개,
  현재 버전 240개. 기준선은 239승과 행동 제한 중단 1건, 현재는 240승이다.
  과거 52회 불완전 보고서와 별도 진단 실행은 공식 행렬에 포함하지 않는다.
- 현재 버전은 정체 0건, 완료된 런의 중복 정산 검증은 양쪽 모두 통과했다.
  다만 기준선 제한 중단 및 양쪽 종료 리소스 오류가 있어 **전체 QA 통과로
  표시하지 않는다**. 모든 프로세스와 별도 진단은 종료되었다.
- 사용자 저장 데이터는 사용하지 않고 별도 임시 프로필로 실행한다.
  후속 UI 수정은 고정된 현재 버전 스냅샷에 반영하지 않는다.

## 최종 비교 결과

Godot 4.6.3 headless, 시드 20261004~20261023, 6개 전략 x 일반/엘리트.
각 전략/경로 조합에 중복 없는 시드 20개가 모두 포함된다.

| 지표 | 기준선 | 현재 버전 |
| --- | ---: | ---: |
| 평가된 케이스 | 240 | 240 |
| 완주/승리 | 239 | 240 |
| 패배 | 0 | 0 |
| 안전 제한 중단 | 1 | 0 |
| 중복 정산 검증 | 완주 239/239 통과 | 240/240 통과 |
| 기록된 전투 | 1439 | 1440 |
| 평균 플레이어 턴 | 2.649757 | 2.652778 |
| 첫 턴 승리 | 150 (10.424%) | 153 (10.625%) |
| 피니셔 사용 전투 | 849 | 862 |
| 전투 최대 봇 행동 수 | 160 | 60 |
| 실행 전후 소스 해시 일치 | 통과 | 통과 |

평균은 기록된 모든 전투의 관측값이며 기준선의 미완료 26턴 전투도 포함한다.
평균 턴과 첫 턴 승리 비율 차이는 작다. 이 고정 정책 결과만으로 인간의 선택
깊이나 재미가 개선됐다고 단정하지 않는다. 개별 그룹 12개와 전체 케이스/전투
데이터는 아래 JSON에 보존한다.

- 기준선: `/tmp/card-draft-choice-qa-baseline-v2-20261004/report.json`
- 현재: `/tmp/card-draft-choice-qa-current-20261004/report.json`
- 비교: `/tmp/card-draft-choice-qa-comparison-20261004.json`
- 동일 하네스 SHA-256:
  `6832248f2063a4ef245d67f68235721d2ec572ff5c9f332a32ab5a5c0935b20f`

양쪽 `matrix_complete` 및 `source_unchanged`는 true다. 하지만 `passed`는
양쪽 모두 false이며 비교 명령도 종료 코드 1을 반환했다. 이는 부분 행렬이나
해시 불일치가 아니라 아래 실제 검출 사항을 보존한 엄격한 판정이다.

### 제한 중단 재현

기준선 `undead_blood / seed=20261011 / elite=true`는 두 번째 막의 엘리트
전투에서 26턴, 160행동 제한에 도달했다. 적 체력 11, 플레이어 체력 19로
전투가 끝나지 않았으며 60초 제한으로 중단된 사례가 아니다. 이 런은 정산에
도달하지 않았으므로 중복 정산 검증은 미실행이지 정산 실패 1건이 아니다.

같은 시드의 일반/엘리트 2회를 별도 재실행하여 동일한 엘리트 중단을 재현했다.
증거: `/tmp/card-draft-choice-baseline-stall-diagnostic/playthrough_metrics.json`
및 `/tmp/card-draft-choice-baseline-stall-diagnostic.log`.
현재 버전의 대응 시드는 승리했고 정산 검증도 통과했다. 이후 적/보상 난수
경로는 버전별로 달라지므로 완전히 같은 전투가 해결됐다는 뜻은 아니다.

### 종료 정리 오류

기준선 `elf_ambush`, 현재 `human_legion` 및 `elf_cycle`의 종료 로그에
`1 resources still in use at exit`가 기록됐다. 이 세 프로세스 자체의 종료
코드는 0이지만 검증기는 로그 오류를 별도로 실패 판정한다. 기준선
`undead_blood`의 종료 코드 1은 위 제한 중단 때문이다.

현재 `elf_cycle` 40회를 상세 로그로 다시 실행한 결과 케이스와 전투 기록이
공식 보고서와 정확히 일치했으며 종료 오류도 재현됐다. 상세 로그는 남은
리소스로 `src/services/relic_service.gd`와 `SceneTreeTimer`, `RefCounted`를
보여준다. 참조가 남는 정확한 원인은 아직 확정하지 않았고, 프로덕션 코드는
수정하지 않았다. 이미 기준선에서도 나타나므로 신규 변경만의 회귀로 단정하지
않는다. 별도 재현은 공식 480개 집계에서 제외한다.

## Scope and status

The comparison uses the existing recommendation bot without changing its policy or
production gameplay. Each version runs seeds **20261004 through 20261023**, all
six starting strategies, and both route modes: **240 evaluated cases per version**.
Safety-stopped cases remain explicit failures, not completed runs.
Normal means the existing first-branch policy; elite means prefer an elite branch
when the current layer offers one. It does not mean every encounter is elite.

- Baseline source: `/tmp/card-draft-choice-baseline` (created by the main agent
  from the pre-feature working tree, including the user's existing uncommitted
  CC0 work).
- Baseline output: `/tmp/card-draft-choice-qa-baseline-v2-20261004`.
- Baseline status: all 240 cases evaluated; 239 completed, one reproducible
  action-limit stop, plus a shutdown resource-error finding.
- Current version: snapshot verified after the main agent reported 2349 passing
  suite tests and integration readiness; benchmark launched with one worker
  alongside two baseline workers. After the main agent confirmed resource
  pressure had eased, 34 completed current-version cases were retained and the
  batch resumed with three workers, with matching source/harness/configuration.
  The deliberate `-15` worker exits are retained as orchestration evidence, not
  gameplay failures. Final status: all 240 runs completed with settlement checks;
  two shutdown resource-error findings keep the strict QA result non-passing.
- Shopping transaction tests belong to the economy agent. This bot leaves shops.
- No commits or pushes are part of this verification.

The first baseline launch (`/tmp/card-draft-choice-qa-baseline-20261004`) used six workers. At 52 completed cases, it was
deliberately stopped to reduce observed system memory contention with the main
agent's test suite, then resumed with two workers and identical limits/policy.
All six initial exits were `-15` (intentional termination), not gameplay failures.
The initial production-source integrity check passed with SHA-256
`d38139bb3599016858f3127c56c3bb1c492205f8ad80f6139cd6da6635ab3a05`.
The completed cases remain in each strategy's checkpoint, and original logs are
preserved. The interrupted in-progress case for each strategy is replayed.
That resume exposed a harness-only checkpoint comparison bug: Godot JSON numbers
were compared as dictionary values against integer configuration values. The
configuration check now explicitly converts numeric fields to integers. The
52-case report is retained as incomplete evidence (52 wins, 312 battles, no
stalls, 52 duplicate settlement passes); it is not the final baseline. A fresh
240-case batch uses the corrected harness throughout.

After the main agent's final readiness signal, the current `src`, `data`,
`assets`, `tests`, and `project.godot` were copied into
`/tmp/card-draft-choice-current`. Current-version runs use that immutable source
snapshot, so later unrelated workspace edits cannot invalidate the comparison.
Source before copying, snapshot, and source after copying all matched SHA-256
`361c7c00ddd42c89f9e278d47de7cca5f3ce642fec2dae9ddf908761bc200b11`.
The manifest is `/tmp/card-draft-choice-current-snapshot-manifest.json`.
After this freeze, the main agent reported a UI-only correction to the economy
modal's blank/narrow Close button in `src/ui/components/economy_detail_view.gd`. It is intentionally
excluded from the already-started snapshot; the main agent confirmed reward
rules are unchanged. Gameplay equivalence is the main agent's stated scope of
that later patch, not a separate result of this frozen benchmark. Visual
correctness of the later patch remains with the economy agent.
Direct file comparison confirmed exactly three added presentation assignments:
horizontal `SIZE_SHRINK_BEGIN`, `clip_text = false`, and
`OVERRUN_NO_TRIMMING`. No reward or transaction code differs in this file.
Frozen file SHA-256:
`f96cf00ca8b98e0a4a852fc00626713229e2fc681567b8e5f91a2e5392b75678`.
Final workspace file SHA-256:
`4767a49bcfee0a90f90f4f55bbf646900f4c1b2ad4af8b2a205a80962f084d3a`.

A second post-freeze fix in `src/ui/components/landscape_battle_view.gd` adds
`_store_battle_snapshot()` after attacker-selection cancellation in the UI
button and back-navigation paths. Direct diff inspection confirmed these are
the only changes in that file. The bot does not press those UI controls or
resume a saved mid-battle selection; its internal recommendation executor is
unchanged. That UI persistence regression and its new capture assertion belong
to the main agent's separate tests, not this frozen benchmark.
Frozen file SHA-256:
`cf097d8105ee9c11b75595003038c3e4eb1e4ed67357d786efe1e562c85f8f8c`.
Post-fix workspace file SHA-256:
`8768f76c16e6933c363b7294ba2792b65a538496016d44078a356badc5079032`.

## Reproduction

From `/Users/parkjunho/card-draft`:

```sh
python3 tools/compare_choice_runs.py run \
  --project /tmp/card-draft-choice-baseline \
  --output /tmp/card-draft-choice-qa-baseline-v2-20261004 --jobs 2

# Only if a later batch needs checkpoint resumption:
python3 tools/compare_choice_runs.py run \
  --project /tmp/card-draft-choice-baseline \
  --output /tmp/card-draft-choice-qa-baseline-v2-20261004 --jobs 2 --resume

# Only after integration is ready:
python3 tools/compare_choice_runs.py run \
  --project /tmp/card-draft-choice-current \
  --output /tmp/card-draft-choice-qa-current-20261004 --jobs 1

# Used after resource pressure eased; preserves the first 34 completed cases:
python3 tools/compare_choice_runs.py run \
  --project /tmp/card-draft-choice-current \
  --output /tmp/card-draft-choice-qa-current-20261004 --jobs 3 --resume

python3 tools/compare_choice_runs.py compare \
  --baseline /tmp/card-draft-choice-qa-baseline-v2-20261004/report.json \
  --current /tmp/card-draft-choice-qa-current-20261004/report.json \
  --output /tmp/card-draft-choice-qa-comparison-20261004.json
```

The helper defaults to 20 seeds beginning at 20261004. Direct probe invocations
retain their old defaults of 10 seeds beginning at 20260909. Both accept
`--seed-count` and `--seed-start`; direct probes still require `--strategy` for
the strategy matrix and an absolute `--test-data-dir` after Godot's `--` separator.

The helper normally requires a fresh output directory, copies the exact same modified
probe into the supplied baseline snapshot, and imports resources headlessly.
Each strategy owns separate `progress.json`, `playthrough_metrics.json`, game
profile, run state, and engine log files inside the output directory. GameStorage
routes saves via the explicit test directory; the player's normal saves are not
used. A checkpoint records its configuration and initial profile; mismatched
configurations are rejected. A direct invocation with the same configuration can
resume completed cases, restoring the original profile before remaining cases.
After a stopped batch has written `report.json`, the helper's `--resume` option
continues the same output directory only when the source hash, harness hash,
seed configuration, and original source-integrity check match. Prior process
exit evidence is retained; logs are appended. This permits smaller worker counts
after resource contention without changing the bot or per-process/battle limits.

## Checks and evidence

The current-version `human_legion` and `elf_cycle` processes completed all 40
cases each and returned exit code 0, but their logs then reported ObjectDB leakage and
`ERROR: 1 resources still in use at exit`. This is retained as an engine-error
finding rather than hidden by the successful gameplay rows. A separate fresh
two-case replay of seed 20261023 (normal/elite), using the same frozen current
snapshot and verbose logging, completed with exit code 0 and no such message.
Its log is `/tmp/card-draft-choice-current-exit-diagnostic.log`; its cases are
excluded from the official matrix. Since `elf_cycle` also exhibits the finding,
it is not established as specific to checkpoint resumption. A separate full
40-case `elf_cycle` verbose diagnostic is recorded at
`/tmp/card-draft-choice-current-cycle-exit-diagnostic.log`; it is also excluded
from the official matrix. The root cause remains unconfirmed.
The same shutdown finding also occurs in the pre-feature baseline's
`elf_ambush` process, after 40 completed cases and exit code 0. It is therefore
not established as a regression introduced by the new gameplay changes.

- Exact, unique `(strategy, seed, elite)` coverage, not merely a total row count.
- Every run reaches the result screen. A stalled battle aborts that case rather
  than repeatedly retrying it in the outer map loop.
- Existing battle bounds remain 160 bot actions and 60 seconds; each strategy
  process also has a hard 1800-second timeout. Import is capped at 180 seconds.
  The helper terminates a process when its log reports a script/engine error.
  No new `assert()` calls are introduced. The initial baseline launch predates
  the immediate log-error watchdog; its logs are monitored while it runs.
- After each completed run, `_finish_run()` is invoked a second time. The entire
  profile and run dictionaries must remain unchanged. This verifies immediate
  duplicate settlement, not a simulated process crash or disk-reload recovery.
- Per-run outcome, HP, visited nodes, completion, stalls, and settlement result.
- Per-battle outcome, turns, first-turn win, finisher usage, net HP lost, action
  count, strategy counters, enemy/tier, and route/seed identity.
- Stable sorting and JSON key ordering; reports omit wall-clock performance
  measurements and run IDs. Strategy-level raw saves contain normal timestamps.
- Harness SHA-256 must match before comparison. Production source/data/assets
  hashes are recorded and checked before/after a run; generated `.uid` and
  `.import` metadata are excluded. Import cache changes are expected.
- A nonzero process exit, script/engine error, incomplete matrix, stall, or
  duplicate settlement failure causes the helper to report failure.

## Integration dependencies and interpretation

The battle UI may remove recommendation buttons, but the unchanged QA bot still
requires `_recommended_action_state()` and `_execute_recommended_action(action)`.
Its existing ally-selection path also requires `_confirm_ally_target(id)` and
`_cancel_ally_selection()`, plus `pending_action`, `player`, `opponent`,
`current_player`, `input_locked`, and `battle_state`. Run flow, reward, event,
rest, and shop internal methods used by the probe must also remain callable.

No action-ranking or target-selection changes are included. The bot still picks
the first reward/relic, uses its existing event option selection, leaves shops,
and heals at rests. Thus this slice measures fixed-policy completion and battle
outcomes; it does not establish human choice quality, shopping balance, optimal
play, or UI usability. Paired seeds align initial random seeds, but production
changes can consume RNG differently, so later encounters are not guaranteed to
have identical random trajectories. Deterministic serialization alone does not
prove repeat-run gameplay determinism.
