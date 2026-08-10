# Fable 5 재점검 결과 (2026-08-10) — 수정 전 점검 기록

전 코드베이스 재감사 워크플로우(68개 에이전트 계획)가 세션 한도로 **9개 완료 시점에 중단**됐다.
완료된 9개 에이전트가 남긴 **원시 발견 26건**을 여기 보존한다. 교차 검증(반박 담당) 전이므로
개별 건은 오탐 가능성이 있다 — 단, ★ 표시는 이 세션에서 직접 사실 확인을 마친 것.

- 워크플로우 재개(저녁, 세션 한도 해제 후):
  `Workflow({scriptPath: '/Users/djj/.claude/projects/-Users-djj-projects-gisa-pass-master/de492df6-15d1-4e84-a5a7-3b7b400eb250/workflows/scripts/gisa-fable5-full-reaudit-wf_70f6c22e-2f6.js', resumeFromRunId: 'wf_70f6c22e-2f6'})`
  — 9개 캐시 재사용, 나머지 59개 실행 + 검증 + 종합 리포트.
- 원본 저널: 세션 디렉터리 `subagents/workflows/wf_70f6c22e-2f6/journal.jsonl`

## 오늘 밤 수정 우선순위 (제안)

1. **★ iOS 심사 리스크** — #14 PrivacyInfo.xcprivacy 미등록 (커밋 71b9634 이 무효였음)
2. **결제 신뢰** — #1 Android 지문, #2 복원 침묵 실패, #3 iOS 로그인 팝업 반복
3. **채점 정오** — #18 괄호 다중항목 오답 처리 (정답을 오답 처리, 유료 유저 직격)
4. **데이터 무결성** — #10 부분 실패에도 리비전 기록, #11 getter 경합, #12 본문 수정 시 중복
5. **수익 보호** — #5 _retry 응시권 이중 소모, 직접 발견 D3 (past_exam _adCounter)
6. 나머지 성능·표기·테스트 공백 건

---

## A. 결제 (purchase_service.dart)

### 1. [high] Android 기기 지문이 Build.ID — OS 업데이트마다 결제 유저가 무료로 강등
`_deviceFingerprint()`가 Android에서 `(await info.androidInfo).id`(= Build.ID)를 쓴다.
이 값은 OS 업데이트·보안패치마다 바뀌고 같은 펌웨어의 모든 기기에서 동일하다.
`_loadCachedPremium()`은 owner != current 시 프리미엄 캐시를 즉시 삭제하므로,
OS 업데이트 → 다음 실행이 오프라인/Play 장애면 결제 유저가 광고 보는 무료 상태로 강등.
백업 복제 감지라는 본래 목적도 Android에선 무력(같은 빌드 기기끼리 지문 동일).
→ ANDROID_ID 계열 안정 식별자로 교체하거나 Android는 지문 검사 생략. (purchase_service.dart:166)

### 2. [high] `_available=false`면 '구매 복원' 버튼이 침묵 무시 — 화면은 '복원 중...' 표시
`restorePurchases()`가 `if (!_available) return;`인데 `_available`은 시작 시 1회만 결정.
`buyPremium()`은 `reloadProducts()`로 재시도하지만 복원엔 없다(복붙 후 한쪽만 수정 패턴).
subscription_screen `_onRestore()`는 결과 무관 '구매 복원 중...' 스낵바 → 재설치 유저의
유일한 수동 복구 경로가 에러 표시 없이 실패. (purchase_service.dart:270)

### 3. [medium] iOS App Store 미로그인 유저에게 자동 복원 로그인 팝업이 매 실행 반복
`_autoRestoreOnce()`가 성공 후에만 플래그를 기록하므로, 로그인 팝업을 취소하면(예외)
플래그 미기록 → 매 실행 팝업 반복. '취소 실패'와 '네트워크 실패' 구분 또는 실패 횟수 상한 필요.
(purchase_service.dart:121)

### 4. [low] 관리자 기기 분기가 purchaseStream 구독 전에 return
관리자 기기에선 결제 콜백이 영영 안 옴 → 그 기기에서의 결제 QA가 무의미. (purchase_service.dart:70)

## B. 시작 성능 (main.dart / database_service.dart)

### 15. [high] runApp 이전에 스토어 네트워크 왕복 2회를 타임아웃 없이 await
`purchaseService.initialize()`가 queryProductDetails + restorePurchases까지 첫 프레임을
인질로 잡는다. 첫 프레임 전에 필요한 건 `_loadCachedPremium` 하나뿐. 특히 **최초 설치 첫 실행**에서
스플래시 위로 Apple ID 로그인 시트가 뜰 수 있다. (main.dart:49)

