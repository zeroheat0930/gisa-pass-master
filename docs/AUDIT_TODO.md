# 감사 후속 조치 (AUDIT TODO)

2026-08-07 다중 에이전트 감사 결과. **1차 49개 + 2차 139개 에이전트**, 소모 토큰 약 720만.

판정 기준: 발견 건마다 **반박 담당 / 재현 담당 검증자 2명**을 독립으로 붙여, 둘 다 실제 결함이라고
판정한 것만 `확정`. 갈리면 `가능성`, 둘 다 부정하면 `기각`.

- 1차: 91건 발견 → 상위 16건 재검증 → **확정 16 / 기각 0**
- 2차: 나머지 69건 재검증 → **확정 37 / 가능성 20 / 기각 12**
- 진행 상황: **수정 완료 20건** (데이터 오답 6건 + 시드 갱신 마이그레이션 포함), 남은 확정 약 28건

---

## 수정 완료 (커밋 `ddda66d`, `a57bb2c`, `f76277d`)

- [x] `purchase_service.dart` — 앱 재시작 시 결제한 프리미엄 소멸
- [x] `purchase_service.dart` — 스토어 연결 실패 시 `purchaseStream` 미구독으로 결제 반영 안 됨
- [x] `purchase_service.dart` — 재설치·기기변경 시 평생 이용권 소실 (설치당 1회 자동 복원)
- [x] `answer_checker.dart` — 순서 무관 규칙이 출력 문제 오답을 정답 처리 (269문항 영향)
- [x] `answer_checker.dart` — `Set == Set` 객체 동일성 비교로 순서 규칙이 죽어 있던 것
- [x] `answer_checker.dart` — 쉼표까지 제거해 항목 경계 소실 (`_stripSeparators`)
- [x] `answer_input_field.dart` — 여러 줄 정답에서 엔터가 줄바꿈 대신 제출로 동작
- [x] `study_provider.dart` / `spaced_repetition_service.dart` — 정답 시 `processAnswer` 미호출로
      오답노트가 영원히 안 비워지고 복습 간격이 1분에 고정
- [x] `database_service.dart` — DB v1·v2 유저가 `duplicate column` 예외로 DB를 영영 못 여는 문제
- [x] `ad_service.dart` — 로드 실패 콜백이 이미 로드된 광고를 사용 불가로 만들어 전면광고 수익 중단
- [x] `ad_service.dart` — 동시 로드 가드 부재로 광고 유실 (네이티브 누수 + fill 낭비)
- [x] `test/` — 채점 로직 **사본**을 검증하던 테스트, 구매 영속화의 **읽기만** 검증하던 테스트

---

## 남은 확정 결함

### HIGH

- [x] ~~`lib/screens/past_exam_screen.dart:436` — 문제은행 탭·AI 예측 모의고사 풀이가 DB에 전혀
      기록되지 않음~~ → `StudyProvider.recordAnswer()` 진입점을 만들어 두 화면에서 호출.
      기록 로직을 화면마다 복붙하지 않도록 정본 하나만 둠
- [ ] `lib/screens/quiz_screen.dart:195` — 학습플랜 '미션 완료' 정답 수에 **전체 문항 수**를 넘겨
      일별 정답률이 항상 100%로 기록됨
- [ ] `lib/main.dart:171` — `IndexedStack` 탭 캐싱 때문에 통계가 **앱 재시작 전까지 절대 자동 갱신 안 됨**
- [ ] `lib/screens/stats_screen.dart:384` — '전체 문제 완료율'이 중복 풀이를 세어 부풀려지고
      100% / 1000문제를 초과 표시
- [ ] `lib/screens/subscription_screen.dart:77` — 구독 화면이 프리미엄 구매 상태를 반영하지 않아
      **결제한 유저에게 계속 "프리미엄 시작하기"** 노출
- [ ] `lib/services/purchase_service.dart:182` — 복원이 `_available=false`면 조용히 무시되는데
      UI는 "구매 복원 중..."만 띄우고 끝남
- [ ] `lib/services/answer_checker.dart:51` — `toLowerCase()` 정규화가 **대소문자 변환 자체를 묻는
      문항**을 무력화 (입력 문자열을 그대로 적어도 정답)
- [ ] `lib/screens/cheat_sheet_screen.dart:25` — 족보 검색이 표 형식 섹션(OSI 7계층) 내용을 못 찾아
      '검색 결과 없음' 표시
- [ ] `test/widget_test.dart:5` — 위젯 테스트가 통째로 없어 `AnswerInputField`의 멀티라인 동작을
      되돌려도 전부 통과
- [ ] `test/app_test.dart:33` — '연타 테스트'가 아무 코드도 실행하지 않아 중복 제출 가드를 제거해도 통과

### MEDIUM

- [ ] `lib/services/spaced_repetition_service.dart:42` — 오답 시 stage를 2단계만 강등해 방금 틀린
      문제를 최대 3일 뒤로 미룸 (에빙하우스 원칙 위배)
