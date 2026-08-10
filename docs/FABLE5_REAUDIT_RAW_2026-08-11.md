# Fable 5 재감사 원시 발견 (2026-08-11) — 검증 전

재감사 워크플로우(wf_70f6c22e-2f6) 재개분. 감사 단계 13/16 영역 완료 시점에
세션 한도로 다시 중단됐다(감사 3개 영역·검증 전체·종합 미실행).
**아래는 교차 검증(반박) 전 원시 발견이므로 오탐 가능성이 있다.**

- 검증 재개(5:20am 한도 해제 후): `Workflow({scriptPath: '/Users/djj/.claude/projects/-Users-djj-projects-gisa-pass-master/de492df6-15d1-4e84-a5a7-3b7b400eb250/workflows/scripts/gisa-fable5-full-reaudit-wf_70f6c22e-2f6.js', resumeFromRunId: 'wf_70f6c22e-2f6'})`
- 총 25건: high 4 / medium 9 / low 12

## 1. [high] Android: 미종결 구매 재전달 없음 — acknowledge 누락 구매는 3일 후 Google 자동 환불

**위치:** lib/services/purchase_service.dart:342

_onPurchaseUpdate 는 grantPremium 저장 실패 시 completePurchase(=Android acknowledge)를 건너뛰고 '다음 실행에 스트림으로 다시 내려와 재시도된다'는 전제로 설계돼 있다. 이 전제는 iOS(StoreKit)에만 참이다. 실제 설치된 in_app_purchase_android-0.4.0+10 의 InAppPurchaseAndroidPlatform 을 확인한 결과, purchaseStream 은 PurchasesUpdatedListener(billingClientManager.purchasesUpdatedStream)와 명시적 restorePurchases() 의 queryPurchases 로만 채워지고 앱 시작 시 자동 queryPurchases 가 없다. 즉 Android 에서는 미종결(미확인) 구매가 다음 실행에 재전달되지 않으며, 자동 복원 티켓(premium_auto_restore_done)은 구매 이전의 첫 실행에서 이미 소진되어 있으므로 어떤 경로로도 acknowledge 가 재시도되지 않는다. Google Play 는 3일 내 acknowledge 되지 않은 구매를 자동 환불·회수한다. 같은 이유로 PurchaseStatus.pending(편의점·후불 결제 등)이 앱 종료 후 승인 완료되는 경우도 앱이 영영 인지하지 못한다(_onPurchaseUpdate 는 pending 을 아예 처리하지 않음). 유일한 복구는 유저가 3일 안에 스스로 '구매 복원' 버튼을 누르는 것뿐이다.

**실패 시나리오:** ① Android 유저가 4,900원 결제 → purchased 콜백에서 grantPremium 의 SharedPreferences 저장이 실패(디스크 풀 등)하거나, 결제 완료 직후 completePurchase 호출 전에 프로세스가 종료됨 → acknowledge 미수행 → 다음 실행에 스트림 재전달 없음 → 3일 후 Google 이 자동 환불하고 구매를 회수 → 결제 유저가 프리미엄을 잃음(저장이 성공했던 경우엔 반대로 환불받고도 로컬 프리미엄이 유지되는 매출 손실). ② pending 결제가 앱 종료 후 승인 → 앱은 어떤 실행에서도 이를 수신하지 않음 → acknowledge 미수행 → 3일 후 자동 환불 → 유저는 돈을 냈다가 이유 없이 환불되고 프리미엄을 받지 못함.

**근거:**
```
purchase_service.dart:342-346 「// 미종결로 두면 다음 실행에 스트림으로 다시 내려와 재시도된다. if (!_lastSaveSucceeded) { ... return; }」 / _onPurchaseUpdate 에 PurchaseStatus.pending 분기 부재(329-359) / in_app_purchase_android-0.4.0+10 in_app_purchase_android_platform.dart:43-45 「billingClientManager.purchasesUpdatedStream .asyncMap(...).listen(_purchaseUpdatedController.add);」 — 시작 시 queryPurchases 호출은 restorePurchases()(230-238)에만 존재
```

## 2. [high] 공백 제거 비교로 띄어쓰기 구분 숫자 출력의 오답 96문항이 정답 처리됨

**위치:** /Users/djj/projects/gisa_pass_master/lib/services/answer_checker.dart:46

2단계 비교(_stripSpaces)가 쉼표는 보존하지만 공백은 전부 제거한다. 주석(43-45행)은 '3,5'와 '35' 오탐을 막으려 쉼표를 남긴다고 명시했지만, C/Java의 printf("%d %d") 류 '공백 구분 다중 값 출력'은 같은 유형의 오탐에 그대로 노출된다. 1000문항 전수 대입 결과 code_reading 96문항(c_questions 61개: 인덱스 1,3,4,6,17,18,21,29,33,36,37,40,41,42,43,44,45,47,49,50,55,56,66,68,69,71,76,78,79,86,87,90,91,92,94,95,97,99,102,103,106,107,108,109,112,113,116,119,120,122,123,124,125,128,130,133,138,142,144,145,147 / java_questions 29개: 8,17,36,47,49,56,59,64,66,68,71,79,82,84,86,87,97,101,111,112,117,122,124,125,130,136,138,141,145 / python_questions 6개: 98,106,111,118,137,139)에서 값 경계를 잘못 잡은 오답이 정답 처리됨을 확인했다.

**실패 시나리오:** c_questions.json 인덱스 1: printf("%d %d", *(p+2), *(p+4)) → 정답 '30 50'. 유저가 포인터 연산을 잘못 이해해 '3050'(한 값)을 입력해도 _stripSpaces 후 '3050'=='3050'으로 정답 처리. c_questions.json 인덱스 29: static 카운터 출력 정답 '1 2 3 '에 대해 '12 3'(1,2를 12로 오해) 입력도 정답 처리. python3 전수 시뮬레이션으로 96문항 모두 재현.

**근거:**
```
// 2) 공백만 제거해 비교 (상호배제 vs 상호 배제).
//    쉼표는 남긴다. 쉼표까지 지우면 항목 경계가 사라져 "3,5"(두 줄 출력)와
//    "35"(한 값)가 서로 정답 처리되는 오탐이 생긴다.
if (_stripSpaces(normUser) == _stripSpaces(normCorrect)) return true;
(공백 구분 출력에는 동일 방어가 없음)
```

## 3. [high] 결제 스트림 → 프리미엄 지급 배선이 어떤 테스트에도 걸려 있지 않다 (v1.5.4 결제 소실 수정이 무방비)

**위치:** lib/services/purchase_service.dart:329

purchase_persistence_test.dart 5건은 전부 @visibleForTesting인 grantPremium()을 직접 호출해 '부품'만 검증한다. 실제 결제가 흐르는 경로인 _onPurchaseUpdate(스토어 purchaseStream 핸들러)는 private이고, test/ 전체에서 PurchaseDetails·_onPurchaseUpdate·purchaseStream을 다루는 테스트가 0건이다(grep으로 확인: 주석 1건뿐). 따라서 이 핸들러가 지키는 세 가지 계약 — (1) purchased/restored 시 grantPremium 호출, (2) 저장 성공(_lastSaveSucceeded) 후에만 completePurchase, (3) 저장 실패 시 트랜잭션 미종결로 다음 실행 재시도 — 를 통째로 되돌려도 155건 전부 통과한다. 이 앱은 유료 결제 유저가 실존하고, 이 지점이 바로 v1.5.4에서 '결제 소실'로 터졌던 곳이다. 알려진 실패 패턴 (b) '테스트가 부품만 검증하고 배선을 안 봄' 그 자체.

