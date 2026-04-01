import 'package:flutter/material.dart';

/// 앱 전체 설정 - 이 파일만 수정하면 다른 자격증 앱으로 변환 가능
class AppConfig {
  AppConfig._();

  // === 앱 기본 정보 ===
  static const String appTitle = '기사패스마스터';
  static const String appSubtitle = '2026 정보처리기사 실기';
  static const String examLabel = '정보처리기사 실기 시험';

  // === 시험 날짜 (D-Day 타이머용) ===
  static final DateTime examDate = DateTime(2026, 4, 18);

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
  static const int adIntervalQuestions = 5; // N문제마다 전면광고

  // === 문제 유형 라벨 (한글) ===
  static const Map<String, String> questionTypeLabels = {
    'code_reading': '코드 분석',
    'sql': 'SQL',
    'short_answer': '단답형',
  };

  // === 구독 설정 ===
  static const int premiumMonthlyPrice = 4900; // 원
  static const int freeTrialDays = 7;

  // === 과목 라벨 ===
  static const Map<String, IconData> questionTypeIcons = {
    'code_reading': Icons.code,
    'sql': Icons.storage,
    'short_answer': Icons.edit_note,
  };
}