### 17. [medium] AdMob SDK·스토어·DB 초기화를 직렬 await — 콜드 스타트가 세 지연의 합
`MobileAds.initialize()`(수 초 가능)는 runApp 전에 있을 이유가 없다. DB 워밍업만 남기고
병렬화/프레임 이후로. (main.dart:33)

### 13·16. [medium] 신규 설치·v6 마이그레이션이 리비전을 기록하지 않아 첫 실행에서 1000문항 동기화 중복 수행
`_onCreate`/v6 마이그레이션이 `app_meta`에 리비전을 안 남겨 직후 리비전 검사가 같은 동기화를
한 번 더(신규 설치 2회, v1→v6는 3회) 돈다. 데이터는 옳지만 첫 실행 스플래시가 배가.
→ 시딩/마이그레이션 완료 시점에 리비전 기록. (database_service.dart:50)

## C. 데이터 무결성 (database_service.dart)

### 10. [high] 부분 동기화 실패에도 리비전이 기록됨 — 침묵형 영구 실패
`syncQuestionsFromAssets`가 파일별 예외를 전부 삼키므로 일부 실패해도 호출자는 성공으로 보고
리비전을 기록 → 그 기기에서 해당 리비전의 수정분이 영영 재시도 안 됨. 81-82행 주석 계약과 정반대.
→ 실패를 전파하거나 실패 시 리비전 기록 생략. (database_service.dart:384)

### 11. [medium] database getter 경합 — 동시 2회 초기화 시 문항 중복 INSERT
getter에 락이 없어 null 창(동기화 시간 전체)에서 `_initDB` 2회 → 양쪽 다 신규 문항 INSERT →
영구 중복. main의 워밍업이 실패를 삼키면 경합 경로가 살아남. → Future 메모이제이션
(`_opening ??= _initDB()`). (database_service.dart:24)

### 12. [medium] questionText/codeSnippet 수정 리비전은 갱신이 아니라 영구 중복 생성
동기화 키가 (본문, 스니펫)이라 본문 오타를 고치면 옛 행 방치 + 새 행 INSERT. 삭제 경로 없음.
현재 diff 0건이라 미발화 상태지만, 메커니즘이 안내하는 사용법에서 즉시 터지는 지뢰.
→ 안정적 문항 ID 도입 또는 본문 수정 시 절차 문서화. (database_service.dart:349)

## D. iOS 스토어 컴플라이언스

### 14. [high] ★확인됨 — PrivacyInfo.xcprivacy가 pbxproj에 미등록, 번들에 절대 포함 안 됨
`grep PrivacyInfo project.pbxproj` → 0건, fileSystemSynchronizedGroups도 0건.
파일 내용은 완벽하지만 Xcode가 번들에 복사하지 않으므로 커밋 71b9634의 수정이 **no-op**.
ATT 호출 + 추적 라벨과 매니페스트 부재의 모순이 제출 바이너리에 그대로 남는다.
→ Runner 타깃 Resources에 등록(PBXFileReference + PBXBuildFile + Resources 페이즈)
후 아카이브 내 `.xcprivacy` 존재 확인. (ios/Runner.xcodeproj/project.pbxproj)

## E. 채점 (answer_checker.dart) — 에이전트가 python3 전수 대입으로 확정 주장

### 18. [high] 항목별 설명 괄호가 붙은 다중 항목 정답에서 교과서적 정답이 오답 처리 (최소 5문항)
괄호 게이트가 '답 전체에 ( 1개 + 끝이 )'일 때만 열려서, 항목마다 괄호가 붙은
`POST(Create), GET(Read), PUT(Update), DELETE(Delete)` 류에서 괄호 뺀 정답이 전부 오답.
확정 문항: short_answer#355·#354·#344, sql#109·#164 (sql은 타입 자체가 게이트 차단).
유사 영향 #277·#321·#342·#353. (answer_checker.dart:103)

### 19. [high] C의 +32 대소문자 변환 문항에서 입력 그대로 옮겨 적어도 정답 (2문항)
`_isCaseSensitive` 마커에 '+32'/'-32'/toupper/tolower 부재 → c#12·#128에서 'ABCDE' 입력이
정답 'abcde'로 접혀 정답 처리. 출제 의도(대소문자 변환) 무력화. (answer_checker.dart:151)

### 20. [medium] '(또는 Deployment)' 산문형 괄호 오해석
short_answer#347: 의도된 대안 'Continuous Deployment'는 오답, 무의미한 '또는 Deployment'
단독 입력은 정답. (answer_checker.dart:112)