**실패 시나리오:** 재현: _onPurchaseUpdate의 grantPremium().then(...) 블록을 v1.5.4 이전처럼 `_iap.completePurchase(purchase);` 단독 호출로 되돌린다 → flutter test 155건 전부 녹색. 프로덕션에서는 4,900원 결제한 유저에게 프리미엄이 켜지지 않거나(grantPremium 미호출), 저장 실패 시 트랜잭션만 종결되어 재시작 후 프리미엄이 사라지고 복구 경로도 없다. 정적 검증 전부 통과 후 릴리즈에서만 터지는 유형.

**근거:**
```
purchase_service.dart:338-350 `grantPremium().then((_) { if (!_lastSaveSucceeded) { ... return; } if (purchase.pendingCompletePurchase) { _iap.completePurchase(purchase); } });` — 이 배선을 검증하는 테스트 없음. purchase_persistence_test.dart:21 `await service.grantPremium();`(직접 호출만). purchase_service.dart:211 주석 스스로 인정: "purchaseStream 을 통하지 않으면 '쓰기' 경로를 검증할 수 없어서"
```

## 4. [high] 리워드 광고가 Google 테스트 광고 단위 ID로 배포 중 — 리워드 노출 수익 0원, 무료 응시권만 무상 지급

**위치:** lib/services/ad_service.dart:27

전면·배너 광고는 실제 계정(ca-app-pub-5911237489066113)의 단위 ID를 쓰는데, 리워드 광고만 Google 공식 테스트 계정(ca-app-pub-3940256099942544)의 데모 단위 ID가 하드코딩되어 있다. 이 상태로 프로덕션에서 리워드 광고가 노출되면 AdMob 수익이 전혀 잡히지 않는다. 문제는 이 리워드 광고가 ExamQuotaDialog에서 'AI 실전 모의고사 무료 쿼터 초과 시 광고 보고 1회 더(하루 최대 2회)'의 대가로 실제 보상(grantBonus)을 지급하는 데 쓰인다는 것이다. 즉 프리미엄(4,900원) 구매를 유도해야 할 지점에서, 수익이 0원인 데모 광고를 보여주고 유료 기능 응시권을 무상으로 풀어주고 있다. 새 수익원(커밋 4dee6ac '리워드 광고 추가 — 새 수익원')이 실제로는 수익 없이 프리미엄 전환만 깎아먹는 상태다.

**실패 시나리오:** 무료 유저가 AI 실전 모의고사 하루 1회를 소진 → 재응시 시도 → ExamQuotaDialog에서 '광고 보고 1회 더' 선택 → Google 테스트 리워드 광고 재생(광고주 없음, eCPM 0) → AiExamQuota.grantBonus()로 응시권 +1 지급. 하루 최대 2회 반복 가능. 앱 운영자에게는 광고 수익 0원이 잡히고, 유저는 프리미엄 없이 하루 3회 응시. 리워드 광고가 노출될 때마다 수익 없는 기능 개방이 반복된다.

**근거:**
```
lib/services/ad_service.dart:27-29
  static const String _androidRewardedId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _iosRewardedId = 'ca-app-pub-3940256099942544/1712485313';
(주석 자인: "현재 Google 공식 **테스트 ID** 다. ... 테스트 ID 그대로 배포해도 앱은 정상 동작하지만 수익은 0 이다.")
대조 — 실 계정 단위: ad_service.dart:18-21 'ca-app-pub-5911237489066113/...'
보상 지급 경로: lib/widgets/exam_quota_dialog.dart:138-155 showRewardedAd() → watched true → return AiExamQuota.grantBonus();
```

## 5. [medium] 리워드 광고가 프로덕션에서 Google 샘플 테스트 ID로 동작 — 수익 0 + 실유저에게 'Test Ad' 노출

**위치:** /Users/djj/projects/gisa_pass_master/lib/services/ad_service.dart:27

전면·배너 광고는 실제 퍼블리셔 ID(ca-app-pub-5911237489066113/…)를 쓰는데, 리워드 광고만 Android·iOS 모두 Google 공식 샘플 테스트 ID(ca-app-pub-3940256099942544/5224354917, /1712485313)다. 커밋 4dee6ac는 '리워드 광고 추가 — 새 수익원'이라고 하지만 이 상태로는 리워드 노출 전량이 수익 0이며, 실유저 화면에 'Test Ad' 라벨이 붙은 영상이 재생된다. 코드 주석이 '실 ID로 바꾸기 전까지'라고 인지하고 있으나 v1.6.1+25 릴리즈 커밋까지 교체되지 않은 채 미푸시 상태다. 부수 결함: isRewardedUsingTestId 게터(line 32-33)가 Android 상수만 검사한다 — 이 코드베이스의 알려진 실패 패턴 (a) '복붙 후 한쪽만 수정' 그대로로, 향후 Android ID만 실 ID로 바꾸면 iOS가 테스트 ID로 남아 있어도 게터는 '실 ID 사용 중'이라고 거짓 보고한다.

**실패 시나리오:** 무료 유저가 쿼터 소진 → ExamQuotaDialog에서 '광고 보고 1회 더' 탭 → 'Test Ad' 라벨이 붙은 Google 데모 영상 시청 → 보상은 지급되지만 AdMob 수익은 0원. 앱의 새 수익원이 전 유저·전 노출에서 무수익. 또한 App Store 심사자가 테스트 광고를 보면 미완성 앱으로 보일 수 있다.

**근거:**
```
static const String _androidRewardedId =
    'ca-app-pub-3940256099942544/5224354917';
static const String _iosRewardedId = 'ca-app-pub-3940256099942544/1712485313';

static bool get isRewardedUsingTestId =>
    _androidRewardedId.startsWith('ca-app-pub-3940256099942544');  // iOS 상수는 검사 안 함
```

## 6. [medium] 오답 직후 1분 뒤 알림이 30분 충돌 방지 유예를 우회해 학습 중인 유저 화면 위로 발화

**위치:** lib/services/database_service.dart:274

getNextReviewSchedule의 30분 유예(_overdueReminderDelay)는 '이미 밀린(overdue)' 복습에만 적용된다. 문제를 틀리면 processAnswer가 stage 0으로 next_review_at = now+1분을 기록하고 곧바로 rescheduleReviewNotification을 부르는데, 이 행은 아직 미래이므로 분기 2(미래 MIN)를 타서 알림이 now+1분으로 예약된다. iOS는 DarwinInitializationSettings의 foreground 표시 기본값이 true이고 Android는 Importance.high 헤드업이라, 유저가 해설을 읽거나 다음 문제를 푸는 도중(60초 이상 머물면) '복습할 시간이에요 — 틀린 문제 1개' 알림이 앱 위로 뜬다. '방금 문제를 푼 유저에게 알림이 겹치지 않게 한다'는 주석의 의도(database_service.dart:269, 295)를 오답 경로가 정면으로 위반한다. 알림을 켠 유저가 오답을 낼 때마다 재현되는 고빈도 UX 결함이다.