- [ ] `lib/providers/study_provider.dart:205` — 전면광고가 채점 직후 provider 내부에서 즉시 떠서
      정답/오답 이펙트를 덮음. 화면의 `shouldShowAd`/`clearAdFlag`는 무의미한 껍데기
- [ ] `lib/widgets/dday_timer.dart:31` — D-Day가 하루씩 적게 표시되고 시험 당일 아침부터 '시험 완료!'
- [ ] `lib/screens/home_screen.dart:116` — 'AI 실전 모의고사'가 결제 안내에는 유료 전용인데
      **코드에 게이트가 전혀 없음** (수익 누수)
- [ ] `lib/screens/stats_screen.dart:740` — 약점 분석이 정답률 100%인 영역까지 '집중 학습 권장'으로 표시
- [ ] `lib/screens/quiz_screen.dart:52` — 제출 중 DB 쓰기 예외 시 입력창·제출·다음 버튼이 전부 사라져
      해당 문제에서 진행 불가로 고착
- [ ] `lib/screens/quiz_screen.dart:192` — 완료 화면에서 뒤로가기 시 플랜 Day 진행이 통째로 유실
- [ ] `lib/widgets/answer_effect.dart:192` — 오버레이가 루트 Overlay에 static 엔트리를 삽입해
      제출 직후 뒤로가기 시 이전 화면이 최대 1.2초 터치 차단됨
- [ ] `lib/widgets/answer_input_field.dart:46` — 입력창 힌트/모드가 "정답이 여러 줄인지"를
      **문제 풀기 전에 노출**해 힌트가 됨 (트레이드오프. 재검토 필요)
- [ ] `lib/screens/past_exam_screen.dart:667` — 소요 시간이 60분 이상에서 '시' 단위를 버려 거짓 시간 표시
- [ ] `lib/screens/ai_prediction_screen.dart:85` — 경과 시간이 60분에서 `00:xx`로 롤오버
- [x] ~~`lib/services/database_service.dart:107` — 문제 시드가 최초 설치 때 1회만 읽혀 정답 수정이
      기존 유저에게 반영되지 않음~~ → DB v6 `syncQuestionsFromAssets` 로 해결
- [ ] `lib/services/database_service.dart:175` — 웹 빌드에서 북마크·복습 큐 조회에 `kIsWeb` 분기가 없어
      항상 0건 반환
- [ ] `lib/services/study_plan_service.dart:454` — '약점 집중 공략'이 한 번도 틀린 적 없는 문제를
      약점으로 넣고 보충 문항과 중복될 수 있음
- [ ] `lib/screens/subscription_screen.dart:41` — 이전 결제 실패 에러가 안 지워져 정상 결제 시도 중에
      엉뚱한 실패 스낵바가 뜸
- [ ] `integration_test/app_test.dart:130` — 탭 이름이 실제 UI와 달라 '탭 50회 왕복' 테스트가
      아무 탭도 누르지 않고 통과

### LOW

- [ ] `lib/services/purchase_service.dart:195` — `grantPremium()`을 await 하지 않고 `completePurchase()`
      호출 — 저장 전 종료 시 구매 근거 소실
- [ ] `lib/screens/ai_prediction_screen.dart:212` — 시험 중 스와이프 백 시 경고 없이 진행 전량 소실 (`PopScope` 부재)
- [ ] `lib/services/answer_checker.dart:16` — 괄호 안 대체표기·부연설명 미처리로 맞게 쓴 답이 오답 처리
- [ ] `lib/screens/quiz_screen.dart:50` — 빈/공백 입력으로 제출 시 3개 화면 모두 무반응 (안내 없음)

---

## 문제 데이터 오답 — ✅ 수정 완료

| 파일 | 인덱스(0-based) | 수정 전 | 수정 후 |
|---|---|---|---|
| `c_questions.json` | **22** | `threefoureother` | `threefourother` |
| `java_questions.json` | 55 | `0` | `-80` |
| `sql_questions.json` | 1 | `1001, 87.5\n1003, 95` | `1003, 95` |
| `sql_questions.json` | 64 | `3, 185\n1, 175` | `3, 185` |
| `sql_questions.json` | 67 | `전자, 3, 541666.67` | `전자, 3, 541666.67\n가구, 2, 225000` |
| `sql_questions.json` | 74 | `박, 5000\n이, 6000\n김, 4000` | `이, 6000\n박, 5000\n김, 4000` |

**근거**

- **c 22** — `switch(x)`에서 x=3이고 `break`가 없어 fall-through로 `three`+`four`+`other`가
  출력되므로 `threefourother`. 저장값에는 `four` 뒤에 `e`가 하나 더 붙어 있었다.
  *(이전 판 문서에서 "오탐 가능성"이라고 적었던 것은 내가 인덱스 21을 확인한 실수였다.
  실제로는 인덱스 22의 진짜 버그였고, 1차 감사 지적이 맞았다.)*

