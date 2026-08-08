import 'package:flutter/material.dart';

import '../config.dart';
import '../models/study_stats.dart';
import '../services/pass_predictor.dart';

/// 합격 예측 점수 카드.
///
/// 실기는 60점 합격이다. "정답률 47%"보다 "지금 보면 47점, 합격까지 13점"이
/// 훨씬 강한 동기부여가 된다. D-Day 바로 아래에 둔다.
class PassScoreCard extends StatelessWidget {
  final StudyStats stats;
  final VoidCallback? onTap;

  const PassScoreCard({super.key, required this.stats, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = PassPredictor.predict(stats);

    if (p.grade == PassGrade.insufficient) {
      return _shell(
        accent: Colors.grey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('합격 예측', Colors.grey[400]!),
            const SizedBox(height: 8),
            Text(
              '${PassPredictor.minimumSample}문제만 풀면 예상 점수를 알려드려요',
              style: TextStyle(color: Colors.grey[300], fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              '지금까지 ${p.sampleSize}문제',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      );
    }

    final accent = switch (p.grade) {
      PassGrade.safe => AppConfig.correctColor,
      PassGrade.borderline => AppConfig.warningColor,
      _ => AppConfig.primaryColor,
    };

    final headline = switch (p.grade) {
      PassGrade.safe => '합격권입니다. 이대로 유지하세요.',
      PassGrade.borderline => '아슬아슬합니다. 오답노트를 비우세요.',
      _ => '합격까지 ${p.gap}점 남았습니다.',
    };

    return _shell(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 좁은 화면(320pt) + 큰 글씨 배율에서 Row 가 넘치던 것을 막는다.
          // 접근성 설정으로 글씨를 키운 유저에게 레이아웃이 깨져 보이면 안 된다.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: _label('지금 시험 보면', Colors.grey[400]!),
              ),
              const SizedBox(width: 8),
              Text(
                '합격 ${PassPredictor.passingScore}점',
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  '${p.score}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text('점',
                  style: TextStyle(
                      color: accent, fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 8, color: Colors.white.withValues(alpha: 0.08)),
                FractionallySizedBox(
                  widthFactor: (p.score / 100).clamp(0.0, 1.0),
                  child: Container(height: 8, color: accent),
                ),
                // 합격선 표식
                FractionallySizedBox(
                  widthFactor: PassPredictor.passingScore / 100,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 2,
                      height: 8,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            headline,
            style: TextStyle(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${p.sampleSize}문제 풀이 기준 · 유형별 배점 반영',
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, Color color) => Text(
        text,
        style: TextStyle(color: color, fontSize: 12, letterSpacing: 0.5),
      );

  Widget _shell({required Color accent, required Widget child}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppConfig.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.5),
        ),
        child: child,
      ),
    );
  }
}