**실패 시나리오:** 알림 ON 상태에서 복습 큐가 비어 있는 유저가 문제은행에서 1문제를 틀림 → processAnswer가 next_review_at=now+1분 기록 → rescheduleReviewNotification이 분기 2로 now+1분에 알림 예약 → 유저가 해설을 60초 이상 읽는 동안 앱 화면 위로 헤드업 알림 발화. 세션 마지막 답이 오답인 채 앱을 닫아도 1분 뒤 알림이 온다(30분 유예 없이).

**근거:**
```
database_service.dart:268-272 `if (overdue > 0) { return (dueAt: now.add(_overdueReminderDelay), ...); }` — 유예는 overdue 분기에만 있고, 분기 2는 `final dueAt = DateTime.tryParse(raw); ... return (dueAt: dueAt, count: ...)` 로 now+1분을 그대로 반환. spaced_repetition_service.dart:55-60 `currentStage = 0; ... final nextReviewAt = DateTime.now().add(Duration(minutes: intervalMinutes));` (stage 0 = 1분)
```

## 7. [medium] cancelAll이 _ready=false면 조용히 no-op — 알림 OFF 후에도 기존 예약(D-Day 포함)이 살아남아 발화

**위치:** lib/services/notification_service.dart:208

setEnabled(false)의 예약 정리는 cancelAll 하나에 의존하는데, cancelAll은 `if (kIsWeb || !_ready) return;`으로 초기화 전이면 아무것도 하지 않는다. 같은 파일의 cancelReviewReminder는 initialize()를 먼저 호출하는 것과 비대칭이다(알려진 실패 패턴 (a): 복붙 후 한쪽만 수정). NotificationService.initialize()는 main.dart에서 AdService.initialize → ATT → PurchaseService.initialize 뒤(190행)에 실행되므로 앱 시작 후 수 초간 _ready=false 창이 있고, initialize가 예외로 실패하면 세션 내내 false다. 이 상태에서 유저가 통계 탭 토글로 알림을 끄면 prefs만 false가 되고 이미 잡힌 복습 알림·D-30/D-7/D-1 알림은 그대로 남는다. 이후 모든 예약 경로(scheduleReviewReminder, scheduleExamCountdown, rescheduleReviewNotification→scheduleReviewReminder)가 isEnabled=false에서 취소 없이 조기 반환하므로, 다음 실행에서도 영원히 정리되지 않는다. scheduleExamCountdown의 주석 '기존 예약 취소는 위에서 계속 수행한다'(180행)도 isEnabled 조기 반환 때문에 거짓이다.

**실패 시나리오:** 알림 ON 유저(복습 알림 + D-30/D-7/D-1 예약됨)가 앱을 콜드 스타트하고 초기화 시퀀스가 끝나기 전(광고 SDK·스토어 연결로 수 초) 통계 탭에서 알림을 OFF → setEnabled(false) → cancelAll이 _ready=false로 즉시 반환 → 예약 전부 잔존 → 수 주 뒤 '내일이 시험입니다' D-1 알림이 옵트아웃한 유료 유저에게 발송. 이후 어떤 실행 경로도 이 예약을 지우지 않는다.

**근거:**
```
notification_service.dart:207-214 `static Future<void> cancelAll() async { if (kIsWeb || !_ready) return; ... }` vs :152-157 `cancelReviewReminder ... await initialize(); if (!_ready) return; await _plugin.cancel(_reviewId);` / main.dart:190 `await NotificationService.initialize();` (AdService·ATT·Purchase await 이후)
```

## 8. [medium] 'N개'·'3V' 등 순서 무관 나열 문항에서 순서만 바꾼 정답이 오답 처리됨

**위치:** /Users/djj/projects/gisa_pass_master/lib/services/answer_checker.dart:275

_allowsUnorderedList는 '모두 쓰시오/고르시오/나열'과 정규식 r'\d+\s*가지'만 순서 무관으로 인정한다. 그러나 실제 데이터에는 '예시를 2개 쓰시오', '알고리즘 2개', '나머지 3개' 같은 'N개' 표현과 '3V를 쓰시오', '원인을 쓰시오' 같은 순서 무관 나열 문항이 존재하며, 이들은 순서를 바꿔 쓰면 오답이 된다. 확인된 문항: short_answer_questions 인덱스 350(CI 도구 2개), 357(해시 알고리즘 2개), 319(빅데이터 3V), 344(소프트웨어 위기 원인), sql_questions 인덱스 55(SELECT 제외 DML 3개). 실기 채점 기준상 이런 나열의 순서는 채점 대상이 아니므로 정답이 오답 처리되는 false negative다.

**실패 시나리오:** short_answer 인덱스 357 '해시 함수의 대표적인 알고리즘 2개를 쓰시오' 정답 'SHA-256, MD5' → 유저가 'MD5, SHA-256' 입력 시 오답. 인덱스 350 정답 'Jenkins, GitHub Actions' → 'GitHub Actions, Jenkins' 오답. sql 인덱스 55 정답 'INSERT, UPDATE, DELETE' → 'DELETE, INSERT, UPDATE' 오답. 인덱스 319 '빅데이터의 3V' 정답 'Volume, Velocity, Variety' → 'Variety, Velocity, Volume' 오답. python3 시뮬레이션으로 전부 재현(is_correct == false).

**근거:**
```
// "N가지를 쓰시오" 는 나열형의 가장 흔한 표현이다. 순서를 묻는 게 아니다.
if (RegExp(r'\d+\s*가지').hasMatch(text)) return true;
('N개', '3V', '원인을 쓰시오' 류는 매칭되지 않아 기본값 false=순서 강제)
```

## 9. [medium] exam_schedule_test의 '확정 일정 소진 후 추정' 그룹이 추정 로직을 전혀 실행하지 못한다 — 그룹명만 있는 통과용 테스트

**위치:** test/exam_schedule_test.dart:30

f6eb26a 커밋의 'D-Day 무한 전환' 수정(확정 일정이 모두 지나면 _projectNextExam으로 추정)을 지킨다고 주장하는 테스트 7건이 전부 DateTime.now() 실시간에 묶여 있다. 오늘(2026-08-11)은 확정 일정(2026-10-18, 2027-04-17)이 남아 있어 nextExam의 for 루프가 항상 확정 항목을 반환하고, 추정 분기 _projectNextExam은 테스트에서 단 한 번도 실행되지 않는다. _projectNextExam은 private이고 시각 주입 시임(seam)도 없어 테스트가 도달할 방법 자체가 없다. '확정 일정 소진 후 추정' 그룹의 단언 2건(연도 >= 올해, isExamDateConfirmed == true)은 추정 로직이 통째로 없어도 참이다.

**실패 시나리오:** 재현: config.dart의 `return _projectNextExam(today);`를 옛 구현 `return _examSchedule.last;`로 되돌린다(수정 전 상태) → flutter test 155건 전부 녹색. 2027-04-17이 지나는 순간 프로덕션에서 D-Day가 과거 날짜에 갇혀 '시험 완료!'에 영영 고정 — 이 테스트 파일이 헤더 주석에서 막겠다고 선언한 바로 그 결함이 무단으로 되살아난다.

