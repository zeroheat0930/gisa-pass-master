import 'package:flutter/material.dart';
import '../config.dart';
import '../models/question.dart';
import 'code_viewer.dart';
import 'question_text.dart';

class QuestionCard extends StatelessWidget {
  final Question question;

  const QuestionCard({super.key, required this.question});

  String get _typeLabel {
    switch (question.questionType) {
      case 'code_reading':
        return '코드 분석';
      case 'sql':
        return 'SQL';
      case 'short_answer':
        return '단답형';
      default:
        return question.questionType;
    }
  }

  Color get _typeColor {
    switch (question.questionType) {
      case 'code_reading':
        return const Color(0xFF569CD6);
      case 'sql':
        return const Color(0xFFCE9178);
      case 'short_answer':
        return AppConfig.correctColor;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppConfig.cardColor,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppConfig.borderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: subject badge + type badge + year/round
            // 배지는 Flexible 로 감싼다 — 좁은 화면 × 큰 글씨 배율에서
            // 과목명이 길면 Row 가 우측으로 넘친다 (W320 × 1.2배부터 재현).
            Row(
              children: [
                Flexible(
                  child: _Badge(
                    label: question.subject,
                    color: const Color(0xFF9C27B0),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: _Badge(
                    label: _typeLabel,
                    color: _typeColor,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    // **문항 데이터의 source 만 믿는다.** 연도로 추측하면 안 된다.
                    // 한때 2025년 이하를 '기출' 로 표시한 적이 있는데, 실제 실기는
                    // 회차당 20문항인 반면 AI 데이터는 회차당 40~60문항이라
                    // 기출일 수 없었다. 유저를 속이는 표기였다.
                    question.isRestored ? '복원 기출' : 'AI 예상',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: question.isRestored
                          ? AppConfig.correctColor
                          : Colors.grey[500],
                      fontSize: 12,
                      fontWeight:
                          question.isRestored ? FontWeight.w700 : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Difficulty stars
            Row(
              children: List.generate(5, (i) {
                return Icon(
                  i < question.difficulty ? Icons.star : Icons.star_border,
                  size: 16,
                  color: i < question.difficulty
                      ? const Color(0xFFFFC107)
                      : Colors.grey[700],
                );
              }),
            ),
            const SizedBox(height: 16),

            // Question text
            QuestionText(
              text: question.questionText,
              style: const TextStyle(
                color: Color(0xFFE0E0E0),
                fontSize: 16,
                height: 1.6,
              ),
            ),

            // Code snippet (if present)
            if (question.codeSnippet != null &&
                question.codeSnippet!.isNotEmpty) ...[
              const SizedBox(height: 16),
              CodeViewer(
                code: question.codeSnippet!,
                language: question.codeLanguage ?? 'c',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
