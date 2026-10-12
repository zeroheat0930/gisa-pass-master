import 'package:flutter/material.dart';

/// 앱 전체 설정 - 이 파일만 수정하면 다른 자격증 앱으로 변환 가능
class AppConfig {
  AppConfig._();

  /// 테스트에서 '오늘'을 고정하기 위한 시임. 프로덕션에서는 항상 null 이다.
  ///
  /// D-Day 문구는 남은 일수에 따라 노출 여부가 갈리는데, 실제 날짜에 의존하면
  /// 시험일이 지나는 순간 테스트가 조용히 반대 분기만 검증하게 된다.
  @visibleForTesting
  static DateTime Function()? nowForTest;

  static DateTime _now() => nowForTest?.call() ?? DateTime.now();

  /// 앱 전체가 쓰는 '지금' (단일 정본). [nowForTest] 를 반영한다.
  ///
  /// 화면마다 `DateTime.now()` 를 따로 부르면 테스트에서 시각을 고정해도 일부만
  /// 따라와서, D-Day 타이머가 D-N 은 고정 시각으로, 시:분:초는 실제 시각으로
  /// 계산하는 식으로 어긋났다.
  static DateTime get now => _now();

  // === 앱 기본 정보 ===
  static const String appTitle = '기사패스마스터';
  static const String examLabel = '정보처리기사 실기 시험';

  /// 부제. 연도는 다음 시험 기준으로 따라간다 — 상수로 박아두면
  /// 해가 바뀌어도 화면에 옛 연도가 그대로 남는다.
  static String get appSubtitle => '${nextExam.year} 정보처리기사 실기';

  // === 시험 일정 (자동으로 다음 회차 전환) ===
  // 큐넷은 기사 실기를 기간(3회: 10.24~11.13)으로만 공지한다. 정보처리기사
  // 필답형은 그 안의 하루에 전국 동시 시행되며, 날짜는 에듀온 시험일정 기준이다.
  // (2026-10 사용자 제보로 3회 10/18 → 10/25, 2회 7/5 → 7/19 정정)
  static final List<({int year, int round, DateTime date})> _examSchedule = [
    (year: 2026, round: 1, date: DateTime(2026, 4, 18)),
    (year: 2026, round: 2, date: DateTime(2026, 7, 19)),
    (year: 2026, round: 3, date: DateTime(2026, 10, 25)),
    // 2027년 일정은 큐넷 공고(통상 11~12월) 뒤에 넣는다. 공고 전 날짜를 여기
    // 넣으면 '(예정)' 없이 확정으로 표시되고 알림까지 예약된다 — 올해 2·3회
    // 날짜도 틀려서 사용자 제보로 고쳤다.
  ];

  // === 시험 시각 ===
  // 정보처리기사 실기 필답형: 입실 09:00, 시작 09:30 — 큐넷 공고 기준, 바뀌면 여기만.
  // 소요 150분이라 12:00 에 끝난다. D-Day 카운트다운은 '시작 시각' 을 겨냥하고,
  // 시작~종료 사이는 '시험 진행 중', 종료 뒤로는 '수고하셨습니다' 로 바뀐다.
  static const int examStartHour = 9;
  static const int examStartMinute = 30;
  static const int examDurationMinutes = 150;

  /// [examDay] 의 시험 시작 시각.
  static DateTime examStartOn(DateTime examDay) => DateTime(examDay.year,
      examDay.month, examDay.day, examStartHour, examStartMinute);

  /// [examDay] 의 시험 종료 시각.
  static DateTime examEndOn(DateTime examDay) =>
      examStartOn(examDay).add(const Duration(minutes: examDurationMinutes));

  /// 시험 다음날부터 며칠 동안 '수고하셨습니다' 를 보여줄지.
  static const int examAftercareDays = 3;

  /// 오늘 기준 1~[examAftercareDays]일 전에 치러진 **확정** 시험. 없으면 null.
  ///
  /// 시험 다음날 자정이면 [nextExam] 이 이미 다음 회차(대개 추정치)로 넘어가서,
  /// 시험 본 다음날 아침 홈에 곧장 'D-174' 가 뜬다. 방금 시험을 치른 유저에게는
  /// 며칠간 마무리 인사를 먼저 보여준다. 추정 일정은 실제로 치러졌는지 모르므로
  /// 대상이 아니다.
  static ({int year, int round, DateTime date})? get recentlyFinishedExam {
    final n = _now();
    final today = DateTime.utc(n.year, n.month, n.day);
    for (final exam in _examSchedule.reversed) {
      final d = DateTime.utc(exam.date.year, exam.date.month, exam.date.day);
      final daysAgo = today.difference(d).inDays;
      if (daysAgo >= 1 && daysAgo <= examAftercareDays) return exam;
    }
    return null;
  }