**근거:**
```
test/exam_schedule_test.dart:31-40 — `expect(AppConfig.nextExam.date.year, greaterThanOrEqualTo(DateTime.now().year));`와 `expect(AppConfig.isExamDateConfirmed, isTrue)` 뿐. config.dart:39-42 `for (final exam in _examSchedule) { if (!exam.date.isBefore(today)) return exam; } return _projectNextExam(today);` — 오늘 기준 루프에서 항상 반환되어 추정 분기 도달 불가
```

## 10. [medium] 신규 기능 '회차별 문제집' 화면이 테스트 0건 — 특히 기출/AI예상 구분 표시가 무방비

**위치:** lib/screens/round_list_screen.dart:126

f6eb26a에서 추가된 RoundListScreen과 그 데이터 경로(DatabaseService.getRoundSummary, getQuestionsByRound, buildPastExamQuiz 재사용)를 참조하는 테스트가 test/ 전체에 단 한 건도 없다(grep 확인). 화면 자신이 헤더 주석에 '아직 시행되지 않은 회차의 문항을 기출로 보여주면 유저를 속이는 것이다'라고 선언한 핵심 불변식 — 2026년 122문항(예상문제)에 'AI 예상' 배지를 붙이는 것 — 이 line 126의 `AppConfig.isPredictedYear(year)` 한 줄에 걸려 있는데, isPredictedYear/lastRealExamYear를 검증하는 테스트도 0건이다. 알려진 실패 패턴 (a) 복붙 후 한쪽만 수정이 이 화면에서 재발해도(예: _roundTile에 predicted 대신 상수 전달) 잡을 장치가 없다.

**실패 시나리오:** 재현: round_list_screen.dart:126을 `final predicted = false;`로 바꾸거나 config.dart:105 isPredictedYear를 `=> false`로 되돌린다 → flutter test 155건 전부 녹색. 프로덕션에서는 시행 전 회차인 2026년 예상문제 122건이 '기출 기반' 배지와 함께 실제 기출로 표시되어, 수험생이 존재하지 않는 기출문제로 시험을 준비하게 된다. getRoundSummary의 kIsWeb 분기·정렬(연도·회차 내림차순)도 마찬가지로 무방비.

**근거:**
```
grep -rn 'RoundListScreen|getRoundSummary|getQuestionsByRound|buildPastExamQuiz|isPredictedYear' test/ → 0건. round_list_screen.dart:126 `final predicted = AppConfig.isPredictedYear(year);`, :211-213 `predicted ? '${r.count}문항 · 시행 전 회차라 AI 예상문제입니다' : '${r.count}문항'`
```

## 11. [medium] wiring_test '통계 재조회 배선' grep이 호출 위치를 구분하지 못해, 문서화된 원래 회귀(initState 이동)가 그대로 통과한다

**위치:** test/wiring_test.dart:400

이 그룹이 지키려는 동작은 'IndexedStack 탭 전환(onDestinationSelected) 시 loadStats 재호출'이다. 그러나 단언은 main.dart 전체에서 문자열 `StatsProvider>().loadStats()`의 존재만 확인한다. 테스트 주석이 스스로 문서화한 원래 회귀 — 'initState 가 다시 돌지 않는다'(IndexedStack이 탭 state를 살려두므로) — 형태로 되돌리면, 즉 loadStats 호출을 onDestinationSelected에서 initState로 옮기면 grep은 여전히 매칭되어 테스트가 통과한다. 조건 `index == 0 || index == 3`도 전혀 검증하지 않아 홈 탭(index 0)만 조건에서 빠져도(패턴 a: 한쪽만 수정) 잡지 못한다. 같은 파일의 그룹 1·6이 스파이로 실호출을 검증하도록 개선된 것과 대조적으로, 이 그룹만 '주석 걷어낸 grep'조차 위치 무관 매칭이라 보호력이 없다.

**실패 시나리오:** 재현: main.dart:253-257의 `if (index == 0 || index == 3) { context.read<StatsProvider>().loadStats(); }`를 onDestinationSelected에서 삭제하고 같은 State의 initState에 `context.read<StatsProvider>().loadStats();`를 추가(전형적 리팩토링) → wiring_test 포함 155건 전부 녹색. 프로덕션에서는 문제를 풀고 홈/통계 탭으로 돌아와도 IndexedStack이 살려둔 화면이 옛 통계를 붙들고 있어, 앱 재시작 전까지 스트릭·정답률이 갱신되지 않는 회귀가 소리 없이 재발한다.

**근거:**
```
wiring_test.dart:401-405 `final main = _activeSource('lib/main.dart'); expect(main.contains('StatsProvider>().loadStats()'), isTrue, ...)` — main.dart 어디에 있든 매칭. 지키려는 실제 배선은 main.dart:253-257의 onDestinationSelected 내부 조건부 호출(현재 main.dart에서 유일한 호출이지만 위치·조건은 미검증)
```

## 12. [medium] 결제 직후 프리미엄 유저에게 배너 광고가 계속 노출 — AI 모의고사 화면이 프리미엄 전환을 반영하지 않음

**위치:** lib/screens/ai_prediction_screen.dart:57

AiPredictionScreen은 initState에서 한 번만 createBannerAd로 배너를 만들고(당시 무료 유저면 생성됨), 이후 프리미엄 상태 변화를 전혀 구독하지 않는다. AdService.setPremium은 전면·리워드 광고만 dispose하고 화면이 소유한 배너에는 손댈 수 없으며, 화면의 build는 _bannerLoaded && _bannerAd != null만 본다(363행). 그 결과 이 화면 위에서 프리미엄을 구매하고 돌아와 '다시 풀기'를 하면, 방금 4,900원으로 '광고 제거'를 산 유저가 20문항 시험 내내 배너 광고를 그대로 본다. 전면광고는 shouldShowAds 게이트로 차단되지만 배너는 화면을 완전히 벗어나기 전까지 남는다. 감사 항목 '프리미엄 유저에게 새는 광고'에 해당하는 실경로다.

**실패 시나리오:** 무료 유저가 AI 실전 모의고사 응시(배너 로드됨) → 결과 화면에서 '다시 풀기' → 쿼터 소진 다이얼로그에서 '프리미엄' 선택 → SubscriptionScreen에서 결제 완료(isPremium=true, setPremium 호출) → 뒤로 돌아와 다시 '다시 풀기' → canStart는 프리미엄이라 즉시 통과 → _buildQuizScreen이 initState 때 만든 _bannerAd를 그대로 표시 → 결제한 유저가 재응시 세션 전체(20문항) 동안 배너 광고를 봄. 화면을 pop하고 새로 진입해야만 사라진다.

**근거:**
```
lib/screens/ai_prediction_screen.dart:57 _bannerAd = globalAdService?.createBannerAd( ... (initState에서 1회만 생성, 프리미엄 전환 리스너 없음)
ai_prediction_screen.dart:363-371 bottomNavigationBar: _bannerLoaded && _bannerAd != null ? ... AdWidget(ad: _bannerAd!) (isPremium 미확인)
lib/services/ad_service.dart:78-89 setPremium은 _interstitialAd/_rewardedAd만 dispose — 화면 소유 배너는 정리 불가
결제 진입 경로: ai_prediction_screen.dart:186-193 ExamQuotaDialog.show(..., onSeePremium: () => Navigator.push(... SubscriptionScreen ...))
```