- **java 55** — Java 복합대입은 **좌변 값을 우변 평가 전에 저장**한다.
  `x=10; x += x -= x *= x;` → `x*=x`로 x=100 → `x-=100`은 저장된 10을 써서 -90 → `x+=-90`도
  저장된 10을 써서 **-80**. 저장된 정답 `0`과 해설 모두 틀렸으므로 **해설도 함께 고칠 것**.
- **sql 1** — `HAVING AVG(점수) >= 88`인데 1001의 평균은 87.5 → 제외. 해설은 이미 "1003만"이라고 되어 있음.
- **sql 64** — `HAVING SUM(점수) >= 180`인데 학번 1은 175 → 제외. 해설은 이미 "3만 출력".
- **sql 67** — `HAVING AVG(가격) > 200000`을 가구(225000)도 통과. 해설은 이미 "전자, 가구 둘 다".
- **sql 74** — `ORDER BY 총구매액 DESC`인데 행 순서가 내림차순이 아님. 해설은 이미 "이, 박, 김".

> 데이터 수정만으로는 기존 유저에게 반영되지 않으므로, **DB v6 마이그레이션
> (`syncQuestionsFromAssets`)** 을 함께 넣었다. id 를 보존하며 내용만 갱신하고,
> 없는 문항은 추가한다. 회귀 테스트는 `test/db_migration_test.dart`.

---

## 채점기 후속 개선 (데이터 수정과 함께 필요)

`sql_questions.json` 67번처럼 **`ORDER BY`가 없는 SQL 결과는 행 순서가 보장되지 않는다.**
그런데 현재 `AnswerChecker`는 SQL을 순서 엄격으로 채점하므로, 유저가 `가구` 행을 먼저 쓰면 오답이 된다.

→ `isCorrectFor`에 `codeSnippet`을 넘기고, `questionType == 'sql'`이면서 `ORDER BY`가 없으면
**행(개행) 단위 다중집합**으로 비교하도록 보강할 것.
쉼표 단위로 쪼개면 행 경계가 깨지므로 **반드시 개행 기준**으로 나눌 것.

---

## 판정이 갈린 항목 (사람 확인 필요, 20건 중 주요 건)

- [x] ~~`lib/services/database_service.dart` — questions 갱신 마이그레이션 부재~~ → DB v6 로 해결
- [ ] `lib/screens/past_exam_screen.dart` — `_submit()` 중복 제출 가드 부재 → 인덱스 어긋남, 만점 초과
- [ ] `lib/providers/study_provider.dart` — AI 예측이 1000문항이 아닌 **무작위 50문항만** 정렬해
      사실상 랜덤 출제
- [ ] `lib/screens/study_plan_screen.dart` — 프리미엄 게이팅 사실상 무력화 (1일/3일 플랜 전 구간 무료,
      플랜 리셋 무제한) *(수익 직결)*
- [ ] `ios/Runner/Info.plist` — `SKAdNetworkItems`에 AdMob 자기 ID 1개만 등록되어 미디에이션
      수요처의 설치 어트리뷰션이 전부 유실 *(광고 수익 직접 손실)*
- [ ] `android/app/src/main/AndroidManifest.xml` — `allowBackup` 제어가 없어 이번에 도입한
      프리미엄 캐시(SharedPreferences)가 백업/기기이전으로 **복제**될 수 있음
- [ ] `lib/main.dart` — ATT 요청을 `runApp()` 이전(앱 비활성)에 await → 프롬프트 미표시 또는 스플래시 멈춤
- [ ] `lib/services/ad_service.dart` — 배너 로드 실패 시 재시도가 없어 해당 화면 세션의 배너 수익 0

---

## 실기기 검증 체크리스트 (배포 전 필수)

1. 샌드박스 결제 → 앱 완전 종료 → 재실행 → **프리미엄 유지**
2. 여러 줄 정답 문제에서 **엔터가 줄바꿈**으로 동작하고 정답 처리되는지
3. 틀린 문제 → 오답노트 → 정답 → **큐에서 빠지고 간격이 1분→10분으로 증가**하는지
4. logcat으로 **전면광고가 3문제마다 실제 송출**되는지 (단위 테스트 불가 항목)

DB 마이그레이션은 `test/db_migration_test.dart`로 대체 검증했으므로 실기기 항목에서 제외.

---

## 구조적 교훈

이 앱에서 버그가 반복된 근본 패턴은 두 가지다.

1. **같은 로직이 여러 곳에 복붙되고 한쪽만 고쳐진다.** 채점 로직 3벌, 입력창 3벌, DB 기록 3벌 중
   1벌만 구현. → 정본 파일(`answer_checker.dart`, `answer_input_field.dart`)로 통합했고,
   새 로직을 만들 때 사본을 만들지 말 것.
2. **테스트가 실제 코드가 아니라 사본·껍데기를 검증한다.** 앱이 틀려도 초록불이 뜬다.
   → 테스트를 추가할 때 "이 테스트는 그 버그를 되돌리면 실제로 실패하는가"를 반드시 확인할 것.
   `test/db_migration_test.dart`에 그 확인을 테스트로 박아두었다(구 구현이 예외를 던지는지 검증).
