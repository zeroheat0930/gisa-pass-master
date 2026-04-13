import 'package:flutter/material.dart';
import '../config.dart';
import '../models/question.dart';
import 'code_viewer.dart';

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
            Row(
              children: [
                _Badge(
                  label: question.subject,
                  color: const Color(0xFF9C27B0),
                ),
                const SizedBox(width: 8),
                _Badge(
                  label: _typeLabel,
                  color: _typeColor,
                ),
                const Spacer(),
                Text(
                  'AI 예측',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
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
            Text(
              question.questionText,
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
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