## 13. [medium] 알림 OFF 시 cancelAll이 초기화 전엔 무음 no-op — 꺼둔 유저에게 예약된 D-Day·복습 알림이 그대로 발송

**위치:** lib/services/notification_service.dart:208

cancelAll()은 `if (kIsWeb || !_ready) return;`으로 플러그인 초기화 전이면 아무것도 취소하지 않고 조용히 반환한다. 반면 같은 파일의 cancelReviewReminder()는 취소 전에 `await initialize()`를 먼저 호출한다 — 같은 취소 로직을 복붙한 뒤 한쪽만 고친 전형적 비대칭이다. NotificationService.initialize()는 시작 postFrame 체인에서 AdMob SDK 초기화(main.dart:166) → ATT 조회(173) → 스토어 왕복(queryProductDetails+자동복원, 183) **뒤에야** 호출되므로(main.dart:190), 콜드 스타트 후 수 초(네트워크가 느리면 그 이상) 동안 _ready=false 창이 열린다. 이 창에서 통계 화면 토글로 알림을 끄면 setEnabled(false) → cancelAll()이 no-op가 되고, 이후 isEnabled=false라 scheduleExamCountdown/scheduleReviewReminder 모두 조기 return하여 기존 OS 예약을 지우는 경로가 영영 다시 돌지 않는다.

**실패 시나리오:** 알림을 켜둔 기존 유저(D-30/D-7/D-1 + 복습 알림이 OS에 예약된 상태)가 앱을 콜드 스타트 → 시작 체인이 main.dart:190의 NotificationService.initialize()에 도달하기 전(AdMob 초기화+ATT+스토어 왕복 동안, 통상 2~6초·저속 네트워크면 더 김)에 통계 탭 → '복습 알림' 토글 OFF → notification_settings_tile.dart:43 setEnabled(false) → cancelAll()이 _ready=false로 조기 return → 예약이 하나도 취소되지 않음. prefs는 false로 저장돼 이후 어떤 시작 경로도 취소를 수행하지 않으므로, 알림을 껐는데도 시험 전날 '내일이 시험입니다' 등 예약 알림이 그대로 발송된다. 유저가 토글을 다시 켰다 끄지 않는 한 복구 경로 없음.

**근거:**
```
notification_service.dart:207-214 `static Future<void> cancelAll() async { if (kIsWeb || !_ready) return; ... await _plugin.cancelAll(); }` — 반면 152-157의 cancelReviewReminder는 `await initialize(); if (!_ready) return; await _plugin.cancel(_reviewId);` 로 초기화를 먼저 수행. 호출부: notification_service.dart:88 `if (!value) await cancelAll();`, 창을 만드는 시작 순서: main.dart:163-190 (AdService.initialize → _requestTracking → 스토어 initialize → 그 뒤에야 NotificationService.initialize).
```

## 14. [low] database getter의 실패 처리에서 _opening을 무조건 null로 리셋해 남의 진행 중 초기화를 지울 수 있음

**위치:** lib/services/database_service.dart:36

getter는 실패한 Future의 모든 awaiter가 각자 catch에서 `_opening = null`을 실행한다. 자신이 await한 Future(opening)와 현재 `_opening`이 같은지 확인하지 않으므로, 늦게 도는 awaiter의 catch가 그 사이 다른 호출자가 새로 시작한 초기화 Future를 클리어할 수 있다. 이후 호출자는 세 번째 `_initDB()`를 시작해 두 개의 `_initDB`가 동시에 진행된다. sqflite가 같은 경로의 openDatabase는 dedup하지만 `syncQuestionsIfRevisionChanged`는 dedup되지 않아, 리비전 불일치 상태에서 두 동기화가 동시에 돌면 둘 다 커밋 전에 `existing` 인덱스를 만들고 DB에 없는 문항을 각자 INSERT한다. 문항 삭제 경로가 없어 중복은 영구적이다. 현재 rev 2는 기존 유저에게 UPDATE만 발생시키므로 즉시 피해는 없지만, 예정된 2026 예상문제 추가나 시드 일부 실패(seedFailed) 후 보충 INSERT 시나리오에서 실제 중복으로 나타난다. 수정은 catch에서 `if (identical(_opening, opening)) _opening = null;` 한 줄이다.

**실패 시나리오:** (1) 콜드 스타트에서 openDatabase가 일시 실패(I/O 오류 등)해 main.dart:50 워밍업 F1 실패, catch가 _opening=null. (2) 첫 화면 진입 시 StatsProvider 쿼리·복습 알림 재예약 등 복수 호출이 동시에 getter를 타서 F2를 공유하고 F2도 실패. (3) awaiter A의 catch가 _opening=null 후 A의 호출자 재시도가 동기적으로 F3을 시작 → 마이크로태스크 큐에 남아 있던 awaiter B의 catch가 실행되며 _opening=null로 F3 참조를 지움. (4) 다음 호출자가 F4를 시작해 F3·F4의 _initDB가 동시 진행 → 리비전이 코드값과 다른 상태면 syncQuestionsFromAssets 2회가 인터리브되어 DB에 없던 문항이 2회 INSERT → 문제은행·회차별 문제집에 같은 문항이 영구히 2번 노출되고 총 문항 수가 1000을 초과.

**근거:**
```
final opening = _opening ??= _initDB();
    try {
      final db = await opening;
      _database = db;
      return db;
    } catch (_) {
      _opening = null;
      rethrow;
    }
```

## 15. [low] 리워드 광고 로드 실패 시 쿼터 다이얼로그가 영구 '광고 준비 중...' — 다이얼로그 내 재시도 경로 없음

**위치:** /Users/djj/projects/gisa_pass_master/lib/widgets/exam_quota_dialog.dart:44

loadRewardedAd()는 다이얼로그 열릴 때 딱 1회 호출된다(line 32). ad_service의 onAdFailedToLoad(line 249-252)는 _isLoadingRewarded=false만 하고 재시도를 걸지 않으므로, 이 1회 로드가 실패하면(no-fill·일시적 네트워크 오류) 다이얼로그가 열려 있는 동안 다시 로드되는 일이 없다. 그런데 readyPoll 타이머(line 45-52)는 isRewardedReady만 500ms마다 폴링하므로 영원히 준비되지 않는 상태를 무한 폴링하고, 버튼 라벨은 실제로는 아무것도 로드 중이 아닌데도 '광고 준비 중...'을 계속 표시한다. 회복하려면 유저가 그 버튼을 눌러 다이얼로그를 닫고(그때서야 line 121에서 재로드 트리거) 스낵바 안내 후 AI 모의고사 카드를 다시 눌러 다이얼로그를 재진입해야 한다.

**실패 시나리오:** 무료 유저가 쿼터 소진 상태에서 AI 모의고사 탭 → 다이얼로그 오픈 직후 리워드 로드가 no-fill로 1회 실패 → 이후 네트워크가 정상이어도 다이얼로그는 계속 '광고 준비 중...' → 기다리던 유저가 버튼을 누르면 다이얼로그가 닫히며 '잠시 후 다시 눌러주세요' 스낵바 → 처음부터 재진입해야 광고를 볼 수 있다. 기다리기만 한 유저는 광고를 영영 보지 못하고 이탈(보너스 미획득 + 리워드 수익 기회 상실).

