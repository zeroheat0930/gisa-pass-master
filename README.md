# 기사패스마스터 (gisa_pass_master)

> 2026 정보처리기사 실기 스파르타 예측 학습 앱

시험일까지 남은 시간을 실시간으로 보여주며, AI 출제 예측 엔진과 에빙하우스 망각곡선 기반 오답 반복 시스템으로 유저를 합격까지 밀어붙이는 학습 앱입니다.

## 주요 기능

### D-Day 실시간 카운트다운
- 시험일까지 남은 일/시/분/초를 빨간색으로 표시
- 절박함을 시각적으로 전달하는 다크 UI

### AI 출제 예측 엔진
- 2020~2026년 문항 빈도 기반 가중치 계산
- `priority_score = 빈출도(40%) + 최신성(30%) + 유형가중치(20%) + 약점(10%)`
- 상위 우선순위 풀에서 무작위로 뽑는다. 정렬 결과를 그대로 자르면 점수가
  결정적이라 매 세션 똑같은 문제만 나오기 때문

### 스파르타 오답노트
- 에빙하우스 망각곡선 기반 8단계 간격 반복 (1분 ~ 14일)
- 정답 시 다음 단계로 승격, **오답 시 처음(1분)으로 리셋**
- 복습 시기가 되면 알림으로 알려줌

### 합격 예측 점수
- 실기 60점 합격 기준으로 현재 실력을 환산
- 유형별 배점(코드분석 40% / SQL 30% / 단답형 30%) 가중 평균
- 표본이 적으면 합격선 쪽으로 축소 보정 — 5문제 맞히고 "합격 확실"이라고
  말하지 않는다 (20문제 미만은 예측하지 않음)

### 복습 알림
- 다음 복습 예정 시각에 1건, 시험 D-30 / D-7 / D-1 아침 9시
- 권한은 첫 실행이 아니라 "틀린 문제가 쌓인" 시점에 제안한다

### 다크 모드 코드 뷰어
- 모노스페이스 폰트로 코드 가독성 극대화
- 신택스 하이라이팅은 v1.3.0+16 에서 제거됨 (긴 코드에서 성능 문제)

### 정답/오답 이펙트
- 정답: 초록색 플래시 + 체크 아이콘 애니메이션
- 오답: 빨간색 셰이크 + X 아이콘 경고

### 학습 통계
- 전체/오늘 풀이 수 및 정답률
- 과목별, 유형별 정답률 분석
- 연속 학습일 트래킹

### 수익화
- 배너 + 전면광고(`AppConfig.adIntervalQuestions` 문제마다). 광고는 채점 직후가
  아니라 **다음 문제로 넘어갈 때** 표시 — 정답/오답 결과를 덮지 않도록
- 리워드 광고: 모의고사 무료 1회를 다 쓰면 광고를 보고 1회 더 (하루 상한 2회)
- 프리미엄 4,900원 — **1회성 비소모성(평생 이용)**. 광고 제거 + 무제한
- ⚠️ 리워드 광고 ID 는 아직 Google 테스트 ID. `ad_service.dart` 참조

## 기술 스택

| 구분 | 기술 |
|------|------|
| 프레임워크 | Flutter 3.41+ |
| 상태 관리 | Provider (ChangeNotifier) |
| 로컬 DB | sqflite + sqflite_common_ffi_web |
| 광고 | google_mobile_ads |
| UI | Material 3 Dark Theme |
| 아키텍처 | Clean Architecture (models/services/providers/screens/widgets) |

## 프로젝트 구조

