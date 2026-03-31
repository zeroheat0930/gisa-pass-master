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

## 라이선스

MIT License