**근거:**
```
if (canEarn && !(globalAdService?.isRewardedReady ?? false)) {
  readyPoll ??= Timer.periodic(const Duration(milliseconds: 500), (t) {
    if (globalAdService?.isRewardedReady ?? false) { t.cancel(); setDialogState(() {}); }
  });
}
// ad_service.dart onAdFailedToLoad: _isLoadingRewarded = false;  ← 재시도 없음, 폴링만 계속
```

## 16. [low] iOS 13–14(StoreKit1 폴백): 취소·실패 트랜잭션을 completePurchase 하지 않아 결제 큐에 영구 잔류·매 실행 재전달

**위치:** lib/services/purchase_service.dart:351

_onPurchaseUpdate 는 purchased/restored 상태에서만 completePurchase 를 호출하고 error/canceled 분기에서는 호출하지 않는다. in_app_purchase_storekit 0.4.8+1 은 iOS 15+ 에서 StoreKit2 를 쓰므로(취소 시 트랜잭션이 큐에 남지 않아 무해) 대부분 유저는 영향이 없지만, 배포 타깃이 iOS 13.0(project.pbxproj IPHONEOS_DEPLOYMENT_TARGET = 13.0)이라 iOS 13–14 기기는 StoreKit1 폴백을 탄다. SK1 경로에서는 canceled/error 트랜잭션도 pendingCompletePurchase == true 로 내려오며(플러그인 소스 확인: pending 이 아닌 모든 상태가 대상), finishTransaction 되지 않은 failed 트랜잭션은 SKPaymentQueue 에 남아 매 실행 옵저버로 재전달된다. error 상태로 재전달되면 실행마다 _error 가 설정되고, 미종결 트랜잭션이 누적된다.

**실패 시나리오:** iOS 13/14 기기 유저가 '프리미엄 시작하기' → Apple 결제 시트에서 취소 → failed 트랜잭션이 종결되지 않고 큐에 잔류 → 이후 매 앱 실행마다 purchaseStream 으로 canceled(또는 error) 이벤트가 재전달됨 → error 인 경우 실행마다 _error 설정, 트랜잭션은 영구히 큐에 남음.

**근거:**
```
purchase_service.dart:351-357 — error/canceled 분기에 completePurchase 부재: 「} else if (purchase.status == PurchaseStatus.error) { ... _error = ...; } else if (purchase.status == PurchaseStatus.canceled) { debugPrint('구매 취소됨'); }」 / in_app_purchase_storekit-0.4.8+1 app_store_purchase_details.dart:75 「_pendingCompletePurchase = status != PurchaseStatus.pending;」 (SK1 경로)
```

## 17. [low] spaced_repetition 행이 영구 잔존해 '졸업' 상태가 존재하지 않음 — 큐 소진 시 알림 취소 경로가 도달 불가 데드 코드

**위치:** lib/services/spaced_repetition_service.dart:78

코드 전반의 주석은 '마지막 문제를 졸업한 유저'(notification_service.dart:150-151, spaced_repetition_service.dart:79-80)라는 상태를 전제로 큐가 비면 알림을 취소한다고 설명하지만, database_service.dart 어디에도 spaced_repetition 행을 삭제하는 코드가 없다(delete는 bookmarks 한 곳뿐). stage는 7(14일)에서 캡되고 consecutive_correct가 아무리 쌓여도 행이 남으므로, 한 번이라도 틀린 문항이 있는 유저에게 getNextReviewSchedule은 영원히 null을 반환하지 않는다. 결과: (1) rescheduleReviewNotification의 next==null → cancelReviewReminder 분기는 실기기에서 도달 불가, (2) 7회 연속 정답으로 사실상 마스터한 문항도 14일마다 '틀린 문제 N개가 기다리고 있어요' 알림 대상으로 영구 순환하며, 시험일(2026-10-18) 이후에도 앱을 열 때마다 다음 14일 알림이 재장전된다. 설명(졸업 존재)과 코드(삭제 부재)의 불일치.

**실패 시나리오:** 유저가 문항 1개를 한 번 틀린 뒤 8회 연속 정답(수 주에 걸쳐) → stage 7 고정, 행 잔존 → 이후 14일 주기로 next_review_at 도래 → 앱을 열 때마다 rescheduleReviewNotification이 '틀린 문제 1개' 알림을 재예약 → 오답노트를 완전히 비우는 것이 불가능하고, 시험이 끝난 뒤에도 알림이 계속 온다.

**근거:**
```
spaced_repetition_service.dart:48 `currentStage = (currentStage + 1).clamp(0, _maxStage);` (삭제 없음) / database_service.dart 전체에서 spaced_repetition 대상 delete 부재(grep 결과 delete는 478행 bookmarks 뿐) / notification_service.dart:150-151 주석 '마지막 문제를 졸업한 뒤에도' — 코드상 졸업 불가
```

## 18. [low] 앱 시작 직후 통계 탭에서 알림을 켜면 onEnabled가 아직 null이라 복습 알림이 예약되지 않음

**위치:** lib/main.dart:194

NotificationOptIn.onEnabled(복습 알림 재예약 콜백)는 main.dart postFrameCallback에서 AdService.initialize → ATT 요청(500ms 지연 + 시스템 다이얼로그) → PurchaseService.initialize를 모두 await한 뒤에야 할당된다(194행). stats_screen.dart:55는 빌드 시점에 이 static을 읽어 NotificationSettingsTile에 넘기므로, 그 전에 유저가 통계 탭에서 토글을 켜면 widget.onEnabled가 null이다. 이 경우 scheduleExamCountdown(D-Day)만 잡히고 다이얼로그·타일이 약속한 복습 알림은 다음 문제 풀이나 앱 재시작 전까지 예약되지 않는다. 창이 수 초로 좁고 재시작 시 자가 치유되지만, 초기화 실패로 postFrame 시퀀스가 중단되면(AdService 예외는 잡지만 Purchase 예외 이후 알림 초기화·할당 라인은 191행 이전 try 밖) 세션 내내 지속된다.

**실패 시나리오:** 콜드 스타트 직후(스토어 연결 등으로 postFrame 시퀀스 수 초 소요) 유저가 곧장 통계 탭 → 알림 토글 ON → NotificationSettingsTile._toggle에서 granted=true, scheduleExamCountdown 실행, widget.onEnabled == null이라 rescheduleReviewNotification 미실행 → 밀린 복습이 있어도 복습 알림이 잡히지 않고, 유저는 '복습 시기를 알려준다'는 안내만 믿고 기다린다.

**근거:**
```
main.dart:194-195 `NotificationOptIn.onEnabled = widget.spacedRepetitionService.rescheduleReviewNotification;` (AdService·ATT·Purchase await 이후에야 실행) / stats_screen.dart:55 `onEnableNotifications: NotificationOptIn.onEnabled,` / notification_settings_tile.dart:54-56 `if (granted) { await NotificationService.scheduleExamCountdown(); await widget.onEnabled?.call(); }`
```

## 19. [low] 괄호 대체표기 규칙이 용어 없이 괄호 안 설명만 쓴 답을 정답 처리

**위치:** /Users/djj/projects/gisa_pass_master/lib/services/answer_checker.dart:53