  /// 추정 날짜를 가장 가까운 주말(토·일)로 옮긴다. 같은 거리면 일요일.
  ///
  /// 통상 월/일을 해마다 그대로 쓰면 요일이 밀려 평일이 나온다(2027년 2회
  /// 7/19 월요일, 3회 10/25 월요일). 실기는 주말에 시행되므로 평일 날짜를
  /// 보여주면 '(예정)' 이라도 틀린 정보다.
  static DateTime _nearestWeekend(DateTime date) {
    // weekday: 월=1 … 토=6, 일=7
    final wd = date.weekday;
    if (wd >= DateTime.saturday) return date;
    final back = wd; // 직전 일요일까지 (월 1 · 화 2 · 수 3 …)
    final fwd = DateTime.saturday - wd; // 다음 토요일까지 (… 수 3 · 목 2 · 금 1)
    // 수요일은 3:3 동률 → 일요일(뒤로).
    final shift = back <= fwd ? -back : fwd;
    return DateTime(date.year, date.month, date.day + shift);
  }

  /// 확정 일정이 모두 지났을 때 쓰는 회차별 통상 시행 월/일.
  /// 실기는 매년 1회 4월 / 2회 7월 / 3회 10월 경에 시행된다.
  static const List<({int month, int day})> _typicalExamDates = [
    (month: 4, day: 18),
    (month: 7, day: 19),
    (month: 10, day: 25),
  ];

  /// 다음 시험 정보 (자동 전환)
  ///
  /// 확정 일정을 먼저 쓰고, 전부 지났으면 통상 시행 시기로 **추정해서 이어간다.**
  /// 예전에는 마지막 항목을 그대로 반환해서, 표에 적힌 마지막 시험일이 지나면
  /// D-Day 가 영영 '시험 완료!' 에 갇혔다.
  static ({int year, int round, DateTime date}) get nextExam {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);