```
lib/
├── config.dart                      # 앱 설정 + 시험 일정(자동 회차 전환)
├── main.dart                        # 엔트리포인트 + MultiProvider + ATT/알림 초기화
├── models/                          # question / answer_record / study_stats / study_plan
├── services/
│   ├── database_service.dart        # 스키마 + 마이그레이션(runMigrations) + CRUD
│   ├── answer_checker.dart          # 채점 로직 **단일 정본** (사본 만들지 말 것)
│   ├── prediction_engine.dart       # 출제 예측 + 세션 선정(selectForSession)
│   ├── spaced_repetition_service.dart  # 에빙하우스 반복 + 알림 재예약
│   ├── pass_predictor.dart          # 합격 예측 점수 (60점 기준)
│   ├── notification_service.dart    # 복습/D-Day 알림
│   ├── ai_exam_quota.dart           # 모의고사 무료 쿼터 + 광고 보상
│   ├── ad_service.dart              # 배너/전면/리워드 광고
│   ├── purchase_service.dart        # 인앱결제 + 구매 영속화
│   └── study_plan_service.dart      # 학습 플랜 미션
├── providers/                       # study_provider / stats_provider
├── screens/                         # home / quiz / past_exam / ai_prediction /
│                                    # cheat_sheet / stats / study_plan / subscription
├── utils/duration_format.dart       # 경과 시간 표기 정본
└── widgets/
    ├── answer_checker 계열          # answer_input_field(입력창 정본) / answer_effect
    ├── pass_score_card.dart         # 합격 예측 카드
    ├── exam_quota_dialog.dart       # 쿼터 소진 안내 정본
    ├── notification_opt_in.dart     # 알림 권한 제안
    └── dday_timer / question_card / code_viewer / smooth_transition

test/
├── wiring_test.dart                 # **배선 테스트** — 부품이 아니라 연결을 검증
├── answer_checker_test.dart         # 채점 규칙
├── db_migration_test.dart           # 마이그레이션 (실기기 없이)
├── purchase_persistence_test.dart   # 구매 영속화 (쓰기+읽기)
├── pass_predictor_test.dart         # 합격 예측
├── ai_exam_quota_test.dart          # 쿼터 + 광고 보상
├── answer_recording_test.dart       # "채점하면 반드시 기록한다" 불변식
├── exam_quota_dialog_test.dart      # 리워드 광고 시청 → 지급 배선
├── question_card_layout_test.dart   # 좁은 화면 × 큰 글씨 오버플로 회귀
└── widget_test.dart                 # 입력창 / 정답 이펙트 오버레이
```

### 이 코드베이스에서 반복된 실패 패턴

두 가지가 계속 사고를 냈다. 새 코드를 짤 때 반드시 피할 것.

1. **같은 로직을 복붙하고 한쪽만 고친다.** 채점 로직 3벌, 입력창 3벌, 시간 표기
   5벌, DB 기록 3벌 중 1벌만 구현 — 전부 실제 버그로 이어졌다.
   정본 파일이 있으면 그것만 쓸 것.
2. **테스트가 부품만 검증하고 연결을 안 본다.** 핵심 수정 3개를 통째로 되돌려도
   테스트 77건이 전부 통과한 적이 있다. 테스트를 추가할 때는
   **"그 버그를 되돌리면 이 테스트가 실제로 실패하는가"** 를 반드시 확인할 것.

## 시작하기

### 요구사항
- Flutter 3.41 이상
- Dart 3.11 이상

### 설치 및 실행

```bash
git clone https://github.com/your-repo/gisa_pass_master.git
cd gisa_pass_master
flutter pub get
flutter run
```

### 플랫폼별 실행

```bash
flutter run -d chrome    # 웹
flutter run               # 연결된 모바일 디바이스
```

### 시뮬레이터에서 검증하기

정적 검증(test/analyze/build)이 전부 통과하는데도 릴리즈에서 앱이 깨지는
버그가 실제로 있었다(Overlay ParentDataWidget). 배포 전 한 번은 띄워볼 것.

```bash
xcrun simctl boot "iPhone 17 Pro"
flutter test integration_test/app_test.dart -d <시뮬레이터ID> --dart-define=SKIP_ATT=true
```

`SKIP_ATT` 는 ATT 시스템 모달이 자동화를 덮는 것을 막는다(시뮬레이터는
`simctl privacy` 로 이 권한을 미리 설정할 수 없다). 실제 빌드에는 영향이 없다.

## 템플릿 시스템

`lib/config.dart` 하나만 수정하면 다른 자격증 앱으로 즉시 변환할 수 있습니다.

### 컴활 1급 앱으로 변환 예시