### 21. [low] code_reading 대소문자 전면 접기 — 케이스가 출제 포인트인 출력도 관대 채점 (75문항)
java enum name() 출력 'WED', boolean 'true' 등 실기 채점은 케이스를 구분하는 문항 포함.
설계 트레이드오프 성격 — 마커 확장 여부 판단 필요. (answer_checker.dart:35)

## F. 화면·UX

### 5. [medium] ai_prediction `_retry` 재진입 가드 없음 — 연타 시 응시권 2회 소모 + Timer 영구 누수
홈 화면은 같은 이유로 가드를 세웠는데(`_isNavigating`) 결과 화면 `_retry`만 빠짐.
연타 → consume 2회(광고로 얻은 응시권 증발) + 첫 Timer.periodic 참조 유실로 세션 내내 발화.
(ai_prediction_screen.dart:173)

### 7. [low] 쿼터 다이얼로그 '광고 준비 중...' 라벨이 로드 완료 후에도 갱신 안 됨
빌드 시점 1회 결정, 리빌드 없음 → 유저가 '안 되는구나' 하고 이탈하는 경로.
(exam_quota_dialog.dart:67)

### 8. [medium] 추정 회차 전환 시 '예정' 표시가 어디에도 없음 — `isExamDateConfirmed` 미배선
게터는 있는데 소비처가 테스트 1곳뿐. 추정 날짜가 확정 일정과 동일 형식으로 표시되고
D-Day 알림도 추정 날짜로 단정 발송. 실패 패턴 (b) 재발. (dday_timer.dart:139)

### 9. [low] 2027-04-18 하루 동안 이미 치른 회차가 'D-DAY'로 재표시
`_projectNextExam`이 시행된 회차를 건너뛰지 않음(확정 4/17 vs 통상 4/18). (config.dart:44)

### 6. [low] 리워드 광고 단위 ID가 Google 테스트 ID인 채 릴리즈 대기 — 리워드 수익 0
사람이 해야 함: AdMob 콘솔에서 단위 생성 후 `_androidRewardedId`/`_iosRewardedId` 교체.
(ad_service.dart:27)

## G. 테스트 공백 (전부 실패 패턴 (b) 재발 지점)

### 22. [high] 리워드 광고 보상 지급 배선(시청→grantBonus)이 어떤 테스트에도 없음
`if (!watched)` 가드 삭제(무조건 지급)도, `grantBonus` 제거(시청했는데 미지급)도 135건 전부 녹색.
(exam_quota_dialog.dart:102)

### 23. [medium] 회차별 문제집(RoundListScreen)+DB 경로+기출/예상 배지 테스트 0건
배지 반전(예상→'기출 기반' 표시 = 유료 유저 기만)도 감지 못 함. (round_list_screen.dart:126)

### 24. [medium] 홈→퀴즈→복귀 통계 재조회 배선 미검증 — 과거 실제 터졌던 회귀 무방비
`loadStats()` 호출 삭제해도 전부 통과. StatsProvider 참조 테스트 자체가 0건. (home_screen.dart:119)

### 25. [medium] app_test '연타 테스트'가 공회전 — 문제 미로드로 조기 return만 20번
중복 제출 가드(`_isAnswered`) 제거해도 통과. (test/app_test.dart:21)

### 26. [low] grep 기반 배선 테스트가 주석에도 매칭 — 호출 주석 처리 되돌림 전부 통과
`AiExamQuota.consume` 호출을 주석 처리해도(무료 무제한 응시) 녹색. (test/wiring_test.dart:226)

---

## H. 직접 발견 (이 세션, 워크플로우 외)

### D1. [medium] 복습 큐가 비면 기존 예약 알림을 취소하지 않음
`rescheduleReviewNotification`이 빈 큐에서 그냥 return → 마지막 항목 졸업 후에도
이전에 잡힌 알림이 그대로 발송("복습할 문제 N개"인데 실제 0개).
→ `NotificationService.cancelReviewReminder()` 추가 + 빈 큐 경로에 배선.

### D2. = #11 (DB getter 경합) — 워크플로우가 독립적으로 재발견

### D3. [low] past_exam `_retry()`가 `_adCounter`를 리셋하지 않음
다시 풀기 후 광고 주기가 이전 세션 잔여값에서 이어짐. ai_prediction `_retry`에도 동일 확인 필요.
(past_exam_screen.dart:555)

### D4. [low] `config.appSubtitle = '2026 정보처리기사 실기'` 하드코딩 — 2027년에도 2026 표시
연도를 `nextExam.year` 기반으로.

### D5. [low] past_exam_screen:180 '2020~2026년' 하드코딩 — 동일 문제
