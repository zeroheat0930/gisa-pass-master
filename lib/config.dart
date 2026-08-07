import 'package:flutter/material.dart';

/// 앱 전체 설정 - 이 파일만 수정하면 다른 자격증 앱으로 변환 가능
class AppConfig {
  AppConfig._();

  // === 앱 기본 정보 ===
  static const String appTitle = '기사패스마스터';
  static const String appSubtitle = '2026 정보처리기사 실기';
  static const String examLabel = '정보처리기사 실기 시험';

  // === 시험 일정 (자동으로 다음 회차 전환) ===
  static final List<({int year, int round, DateTime date})> _examSchedule = [
    (year: 2026, round: 1, date: DateTime(2026, 4, 18)),
    (year: 2026, round: 2, date: DateTime(2026, 7, 5)),
    (year: 2026, round: 3, date: DateTime(2026, 10, 18)),
    (year: 2027, round: 1, date: DateTime(2027, 4, 17)),
  ];

  /// 다음 시험 정보 (자동 전환)
  static ({int year, int round, DateTime date}) get nextExam {
    final now = DateTime.now();
    for (final exam in _examSchedule) {
      final today = DateTime(now.year, now.month, now.day);
      if (!exam.date.isBefore(today)) return exam;
    }
    return _examSchedule.last;
  }

  static DateTime get examDate => nextExam.date;

  /// 시험까지 남은 일수 (달력 기준, 단일 정본).
  ///
  /// `examDate.difference(now).inDays` 를 쓰면 남은 시간을 24로 나눈 값이라
  /// 시험 전날 밤에 이미 0이 되어 D-Day 가 하루씩 적게 표시된다.
  static int get daysUntilExam {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exam = DateTime(examDate.year, examDate.month, examDate.day);
    final diff = exam.difference(today).inDays;
    return diff < 0 ? 0 : diff;
  }
  static String get examRoundLabel => '${nextExam.year}년 ${nextExam.round}회';

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