```dart
class AppConfig {
  static const String appTitle = '컴활패스마스터';
  static const String appSubtitle = '2026 컴퓨터활용능력 1급 실기';
  static const String examLabel = '컴퓨터활용능력 1급 실기 시험';
  static final DateTime examDate = DateTime(2026, 5, 10);
  static const Color primaryColor = Color(0xFF2196F3);
  static const String dbName = 'comhwal_master.db';
  // ...
}
```

### 변경 가능한 설정 항목

| 항목 | 설명 | 예시 |
|------|------|------|
| `appTitle` | 앱 이름 | "한국사패스마스터" |
| `primaryColor` | 테마 메인 색상 | `Color(0xFF4CAF50)` |
| `examDate` | 시험일 (D-Day용) | `DateTime(2026, 6, 7)` |
| `dbName` | DB 파일명 | `"history_master.db"` |
| `adIntervalQuestions` | 광고 간격 (N문제마다) | `7` |
| `examLabel` | D-Day 타이머 라벨 | "한국사능력검정시험" |

## DB 스키마

### questions (문제)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | INTEGER PK | 자동 증가 |
| year | INTEGER | 출제 연도 |
| round | INTEGER | 회차 |
| subject | TEXT | 과목 |
| question_type | TEXT | code_reading / sql / short_answer |
| question_text | TEXT | 문제 본문 |
| code_snippet | TEXT | 코드 (nullable) |
| code_language | TEXT | c / java / sql (nullable) |
| answer | TEXT | 정답 |
| explanation | TEXT | 해설 |
| difficulty | INTEGER | 난이도 (1-5) |
| frequency_weight | REAL | 빈출 가중치 (0.0-1.0) |

### answer_records (풀이 기록)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | INTEGER PK | 자동 증가 |
| question_id | INTEGER FK | questions.id |
| is_correct | INTEGER | 0 or 1 |
| user_answer | TEXT | 유저 입력 답 |
| answered_at | TEXT | ISO8601 타임스탬프 |
| time_spent_seconds | INTEGER | 풀이 소요 시간 |

### spaced_repetition (반복 학습)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | INTEGER PK | 자동 증가 |
| question_id | INTEGER FK | questions.id (UNIQUE) |
| stage | INTEGER | 반복 단계 (0-7) |
| next_review_at | TEXT | 다음 복습 시각 |
| consecutive_correct | INTEGER | 연속 정답 수 |
| last_reviewed_at | TEXT | 마지막 복습 시각 |

## 문제 데이터

`assets/questions/*.json` 에 **총 1,000문항**.

| 파일 | 문항 수 |
|------|--------|
| `c_questions.json` | 150 |
| `java_questions.json` | 150 |
| `python_questions.json` | 150 |
| `sql_questions.json` | 192 |
| `short_answer_questions.json` | 358 |

이 중 **125문항은 정답이 여러 줄**이다(실행 결과 문제). 채점과 입력 처리에서
늘 특수 케이스이므로 `AnswerChecker` / `AnswerInputField` 를 고칠 때 반드시 확인할 것.

문제 데이터는 최초 설치 때 DB 에 시딩되고, 이후 수정은 `syncQuestionsFromAssets`
(DB v6 마이그레이션)로 기존 유저에게 반영된다. **id 를 보존**해야 학습 이력이
엉뚱한 문제에 붙지 않는다.

## 변경 이력

### v1.6.3+27 (2026-08-11)

재감사 검증이 완주됐다(총 33건 → 확정 23·가능성 2·기각 1·미검증 3).
이번 판은 v1.6.2 에서 못 다룬 **확정 잔여분 전부**를 수정한다.

#### 채점 (3건)
- "알고리즘 2개"·"빅데이터의 3V" 류 나열 문항에서 순서만 바꾼 정답이 오답 처리
  → 'N개'·'NV' 표현도 순서 무관으로 인정 (code_reading 은 여전히 순서 엄격)
- "컨테이너 오케스트레이션(자동 배포, 확장, 관리)"에서 괄호 안 설명만 쓴 답이
  정답 처리 → 괄호 단독 답변은 한 단어 동의어("스택(stack)")일 때만 인정
- CRUD 항목별 괄호에서 대응 관계를 뒤바꿔 써도 정답 처리
  → 유저가 괄호를 직접 썼으면 내용까지 채점