short_answer 끝 괄호 1쌍 게이트를 통과하면 _parenVariants가 '괄호 안 문구 단독'도 변형으로 인정한다. 이는 '스택(Stack)'→'stack' 같은 영문 대체표기를 위한 것이지만, 괄호가 대체표기가 아니라 부연 설명인 문항에서는 핵심 용어를 아예 쓰지 않은 답이 정답이 된다. 전수 스캔 결과 게이트 통과 문항은 2개뿐이며 그중 short_answer_questions 인덱스 316이 해당된다(인덱스 346의 '또는 Deployment'는 정상 동작 확인).

**실패 시나리오:** short_answer 인덱스 316 '쿠버네티스(Kubernetes)의 주요 역할을 쓰시오' 정답 '컨테이너 오케스트레이션(자동 배포, 확장, 관리)' → 유저가 핵심 용어 '컨테이너 오케스트레이션' 없이 '자동 배포, 확장, 관리'만 입력해도 inside-variant로 정답 처리. python3 시뮬레이션으로 재현(is_correct == true).

**근거:**
```
final inside = RegExp(r'\(([^)]*)\)')
    .allMatches(normalized)
    .map((m) => m.group(1)?.trim() ?? '')
    .where((v) => v.isNotEmpty && !v.startsWith('또는'))
    .toList();
return [ if (withoutParens.isNotEmpty) withoutParens, ..., ...inside ];
```

## 20. [low] 항목별 괄호 벗기기가 CRUD 대응 관계가 틀린 답을 정답 처리

**위치:** /Users/djj/projects/gisa_pass_master/lib/services/answer_checker.dart:63

3b 단계(_allowsItemParenVariants)는 'POST(Create), GET(Read)' 형태에서 괄호를 항목별 부연으로 보고 벗긴 뒤 비교한다. 그 결과 괄호 안 내용은 무엇을 쓰든 채점에 반영되지 않는다. short_answer_questions 인덱스 354는 'REST API에서 CRUD에 대응하는 HTTP 메서드'를 묻는 문항으로, 정답의 괄호가 바로 그 대응 관계(POST=Create 등)를 담고 있는데, 대응을 완전히 뒤바꿔 써도 정답 처리된다. 3b 트리거 문항은 전수 스캔상 6개이며 나머지 5개(343, 346, 353, sql 108, 163)는 괄호가 순수 부연이라 문제없다.

**실패 시나리오:** short_answer 인덱스 354 정답 'POST(Create), GET(Read), PUT(Update), DELETE(Delete)' → 유저가 'POST(Read), GET(Create), PUT(Delete), DELETE(Update)'(대응 관계 전부 오류)를 입력해도 괄호를 벗긴 ['post','get','put','delete'] 끼리 비교되어 정답 처리. python3 시뮬레이션으로 재현(is_correct == true).

**근거:**
```
if (_allowsItemParenVariants(questionType, normCorrect)) {
  final cu = _tokens(normUser).map(_stripItemParen).toList();
  final cc = _tokens(normCorrect).map(_stripItemParen).toList();
  if (_sameOrderedList(cu, cc)) return true;
```

## 21. [low] NSPrivacyTracking=true인데 NSPrivacyTrackingDomains가 빈 배열 — Apple 스펙 문구와 불일치

**위치:** /Users/djj/projects/gisa_pass_master/ios/Runner/PrivacyInfo.xcprivacy:14

Apple 공식 스펙(Privacy manifest files 문서, JSON API로 원문 확인)은 NSPrivacyTracking에 대해 'When set to true you need to provide a list of internet domains in NSPrivacyTrackingDomains'라고 명시하는데, 이 파일은 true 선언 후 도메인 배열을 비워 두었다. 주석은 'Google Mobile Ads SDK가 자체 매니페스트로 선언한다'고 근거를 대며, 실제로 Podfile.lock의 Google-Mobile-Ads-SDK 11.13.0(≥11.2.0)은 자체 프라이버시 매니페스트에 추적 도메인을 포함하므로 실질적 커버는 된다. 또한 2026-08 현재 App Store Connect의 자동 검증(ITMS)은 true+빈 배열 조합을 차단하지 않아 즉시 리젝될 가능성은 낮다. 그 외 검증 항목은 전부 통과: plist 형식 유효(plistlib 파싱), 수집 데이터 타입·목적 상수 전부 Apple 유효값, CA92.1 사유 코드 유효, project.pbxproj Resources 빌드 페이즈에 배선 확인(274행). Info.plist SKAdNetwork 50개(중복 0, 전부 소문자·.skadnetwork 접미사), ATT 문구 존재, AndroidManifest 리시버 exported=false(플러그인 공식 문서와 동일 형태·Dart는 inexactAllowWhileIdle이라 정확 알람 권한 불필요), 백업 규칙 두 파일 실존·유효, desugaring 2.1.4 활성 — 모두 결함 없음.

**실패 시나리오:** 아카이브를 App Store Connect에 업로드 → 심사 단계에서 리뷰어(Guideline 5.1.2 개인정보 검토)가 앱 번들의 PrivacyInfo.xcprivacy를 열어보면 NSPrivacyTracking=true인데 도메인 목록이 비어 있어 스펙 문구('true로 설정하면 도메인 목록을 제공해야 한다')와의 불일치를 근거로 문의/리젝을 걸 수 있다. Apple이 향후 이 조합의 자동 검증을 강화하면(과거 required-reason API의 ITMS-91053처럼) 업로드 자체가 경고/차단될 수 있다. 현재는 SDK 자체 매니페스트가 도메인을 선언하므로 실동작(ATT 거부 시 해당 도메인 요청 차단)은 정상.

**근거:**
```
PrivacyInfo.xcprivacy 10-15행: <key>NSPrivacyTracking</key>\n  <true/>\n  ...\n  <key>NSPrivacyTrackingDomains</key>\n  <array/> — Apple 스펙 원문(developer.apple.com/documentation/bundleresources/privacy-manifest-files): "When set to true you need to provide a list of internet domains in NSPrivacyTrackingDomains." / Podfile.lock 9행: "Google-Mobile-Ads-SDK (11.13.0)" (11.2.0+ 자체 프라이버시 매니페스트 포함)
```

## 22. [low] 기출 회차 풀이 중 모든 문제 카드에 'AI 예측' 라벨이 고정 표시되어 기출/예상 구분 계약과 모순

**위치:** lib/widgets/question_card.dart:71

회차별 문제집은 '기출 기반'과 'AI 예상' 배지로 회차를 구분하는 것이 화면의 핵심 계약이다(round_list_screen.dart 13행 주석: "기출과 예상문제를 반드시 구분해서 표시한다"). 그런데 회차 풀이가 재사용하는 buildPastExamQuiz → _QuizScreen → QuestionCard는 헤더 우상단에 무조건 'AI 예측' 텍스트를 표시한다. AI 예측 학습 화면용으로 만든 카드를 조건 없이 재사용한 결과로, 2020~2025년 실제 기출 문항이 전부 'AI 예측'으로 표기된다. 회차 목록에서 '기출 기반' 배지를 보고 들어온 유저가 풀이 화면에서는 문항마다 반대 라벨을 보게 된다.

**실패 시나리오:** 문제은행 탭 → 회차별 문제집 → '2023년 2회'(배지: 기출 기반) 진입 → 첫 문제 카드 우상단에 'AI 예측' 표시. 실제 기출 문항 56개 전부가 AI 생성 예상문제처럼 표기된다. 반대로 2026년 예상 회차도 동일 라벨이라 구분 정보가 무의미해진다.

