# 기사패스마스터 (gisa_pass_master)

> 2026 정보처리기사 실기 스파르타 예측 학습 앱

시험일까지 남은 시간을 실시간으로 보여주며, AI 출제 예측 엔진과 에빙하우스 망각곡선 기반 오답 반복 시스템으로 유저를 합격까지 밀어붙이는 학습 앱입니다.

## 주요 기능

### D-Day 실시간 카운트다운
- 시험일까지 남은 일/시/분/초를 빨간색으로 표시
- 절박함을 시각적으로 전달하는 다크 UI

### AI 출제 예측 엔진
- 2023~2025년 기출 빈도 기반 가중치 계산
- `priority_score = 빈출도(40%) + 최신성(30%) + 유형가중치(20%) + 약점(10%)`
- 코드 읽기, SQL 문제를 최우선으로 출제

### 스파르타 오답노트
- 에빙하우스 망각곡선 기반 8단계 간격 반복 (1분 ~ 14일)
- 정답 시 다음 단계로 승격, 오답 시 2단계 강등
- 복습 시기가 된 문제를 자동으로 큐에 올림

### 다크 모드 코드 뷰어
- VS Code 스타일 Syntax Highlighting
- C, Java, SQL 키워드별 색상 구분
- 모노스페이스 폰트로 코드 가독성 극대화

### 정답/오답 이펙트
- 정답: 초록색 플래시 + 체크 아이콘 애니메이션
- 오답: 빨간색 셰이크 + X 아이콘 경고

### 학습 통계
- 전체/오늘 풀이 수 및 정답률
- 과목별, 유형별 정답률 분석
- 연속 학습일 트래킹

### AdMob 전면광고
- 연속 5문제 풀이 후 인터스티셜 광고 표시
- Google 테스트 광고 ID 적용 (프로덕션 전환 시 교체)

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
├── config.dart                  # 앱 설정 (템플릿 변수)
├── main.dart                    # 엔트리포인트 + MultiProvider
├── models/
│   ├── question.dart            # 문제 모델
│   ├── answer_record.dart       # 풀이 기록 모델
│   └── study_stats.dart         # 학습 통계 모델
├── services/
│   ├── database_service.dart    # SQLite 스키마 + CRUD
│   ├── question_seed_data.dart  # 초기 더미 데이터 10문제
│   ├── prediction_engine.dart   # 출제 예측 엔진
│   ├── spaced_repetition_service.dart  # 에빙하우스 반복
│   └── ad_service.dart          # AdMob 전면광고
├── providers/
│   ├── study_provider.dart      # 퀴즈 플로우 상태 관리
│   └── stats_provider.dart      # 통계 상태 관리
├── screens/
│   ├── home_screen.dart         # 메인 (D-Day + 모드 선택)
│   ├── quiz_screen.dart         # 문제 풀이
│   ├── wrong_answer_screen.dart # 스파르타 오답노트
│   └── stats_screen.dart        # 학습 통계
└── widgets/
    ├── dday_timer.dart          # D-Day 카운트다운
    ├── code_viewer.dart         # 다크 코드 뷰어
    ├── answer_effect.dart       # 정답/오답 이펙트
    └── question_card.dart       # 문제 카드
```

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
flutter run -d macos     # macOS (Xcode 필요)
flutter run               # 연결된 모바일 디바이스
```

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

## 시드 데이터

초기 10문제가 포함되어 있습니다:
- C 포인터 변수 출력
- C 배열 반복문 합계
- Java 상속 오버라이딩
- Java 추상 클래스 구현
- SQL SELECT JOIN
- SQL GROUP BY HAVING
- SQL 서브쿼리
- OSI 7계층 순서
- 디자인 패턴 (팩토리 메서드)
- 소프트웨어 테스트 기법 (경계값 분석)

## 변경 이력

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

#### 테스트 (반복 실패의 근본 원인)
- 기존 테스트가 채점 로직의 **사본**을 검증하고 있어, 앱이 틀려도 통과했음 → 정본 호출로 교체
- 구매 영속화 테스트가 **읽기만** 검증해 저장 코드를 지워도 통과했음 → `grantPremium`에 테스트 seam을 두고 쓰기·읽기 왕복을 검증
- 광고 간격 테스트가 v1.5.0+20의 5→3 변경 이후 계속 깨져 있던 것을 수정
- `test/answer_checker_test.dart` 신설 — 여러 줄 정답, 순서 채점, 다중집합 비교 회귀 방지

#### 기타
- 전면광고 프리로드를 프리미엄 판정 이후로 이동 — 결제 유저의 불필요한 광고 요청 제거

> **미수정 (다음 판):** 문제은행 탭 풀이가 DB에 기록되지 않는 문제, 학습플랜 정답률 100% 고정, 통계 자동 갱신 부재, 구독 화면의 프리미엄 상태 미반영, 전면광고 로드 실패 시 수익 중단, 문제 데이터 오답 3건(`c_questions` 22번 오타, `sql_questions` 2·65번 HAVING 조건).

### v1.5.3+22 (2026-04-26)
- 광고 누락 진입점 fix: `past_exam_screen.dart`의 `_QuizScreen`, `ai_prediction_screen.dart`에 배너+전면 광고 코드 추가
  - v1.5.0+20 배너광고 도입 시 두 화면이 누락되어 문제은행/AI 예측 진입 사용자에게 광고 0회 노출
  - 갤럭시탭(R54MA030SMD) 실기기 logcat으로 전 경로 광고 송출 검증 완료
- AdMob W-8BEN 세금 정보 제출 (서비스 0% 원천징수, 만료 2029-12-31) — 진단 중 발견한 fill rate 저하 부수 원인

## 라이선스

MIT License