#### 문제 데이터 + DB v7
- **c_questions[106] — 1000문항 중 유일하게 실측과 불일치하던 문항 교체.**
  `printf("%d %d %d", i, i++, i)` 는 C 표준상 미정의 동작이라 등록 정답
  '6 5 6'(gcc 가정)이 clang 실측 '5 5 6'과 다르고, 같은 파일 87·119번과 정반대
  평가순서를 가정해 모순이었다. 잘 정의된 후위 증가 문항으로 교체(실측 '5 6' 일치).
  본문 수정은 리비전 동기화로 불가능하므로(매칭 키) **DB v7 마이그레이션**으로
  id 를 보존한 채 UPDATE — README 의 "본문 수정 절차" 첫 실사용

#### 복습 엔진
- **졸업 도입** — 마지막 단계(14일)에서 또 맞히면 큐에서 제거한다. 지금까지는
  한 번 틀린 문항이 영구히 14일 주기로 순환해 오답노트를 비울 수 없었고,
  시험이 끝나도 알림이 계속 왔다. "빈 큐면 알림 취소" 경로도 이제 실제로 도달한다
- 오답 직후 1분 뒤 알림이 학습 중 화면 위로 뜨던 문제 — 30분 유예를 미래 분기에도 적용
- 알림 OFF 가 초기화 전이면 조용히 실패하던 cancelAll — 초기화 보장 후 취소
- 앱 시작 직후 통계 탭에서 알림을 켜면 복습 알림이 예약되지 않던 창 제거
  (onEnabled 할당을 첫 프레임 전 동기 시점으로 이동)

#### 화면·판매 문구
- 구독 화면이 게이트 없는 기능('AI 무제한 예측 문제')과 존재하지 않는 기능
  ('기출 유형 심층 분석')을 유료 전용으로 판매 → 실제 게이트가 있는 것만 표기
- 통계 정답률 링이 96px 가 아니라 36px 로 붕괴(텍스트가 링을 덮음) → Positioned.fill
- 학습 완료 화면 rebuild 마다 알림 옵트인 다이얼로그가 겹쳐 뜰 수 있던 레이스 → 1회 가드
- 문제 카드 'AI 예측' 고정 라벨 → 문항 연도 기준 '기출'/'AI 예상' 표기
- 쿼터 다이얼로그: 리워드 로드 실패 시 '광고 준비 중...' 영구 고착 → 2초마다 재요청
- '회차별 문제집' 카드 연타 시 화면이 두 장 쌓이던 문제 → 가드
- owner 미기록 결제 유저(초기 구매자) 백업 복제 방어 백필
- isRewardedUsingTestId 가 Android 만 검사하던 복붙 비대칭 수정

#### 검증
- 테스트 160건 → **173건**. `analyze` 0건. 시뮬레이터 통합 테스트 통과
- 배선 테스트 강화: 리워드 다이얼로그 진입점, 홈 복귀 loadStats 2곳,
  홈 탭 갱신 조건, 기출/예상 경계, 복습 졸업, DB v6→v7 교체

> **미수정:** 리워드 광고 실 ID 교체(사람: AdMob 콘솔 — 현재 수익 0 + 'Test Ad'
> 노출 중, **최우선**), PrivacyInfo NSPrivacyTrackingDomains 빈 배열(가능성 판정 —
> SDK 매니페스트가 실질 커버, 심사 문의 시 대응), DB v1 유저 이력 삭제(미검증,
> v1 배포 이력상 대상자 거의 없음)

### v1.6.2+26 (2026-08-11)

전면 재감사(68 에이전트)의 교차 검증에서 **확정된 4건** 수정.
원시 발견 전체는 docs/FABLE5_REAUDIT_RAW_2026-08-11.md (잔여 검증 재개 명령 포함).

- **Android 미종결 구매가 3일 후 Google 에서 자동 환불되던 경로 차단** —
  "미종결 구매는 다음 실행에 스트림으로 재전달된다"는 전제가 iOS(StoreKit)에만
  참이었다. Android 는 매 실행 복원(queryPurchases, UI 없음)을 돌려 acknowledge
  누락·pending 승인 건을 재수신한다