**근거:**
```
question_card.dart 70-77행: `const Spacer(), Text('AI 예측', style: TextStyle(color: Colors.grey[500], fontSize: 12,),),` — 문항의 year/round와 무관하게 무조건 렌더링. round_list_screen.dart의 배지(`predicted ? 'AI 예상' : '기출 기반'`)와 모순.
```

## 23. [low] '회차별 문제집' 진입 카드에 중복 탭 가드가 없어 빠른 연타 시 RoundListScreen이 두 번 push됨

**위치:** lib/screens/past_exam_screen.dart:148

같은 파일의 다른 진입 경로는 전부 중복 진입 가드가 있다 — `_loadAndStart`는 `if (_isLoading) return;`(73행), RoundListScreen의 `_open`은 `_opening` 가드(47행). 그런데 이번 커밋에서 새로 추가된 '회차별 문제집' 카드의 onTap만 가드 없이 `Navigator.push`를 직접 호출한다. 알려진 실패 패턴 (a) '같은 로직 복붙 후 한쪽만 수정'의 사례로, 페이지 전환 애니메이션 중 이전 화면이 여전히 히트테스트를 받으므로 빠른 두 번째 탭이 두 번째 push를 만든다.

**실패 시나리오:** 문제은행 탭에서 '회차별 문제집' 카드를 빠르게 두 번 탭(전환 애니메이션 완료 전) → RoundListScreen 라우트가 2장 쌓임 → 뒤로가기를 눌러도 다시 회차 목록이 나와 유저가 뒤로가기를 두 번 해야 문제은행으로 돌아온다. DB 손상은 없으나 내비게이션이 눈에 띄게 어긋난다.

**근거:**
```
past_exam_screen.dart 148-152행: `onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoundListScreen(db: widget.db),),),` — 가드 없음. 대조: 같은 파일 73행 `if (_isLoading) return;`, round_list_screen.dart 47-48행 `if (_opening) return; _opening = true;`
```

## 24. [low] 구독 화면이 무료로 이미 전부 열려 있는 기능('AI 무제한 예측 문제')과 게이트가 존재하지 않는 기능('기출 유형 심층 분석')을 프리미엄 전용으로 판매

**위치:** lib/screens/subscription_screen.dart:345

구독 화면 기능 비교표는 'AI 무제한 예측 문제'(free: false)와 '기출 유형 심층 분석'(free: false)을 프리미엄 전용으로 표시한다. 그러나 실제 코드에서 예측 학습(StudyMode.prediction, PredictionEngine 기반 loadQuestions)은 home_screen에서 아무 게이트 없이 무료 유저에게 무제한 제공되고, '기출 유형 심층 분석'이라는 이름으로 게이팅된 기능은 코드 어디에도 없다(stats_screen·round_list_screen·cheat_sheet_screen 전체에 isPremium 참조 grep 결과 0건). 실제로 프리미엄이 여는 것은 광고 제거, AI 실전 모의고사 무제한(무료 1회/일), 학습플랜 Day 4 이후뿐이다. 결제 유저가 '산 것'과 실제 받는 것이 달라 환불·리뷰 분쟁 및 스토어 심사(기능 허위 표기) 리스크가 있고, 유료 결제 유저가 이미 존재하는 앱에서 판매 문구와 코드의 불일치는 그 자체가 결함이다.

**실패 시나리오:** 무료 유저가 홈에서 '예측 학습' 진입 → 게이트 없이 PredictionEngine이 고른 50문항 세션을 횟수 제한 없이 반복 사용 가능(home_screen.dart:106 provider.loadQuestions() — isPremium/쿼터 확인 없음). 한편 결제 유저가 비교표의 '기출 유형 심층 분석'을 찾으면 해당 기능 자체가 없다. 구매 전후 기능 차이가 표와 달라, 4,900원 결제 유저가 '무료와 다를 게 없다'며 환불을 요구하는 재현 경로가 성립한다.

**근거:**
```
lib/screens/subscription_screen.dart:345-347
  _FeatureRow(label: 'AI 무제한 예측 문제', free: false, premium: true),
  _FeatureRow(label: 'AI 실전 모의고사 무제한', free: false, premium: true),
  _FeatureRow(label: '기출 유형 심층 분석', free: false, premium: true),
대조 — lib/screens/home_screen.dart:105-112 예측 학습 진입에 프리미엄·쿼터 게이트 없음: else { await provider.loadQuestions(); } ... Navigator.push(... QuizScreen(mode: mode))
'심층 분석' 게이트 부재: grep isPremium — stats_screen.dart·round_list_screen.dart·cheat_sheet_screen.dart 매치 0건
```

## 25. [low] StatsScreen이 NotificationOptIn.onEnabled 정적 값을 build 시점에 캡처 — 할당 전에 열린 통계 탭에선 토글 ON이 복습 알림을 예약하지 못함

**위치:** lib/screens/stats_screen.dart:55

NotificationOptIn.onEnabled(정적 필드)는 시작 postFrame 체인 끝부분(main.dart:194, AdMob+ATT+스토어 init 이후)에서야 할당된다. StatsScreen.build는 이 정적 값을 그 시점 값 그대로 읽어 `_StatsDashboard(onEnableNotifications: ...)` → NotificationSettingsTile 생성자로 흘려보낸다. 체인이 끝나기 전에 통계 탭이 빌드되면 null이 캡처되고, 이 null은 다음 StatsProvider notify로 인한 재빌드까지(탭에 머무는 동안은 무기한) 유지된다. 그 상태에서 토글을 켜면 tile은 scheduleExamCountdown만 수행하고 `widget.onEnabled?.call()`(notification_settings_tile.dart:56)이 null이라 복습 알림 재예약이 누락된다. quiz_screen의 옵트인 다이얼로그는 호출 시점에 정적 값을 직접 읽어(notification_opt_in.dart:93) 이 캡처 문제가 없다 — 같은 콜백을 쓰는 두 경로 중 한쪽만 안전한 배선이다.

**실패 시나리오:** 복습 큐가 쌓여 있고 알림이 꺼진 유저가 콜드 스타트 직후(시작 체인이 main.dart:194에 도달하기 전) 통계 탭을 엶 → StatsScreen이 onEnabled=null을 캡처 → loadStats 완료 재빌드도 체인 완료 전이면 여전히 null → 유저가 탭에 머문 채 잠시 후 '복습 알림' 토글 ON → 권한 허용 → D-Day 알림만 예약되고 밀린 복습 알림(연체 시 +30분 발송분)은 예약되지 않음 → '복습 시기를 알려드려요'라는 화면 약속과 달리 그 세션에서 문제를 추가로 풀거나 앱을 재시작하기 전까지 복습 알림이 오지 않는다.

**근거:**
```
stats_screen.dart:52-56 `: _StatsDashboard(stats: stats, onEnableNotifications: NotificationOptIn.onEnabled,)` — build 시점의 정적 값 캡처. 할당 시점: main.dart:194-195 `NotificationOptIn.onEnabled = widget.spacedRepetitionService.rescheduleReviewNotification;` (AdService.initialize·ATT·PurchaseService.initialize await 이후). 소비처: notification_settings_tile.dart:54-56 `if (granted) { await NotificationService.scheduleExamCountdown(); await widget.onEnabled?.call(); }`.
```