    for (final exam in _examSchedule) {
      if (!exam.date.isBefore(today)) return exam;
    }
    return _projectNextExam(today);
  }

  /// 확정 일정이 바닥났을 때 다음 회차를 추정한다.
  static ({int year, int round, DateTime date}) _projectNextExam(DateTime today) {
    // 확정 일정에 이미 있는 (연도, 회차) 는 추정으로 다시 내놓지 않는다.
    // 예: 2027-1회가 4/17(확정) 시행됐는데, 통상일인 4/18 하루 동안
    // 같은 1회가 'D-DAY' 로 재표시되던 문제.
    final held = _examSchedule.map((e) => (e.year, e.round)).toSet();

    for (var year = today.year; year <= today.year + 5; year++) {
      for (var i = 0; i < _typicalExamDates.length; i++) {
        if (held.contains((year, i + 1))) continue;
        final d = _typicalExamDates[i];
        // 주말 보정 뒤에 오늘과 비교한다 — 보정이 날짜를 앞당길 수 있다.
        final date = _nearestWeekend(DateTime(year, d.month, d.day));
        if (!date.isBefore(today)) {
          return (year: year, round: i + 1, date: date);
        }
      }
    }
    // 여기까지 오는 일은 없지만, 그래도 과거 날짜를 반환하지는 않는다.
    return (
      year: today.year + 1,
      round: 1,
      date: _nearestWeekend(DateTime(today.year + 1,
          _typicalExamDates.first.month, _typicalExamDates.first.day)),
    );
  }

  /// 지금 보고 있는 시험일이 확정 일정인지(= 공고된 날짜인지).
  /// 추정치면 화면에 '예정' 표시를 붙여 유저를 오도하지 않는다.
  static bool get isExamDateConfirmed {
    final target = nextExam.date;
    return _examSchedule.any((e) =>
        e.date.year == target.year &&
        e.date.month == target.month &&
        e.date.day == target.day);
  }

  static DateTime get examDate => nextExam.date;

  /// [day] 당일 또는 그 이후의 첫 **확정** 시험일. 확정 일정이 바닥났으면
  /// (추정 경로) null — 추정 날짜로 D-문구를 단언하면 거짓 표기가 된다.
  ///
  /// 학습 플랜 미션 문구용이다. [nextExam] 은 '오늘' 기준이라 시험이 지나면
  /// 다음 회차로 넘어가 버려서, 플랜이 겨냥한 시험을 알려면 플랜 시작일로 찾아야 한다.
  static DateTime? confirmedExamOnOrAfter(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    for (final exam in _examSchedule) {
      if (!exam.date.isBefore(d)) return exam.date;
    }
    return null;
  }

  /// 시험까지 남은 일수 (달력 기준, 단일 정본).
  ///
  /// `examDate.difference(now).inDays` 를 쓰면 남은 시간을 24로 나눈 값이라
  /// 시험 전날 밤에 이미 0이 되어 D-Day 가 하루씩 적게 표시된다.
  static int get daysUntilExam {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final exam = DateTime(examDate.year, examDate.month, examDate.day);
    final diff = exam.difference(today).inDays;
    return diff < 0 ? 0 : diff;
  }
  static String get examRoundLabel => '${nextExam.year}년 ${nextExam.round}회';

  /// D-Day 문구를 화면에 내보내도 되는 기간(일).
  static const int examCountdownWindowDays = 60;

  /// 남은 일수를 판매 문구에 써도 되는 시점인지 (단일 정본).
  ///
  /// 두 조건이 모두 필요하다. 시험일이 지나면 다음 회차로 넘어가 D-181 같은
  /// 값이 나오고(문구가 헛소리가 된다), 확정 일정이 바닥나면 [nextExam] 은
  /// **추정치**라 그 날짜로 남은 일수를 단언하면 거짓 표기가 된다.
  static bool get shouldShowExamCountdown =>
      isExamDateConfirmed && daysUntilExam <= examCountdownWindowDays;

  /// 판매 문구 뒤에 붙는 D-Day 꼬리표 (단일 정본). 노출 여부 판단까지 여기서 끝낸다.
  ///
  /// 이 조립을 화면마다 따로 갖고 있으면 이 저장소의 반복된 실패 패턴이 그대로
  /// 재발한다 — 같은 것을 복붙하고 한쪽만 고치는 것. 구분자(` · `)까지 포함해
  /// 돌려주므로 호출부는 자기 문구 뒤에 **붙이기만** 한다.
  ///
  /// 시험 당일은 'D-0' 이 아니라 홈 D-Day 타이머와 같은 'D-DAY' 로 적는다.
  static String get examCountdownSuffix {
    if (!shouldShowExamCountdown) return '';
    final days = daysUntilExam;
    return days == 0 ? ' · 오늘이 시험일(D-DAY)' : ' · 시험까지 D-$days';
  }

  // === 테마 컬러 ===
  static const Color primaryColor = Color(0xFFE53935);
  static const Color backgroundColor = Color(0xFF121212);
  static const Color cardColor = Color(0xFF1E1E1E);
  static const Color surfaceColor = Color(0xFF1A1A1A);
  static const Color borderColor = Color(0xFF3C3C3C);
  static const Color correctColor = Color(0xFF4CAF50);
  static const Color wrongColor = Color(0xFFE53935);
  static const Color warningColor = Color(0xFFFF6D00);

  // === 데이터베이스 ===
  /// 문의 메일. 앱 안에서 이 주소를 노출하는 곳은 여기 하나만 본다.
  static const String contactEmail = 'zeroheat0930@gmail.com';

  static const String dbName = 'gisa_pass_master.db';

  // === 광고 설정 ===
  static const int adIntervalQuestions = 3; // 3문제마다 전면광고

  // === 문제 유형 라벨 (한글) ===
  static const Map<String, String> questionTypeLabels = {
    'code_reading': '코드 분석',
    'sql': 'SQL',
    'short_answer': '단답형',
  };

  // === 프리미엄 설정 ===
  static const int premiumPrice = 4900; // 원

  // === 과목 라벨 ===
  static const Map<String, IconData> questionTypeIcons = {
    'code_reading': Icons.code,
    'sql': Icons.storage,
    'short_answer': Icons.edit_note,
  };
}