- **공백 구분 숫자 출력 96문항에서 값을 붙여 쓴 오답("3050" vs "30 50")이
  정답 처리되던 문제** — 정답에 숫자-공백-숫자 경계가 있으면 공백 제거 비교를
  건너뛴다 ("상호 배제" 류 띄어쓰기 관용은 유지)
- **기록 배선 테스트가 선언문·주석에 매칭되어 무력화** — 채점-무기록 회귀
  (v1.5.4 재판)를 되돌려도 통과했다. 주석 제거 + 호출식 매칭으로 교체
- **회차별 문제집 테스트 신설** — 기출/AI 예상 배지 구분과 (연도, 회차) 인자
  배선 검증. 인자를 뒤바꾸는 뮤테이션이 실제로 실패함을 확인

테스트 160건, `analyze` 0건. 세 수정 모두 뮤테이션(되돌림)으로 테스트가
실제로 잡는지 확인함.

### v1.6.1+25 (2026-08-11)

Fable 5 재점검(docs/FABLE5_AUDIT_2026-08-10.md)에서 확정된 결함 수정판.

#### 결제 (수익 직결)
- **Android 결제 유저가 OS 업데이트 후 무료로 강등되던 문제** — 기기 지문이
  Build.ID 라 OS 업데이트마다 바뀌었고, 같은 펌웨어 기기끼리는 동일해 백업 복제
  감지 목적에도 무력했다. Android 는 지문 검사를 생략한다
- **'구매 복원' 버튼이 침묵으로 죽던 문제** — 시작 시 1회 판정된 스토어 가용성이
  false 로 남으면 복원 요청 없이 return 하는데 화면은 '복원 중...'만 표시했다
  (buyPremium 은 재확인하는데 복원만 빠진 복붙-한쪽만-수정 패턴). 가용성 재확인
  + 실패 시 에러 표시
- **iOS 미로그인 유저에게 자동 복원 로그인 팝업이 매 실행 반복** — 팝업 취소가
  예외로 떨어져 완료 플래그가 영영 안 섰다. 시도 3회 상한
- purchaseStream 구독을 관리자 기기 분기보다 앞으로 — 관리자 기기 결제 QA 복구

#### 시작 성능
- **콜드 스타트가 AdMob SDK + 스토어 왕복 2회 + DB 초기화의 직렬 합이던 문제**
  — 첫 프레임 전에는 프리미엄 캐시 복원(로컬)과 DB 워밍업만 병렬로 기다리고,
  AdMob SDK·스토어 연결은 첫 프레임 이후로 이동. 최초 설치 첫 실행에서
  스플래시 위로 Apple ID 로그인 시트가 뜨던 경로도 함께 제거
- 신규 설치·v6 마이그레이션이 리비전을 안 남겨 직후 1000문항 동기화를 한 번 더
  돌던 중복 제거 (첫 실행 스플래시 배가 원인)

#### 데이터 무결성
- **문제 동기화가 일부 파일 실패에도 리비전을 기록하던 문제** — 그 기기에서 해당
  리비전의 정답 수정이 영영 재시도되지 않았다. 실패를 전파해 리비전 기록을 막고,
  v6 마이그레이션 경로에서는 openDatabase 를 죽이지 않게 격리
- DB getter 경합 수정 — 동시 초기화 2회로 문항이 중복 INSERT 되던 창을
  Future 메모이제이션으로 봉쇄
- 본문(questionText/codeSnippet) 수정 금지 규칙 문서화 — 동기화 키라서 고치면
  영구 중복이 생긴다. 고쳐야 하면 DB 버전을 올리고 마이그레이션으로

#### 채점
- 항목별 설명 괄호 정답("POST(Create), GET(Read)...")에서 괄호 뺀 교과서적
  정답이 오답 처리되던 문제 (최소 5문항, 유료 유저 직격)
- C 의 ±32 대소문자 변환 문항에서 입력을 그대로 옮겨 적어도 정답이 되던 문제
- "Delivery(또는 Deployment)" 류 괄호를 대체어로 해석 — 의도된 대안이 오답,
  무의미한 "또는 Deployment" 단독이 정답이던 역전 수정

#### iOS 심사
- **PrivacyInfo.xcprivacy 를 Runner 타깃 Resources 에 실제 등록** — 파일만 있고
  pbxproj 미등록이라 번들에 포함되지 않았다 (커밋 71b9634 가 no-op 이었음)

#### UX
- 모의고사 결과 '다시 풀기' 연타 시 응시권 2회 소모 + Timer 누수 — 재진입 가드
- '다시 풀기' 후 광고 주기가 이전 세션 잔여값에서 이어지던 것 리셋 (두 화면)
- 쿼터 다이얼로그 '광고 준비 중...' 라벨이 로드 완료 시 갱신되도록 폴링
- 추정 시험일에 '(예정)' 표시 + 추정 일정에는 D-Day 단정 알림 미발송
- 추정 회차가 이미 치른 확정 회차를 D-DAY 로 재표시하던 문제
- 복습 큐가 비면 기존 예약 알림 취소 (마지막 문제 졸업 후 유령 알림 제거)
- 부제 연도·'2020~2026년' 하드코딩을 시험 일정 기반으로
- QuestionCard 헤더가 좁은 화면 × 큰 글씨에서 우측 오버플로 — 배지 Flexible 화

#### 검증
- 테스트 145건 → **155건**. `analyze` 경고 0건
- 리워드 광고 **시청 → 지급 배선** 위젯 테스트 신설 — 가드 제거·지급 제거
  뮤테이션 2종이 실제로 실패함을 확인하고 넣었다
- grep 배선 테스트가 주석에도 매칭되던 구멍 수정 — 호출을 주석 처리해 되돌리면
  이제 실패한다
- 통계 탭 재조회 배선, QuestionCard 오버플로 회귀 테스트 추가

> **미수정 (다음 판):** 리워드 광고 단위 ID 교체(사람: AdMob 콘솔), code_reading
> 대소문자 전면 접기 판단(#21), 회차별 문제집 테스트 공백(#23), app_test 연타
> 테스트 공회전(#25)

### v1.6.0+24 (2026-08-08)

다중 에이전트 감사·QA(총 330여 개 에이전트)로 확정된 결함을 정리하고,
3회차 시험 대비 기능 3건을 추가했다.

#### 새 기능
- **복습 알림** — 에빙하우스 반복 엔진은 처음부터 있었지만 알려줄 수단이 없어
  절반만 돌고 있었다. 복습 시기와 D-30/7/1 을 알림으로 연결.
  권한은 첫 실행이 아니라 "틀린 문제가 쌓인" 시점에만 제안한다
- **합격 예측 점수** — 실기 60점 합격 기준으로 환산. 유형별 배점(코드분석 40%,
  SQL 30%, 단답형 30%)을 가중하고, 표본이 적으면 합격선 쪽으로 축소 보정한다
- **리워드 광고** — 모의고사 무료 1회를 다 쓰면 광고를 보고 1회 더.
  새 수익원이자 프리미엄 체험 통로. 하루 보너스 상한 2회

#### 주요 수정 (상세는 docs/AUDIT_TODO.md)
- 결제: 재시작 시 프리미엄 소실, 스토어 연결 실패 시 결제 미반영, 자동 복원,
  저장 실패 시 트랜잭션 종결, 백업으로 인한 프리미엄 복제
- 채점: 여러 줄 정답(125문항), 엔터 줄바꿈, 순서 채점, 대소문자, 괄호 표기
- 데이터: 정답 오류 6건 + 기존 유저 반영 마이그레이션(DB v6, id 보존)
- 학습: 문제은행 풀이 DB 미기록, 오답노트 영구 미졸업, 복습 간격 1분 고정
- 광고: 전면광고 영구 중단, 동시 로드 유실, 채점 결과를 덮는 타이밍, ATT 순서
- 통계: 자동 갱신 부재, 완료율 중복 집계, 플랜 정답률 100% 고정

#### 검증 체계
- 테스트 27건 → **109건**. `analyze` 경고 0건
- **배선 테스트 도입** — 이 앱의 반복 실패 패턴은 "부품은 멀쩡한데 연결이 빠진 것"
  이었다. 실제로 핵심 수정 3개를 되돌려도 기존 테스트 77건이 전부 통과했다.
  이제 연결 자체를 검증한다
- **시뮬레이터 실행 검증 복구** — `SUPPORTED_PLATFORMS = iphoneos` 때문에
  시뮬레이터 빌드가 아예 불가능했다. 통합 테스트도 D-Day 타이머 때문에
  `pumpAndSettle` 이 영원히 끝나지 않아 한 번도 실행된 적이 없었다. 둘 다 복구

### v1.5.4+23 (2026-08-07)

49개 에이전트 다중 영역 감사에서 확정된 결함들을 수정. 이번 판의 뿌리는 **복붙된 로직 중 한쪽만 고쳐지는 패턴**과 **로직 사본을 검증해 진짜 결함을 가려주던 테스트**였다.

#### 결제 (수익 직결)
- **앱 재시작 시 결제한 프리미엄이 소멸되던 문제**
  - 원인: `completePurchase()`로 종결된 트랜잭션은 재시작 시 `purchaseStream`으로 재전달되지 않는데, 복원 경로가 구독 화면의 수동 "복원" 버튼 하나뿐이라 유저가 도달할 방법이 없었음
  - 조치: `shared_preferences`에 구매를 영속 저장하고 스토어 통신보다 **먼저** 읽어 복원. 오프라인·스토어 장애에서도 유지됨
- **스토어 초기 연결이 실패하면 결제해도 프리미엄이 켜지지 않던 문제**
  - 원인: `isAvailable()`이 false면 그 앞에서 `return` 해 `purchaseStream` 구독 자체가 생성되지 않았음. 그 세션에서는 결제가 완료돼도 콜백이 오지 않음
  - 조치: 구독을 스토어 가용성과 무관하게 최우선으로 건다
- **재설치·기기변경 시 평생 이용권을 잃던 문제** — 설치당 1회 자동 복원 추가. 매 실행 복원은 iOS에서 App Store 로그인 팝업을 유발할 수 있어 1회로 제한
- `InAppPurchase.instance`를 지연 평가로 변경 — 서비스 생성만으로 스토어 연결이 시작되던 것을 제거

#### 채점 (스토어 리뷰 접수 건)
- **정답을 제대로 입력해도 오답 처리되던 문제**
  - 전체 1000문항 중 **125문항(12.5%)** 은 정답이 여러 줄이다 (실행 결과 문제, 예: `3\n1`)
  - 원인 ①: 문제은행 탭만 단순 문자열 비교라 이 125문항이 **입력값과 무관하게 100% 오답**
  - 원인 ②: 입력창이 한 줄짜리라 줄을 나누려 엔터를 누르면 줄바꿈 대신 즉시 제출 → 첫 줄만 채점
  - 조치: 채점 로직을 `services/answer_checker.dart` 정본으로 통합(3벌 복붙 제거), 입력창을 `widgets/answer_input_field.dart`로 통합. 정답이 여러 줄이면 엔터=줄바꿈, 한 줄이면 엔터=제출
- **순서가 뒤바뀐 오답이 정답 처리되던 문제** (감사에서 269문항 영향으로 지목)
  - 원인: 나열 순서를 항상 무시했는데, 실행 결과·`ORDER BY`·"순서대로 쓰시오" 문항은 순서가 곧 정답
  - 조치: **기본을 순서 엄격**으로 바꾸고, 지문이 "모두 쓰시오" 류일 때만 순서를 무시
- `Set == Set`은 Dart에서 원소 비교가 아닌 **객체 동일성 비교**라 "순서 무관" 규칙이 처음부터 죽어 있었음 → 다중집합 비교로 교체 (중복 항목도 정확히 비교)
- 쉼표까지 지워 비교하던 것을 공백만 제거하도록 되돌림 — 항목 경계가 사라져 서로 다른 문항의 정답이 충돌하던 오탐 제거

#### 학습 데이터
- **오답노트가 영원히 비워지지 않던 문제** — 호출부가 오답일 때만 `processAnswer`를 불러 stage 승격이 아예 일어나지 않았음
- **에빙하우스 복습 간격이 항상 1분에 고정되던 문제** — 위와 같은 뿌리. stage가 0에서 올라가질 못했음
  - 조치: 정답일 때도 항상 호출하고, "오답만 큐에 진입" 규칙은 `SpacedRepetitionService` 내부 가드로 이동

#### DB 마이그레이션
- **DB v1·v2 유저가 업데이트하면 앱이 DB를 영영 열지 못하던 문제** (치명)
  - 원인: `_createStudyPlanTables`가 `plan_type`을 **포함해** 테이블을 만드는데 `_addPlanTypeColumn`이 무조건 `ALTER TABLE ADD COLUMN`을 실행 → `duplicate column` 예외. `onUpgrade`에서 던진 예외는 `openDatabase` 전체를 실패시킨다
  - 조치: `PRAGMA table_info`로 컬럼 존재를 확인해 멱등화
  - 실기기로는 구버전 빌드를 설치해야 재현되므로 `test/db_migration_test.dart`로 검증.
    구버전 스키마(v3·v4)와 신버전 스키마(v1·v2 경로)를 모두 재현하고, **구 구현이 실제로
    예외를 던지는지까지 테스트로 못박아** 테스트가 헛돌지 않음을 보장

#### 테스트 (반복 실패의 근본 원인)
- 기존 테스트가 채점 로직의 **사본**을 검증하고 있어, 앱이 틀려도 통과했음 → 정본 호출로 교체
- 구매 영속화 테스트가 **읽기만** 검증해 저장 코드를 지워도 통과했음 → `grantPremium`에 테스트 seam을 두고 쓰기·읽기 왕복을 검증
- 광고 간격 테스트가 v1.5.0+20의 5→3 변경 이후 계속 깨져 있던 것을 수정
- `test/answer_checker_test.dart` 신설 — 여러 줄 정답, 순서 채점, 다중집합 비교 회귀 방지

#### 광고 (수익 직결)
- **전면광고가 영구히 표시되지 않게 되던 문제**
  - 원인: `onAdFailedToLoad`가 무조건 `_isAdLoaded = false`로 덮어써서, 이미 로드해둔
    광고가 멀쩡히 있어도 사용 불가 상태가 됐음. 그러면 `showInterstitialAd()`가
    다시 로드를 걸고 또 실패하면 같은 상태에 갇혀 전면광고 수익이 끊긴다
  - 조치: 로드된 광고가 있으면 실패 콜백이 상태를 건드리지 않도록 변경
- **동시 로드로 광고가 유실되던 문제** — `showInterstitialAd()`가 준비 안 됐을 때마다
  로드를 걸어(3문제마다) 여러 개가 겹쳤고, 나중 성공분이 앞의 광고를 `dispose` 없이
  덮어썼음. 네이티브 누수 + AdMob fill 낭비 → 로드 중복 가드 추가
- 전면광고 프리로드를 프리미엄 판정 이후로 이동 — 결제 유저의 불필요한 광고 요청 제거
- 위 두 건은 플러그인 콜백 내부라 단위 테스트가 어렵다. **실기기 logcat 확인 필요**

> **미수정 (다음 판):** 문제은행 탭 풀이가 DB에 기록되지 않는 문제, 학습플랜 정답률 100% 고정, 통계 자동 갱신 부재, 구독 화면의 프리미엄 상태 미반영, 전면광고 로드 실패 시 수익 중단, 문제 데이터 오답 3건(`c_questions` 22번 오타, `sql_questions` 2·65번 HAVING 조건).

### v1.5.3+22 (2026-04-26)
- 광고 누락 진입점 fix: `past_exam_screen.dart`의 `_QuizScreen`, `ai_prediction_screen.dart`에 배너+전면 광고 코드 추가
  - v1.5.0+20 배너광고 도입 시 두 화면이 누락되어 문제은행/AI 예측 진입 사용자에게 광고 0회 노출
  - 갤럭시탭(R54MA030SMD) 실기기 logcat으로 전 경로 광고 송출 검증 완료
- AdMob W-8BEN 세금 정보 제출 (서비스 0% 원천징수, 만료 2029-12-31) — 진단 중 발견한 fill rate 저하 부수 원인

## 라이선스

MIT License
